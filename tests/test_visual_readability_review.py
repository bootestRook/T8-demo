import importlib
import importlib.util
import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "visual_readability_review.py"


def load_review_module():
    scripts_dir = str(ROOT / "scripts")
    if scripts_dir not in sys.path:
        sys.path.insert(0, scripts_dir)
    spec = importlib.util.spec_from_file_location("visual_readability_review", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def write_rgb_png(path: Path, width: int = 320, height: int = 240) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = bytearray()
    palette = [
        (42, 52, 64),
        (210, 224, 236),
        (92, 170, 112),
        (230, 180, 60),
    ]
    for y in range(height):
        rows.append(0)
        for x in range(width):
            rows.extend(palette[(x // 32 + y // 32) % len(palette)])

    def chunk(kind: bytes, data: bytes) -> bytes:
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    data = b"\x89PNG\r\n\x1a\n"
    data += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(bytes(rows)))
    data += chunk(b"IEND", b"")
    path.write_bytes(data)


class VisualReadabilityReviewTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.review = load_review_module()
        self.asset_coverage = importlib.import_module("asset_coverage")
        self.configure_roots()
        (self.root / "docs").mkdir(parents=True)
        (self.root / "src" / "game").mkdir(parents=True)
        (self.root / "src" / "ui").mkdir(parents=True)
        (self.root / "scenes").mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def configure_roots(self):
        self.review.PROJECT_ROOT = self.root
        self.review.SCREENSHOT_ROOT = self.root / "reports" / "screenshots"
        self.review.RUNTIME_UI_PATHS = [self.root / "src" / "ui", self.root / "scenes"]
        self.asset_coverage.PROJECT_ROOT = self.root
        self.asset_coverage.RUNTIME_SCAN_PATHS = [
            self.root / "project.godot",
            self.root / "export_presets.cfg",
            self.root / "src",
            self.root / "scenes",
        ]

    def write(self, rel_path, text):
        path = self.root / rel_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def touch_asset(self, rel_path):
        path = self.root / rel_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"asset")

    def write_real_concept(self, placeholder=False):
        status = "程序化占位" if placeholder else "首版素材"
        self.write(
            "docs/game-concept.md",
            f"""# 游戏设定卡

## 概念ID
- `readability-test`

## 平台与目标层级
- 目标层级：小型完整游戏首版

## 美术方向
- 选中风格候选图：assets/generated/style_candidates/test.png
- 素材落地状态：{status}
""",
        )

    def write_dynamic_concept(self):
        self.write(
            "docs/game-concept.md",
            """# 游戏设定卡

## 概念ID
- `dynamic-test`

## 玩法蓝图
- `extraction`

## 平台与目标层级
- 目标层级：小型完整游戏首版

## 一句话目标
- 动作射击生存玩法，玩家躲避敌人并撤离。

## 美术方向
- 素材落地状态：首版素材
""",
        )

    def write_puzzle_concept(self):
        self.write(
            "docs/game-concept.md",
            """# 游戏设定卡

## 概念ID
- `puzzle-test`

## 一句话目标
- 抽象解谜益智游戏，玩家通过空间逻辑推动机关。

## 美术方向
- 素材落地状态：首版素材
""",
        )

    def write_action_puzzle_concept(self):
        self.write(
            "docs/game-concept.md",
            """# 游戏设定卡

## 概念ID
- `action-puzzle-test`

## 一句话目标
- 动作解谜游戏，玩家在平台关卡中躲避敌人并推动机关。

## 美术方向
- 素材落地状态：首版素材
""",
        )

    def write_text_adventure_concept(self):
        self.write(
            "docs/game-concept.md",
            """# 游戏设定卡

## 概念ID
- `text-adventure-test`

## 一句话目标
- 文字冒险叙事游戏，通过对话选择推进剧情。

## 美术方向
- 素材落地状态：首版素材
""",
        )

    def write_screenshots(self):
        shot_dir = self.root / "reports" / "screenshots" / "20260610-120000"
        write_rgb_png(shot_dir / "01-ready.png")
        write_rgb_png(shot_dir / "02-running.png")

    def run_review(self):
        self.review.checks = []
        self.review.final_status = "PASS"
        concept = self.review._concept()
        directory = self.review._latest_screenshot_dir(None)
        shots = self.review._screenshots(directory)
        self.review._check_screenshot_evidence(directory, shots)
        self.review._check_pixel_readability(shots)
        self.review._check_runtime_visual_roles(concept)
        self.review._check_ui_placeholder_risk(concept)
        return self.review.final_status, {item["name"]: item for item in self.review.checks}

    def test_missing_screenshots_are_concerns_not_false_pass(self):
        self.write("docs/game-concept.md", "- `starter-template`\n")
        status, checks = self.run_review()
        self.assertEqual(status, "CONCERNS")
        self.assertEqual(checks["截图证据"]["status"], "CONCERNS")

    def test_real_game_with_screenshots_and_visual_roles_passes(self):
        self.write_real_concept()
        self.write_screenshots()
        self.touch_asset("assets/sprites/player/player.png")
        self.touch_asset("assets/sprites/enemy/enemy.png")
        self.touch_asset("assets/ui/hud-panel.png")
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
        self.write(
            "src/game/AssetRegistry.gd",
            """extends Node
const PLAYER = "res://assets/sprites/player/player.png"
const ENEMY = "res://assets/sprites/enemy/enemy.png"
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        self.write(
            "src/ui/Hud.gd",
            """extends Control
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_review()
        self.assertEqual(status, "PASS")
        self.assertEqual(checks["截图证据"]["status"], "PASS")
        self.assertEqual(checks["运行中画面基础像素"]["status"], "PASS")

    def test_missing_asset_manifest_keeps_visual_review_as_concerns(self):
        self.write_real_concept()
        self.write_screenshots()
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
        self.write(
            "src/ui/Hud.gd",
            """extends Control
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_review()
        self.assertEqual(status, "CONCERNS")
        self.assertEqual(checks["运行时视觉素材引用"]["status"], "CONCERNS")
        self.assertIn("缺少 docs/project/art/asset-manifest.json", checks["运行时视觉素材引用"]["detail"])

    def test_placeholder_visuals_remain_concerns(self):
        self.write_real_concept(placeholder=True)
        self.write_screenshots()
        status, checks = self.run_review()
        self.assertEqual(status, "CONCERNS")
        self.assertEqual(checks["运行时视觉素材引用"]["status"], "CONCERNS")
        self.assertEqual(checks["UI 占位风险"]["status"], "CONCERNS")

    def test_non_actor_game_missing_player_and_threat_is_concerns(self):
        self.write_puzzle_concept()
        self.write_screenshots()
        self.touch_asset("assets/ui/hud-panel.png")
        self.write(
            "src/ui/Hud.gd",
            """extends Control
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_review()
        self.assertEqual(status, "CONCERNS")
        self.assertEqual(checks["运行时视觉素材引用"]["status"], "CONCERNS")
        self.assertIn("非动态角色类", checks["运行时视觉素材引用"]["detail"])
        self.assertEqual(checks["UI 占位风险"]["status"], "PASS")

    def test_dynamic_game_missing_player_remains_fail(self):
        self.write_dynamic_concept()
        self.write_screenshots()
        self.touch_asset("assets/ui/hud-panel.png")
        self.write(
            "src/ui/Hud.gd",
            """extends Control
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_review()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时视觉素材引用"]["status"], "FAIL")
        self.assertIn("玩家/主角", checks["运行时视觉素材引用"]["detail"])

    def test_temporary_manifest_assets_do_not_hide_missing_dynamic_roles(self):
        self.write_dynamic_concept()
        self.write_screenshots()
        self.touch_asset("assets/ui/hud-panel.png")
        self.touch_asset("assets/sprites/player/debug.png")
        self.write(
            "docs/project/art/asset-manifest.json",
            """{
  "assets": [
    {"id": "debug-player", "role": "player_actor", "source": "placeholder", "runtime_path": "assets/sprites/player/debug.png", "runtime_bound": true, "screenshot_visible": true},
    {"id": "hud", "role": "ui_skin", "source": "ai_generated", "runtime_path": "assets/ui/hud-panel.png", "runtime_bound": true, "screenshot_visible": true}
  ]
}
""",
        )
        self.write(
            "src/ui/Hud.gd",
            """extends Control
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_review()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时视觉素材引用"]["status"], "FAIL")
        self.assertIn("玩家/主角", checks["运行时视觉素材引用"]["detail"])
        self.assertIn("程序化/占位/调试素材", checks["运行时视觉素材引用"]["detail"])

    def test_action_puzzle_uses_dynamic_priority(self):
        self.write_action_puzzle_concept()
        self.write_screenshots()
        self.touch_asset("assets/ui/hud-panel.png")
        self.write(
            "src/ui/Hud.gd",
            """extends Control
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_review()
        self.assertEqual(status, "FAIL")
        self.assertEqual(checks["运行时视觉素材引用"]["status"], "FAIL")
        self.assertIn("玩家/主角", checks["运行时视觉素材引用"]["detail"])

    def test_text_adventure_missing_actor_visuals_is_concerns(self):
        self.write_text_adventure_concept()
        self.write_screenshots()
        self.touch_asset("assets/ui/hud-panel.png")
        self.write(
            "src/ui/Hud.gd",
            """extends Control
const HUD_PANEL = "res://assets/ui/hud-panel.png"
""",
        )
        status, checks = self.run_review()
        self.assertEqual(status, "CONCERNS")
        self.assertEqual(checks["运行时视觉素材引用"]["status"], "CONCERNS")
        self.assertIn("非动态角色类", checks["运行时视觉素材引用"]["detail"])

    def test_rel_allows_paths_outside_project_root(self):
        with tempfile.TemporaryDirectory() as other:
            external = Path(other) / "outside.png"
            external.write_bytes(b"")
            self.assertEqual(self.review._rel(external), external.as_posix())


if __name__ == "__main__":
    unittest.main()
