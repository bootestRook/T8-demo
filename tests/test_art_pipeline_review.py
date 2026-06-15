import importlib
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "art_pipeline_review.py"


def load_review_module():
    scripts_dir = str(ROOT / "scripts")
    if scripts_dir not in sys.path:
        sys.path.insert(0, scripts_dir)
    spec = importlib.util.spec_from_file_location("art_pipeline_review", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class ArtPipelineReviewTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.review = load_review_module()
        self.asset_coverage = importlib.import_module("asset_coverage")
        self.configure_roots()
        (self.root / "docs").mkdir(parents=True)
        (self.root / "src" / "game").mkdir(parents=True)
        (self.root / "scenes").mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def configure_roots(self):
        self.review.PROJECT_ROOT = self.root
        self.review.DOC_SCAN_FILES = []
        self.review.DOC_SCAN_DIRS = []
        self.review.RUNTIME_SCAN_PATHS = [
            self.root / "project.godot",
            self.root / "export_presets.cfg",
            self.root / "src",
            self.root / "scenes",
        ]
        self.asset_coverage.PROJECT_ROOT = self.root
        self.asset_coverage.RUNTIME_SCAN_PATHS = list(self.review.RUNTIME_SCAN_PATHS)

    def write(self, rel_path, text):
        path = self.root / rel_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def touch_asset(self, rel_path):
        path = self.root / rel_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"")

    def run_role_check(self):
        self.review.checks = []
        self.review.final_status = "PASS"
        self.review._check_runtime_role_coverage()
        return self.review.final_status, {item["name"]: item for item in self.review.checks}

    def run_style_guide_check(self):
        self.review.checks = []
        self.review.final_status = "PASS"
        self.review._check_style_guide()
        return self.review.final_status, {item["name"]: item for item in self.review.checks}

    def run_manifest_and_role_check(self):
        return self.run_role_check()

    def write_real_concept(self):
        self.write(
            "docs/game-concept.md",
            """# 游戏设定卡

## 概念ID
- `forest-raid`

## 平台与目标层级
- 目标层级：小型完整游戏首版

## 美术方向
- 选中风格候选图：assets/generated/style_candidates/forest.png
- 素材落地状态：待生成运行时素材

## 首版内容单元
- 第 1 个内容单元：教学。
- 第 2 个内容单元：目标组合变化。
- 第 3 个内容单元：阶段压力。

## 本轮美术素材计划
- 玩家、敌人、HUD 图标。
""",
        )

    def test_starter_template_keeps_asset_coverage_exempt(self):
        self.write("docs/game-concept.md", "- `starter-template`\n- 素材落地状态：空脚手架，无运行时美术。\n")
        status, checks = self.run_role_check()
        self.assertEqual(status, "PASS")
        self.assertEqual(checks["运行时素材角色覆盖"]["status"], "PASS")

    def test_invalid_manifest_fails_even_for_starter_template(self):
        self.write("docs/game-concept.md", "- `starter-template`\n- 素材落地状态：空脚手架，无运行时美术。\n")
        self.write("docs/project/art/asset-manifest.json", "{bad json")
        status, checks = self.run_role_check()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "FAIL")
        self.assertIn("不是合法 JSON", checks["运行时素材来源清单"]["detail"])

    def test_real_game_with_actor_assets_but_no_ui_fails(self):
        self.write_real_concept()
        self.touch_asset("assets/sprites/player/player.png")
        self.touch_asset("assets/sprites/enemy/enemy.png")
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/player.png"
const ENEMY = "res://assets/sprites/enemy/enemy.png"
""",
        )
        status, checks = self.run_role_check()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时素材角色覆盖"]["status"], "FAIL")
        self.assertIn("没有 PSD/UI 设计稿不是豁免条件", checks["运行时素材角色覆盖"]["detail"])

    def test_real_game_missing_actor_assets_fails_even_with_ui(self):
        self.write_real_concept()
        self.touch_asset("assets/ui/hud-panel.png")
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_role_check()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时素材角色覆盖"]["status"], "FAIL")
        self.assertIn("主角/玩家素材", checks["运行时素材角色覆盖"]["detail"])

    def test_missing_runtime_asset_reference_fails(self):
        self.write_real_concept()
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/player.png"
const ENEMY = "res://assets/sprites/enemy/enemy.png"
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_role_check()
        self.assertEqual(status, "FAIL")
        self.assertIn("不存在的素材文件", checks["运行时素材角色覆盖"]["detail"])

    def test_non_ui_sprite_icon_does_not_satisfy_ui_coverage(self):
        self.write_real_concept()
        self.touch_asset("assets/sprites/player/player.png")
        self.touch_asset("assets/sprites/enemy/enemy.png")
        self.touch_asset("assets/sprites/hud/icon.png")
        self.write(
            "src/ui/Hud.gd",
            """extends Control
const HUD_ICON = "res://assets/sprites/hud/icon.png"
const PLAYER = "res://assets/sprites/player/player.png"
const ENEMY = "res://assets/sprites/enemy/enemy.png"
""",
        )
        status, checks = self.run_role_check()
        self.assertEqual(status, "FAIL")
        self.assertIn("未发现 assets/ui", checks["运行时素材角色覆盖"]["detail"])

    def test_real_game_with_ui_runtime_asset_passes_role_coverage(self):
        self.write_real_concept()
        self.touch_asset("assets/sprites/player/player.png")
        self.touch_asset("assets/sprites/enemy/enemy.png")
        self.touch_asset("assets/ui/hud-panel.png")
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/player.png"
const ENEMY = "res://assets/sprites/enemy/enemy.png"
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_role_check()
        self.assertEqual(status, "CONCERNS")
        self.assertIn("运行时素材来源清单", checks)
        self.assertEqual(checks["运行时素材来源清单"]["status"], "CONCERNS")
        self.assertEqual(checks["运行时素材角色覆盖"]["status"], "PASS")

    def test_real_game_with_formal_asset_manifest_passes_role_coverage(self):
        self.write_real_concept()
        for path in [
            "assets/sprites/player/player.png",
            "assets/sprites/enemy/enemy.png",
            "assets/ui/hud-panel.png",
        ]:
            self.touch_asset(path)
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "version": 1,
  "assets": [
    {
      "id": "player",
      "role": "player_actor",
      "source": "ai_generated",
      "runtime_path": "assets/sprites/player/player.png",
      "runtime_bound": true,
      "screenshot_visible": true
    },
    {
      "id": "enemy",
      "role": "challenge_actor",
      "source": "ai_generated",
      "runtime_path": "assets/sprites/enemy/enemy.png",
      "runtime_bound": true,
      "screenshot_visible": true
    },
    {
      "id": "hud",
      "role": "ui_skin",
      "source": "ai_generated",
      "runtime_path": "assets/ui/hud-panel.png",
      "runtime_bound": true,
      "screenshot_visible": true
    }
  ]
}
""",
        )
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/player.png"
const ENEMY = "res://assets/sprites/enemy/enemy.png"
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "PASS")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "PASS")
        self.assertEqual(checks["运行时素材角色覆盖"]["status"], "PASS")

    def test_manifest_placeholder_blocks_formal_completion(self):
        self.write_real_concept()
        self.touch_asset("assets/sprites/player/player.png")
        self.touch_asset("assets/sprites/enemy/enemy.png")
        self.touch_asset("assets/ui/hud-panel.png")
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "player", "role": "player_actor", "source": "placeholder", "runtime_path": "assets/sprites/player/player.png", "runtime_bound": true, "screenshot_visible": true},
    {"id": "enemy", "role": "challenge_actor", "source": "ai_generated", "runtime_path": "assets/sprites/enemy/enemy.png", "runtime_bound": true, "screenshot_visible": true},
    {"id": "hud", "role": "ui_skin", "source": "ai_generated", "runtime_path": "assets/ui/hud-panel.png", "runtime_bound": true, "screenshot_visible": true}
  ]
}
""",
        )
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/player.png"
const ENEMY = "res://assets/sprites/enemy/enemy.png"
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "CONCERNS")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "CONCERNS")
        self.assertIn("临时素材", checks["运行时素材来源清单"]["detail"])

    def test_manifest_only_temporary_assets_fails_source_manifest(self):
        self.write_real_concept()
        self.touch_asset("assets/sprites/player/debug.png")
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "debug-player", "role": "player_actor", "source": "placeholder", "runtime_path": "assets/sprites/player/debug.png", "runtime_bound": true, "screenshot_visible": true}
  ]
}
""",
        )
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const DEBUG_PLAYER = "res://assets/sprites/player/debug.png"
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "FAIL")
        self.assertIn("未登记任何正式运行时素材", checks["运行时素材来源清单"]["detail"])
        self.assertIn("临时素材", checks["运行时素材来源清单"]["detail"])

    def test_manifest_directory_path_is_not_formal_runtime_asset(self):
        self.write_real_concept()
        (self.root / "assets/sprites/player").mkdir(parents=True, exist_ok=True)
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "player-dir", "role": "player_actor", "source": "ai_generated", "runtime_path": "assets/sprites/player", "runtime_bound": true, "screenshot_visible": true}
  ]
}
""",
        )
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER_DIR = "res://assets/sprites/player"
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "FAIL")
        self.assertIn("没有已接入", checks["运行时素材来源清单"]["detail"])

    def test_manifest_planned_asset_does_not_satisfy_runtime_coverage(self):
        self.write_real_concept()
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "player", "role": "player_actor", "source": "ai_generated", "runtime_path": "assets/sprites/player/player.png", "runtime_bound": false, "screenshot_visible": false},
    {"id": "enemy", "role": "challenge_actor", "source": "ai_generated", "runtime_path": "assets/sprites/enemy/enemy.png", "runtime_bound": false, "screenshot_visible": false},
    {"id": "hud", "role": "ui_skin", "source": "ai_generated", "runtime_path": "assets/ui/hud-panel.png", "runtime_bound": false, "screenshot_visible": false}
  ]
}
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "FAIL")
        self.assertIn("没有已接入", checks["运行时素材来源清单"]["detail"])
        self.assertEqual(checks["运行时素材角色覆盖"]["status"], "FAIL")
        self.assertIn("主角/玩家素材", checks["运行时素材角色覆盖"]["detail"])

    def test_manifest_runtime_bound_without_code_reference_fails(self):
        self.write_real_concept()
        for path in [
            "assets/sprites/player/player.png",
            "assets/sprites/enemy/enemy.png",
            "assets/ui/hud-panel.png",
        ]:
            self.touch_asset(path)
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "player", "role": "player_actor", "source": "ai_generated", "runtime_path": "assets/sprites/player/player.png", "runtime_bound": true, "screenshot_visible": true},
    {"id": "enemy", "role": "challenge_actor", "source": "ai_generated", "runtime_path": "assets/sprites/enemy/enemy.png", "runtime_bound": true, "screenshot_visible": true},
    {"id": "hud", "role": "ui_skin", "source": "ai_generated", "runtime_path": "assets/ui/hud-panel.png", "runtime_bound": true, "screenshot_visible": true}
  ]
}
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "FAIL")
        self.assertIn("没有已接入", checks["运行时素材来源清单"]["detail"])
        self.assertEqual(checks["运行时素材角色覆盖"]["status"], "FAIL")
        self.assertIn("未发现任何 res://assets/", checks["运行时素材角色覆盖"]["detail"])

    def test_manifest_bound_asset_without_screenshot_visible_is_not_delivery_ready(self):
        self.write_real_concept()
        for path in [
            "assets/sprites/player/player.png",
            "assets/sprites/enemy/enemy.png",
            "assets/ui/hud-panel.png",
        ]:
            self.touch_asset(path)
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "player", "role": "player_actor", "source": "ai_generated", "runtime_path": "assets/sprites/player/player.png", "runtime_bound": true, "screenshot_visible": false},
    {"id": "enemy", "role": "challenge_actor", "source": "ai_generated", "runtime_path": "assets/sprites/enemy/enemy.png", "runtime_bound": true, "screenshot_visible": false},
    {"id": "hud", "role": "ui_skin", "source": "ai_generated", "runtime_path": "assets/ui/hud-panel.png", "runtime_bound": true, "screenshot_visible": false}
  ]
}
""",
        )
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/player.png"
const ENEMY = "res://assets/sprites/enemy/enemy.png"
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "FAIL")
        self.assertIn("没有已接入", checks["运行时素材来源清单"]["detail"])

    def test_manifest_postprocess_meta_edge_touch_fails(self):
        self.write_real_concept()
        for path in [
            "assets/sprites/player/walk/frame-01.png",
            "assets/sprites/enemy/enemy.png",
            "assets/ui/hud-panel.png",
        ]:
            self.touch_asset(path)
        self.write(
            "assets/sprites/player/walk/pipeline-meta.json",
            """{
  "rows": 2,
  "cols": 2,
  "shared_scale": true,
  "frames": [
    {"grid": [0, 0], "edge_touch": true},
    {"grid": [0, 1], "edge_touch": false},
    {"grid": [1, 0], "edge_touch": false},
    {"grid": [1, 1], "edge_touch": false}
  ],
  "edge_touch_frames": [[0, 0]]
}
""",
        )
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "player-walk", "role": "player_actor", "source": "ai_generated", "runtime_path": "assets/sprites/player/walk/frame-01.png", "runtime_bound": true, "screenshot_visible": true, "postprocess_meta": "assets/sprites/player/walk/pipeline-meta.json"},
    {"id": "enemy", "role": "challenge_actor", "source": "ai_generated", "runtime_path": "assets/sprites/enemy/enemy.png", "runtime_bound": true, "screenshot_visible": true},
    {"id": "hud", "role": "ui_skin", "source": "ai_generated", "runtime_path": "assets/ui/hud-panel.png", "runtime_bound": true, "screenshot_visible": true}
  ]
}
""",
        )
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/walk/frame-01.png"
const ENEMY = "res://assets/sprites/enemy/enemy.png"
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "FAIL")
        self.assertIn("帧触边", checks["运行时素材来源清单"]["detail"])

    def test_manifest_postprocess_meta_bad_rows_fails_without_crashing(self):
        self.write_real_concept()
        for path in [
            "assets/sprites/player/walk/frame-01.png",
            "assets/sprites/enemy/enemy.png",
            "assets/ui/hud-panel.png",
        ]:
            self.touch_asset(path)
        self.write(
            "assets/sprites/player/walk/pipeline-meta.json",
            """{
  "rows": "2x",
  "cols": 2,
  "shared_scale": true,
  "frames": []
}
""",
        )
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "player-walk", "role": "player_actor", "source": "ai_generated", "runtime_path": "assets/sprites/player/walk/frame-01.png", "runtime_bound": true, "screenshot_visible": true, "postprocess_meta": "assets/sprites/player/walk/pipeline-meta.json"},
    {"id": "enemy", "role": "challenge_actor", "source": "ai_generated", "runtime_path": "assets/sprites/enemy/enemy.png", "runtime_bound": true, "screenshot_visible": true},
    {"id": "hud", "role": "ui_skin", "source": "ai_generated", "runtime_path": "assets/ui/hud-panel.png", "runtime_bound": true, "screenshot_visible": true}
  ]
}
""",
        )
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/walk/frame-01.png"
const ENEMY = "res://assets/sprites/enemy/enemy.png"
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "FAIL")
        self.assertIn("rows/cols 必须是正整数", checks["运行时素材来源清单"]["detail"])

    def test_manifest_postprocess_meta_ui_without_shared_scale_passes(self):
        self.write_real_concept()
        for path in [
            "assets/sprites/player/player.png",
            "assets/sprites/enemy/enemy.png",
            "assets/ui/hud-icon.png",
        ]:
            self.touch_asset(path)
        self.write(
            "assets/ui/pipeline-meta.json",
            """{
  "rows": 2,
  "cols": 2,
  "shared_scale": false,
  "frames": [{}, {}, {}, {}],
  "edge_touch_frames": []
}
""",
        )
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "player", "role": "player_actor", "source": "ai_generated", "runtime_path": "assets/sprites/player/player.png", "runtime_bound": true, "screenshot_visible": true},
    {"id": "enemy", "role": "challenge_actor", "source": "ai_generated", "runtime_path": "assets/sprites/enemy/enemy.png", "runtime_bound": true, "screenshot_visible": true},
    {"id": "hud", "role": "ui_skin", "source": "ai_generated", "runtime_path": "assets/ui/hud-icon.png", "runtime_bound": true, "screenshot_visible": true, "postprocess_meta": "assets/ui/pipeline-meta.json"}
  ]
}
""",
        )
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/player.png"
const ENEMY = "res://assets/sprites/enemy/enemy.png"
const HUD = "res://assets/ui/hud-icon.png"
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "PASS")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "PASS")

    def test_manifest_postprocess_meta_outside_project_fails(self):
        self.write_real_concept()
        for path in [
            "assets/sprites/player/walk/frame-01.png",
            "assets/sprites/enemy/enemy.png",
            "assets/ui/hud-panel.png",
        ]:
            self.touch_asset(path)
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "player-walk", "role": "player_actor", "source": "ai_generated", "runtime_path": "assets/sprites/player/walk/frame-01.png", "runtime_bound": true, "screenshot_visible": true, "postprocess_meta": "../outside/pipeline-meta.json"},
    {"id": "enemy", "role": "challenge_actor", "source": "ai_generated", "runtime_path": "assets/sprites/enemy.png", "runtime_bound": true, "screenshot_visible": true},
    {"id": "hud", "role": "ui_skin", "source": "ai_generated", "runtime_path": "assets/ui/hud-panel.png", "runtime_bound": true, "screenshot_visible": true}
  ]
}
""",
        )
        self.touch_asset("assets/sprites/enemy.png")
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/walk/frame-01.png"
const ENEMY = "res://assets/sprites/enemy.png"
const HUD = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "FAIL")
        self.assertIn("项目内相对路径", checks["运行时素材来源清单"]["detail"])

    def test_manifest_postprocess_meta_player_path_with_ui_substring_still_warns_shared_scale(self):
        self.write_real_concept()
        for path in [
            "assets/sprites/player/suit-run/frame-01.png",
            "assets/sprites/enemy/enemy.png",
            "assets/ui/hud-panel.png",
        ]:
            self.touch_asset(path)
        self.write(
            "assets/sprites/player/suit-run/pipeline-meta.json",
            """{
  "rows": 2,
  "cols": 2,
  "shared_scale": false,
  "frames": [{}, {}, {}, {}],
  "edge_touch_frames": []
}
""",
        )
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "player-suit-run", "role": "player_actor", "source": "ai_generated", "runtime_path": "assets/sprites/player/suit-run/frame-01.png", "runtime_bound": true, "screenshot_visible": true, "postprocess_meta": "assets/sprites/player/suit-run/pipeline-meta.json"},
    {"id": "enemy", "role": "challenge_actor", "source": "ai_generated", "runtime_path": "assets/sprites/enemy/enemy.png", "runtime_bound": true, "screenshot_visible": true},
    {"id": "hud", "role": "ui_skin", "source": "ai_generated", "runtime_path": "assets/ui/hud-panel.png", "runtime_bound": true, "screenshot_visible": true}
  ]
}
""",
        )
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/suit-run/frame-01.png"
const ENEMY = "res://assets/sprites/enemy/enemy.png"
const HUD = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "CONCERNS")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "CONCERNS")
        self.assertIn("shared_scale", checks["运行时素材来源清单"]["detail"])

    def test_manifest_prop_pack_edge_touch_fails(self):
        self.write_real_concept()
        for path in [
            "assets/sprites/player/player.png",
            "assets/sprites/props/rock/prop.png",
            "assets/ui/hud-panel.png",
        ]:
            self.touch_asset(path)
        self.write(
            "assets/sprites/props/prop-pack.json",
            """{
  "accepted": [{"label": "rock", "edge_touch": true}],
  "edge_touch_props": ["rock"]
}
""",
        )
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "player", "role": "player_actor", "source": "ai_generated", "runtime_path": "assets/sprites/player/player.png", "runtime_bound": true, "screenshot_visible": true},
    {"id": "rock", "role": "challenge_actor", "source": "ai_generated", "runtime_path": "assets/sprites/props/rock/prop.png", "runtime_bound": true, "screenshot_visible": true, "prop_pack_meta": "assets/sprites/props/prop-pack.json"},
    {"id": "hud", "role": "ui_skin", "source": "ai_generated", "runtime_path": "assets/ui/hud-panel.png", "runtime_bound": true, "screenshot_visible": true}
  ]
}
""",
        )
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/player.png"
const ROCK = "res://assets/sprites/props/rock/prop.png"
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_manifest_and_role_check()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时素材来源清单"]["status"], "FAIL")
        self.assertIn("道具触边", checks["运行时素材来源清单"]["detail"])

    def test_style_guide_rejects_positive_style_candidate_runtime_reference(self):
        self.write_real_concept()
        self.write(
            "docs/project/art/style-guide.md",
            """# 风格指南

## 风格锚点

- 选中风格候选图：assets/generated/style_candidates/forest.png

## 色板

- 高识别主色。

## 线条与材质

- 描边统一。

## 角色比例

- 玩家清晰。

## UI 形状语言

- HUD 图标统一。

## VFX 气质

- 命中反馈统一。

## 运行时素材包

- 玩家素材进入 `assets/sprites/`。
- UI 素材进入 `assets/ui/`。
- 运行时生成源图进入 `assets/generated/runtime/`。
- VFX 可接入 `addons/`。
- 运行时素材：`assets/generated/style_candidates/forest.png`。

## 禁止事项

- 不得把 `style_candidates/` 候选图直接作为运行时素材。
""",
        )
        status, checks = self.run_style_guide_check()
        self.assertEqual(status, "FAIL")
        self.assertIn("疑似把候选图当运行时素材来源", checks["统一风格指南"]["detail"])

    def test_style_guide_rejects_mixed_anchor_and_runtime_candidate_sentence(self):
        self.write_real_concept()
        self.write(
            "docs/project/art/style-guide.md",
            """# 风格指南

## 风格锚点

- 选中风格候选图：assets/generated/style_candidates/forest.png，可直接作为运行时素材接入。

## 色板

- 高识别主色。

## 线条与材质

- 描边统一。

## 角色比例

- 玩家清晰。

## UI 形状语言

- HUD 图标统一。

## VFX 气质

- 命中反馈统一。

## 运行时素材包

- 玩家素材进入 `assets/sprites/`。
- UI 素材进入 `assets/ui/`。
- 运行时生成源图进入 `assets/generated/runtime/`。
- VFX 可接入 `addons/`。

## 禁止事项

- 不得把候选图直接作为正式素材。
""",
        )
        status, checks = self.run_style_guide_check()
        self.assertEqual(status, "FAIL")
        self.assertIn("疑似把候选图当运行时素材来源", checks["统一风格指南"]["detail"])

    def test_style_guide_allows_negative_style_candidate_runtime_sentence(self):
        self.write_real_concept()
        self.write(
            "docs/project/art/style-guide.md",
            """# 风格指南

## 风格锚点

- 选中风格候选图：assets/generated/style_candidates/forest.png。

## 色板

- 高识别主色。

## 线条与材质

- 描边统一。

## 角色比例

- 玩家清晰。

## UI 形状语言

- HUD 图标统一。

## VFX 气质

- 命中反馈统一。

## 运行时素材包

- 玩家素材进入 `assets/sprites/`。
- UI 素材进入 `assets/ui/`。
- 运行时生成源图进入 `assets/generated/runtime/`。
- VFX 可接入 `addons/`。

## 禁止事项

- 不得把 `style_candidates/` 候选图直接作为运行时素材。
""",
        )
        status, checks = self.run_style_guide_check()
        self.assertEqual(status, "PASS")
        self.assertEqual(checks["统一风格指南"]["status"], "PASS")


if __name__ == "__main__":
    unittest.main()
