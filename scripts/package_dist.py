#!/usr/bin/env python3
"""
部署打包脚本 — godot-v1 模板
将 html5/ 目录打包为可上传到平台的 zip（index.html 在 zip 根目录）

用法：
  python scripts/package_dist.py [--out exports/godot-v1-plus-web.zip]
"""
import argparse
import json
import sys
import zipfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
HTML5_DIR    = PROJECT_ROOT / "html5"
DEFAULT_OUT  = PROJECT_ROOT / "exports" / "godot-v1-plus-web.zip"

def main() -> int:
    parser = argparse.ArgumentParser(description="打包 Godot Web 产物为部署 zip")
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    json_mode = args.json
    out_path  = Path(args.out)

    def log(level: str, msg: str) -> None:
        if not json_mode:
            print(f"[{level}] {msg}")

    if not HTML5_DIR.exists():
        msg = f"html5/ 目录不存在，请先运行 python scripts/export_web.py"
        if json_mode:
            print(json.dumps({"status": "error", "message": msg}, ensure_ascii=False))
        else:
            print(f"[FAIL] {msg}")
        return 1

    index = HTML5_DIR / "index.html"
    if not index.exists():
        msg = "html5/index.html 不存在，导出产物可能不完整"
        if json_mode:
            print(json.dumps({"status": "error", "message": msg}, ensure_ascii=False))
        else:
            print(f"[FAIL] {msg}")
        return 1

    # 收集文件，以 index.html 在根目录
    files: list[tuple[str, bytes]] = []
    for f in sorted(HTML5_DIR.rglob("*")):
        if not f.is_file():
            continue
        rel = f.relative_to(HTML5_DIR).as_posix()
        if rel == ".gdignore" or f.suffix == ".import":
            continue
        files.append((rel, f.read_bytes()))

    log("INFO", f"打包 {len(files)} 个文件 → {out_path}")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for rel, data in files:
            zf.writestr(rel, data)

    size_kb = out_path.stat().st_size // 1024
    log("OK", f"部署 zip 已生成：{out_path}（{size_kb} KB）")
    log("NEXT", "上传到平台：AI 工程包 → 部署作品 → 上传 zip")

    if json_mode:
        print(json.dumps({
            "status": "ok",
            "output": str(out_path),
            "size_kb": size_kb,
            "file_count": len(files),
        }, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    sys.exit(main())
