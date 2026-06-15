import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]


class AssetProcessingScriptsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def make_sheet(self, path: Path) -> None:
        image = Image.new("RGB", (128, 128), "#ff00ff")
        draw = ImageDraw.Draw(image)
        for index, color in enumerate(["red", "green", "blue", "yellow"]):
            x = (index % 2) * 64 + 18
            y = (index // 2) * 64 + 16
            draw.rectangle((x, y, x + 24, y + 30), fill=color)
        image.save(path)

    def run_script(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, *args],
            cwd=ROOT,
            text=True,
            encoding="utf-8",
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    def test_process_spritesheet_outputs_meta_and_frames(self):
        sheet = self.root / "sheet.png"
        out_dir = self.root / "frames"
        self.make_sheet(sheet)
        result = self.run_script(
            "scripts/process_spritesheet.py",
            str(sheet),
            "--rows",
            "2",
            "--cols",
            "2",
            "--out-dir",
            str(out_dir),
            "--output-width",
            "64",
            "--output-height",
            "64",
            "--shared-scale",
            "--reject-edge-touch",
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        meta = json.loads((out_dir / "pipeline-meta.json").read_text(encoding="utf-8"))
        self.assertEqual(meta["rows"], 2)
        self.assertEqual(meta["cols"], 2)
        self.assertEqual(meta["edge_touch_frames"], [])
        self.assertTrue((out_dir / "frame-01.png").exists())
        self.assertTrue((out_dir / "sheet-transparent.png").exists())

    def test_extract_prop_pack_outputs_manifest(self):
        sheet = self.root / "props.png"
        out_dir = self.root / "props"
        self.make_sheet(sheet)
        result = self.run_script(
            "scripts/extract_prop_pack.py",
            str(sheet),
            "--rows",
            "2",
            "--cols",
            "2",
            "--labels",
            "red,green,blue,yellow",
            "--out-dir",
            str(out_dir),
            "--reject-edge-touch",
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        meta = json.loads((out_dir / "prop-pack.json").read_text(encoding="utf-8"))
        self.assertEqual(len(meta["accepted"]), 4)
        self.assertEqual(meta["edge_touch_props"], [])
        self.assertTrue((out_dir / "red" / "prop.png").exists())

    def test_compose_layered_map_preview_includes_foreground(self):
        base = self.root / "base.png"
        props_dir = self.root / "props"
        props_dir.mkdir()
        Image.new("RGBA", (64, 64), (10, 10, 10, 255)).save(base)
        Image.new("RGBA", (8, 8), (255, 0, 0, 255)).save(props_dir / "prop.png")
        Image.new("RGBA", (8, 8), (0, 255, 0, 255)).save(props_dir / "fg.png")
        placements = self.root / "placements.json"
        placements.write_text(
            json.dumps(
                {
                    "props": [{"id": "prop", "image": str(props_dir / "prop.png"), "x": 12, "y": 20, "w": 8, "h": 8}],
                    "foreground": [{"id": "fg", "image": str(props_dir / "fg.png"), "x": 28, "y": 20, "w": 8, "h": 8}],
                }
            ),
            encoding="utf-8",
        )
        output = self.root / "preview.png"
        report = self.root / "report.json"
        result = self.run_script(
            "scripts/compose_layered_map_preview.py",
            "--base",
            str(base),
            "--placements",
            str(placements),
            "--output",
            str(output),
            "--report",
            str(report),
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        data = json.loads(report.read_text(encoding="utf-8"))
        self.assertEqual([item["id"] for item in data["pasted"]], ["prop", "fg"])
        self.assertEqual(data["pasted"][1]["layer"], "foreground")


if __name__ == "__main__":
    unittest.main()
