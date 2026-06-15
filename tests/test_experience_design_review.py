import importlib.util
import argparse
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "experience_design_review.py"
NEW_CONCEPT_SCRIPT = ROOT / "scripts" / "new_game_concept.py"


def load_review_module():
    spec = importlib.util.spec_from_file_location("experience_design_review", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def load_new_concept_module():
    spec = importlib.util.spec_from_file_location("new_game_concept", NEW_CONCEPT_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class ExperienceDesignReviewTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.review = load_review_module()
        self.review.PROJECT_ROOT = self.root
        self.review.BLUEPRINTS_FILE = self.root / "spec" / "gameplay_blueprints.json"
        (self.root / "docs").mkdir(parents=True)
        (self.root / "src" / "game").mkdir(parents=True)
        (self.root / "scenes").mkdir(parents=True)
        (self.root / "spec").mkdir(parents=True)
        self.write(
            "spec/gameplay_blueprints.json",
            """{
  "experience_floor": {
    "default": {
      "min_content_units": 3,
      "requires_unit_differences": true,
      "requires_stage_change": true,
      "requires_settlement": true,
      "requires_progress": true,
      "requires_decision_pressure": true
    },
    "dynamic_blueprints": ["extraction"],
    "dynamic_keywords": ["射击", "动作", "生存", "搜打撤"],
    "genre_requirements": {"extraction": ["搜集", "撤离", "死亡损失", "高价值", "风险"]}
  },
  "blueprints": [
    {"id": "starter_template"},
    {"id": "common_loop"},
    {"id": "extraction"}
  ]
}""",
        )

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, rel_path, text):
        path = self.root / rel_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def run_review(self):
        status, checks, active = self.review._run_checks()
        by_name = {item["name"]: item for item in checks}
        return status, by_name, active

    def write_valid_extraction_game(self, animation=True):
        self.write(
            "docs/game-concept.md",
            """# 游戏设定卡

## 概念ID
- `raid-test`

## 玩法蓝图
- `extraction`

## 平台与目标层级
- 目标层级：小型完整游戏首版

## 一句话目标
- 搜打撤射击：搜集物资，在风险升高时选择撤离，死亡损失背包。

## 首版内容单元
- 第 1 个内容单元：教学搜集和撤离，布局简单，低风险。
- 第 2 个内容单元：目标组合变化，加入高价值诱饵和更多敌人。
- 第 3 个内容单元：倒计时撤离，阶段压力升高，失败会死亡损失。

## 本轮美术素材计划
- 玩家 walk/shoot 动作帧；敌人 walk/death；撤离点 UI 图标。

## 小型完整首版必做
- 有结算反馈：胜利、失败、本轮表现、下一步。
- 有进度反馈：当前关卡、完成状态、最佳成绩。
""",
        )
        self.write(
            "src/game/ContentUnits.gd",
            """extends Node
var units = [
    {"id": "unit_1", "name": "搜集教学"},
    {"id": "unit_2", "name": "高价值诱饵"},
    {"id": "unit_3", "name": "倒计时撤离"},
]
""",
        )
        anim_line = "var node_type = \"AnimationPlayer\"" if animation else ""
        self.write(
            "scenes/Game.gd",
            f"""extends Node
{anim_line}
var current_unit = "unit_1"
var best_score = 0
var stage_pressure = 1
var reward_choice = "撤离"
func show_settlement():
    var summary = "结算 胜利 失败 本轮表现 下一步"
""",
        )
        if animation:
            for index in range(4):
                self.write(f"assets/sprites/player/walk/frame_{index}.png", "")
            self.write(
                "src/game/AssetRegistry.gd",
                """extends Node
const PLAYER_WALK_DIR = "res://assets/sprites/player/walk"
""",
            )

    def test_starter_template_is_exempt(self):
        self.write("docs/game-concept.md", "- `starter-template`\n无内置游戏，输入 init。")
        self.write("src/game/ContentUnits.gd", "extends Node\nvar units: Array[Dictionary] = []\n")
        status, checks, active = self.run_review()
        self.assertEqual(status, "PASS")
        self.assertEqual(active, ["starter_template"])
        self.assertEqual(checks["空脚手架体验豁免"]["status"], "PASS")

    def test_valid_small_complete_dynamic_game_passes(self):
        self.write_valid_extraction_game(animation=True)
        status, checks, _ = self.run_review()
        self.assertEqual(status, "PASS")
        self.assertEqual(checks["首版内容单元数量"]["status"], "PASS")
        self.assertEqual(checks["动态品类动画证据"]["status"], "PASS")

    def test_missing_content_units_fails(self):
        self.write_valid_extraction_game(animation=True)
        self.write("src/game/ContentUnits.gd", "extends Node\nvar units = [{\"id\": \"only_one\"}]\n")
        status, checks, _ = self.run_review()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["首版内容单元数量"]["status"], "FAIL")

    def test_concept_only_system_stages_do_not_satisfy_runtime_evidence(self):
        self.write(
            "docs/game-concept.md",
            """# 游戏设定卡

## 玩法蓝图
- `common_loop`

## 平台与目标层级
- 目标层级：完整游戏首版

## 系统阶段
- 阶段一：资源压力变化。
- 阶段二：规则变化。
- 阶段三：奖励变化。

## 本轮美术素材计划
- 玩家和 UI。

## 完整首版必做
- 30 秒内有阶段变化。
- 有结算反馈。
- 有进度反馈。
""",
        )
        self.write("src/game/ContentUnits.gd", "extends Node\nvar units = []\n")
        self.write(
            "scenes/Game.gd",
            """extends Node
var stage_pressure = 1
var reward_choice = "升级"
var current_unit = "unit_1"
var best_score = 0
func show_settlement():
    var summary = "结算 胜利 失败 本轮表现 下一步"
""",
        )
        status, checks, _ = self.run_review()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["首版内容单元数量"]["status"], "FAIL")

    def test_missing_animation_fails_for_dynamic_game(self):
        self.write_valid_extraction_game(animation=False)
        status, checks, _ = self.run_review()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["动态品类动画证据"]["status"], "FAIL")

    def test_plan_text_does_not_satisfy_runtime_evidence(self):
        self.write_valid_extraction_game(animation=True)
        self.write(
            "src/game/ContentUnits.gd",
            """extends Node
var units = [
    {"id": "unit_1", "name": "A"},
    {"id": "unit_2", "name": "B"},
    {"id": "unit_3", "name": "C"},
]
""",
        )
        self.write(
            "scenes/Game.gd",
            """extends Node
func noop():
    pass
""",
        )
        status, checks, _ = self.run_review()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["30 秒内变化"]["status"], "FAIL")
        self.assertEqual(checks["结算反馈"]["status"], "FAIL")
        self.assertEqual(checks["进度反馈"]["status"], "FAIL")

    def test_animation_node_string_alone_does_not_pass(self):
        self.write_valid_extraction_game(animation=False)
        self.write(
            "scenes/Game.gd",
            """extends Node
var fake = "AnimationPlayer"
var current_unit = "unit_1"
var best_score = 0
var stage_pressure = 1
var reward_choice = "撤离"
func show_settlement():
    var summary = "结算 胜利 失败 本轮表现 下一步"
""",
        )
        status, checks, _ = self.run_review()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["动态品类动画证据"]["status"], "FAIL")

    def test_new_game_concept_uses_first_version_units_without_p0_sections(self):
        module = load_new_concept_module()
        args = argparse.Namespace(
            blueprints="custom",
            content_units="首版内容单元 A；首版内容单元 B；首版内容单元 C",
            runtime_art_plan="玩家素材",
            goal="测试目标",
            platform="浏览器 Web",
            level="小型完整游戏首版",
            core_action="移动",
            feedback="命中反馈",
            end_condition="结算",
            invariant="不变量",
            art_style="测试风格",
            style_candidate="未选择",
            runtime_art_status="待生成运行时素材",
            source_doc="",
            extracted_doc="",
            systems="",
            deferred_systems="",
        )
        text = module._build(args, "test-id")
        self.assertIn("首版内容单元 A", text)
        self.assertIn("## 首版基础闭环", text)
        self.assertIn("## 后续增强", text)
        self.assertNotIn("技术 P0", text)
        self.assertNotIn("P1", text)
        self.assertNotIn("第 1 个教学核心操作", text)

    def test_skip_project_docs_still_writes_required_style_guide(self):
        module = load_new_concept_module()
        module.PROJECT_ROOT = self.root
        module.CONCEPT_FILE = self.root / "docs" / "game-concept.md"
        module.ARCHIVE_DIR = self.root / "docs" / "concepts"
        module.PROJECT_DOC_DIR = self.root / "docs" / "project"
        module.DESIGN_INPUTS_DIR = self.root / "docs" / "design-inputs"
        argv = [
            "new_game_concept.py",
            "--goal",
            "测试完整首版",
            "--art-style",
            "统一卡通",
            "--core-action",
            "移动和收集",
            "--feedback",
            "拾取闪光",
            "--end-condition",
            "完成目标后结算",
            "--invariant",
            "玩家必须看清目标",
            "--style-candidate",
            "assets/generated/style_candidates/test.png",
            "--skip-project-docs",
            "--concept-id",
            "skip-style-test",
        ]
        with mock.patch.object(sys, "argv", argv):
            result = module.main()
        self.assertEqual(result, 0)
        self.assertTrue((self.root / "docs" / "project" / "art" / "style-guide.md").exists())
        self.assertFalse((self.root / "docs" / "project" / "gameplay" / "README.md").exists())


if __name__ == "__main__":
    unittest.main()
