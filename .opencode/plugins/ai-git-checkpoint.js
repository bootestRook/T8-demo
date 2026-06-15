import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

function readPolicy(root) {
  const policyPath = join(root, ".ai-git-policy.json");
  if (!existsSync(policyPath)) {
    return { autoCommit: false, commitOnSessionIdle: false };
  }

  try {
    return {
      autoCommit: false,
      commitOnSessionIdle: false,
      ...JSON.parse(readFileSync(policyPath, "utf8"))
    };
  } catch {
    return { autoCommit: false, commitOnSessionIdle: false };
  }
}

export const AiGitCheckpointPlugin = async ({ directory, worktree, client }) => {
  const root = worktree || directory;

  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") {
        return;
      }

      const policy = readPolicy(root);
      if (!policy.autoCommit || !policy.commitOnSessionIdle) {
        return;
      }

      try {
        execFileSync("python", ["scripts/git_ai.py", "checkpoint", "--auto"], {
          cwd: root,
          stdio: "ignore"
        });

        await client.app.log({
          body: {
            service: "ai-git-checkpoint",
            level: "info",
            message: "AI Git checkpoint hook completed"
          }
        });
      } catch (error) {
        await client.app.log({
          body: {
            service: "ai-git-checkpoint",
            level: "warn",
            message: `AI Git checkpoint hook skipped: ${error.message}`
          }
        });
      }
    }
  };
};
