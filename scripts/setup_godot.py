#!/usr/bin/env python3
"""
Export Templates 安装检测 — godot-v1 模板
检测 Godot Export Templates 是否已安装，并写入标记文件供 check_env.py 使用

用法：
  python scripts/setup_godot.py [--mark]  # --mark 强制写入标记（已手动确认安装）
"""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
MARKER_FILE  = PROJECT_ROOT / ".godot-export-templates-ready"

sys.path.insert(0, str(PROJECT_ROOT / "scripts"))
from godot_locator import find_godot, godot_version  # noqa: E402


def _sort_godot_exec_paths(paths: list[Path]) -> list[str]:
    dedup: list[str] = []
    seen: set[str] = set()
    for path in paths:
        if not path.is_file():
            continue
        text = str(path)
        key = text.lower()
        if key in seen:
            continue
        seen.add(key)
        dedup.append(text)
    return sorted(
        dedup,
        key=lambda value: (
            0 if "console" in Path(value).name.lower() else 1,
            Path(value).name.lower(),
            value.lower(),
        ),
    )


def _find_godot() -> str | None:
    return find_godot()


def _godot_template_version() -> str | None:
    godot = _find_godot()
    if not godot:
        return None
    version = godot_version(godot)
    if not version:
        return None
    parts = version.split(".")
    if len(parts) >= 4 and parts[0].isdigit() and parts[1].isdigit():
        return ".".join(parts[:4])
    return None


def _has_web_template(path: Path) -> bool:
    return any(
        (path / name).exists()
        for name in ("web_nothreads_release.zip", "web_release.zip", "web_dlink_release.zip")
    )


def _templates_dir() -> Path:
    if sys.platform == "win32":
        return Path(os.environ.get("APPDATA", "")) / "Godot" / "export_templates"
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Godot" / "export_templates"
    else:
        return Path.home() / ".local" / "share" / "godot" / "export_templates"


def main() -> int:
    parser = argparse.ArgumentParser(description="检测 Godot Export Templates 安装状态")
    parser.add_argument("--mark", action="store_true", help="强制写入已安装标记")
    args = parser.parse_args()

    if args.mark:
        MARKER_FILE.write_text("ok\n", encoding="utf-8")
        print("[OK] 已写入 Export Templates 安装标记")
        return 0

    # 扫描实际目录
    tpl_dir = _templates_dir()
    if tpl_dir.exists():
        expected = _godot_template_version()
        if expected and _has_web_template(tpl_dir / expected):
            print(f"[OK] 检测到 Export Templates：{expected}")
            MARKER_FILE.write_text("ok\n", encoding="utf-8")
            print(f"[OK] 已写入标记文件：{MARKER_FILE}")
            return 0
        subdirs = [p for p in tpl_dir.iterdir() if p.is_dir() and _has_web_template(p)]
        if subdirs:
            versions = [p.name for p in subdirs]
            print(f"[OK] 检测到 Export Templates：{', '.join(versions)}")
            MARKER_FILE.write_text("ok\n", encoding="utf-8")
            print(f"[OK] 已写入标记文件：{MARKER_FILE}")
            return 0

    # 未安装
    print("[WARN] 未检测到 Godot Export Templates")
    print("[NEXT] 把 Godot_v4.x-stable_export_templates.tpz 放入 tools/ 后运行 init.cmd")
    print("[NEXT] 或在 Godot 编辑器中：Editor → Manage Export Templates → Download")
    print("[NEXT] 安装完成后运行：python scripts/setup_godot.py")
    print(f"[NEXT] 或手动写入标记：python scripts/setup_godot.py --mark")
    return 1


if __name__ == "__main__":
    sys.exit(main())
