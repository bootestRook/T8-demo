import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { tool } from "@opencode-ai/plugin";

function candidates(command) {
  if (command.includes("/") || command.includes("\\")) {
    return [command];
  }
  return process.platform === "win32" ? [`${command}.cmd`, command] : [command];
}

function run(command, args, cwd) {
  let lastError = null;

  for (const candidate of candidates(command)) {
    try {
      return execFileSync(candidate, args, {
        cwd,
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"]
      }).trim();
    } catch (error) {
      lastError = error;
    }
  }

  const stdout = lastError?.stdout?.toString?.() ?? "";
  const stderr = lastError?.stderr?.toString?.() ?? "";
  throw new Error([stdout, stderr, lastError?.message].filter(Boolean).join("\n"));
}

function pythonScript(script, cwd, extraArgs = []) {
  return run(findPython(cwd), [script, ...extraArgs], cwd);
}

function findPython(cwd) {
  const localCandidates = process.platform === "win32"
    ? [
        join(cwd, "tools", "python", "python.exe"),
        join(cwd, "tools", "python3", "python.exe"),
        join(cwd, "tools", "python.exe")
      ]
    : [
        join(cwd, "tools", "python", "bin", "python3"),
        join(cwd, "tools", "python", "bin", "python")
      ];

  for (const candidate of localCandidates) {
    if (existsSync(candidate)) {
      return candidate;
    }
  }

  return "python";
}

function readJsonOutput(output) {
  try {
    return JSON.parse(output);
  } catch {
    return null;
  }
}

function trimOutput(value, maxChars = 12000) {
  const text = (value || "").trim();
  if (!text) {
    return "(no output)";
  }

  if (text.length <= maxChars) {
    return text;
  }

  return `${text.slice(0, maxChars)}\n... (truncated)`;
}

function appendMachineSummary(lines, summary) {
  lines.push("");
  lines.push("### 机器摘要");
  lines.push("```json");
  lines.push(JSON.stringify(summary, null, 2));
  lines.push("```");
}

function formatExportReport(output) {
  const result = readJsonOutput(output);
  if (!result) {
    const lines = [
      "## Web 导出",
      "",
      "状态：需要检查",
      "",
      "### 技术日志",
      "```text",
      trimOutput(output),
      "```"
    ];
    appendMachineSummary(lines, {
      status: "UNKNOWN",
      command: "python scripts/export_web.py --json",
      nextAction: "查看技术日志并修复导出问题",
      filesToRead: [
        ".agents/skills/godot-smoke-check/SKILL.md",
        "docs/TOOLCHAIN.md"
      ],
      validation: "重新执行 game_export_game"
    });
    return lines.join("\n");
  }

  const success = result.status === "ok";
  const lines = [];
  lines.push("## Web 导出");
  lines.push("");
  lines.push(`状态：${success ? "导出成功" : "导出失败"}`);
  if (result.output_dir) {
    lines.push(`导出路径：${result.output_dir}`);
  }
  lines.push("");
  lines.push("### 下一步");
  if (success) {
    lines.push("- 执行 `game_preview_game` 启动本地预览。");
    lines.push("- 浏览器打开预览地址试玩当前版本。");
  } else {
    lines.push("- 把下方技术日志继续发给 AI，让 AI 自动排查。");
  }
  appendMachineSummary(lines, {
    status: success ? "PASS" : "FAIL",
    command: "python scripts/export_web.py --json",
    nextAction: success ? "启动预览服务器试玩" : "读取运行日志并排查导出失败",
    filesToRead: success
      ? ["docs/AI_WORKFLOW.md", "docs/game-concept.md"]
      : [".agents/skills/godot-smoke-check/SKILL.md", "docs/TOOLCHAIN.md"],
    validation: success ? "浏览器访问 URL 无白屏、可交互" : "修复后重新执行 game_export_game"
  });
  return lines.join("\n");
}

function formatServeReport(output) {
  const result = readJsonOutput(output);
  if (!result) {
    const lines = [
      "## 试玩预览",
      "",
      "状态：需要检查",
      "",
      "### 技术日志",
      "```text",
      trimOutput(output),
      "```"
    ];
    appendMachineSummary(lines, {
      status: "UNKNOWN",
      command: "python scripts/run_web_preview.py --json",
      nextAction: "查看技术日志并修复预览服务器启动",
      filesToRead: [
        "docs/TOOLCHAIN.md"
      ],
      validation: "重新执行 game_preview_game"
    });
    return lines.join("\n");
  }

  const ready = result.status === "ready";
  const lines = [];
  lines.push("## 试玩预览");
  lines.push("");
  lines.push(`状态：${ready ? "已准备好" : "启动失败"}`);
  if (result.url) {
    lines.push(`打开地址：${result.url}`);
  }
  lines.push("");
  lines.push("### 下一步");
  if (ready) {
    lines.push("- 浏览器里试玩当前版本。");
    lines.push("- 回到 OpenCode，直接说哪里不好、哪里想改。");
    lines.push("- AI 改完后需要重新导出（`game_export_game`），然后刷新浏览器即可看到新效果。");
  } else {
    lines.push("- 把下方技术日志继续发给 AI，让 AI 自动排查。");
  }
  lines.push("");
  lines.push("### 技术信息");
  if (result.port) {
    lines.push(`- 端口：${result.port}`);
  }
  if (result.dir) {
    lines.push(`- 目录：${result.dir}`);
  }
  appendMachineSummary(lines, {
    status: ready ? "PASS" : "FAIL",
    command: "python scripts/run_web_preview.py --json",
    nextAction: ready ? "试玩并收集反馈" : "排查预览服务器启动失败",
    url: result.url || "",
    filesToRead: ready
      ? ["docs/AI_WORKFLOW.md", "docs/game-concept.md"]
      : ["docs/TOOLCHAIN.md"],
    validation: ready ? "浏览器访问 URL 无白屏、可交互" : "修复后重新执行 game_preview_game"
  });
  return lines.join("\n");
}

function formatInitReport({ status, commandLine, platform, steps, next, output }) {
  const lines = [];
  lines.push("## 首次初始化结果");
  lines.push("");
  lines.push(`状态：${status === "PASS" ? "成功" : "失败"}`);
  lines.push(`下一步：${next}`);
  lines.push("");
  lines.push("### AI 已完成");
  steps.forEach((step) => {
    lines.push(`- ${step}`);
  });
  lines.push("");
  lines.push("### 技术信息");
  lines.push(`- 平台：${platform}`);
  lines.push(`- 执行命令：\`${commandLine}\``);
  lines.push("");
  lines.push("### 技术日志");
  lines.push("```text");
  lines.push(trimOutput(output));
  lines.push("```");
  appendMachineSummary(lines, {
    status,
    command: commandLine,
    nextAction: next,
    filesToRead: [
      "docs/AI_WORKFLOW.md",
      "docs/game-concept.md",
        "docs/GAME_DESIGN_GUIDE.md",
      "docs/QUALITY_BAR.md"
    ],
    validation: status === "PASS" ? "环境检查已由初始化流程执行" : "查看技术日志并修复失败点"
  });
  return lines.join("\n");
}

export const GameToolsPlugin = async ({ directory, worktree }) => {
  const root = worktree || directory;

  return {
    tool: {
      game_context: tool({
        description: "继续上次制作：汇总当前 Godot 游戏项目上下文、进度记录、最近本地存档点和可复制给 AI 的续作提示。",
        args: {},
        async execute() {
          return pythonScript("scripts/ai_context.py", root);
        }
      }),

      game_health: tool({
        description: "检查 Python、Godot 4、Export Templates、Git 和项目依赖是否可用。",
        args: {},
        async execute() {
          return pythonScript("scripts/check_env.py", root);
        }
      }),

      game_ai_review: tool({
        description: "AI 自动审查：检查 PM 状态、脚本语法、文档路由、模板导出、Web 导出和运行体验。",
        args: {},
        async execute() {
          return pythonScript("scripts/ai_review.py", root);
        }
      }),

      game_init: tool({
        description: "首次初始化：检查 Python、Godot、Export Templates 和 Git，初始化 PM 工作流状态源。",
        args: {},
        async execute() {
          const steps = [
            "检查这台电脑能否运行项目",
            "检查 Godot 4 和 Export Templates",
            "检查项目环境",
            "初始化 PM 工作流状态源",
            "配置项目级 GodotMCP"
          ];

          const pythonCommand = findPython(root);
          const commandLine = `${pythonCommand} scripts/check_env.py --fast && ${pythonCommand} .agents/skills/pm-agile/scripts/pm_cli.py init-backlog && ${pythonCommand} scripts/setup_ai_mcp.py --apply-project`;
          try {
            const checkOutput = pythonScript("scripts/check_env.py", root, ["--fast"]);
            let pmOutput = "";
            try {
              pmOutput = pythonScript(".agents/skills/pm-agile/scripts/pm_cli.py", root, ["init-backlog"]);
            } catch (e) {
              pmOutput = e?.message || String(e);
            }
            const mcpOutput = pythonScript("scripts/setup_ai_mcp.py", root, ["--apply-project"]);
            return formatInitReport({
              status: "PASS",
              commandLine,
              platform: process.platform,
              steps,
              next: "重启或刷新 AI 客户端后，GodotMCP 工具会随项目配置加载；也可以先回到对话框输入 `init` 选择游戏方向和美术风格。",
              output: checkOutput + "\n" + pmOutput + "\n" + mcpOutput
            });
          } catch (error) {
            return formatInitReport({
              status: "FAIL",
              commandLine,
              platform: process.platform,
              steps,
              next: "把这段结果继续发给 AI，让 AI 根据技术日志自动修复。",
              output: error?.message || String(error)
            });
          }
        }
      }),

      game_export_game: tool({
        description: "导出 Web 版本：使用 Godot headless 模式导出 Web 版本到 html5/。",
        args: {},
        async execute() {
          return formatExportReport(pythonScript("scripts/export_web.py", root, ["--json"]));
        }
      }),

      game_preview_game: tool({
        description: "推荐试玩入口：导出 Web 版本并启动本地预览服务器，返回适合小白阅读的试玩卡片。",
        args: {},
        async execute() {
          const exportOutput = pythonScript("scripts/export_web.py", root, ["--json"]);
          const exportResult = readJsonOutput(exportOutput);
          if (!exportResult || exportResult.status !== "ok") {
            return formatExportReport(exportOutput);
          }

          return formatServeReport(pythonScript("scripts/run_web_preview.py", root, ["--json", "--open"]));
        }
      }),

      game_stop_game: tool({
        description: "停止由 game_preview_game 启动的本地预览服务器。",
        args: {},
        async execute() {
          return pythonScript("scripts/stop_web_preview.py", root, ["--json"]);
        }
      }),

      game_save: tool({
        description: "创建本地存档点。等价于 python scripts/git_ai.py checkpoint。",
        args: {},
        async execute() {
          return pythonScript("scripts/git_ai.py", root, ["checkpoint"]);
        }
      }),

      game_undo_preview: tool({
        description: "预览回档最近一次本地存档点，不会直接确认回滚。",
        args: {},
        async execute() {
          return pythonScript("scripts/git_ai.py", root, ["rollback"]);
        }
      }),

      game_package_dist: tool({
        description: "打包 Web 版本为 zip，用于平台部署上传。",
        args: {},
        async execute() {
          return pythonScript("scripts/package_dist.py", root);
        }
      }),

      game_setup_godot_mark: tool({
        description: "手动确认 Export Templates 已安装并写入标记文件。在 Godot 编辑器内安装完 Export Templates 后使用。",
        args: {},
        async execute() {
          return pythonScript("scripts/setup_godot.py", root, ["--mark"]);
        }
      })
    }
  };
};
