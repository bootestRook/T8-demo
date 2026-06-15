import importlib.util
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
AGENT_TASK = ROOT / "scripts" / "agent_task.py"
AGENT_MERGE = ROOT / "scripts" / "agent_merge.py"


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class AgentTaskMergeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.workspace = self.root / ".pm" / "workspaces" / "codex" / "2026-06-06-test"
        self.agent_dir = self.workspace / "artifacts" / "agents" / "T-01-docs"
        self.agent_dir.mkdir(parents=True)
        (self.workspace / "meta.json").write_text("{}", encoding="utf-8")
        self.task = load_module("agent_task_under_test", AGENT_TASK)
        self.merge = load_module("agent_merge_under_test", AGENT_MERGE)
        self.task.PROJECT_ROOT = self.root
        self.task.PM_WORKSPACES = self.root / ".pm" / "workspaces"
        self.merge.PROJECT_ROOT = self.root

    def tearDown(self):
        self.tmp.cleanup()

    def create_args(self, **overrides):
        data = {
            "demand_id": "test",
            "task_id": "T-01",
            "role": "docs",
            "goal": "Update docs",
            "coordinator": "codex",
            "status": "draft",
            "allowed_path": ["docs/MULTI_AGENT_WORKFLOW.md"],
            "blocked_path": None,
            "read_first": None,
            "required_gate": [],
            "manifest": None,
            "force": False,
        }
        data.update(overrides)
        return type("Args", (), data)()

    def merge_args(self, manifest, patch):
        return type("Args", (), {"manifest": str(manifest), "patch": str(patch)})()

    def run_quiet(self, func, args):
        with mock.patch("sys.stdout", new=io.StringIO()):
            return func(args)

    def write_manifest(self, status="submitted", allowed=None, blocked=None, role="docs"):
        manifest = {
            "schema_version": 1,
            "demand_id": "test",
            "task_id": "T-01",
            "role": role,
            "status": status,
            "goal": "Update docs",
            "allowed_paths": allowed or ["docs/MULTI_AGENT_WORKFLOW.md"],
            "blocked_paths": blocked or [".pm/project/"],
        }
        path = self.agent_dir / "manifest.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        return path

    def write_patch(self, rel_path, content="new line"):
        patch = self.agent_dir / "changes.patch"
        patch.write_text(
            f"""diff --git a/{rel_path} b/{rel_path}
--- a/{rel_path}
+++ b/{rel_path}
@@ -1 +1,2 @@
 old line
+{content}
""",
            encoding="utf-8",
        )
        return patch

    def test_create_rejects_manifest_outside_project(self):
        outside = Path(self.tmp.name).parent / "outside-manifest.json"
        args = self.create_args(manifest=str(outside))
        self.assertEqual(self.run_quiet(self.task.cmd_create, args), 1)

    def test_create_rejects_manifest_outside_agent_artifacts(self):
        args = self.create_args(manifest=str(self.root / "manifest.json"))
        self.assertEqual(self.run_quiet(self.task.cmd_create, args), 1)

    def test_create_rejects_manifest_with_wrong_agent_artifact_shape(self):
        wrong = self.root / ".pm" / "workspaces" / "codex" / "2026-06-06-test" / "artifacts" / "manifest.json"
        args = self.create_args(manifest=str(wrong))
        self.assertEqual(self.run_quiet(self.task.cmd_create, args), 1)

    def test_create_refuses_to_overwrite_existing_package(self):
        args = self.create_args()
        self.assertEqual(self.run_quiet(self.task.cmd_create, args), 0)
        changed_files = self.agent_dir / "changed_files.txt"
        changed_files.write_text("docs/MULTI_AGENT_WORKFLOW.md\n", encoding="utf-8")
        self.assertEqual(self.run_quiet(self.task.cmd_create, args), 1)
        self.assertEqual(changed_files.read_text(encoding="utf-8"), "docs/MULTI_AGENT_WORKFLOW.md\n")

    def test_create_accepts_code_review_role(self):
        args = self.create_args(task_id="T-04", role="code-review", allowed_path=["src/"])
        self.assertEqual(self.run_quiet(self.task.cmd_create, args), 0)
        manifest = self.workspace / "artifacts" / "agents" / "T-04-code-review" / "manifest.json"
        data = json.loads(manifest.read_text(encoding="utf-8"))
        self.assertEqual(data["role"], "code-review")

    def test_manifest_check_rejects_middle_parent_segment(self):
        manifest = self.write_manifest(allowed=["docs/../../.pm/project/backlog.json"])
        args = type("Args", (), {"manifest": str(manifest)})()
        self.assertEqual(self.run_quiet(self.task.cmd_check, args), 1)

    def test_manifest_check_rejects_windows_absolute_forms(self):
        manifest = self.write_manifest(allowed=["C:/tmp/file.txt"], blocked=["//server/share/file.txt"])
        args = type("Args", (), {"manifest": str(manifest)})()
        self.assertEqual(self.run_quiet(self.task.cmd_check, args), 1)

    def test_manifest_check_handles_invalid_json(self):
        manifest = self.agent_dir / "manifest.json"
        manifest.write_text("{not json", encoding="utf-8")
        args = type("Args", (), {"manifest": str(manifest)})()
        self.assertEqual(self.run_quiet(self.task.cmd_check, args), 1)

    def test_manifest_check_handles_non_object_json(self):
        manifest = self.agent_dir / "manifest.json"
        manifest.write_text("[]", encoding="utf-8")
        args = type("Args", (), {"manifest": str(manifest)})()
        self.assertEqual(self.run_quiet(self.task.cmd_check, args), 1)

    def test_manifest_check_handles_non_list_paths(self):
        manifest = self.write_manifest()
        data = json.loads(manifest.read_text(encoding="utf-8"))
        data["allowed_paths"] = None
        data["blocked_paths"] = None
        manifest.write_text(json.dumps(data), encoding="utf-8")
        args = type("Args", (), {"manifest": str(manifest)})()
        self.assertEqual(self.run_quiet(self.task.cmd_check, args), 1)

    def test_merge_rejects_manifest_outside_agent_artifacts(self):
        manifest = self.root / ".pm" / "workspaces" / "codex" / "2026-06-06-test" / "manifest.json"
        manifest.parent.mkdir(parents=True, exist_ok=True)
        manifest.write_text(
            json.dumps(
                {
                    "demand_id": "test",
                    "task_id": "T-01",
                    "role": "docs",
                    "status": "submitted",
                    "goal": "Update docs",
                    "allowed_paths": ["docs/MULTI_AGENT_WORKFLOW.md"],
                    "blocked_paths": [".pm/project/"],
                }
            ),
            encoding="utf-8",
        )
        patch = self.write_patch("docs/MULTI_AGENT_WORKFLOW.md")
        self.assertEqual(self.run_quiet(self.merge.cmd_check, self.merge_args(manifest, patch)), 1)

    def test_merge_handles_invalid_manifest_json(self):
        manifest = self.agent_dir / "manifest.json"
        manifest.write_text("{not json", encoding="utf-8")
        patch = self.write_patch("docs/MULTI_AGENT_WORKFLOW.md")
        self.assertEqual(self.run_quiet(self.merge.cmd_check, self.merge_args(manifest, patch)), 1)

    def test_merge_handles_non_object_manifest_json(self):
        manifest = self.agent_dir / "manifest.json"
        manifest.write_text('"not an object"', encoding="utf-8")
        patch = self.write_patch("docs/MULTI_AGENT_WORKFLOW.md")
        self.assertEqual(self.run_quiet(self.merge.cmd_check, self.merge_args(manifest, patch)), 1)

    def test_merge_handles_non_list_paths(self):
        manifest = self.write_manifest()
        data = json.loads(manifest.read_text(encoding="utf-8"))
        data["allowed_paths"] = None
        data["blocked_paths"] = None
        manifest.write_text(json.dumps(data), encoding="utf-8")
        patch = self.write_patch("docs/MULTI_AGENT_WORKFLOW.md")
        self.assertEqual(self.run_quiet(self.merge.cmd_check, self.merge_args(manifest, patch)), 1)

    def test_merge_rejects_draft_manifest(self):
        manifest = self.write_manifest(status="draft")
        patch = self.write_patch("docs/MULTI_AGENT_WORKFLOW.md")
        self.assertEqual(self.run_quiet(self.merge.cmd_check, self.merge_args(manifest, patch)), 1)

    def test_merge_rejects_path_outside_allowed_paths(self):
        manifest = self.write_manifest(status="submitted")
        patch = self.write_patch("README.md")
        self.assertEqual(self.run_quiet(self.merge.cmd_check, self.merge_args(manifest, patch)), 1)

    def test_merge_rejects_parent_segment_in_patch_path(self):
        manifest = self.write_manifest(status="submitted", allowed=["docs/"])
        patch = self.write_patch("docs/../../README.md")
        self.assertEqual(self.run_quiet(self.merge.cmd_check, self.merge_args(manifest, patch)), 1)

    def test_merge_rejects_windows_absolute_patch_path(self):
        manifest = self.write_manifest(status="submitted", allowed=["docs/"])
        patch = self.write_patch("C:/tmp/file.txt")
        self.assertEqual(self.run_quiet(self.merge.cmd_check, self.merge_args(manifest, patch)), 1)

    def test_merge_accepts_valid_patch_when_git_check_passes(self):
        manifest = self.write_manifest(status="submitted")
        patch = self.write_patch("docs/MULTI_AGENT_WORKFLOW.md")
        with mock.patch.object(self.merge.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess(["git"], 0, stdout="")
            self.assertEqual(self.run_quiet(self.merge.cmd_check, self.merge_args(manifest, patch)), 0)

    def test_merge_accepts_code_review_role_when_git_check_passes(self):
        manifest = self.write_manifest(status="submitted", role="code-review")
        patch = self.write_patch("docs/MULTI_AGENT_WORKFLOW.md")
        with mock.patch.object(self.merge.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess(["git"], 0, stdout="")
            self.assertEqual(self.run_quiet(self.merge.cmd_check, self.merge_args(manifest, patch)), 0)


if __name__ == "__main__":
    unittest.main()
