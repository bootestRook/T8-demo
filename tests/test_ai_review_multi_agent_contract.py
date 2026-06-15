import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AI_REVIEW = ROOT / "scripts" / "ai_review.py"


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class AiReviewMultiAgentContractTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.review = load_module("ai_review_under_test", AI_REVIEW)
        self.review.PROJECT_ROOT = self.root
        self.review.checks = []
        self.review.final_status = "PASS"

    def tearDown(self):
        self.tmp.cleanup()

    def write_contract(self, task_roles=None, merge_roles=None, docs_roles=None):
        task_roles = task_roles or {"coordinator", "gameplay", "code-review"}
        merge_roles = merge_roles or set(task_roles)
        docs_roles = docs_roles or set(task_roles | merge_roles)

        (self.root / "scripts").mkdir(parents=True)
        (self.root / "docs" / "templates").mkdir(parents=True)
        (self.root / ".agents" / "roles").mkdir(parents=True)

        (self.root / "scripts" / "agent_task.py").write_text(
            "VALID_ROLES = " + repr(task_roles) + "\n",
            encoding="utf-8",
        )
        (self.root / "scripts" / "agent_merge.py").write_text(
            "VALID_ROLES = " + repr(merge_roles) + "\n",
            encoding="utf-8",
        )
        (self.root / "docs" / "templates" / "agent-task.md").write_text("template\n", encoding="utf-8")

        for role in task_roles | merge_roles:
            (self.root / ".agents" / "roles" / f"{role}.md").write_text(role, encoding="utf-8")
        workflow_text = "\n".join(sorted(docs_roles))
        coordinator_text = "\n".join(sorted(docs_roles))
        (self.root / "docs" / "MULTI_AGENT_WORKFLOW.md").write_text(workflow_text, encoding="utf-8")
        (self.root / ".agents" / "roles" / "coordinator.md").write_text(coordinator_text, encoding="utf-8")

    def contract_check(self):
        self.review.checks = []
        self.review.final_status = "PASS"
        self.review._check_multi_agent_contract()
        return self.review.checks[-1]

    def test_roles_from_script_reads_valid_roles_with_ast(self):
        script = self.root / "roles.py"
        script.write_text("VALID_ROLES = {'docs', 'code-review'}\n", encoding="utf-8")
        self.assertEqual(self.review._roles_from_script(script), {"docs", "code-review"})

    def test_multi_agent_contract_passes_when_scripts_and_docs_match(self):
        self.write_contract()
        check = self.contract_check()
        self.assertEqual(check["status"], "PASS")

    def test_multi_agent_contract_fails_when_script_roles_differ(self):
        self.write_contract(merge_roles={"coordinator", "gameplay"})
        check = self.contract_check()
        self.assertEqual(check["status"], "FAIL")
        self.assertIn("scripts/agent_merge.py 缺少角色：code-review", check["detail"])

    def test_multi_agent_contract_fails_when_docs_miss_role(self):
        self.write_contract(docs_roles={"coordinator", "gameplay"})
        check = self.contract_check()
        self.assertEqual(check["status"], "FAIL")
        self.assertIn("docs/MULTI_AGENT_WORKFLOW.md 缺少角色 code-review", check["detail"])

    def test_multi_agent_contract_fails_when_role_file_is_missing(self):
        self.write_contract()
        (self.root / ".agents" / "roles" / "code-review.md").unlink()
        check = self.contract_check()
        self.assertEqual(check["status"], "FAIL")
        self.assertIn("缺少角色文件：.agents/roles/code-review.md", check["detail"])

    def test_multi_agent_contract_fails_when_role_file_is_not_in_scripts(self):
        self.write_contract()
        (self.root / ".agents" / "roles" / "extra-review.md").write_text("extra", encoding="utf-8")
        check = self.contract_check()
        self.assertEqual(check["status"], "FAIL")
        self.assertIn("脚本未声明角色文件：.agents/roles/extra-review.md", check["detail"])

    def test_visual_review_uses_current_experience_screenshot_dir(self):
        commands = []

        def fake_run(command, timeout=180, env=None):
            commands.append(command)
            text = " ".join(str(item) for item in command)
            if "check_env.py" in text:
                return True, json.dumps(
                    {
                        "checks": [
                            {"check": "python", "status": "ok"},
                            {"check": "godot", "status": "ok"},
                            {"check": "export_templates", "status": "ok"},
                        ]
                    }
                )
            if "export_web.py" in text:
                return True, json.dumps({"status": "ok", "output_dir": "html5", "file_count": 3})
            if "experience_check.py" in text:
                return True, json.dumps(
                    {
                        "status": "PASS",
                        "screenshots": {
                            "ready": "reports/screenshots/current/01-ready.png",
                            "running": "reports/screenshots/current/02-running.png",
                        },
                    }
                )
            if "visual_readability_review.py" in text:
                return True, json.dumps({"status": "PASS", "screenshot_dir": "reports/screenshots/current", "checks": []})
            return True, ""

        self.review._run = fake_run
        self.review.checks = []
        self.review.final_status = "PASS"
        self.review.experience_screenshot_dir = ""
        (self.root / "scripts").mkdir(parents=True, exist_ok=True)
        (self.root / "scripts" / "visual_readability_review.py").write_text("# test stub\n", encoding="utf-8")

        self.review._check_export_and_experience(skip_runtime=False)
        self.review._check_visual_readability(skip_runtime=False)

        visual_command = next(command for command in commands if "visual_readability_review.py" in " ".join(str(item) for item in command))
        self.assertIn("--screenshots-dir", visual_command)
        self.assertIn("reports/screenshots/current", visual_command)
        self.assertEqual(self.review.experience_screenshot_dir, "reports/screenshots/current")

    def test_visual_review_does_not_fallback_to_old_screenshots_without_current_dir(self):
        commands = []

        def fake_run(command, timeout=180, env=None):
            commands.append(command)
            text = " ".join(str(item) for item in command)
            if "check_env.py" in text:
                return True, json.dumps(
                    {
                        "checks": [
                            {"check": "python", "status": "ok"},
                            {"check": "godot", "status": "ok"},
                            {"check": "export_templates", "status": "ok"},
                        ]
                    }
                )
            if "export_web.py" in text:
                return True, json.dumps({"status": "ok", "output_dir": "html5", "file_count": 3})
            if "experience_check.py" in text:
                return True, json.dumps({"status": "CONCERNS", "screenshots": {}})
            if "visual_readability_review.py" in text:
                return True, json.dumps({"status": "PASS", "screenshot_dir": "reports/screenshots/old", "checks": []})
            return True, ""

        self.review._run = fake_run
        self.review.checks = []
        self.review.final_status = "PASS"
        self.review.experience_screenshot_dir = ""
        (self.root / "scripts").mkdir(parents=True, exist_ok=True)
        (self.root / "scripts" / "visual_readability_review.py").write_text("# test stub\n", encoding="utf-8")

        self.review._check_export_and_experience(skip_runtime=False)
        self.review._check_visual_readability(skip_runtime=False)

        self.assertFalse(any("visual_readability_review.py" in " ".join(str(item) for item in command) for command in commands))
        self.assertEqual(self.review.checks[-1]["name"], "视觉可读性审查")
        self.assertEqual(self.review.checks[-1]["status"], "CONCERNS")
        self.assertIn("不使用历史截图目录", self.review.checks[-1]["detail"])


if __name__ == "__main__":
    unittest.main()
