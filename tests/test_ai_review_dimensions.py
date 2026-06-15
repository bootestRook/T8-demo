import importlib.util
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "ai_review.py"


def load_review_module():
    spec = importlib.util.spec_from_file_location("ai_review", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class AiReviewDimensionsTest(unittest.TestCase):
    def setUp(self):
        self.review = load_review_module()
        self.review.checks = []
        self.review.final_status = "PASS"

    def test_dimensions_split_art_gameplay_ux_and_human_acceptance(self):
        self.review._add("Python 语法", "PASS", "ok")
        self.review._add("美术管线审查", "FAIL", "缺少正式素材")
        self.review._add("玩法语义审查", "PASS", "ok")
        self.review._add("体验检查", "CONCERNS", "缺少截图")

        dimensions = {item["name"]: item for item in self.review._dimension_summary()}

        self.assertEqual(dimensions["Technical"]["status"], "PASS")
        self.assertEqual(dimensions["Art"]["status"], "FAIL")
        self.assertEqual(dimensions["Gameplay"]["status"], "PASS")
        self.assertEqual(dimensions["UX"]["status"], "CONCERNS")
        self.assertEqual(dimensions["Human Acceptance"]["status"], "FAIL")

    def test_human_acceptance_remains_pending_after_full_auto_pass(self):
        self.review._add("Python 语法", "PASS", "ok")
        self.review._add("美术管线审查", "PASS", "ok")
        self.review._add("玩法语义审查", "PASS", "ok")
        self.review._add("体验检查", "PASS", "ok")

        dimensions = {item["name"]: item for item in self.review._dimension_summary()}

        self.assertEqual(self.review.final_status, "PASS")
        self.assertEqual(dimensions["Human Acceptance"]["status"], "CONCERNS")
        self.assertIn("人工试玩验收", dimensions["Human Acceptance"]["detail"])

    def test_technical_dimension_uses_actual_check_names(self):
        self.review._add("多 Agent 契约", "FAIL", "角色索引不一致")
        self.review._add("Web 导出与体验", "CONCERNS", "skip-runtime")

        dimensions = {item["name"]: item for item in self.review._dimension_summary()}

        self.assertEqual(dimensions["Technical"]["status"], "FAIL")
        self.assertIn("多 Agent 契约", dimensions["Technical"]["detail"])
        self.assertIn("Web 导出与体验", dimensions["Technical"]["detail"])


if __name__ == "__main__":
    unittest.main()
