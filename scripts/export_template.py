#!/usr/bin/env python3
"""
导出干净的脚手架包，默认排除运行时、导出产物和本地 PM 状态。
默认携带 tools/ 下的 portable 工具或工具压缩包，让新手解压后可直接 init。
导出包会生成一个空 Git 仓库，作为新手 AI 存档点的基础，不复制当前仓库历史。

用法：
  python scripts/export_template.py --dry-run
  python scripts/export_template.py --format zip
"""
from __future__ import annotations

import argparse
import json
import shutil
import tarfile
import tempfile
import zipfile
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
INCLUDE_TOOLS = True
INCLUDE_EMPTY_GIT = True

EXCLUDED_DIR_NAMES = {
    ".git",
    ".godot",
    ".idea",
    ".vscode",
    ".cache",
    ".codex",
    ".pm",
    ".runtime",
    ".pytest_cache",
    "__pycache__",
    "build",
    "coverage",
    "dist",
    "downloads",
    "exports",
    "html5",
    "node_modules",
    "reports",
    "temp",
    "tmp",
}

EXCLUDED_PATH_PREFIXES = {
    ".agents/.pm/",
    ".agents/skills/ui-studio/evals/",
    ".agents/skills/ui-studio/test-source/",
}

INCLUDED_TOOL_BUNDLE_PREFIXES = (
    "tools/godot-mcp-node/",
)

EXCLUDED_FILE_NAMES = {
    ".DS_Store",
    ".mcp.json",
    "Thumbs.db",
    ".godot-export-templates-ready",
}

EXCLUDED_SUFFIXES = {
    ".log",
    ".pyc",
    ".pyo",
    ".uid",
    ".import",
}

def _read_template_code() -> str:
    path = PROJECT_ROOT / "template.json"
    if not path.exists():
        return "godot-v1-plus"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return str(data.get("template_code") or "godot-v1-plus")
    except Exception:
        return "godot-v1-plus"


def _timestamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")


def _to_posix(path: Path) -> str:
    return path.as_posix()


def _relative(path: Path) -> str:
    return _to_posix(path.relative_to(PROJECT_ROOT))


def _has_tool_file(patterns: tuple[str, ...]) -> bool:
    tools = PROJECT_ROOT / "tools"
    if not tools.exists():
        return False
    return any(tools.rglob(pattern) for pattern in patterns)


def _is_generated_tool_extract(rel: str) -> bool:
    # GDScript Toolkit is intentionally not excluded: the default template is
    # expected to run quality gates out of the box without network access.
    if rel.startswith("tools/python/"):
        return _has_tool_file(("python-*-embed-amd64.zip", "python-*-embed-win32.zip"))
    if rel.startswith("tools/git/"):
        return _has_tool_file(("PortableGit-*-64-bit.7z.exe", "PortableGit-*.7z.exe"))
    if rel.startswith("tools/godot/"):
        return _has_tool_file(("Godot_v4*_win64.exe.zip", "Godot_v4*_win64.zip", "Godot_v4*_windows*.zip"))
    if rel.startswith("tools/node/"):
        return _has_tool_file(("node-v*-win-x64.zip", "node-v*-win-x86.zip", "node-v*-windows*.zip"))
    if rel.startswith(("tools/godotmcp/", "tools/godot-mcp/")):
        return True
    return False


def _is_included_tool_bundle(rel: str) -> bool:
    return INCLUDE_TOOLS and any(rel.startswith(prefix) for prefix in INCLUDED_TOOL_BUNDLE_PREFIXES)


def _should_exclude(path: Path) -> bool:
    rel = _relative(path)
    first = rel.split("/", 1)[0]

    if first == "tools":
        if _is_included_tool_bundle(rel):
            return False
        if not INCLUDE_TOOLS:
            return path.is_file() and rel != "tools/README.md"
        return _is_generated_tool_extract(rel)

    if first == "installers":
        return True

    if path.is_dir() and path.name in EXCLUDED_DIR_NAMES:
        return True
    if first in EXCLUDED_DIR_NAMES:
        return True
    if any(rel == prefix.rstrip("/") or rel.startswith(prefix) for prefix in EXCLUDED_PATH_PREFIXES):
        return True
    if path.is_file() and path.name in EXCLUDED_FILE_NAMES:
        return True
    if path.is_file() and path.suffix.lower() in EXCLUDED_SUFFIXES:
        return True
    return False


def _included_files() -> list[str]:
    files: list[str] = []
    for path in sorted(PROJECT_ROOT.rglob("*")):
        if path == PROJECT_ROOT:
            continue
        rel = _relative(path)
        rel_parts = path.relative_to(PROJECT_ROOT).parts
        if not _is_included_tool_bundle(rel) and any(part in EXCLUDED_DIR_NAMES for part in rel_parts[:-1]):
            continue
        if _should_exclude(path):
            continue
        if path.is_file():
            files.append(_relative(path))
    return files


def _copy_to(staging_dir: Path, files: list[str]) -> None:
    for rel in files:
        src = PROJECT_ROOT / rel
        dst = staging_dir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def _sanitize_generated_project_config(staging_dir: Path) -> None:
    opencode = staging_dir / "opencode.json"
    if not opencode.exists():
        return
    try:
        data = json.loads(opencode.read_text(encoding="utf-8"))
    except Exception:
        return
    if not isinstance(data, dict):
        return
    mcp = data.get("mcp")
    if isinstance(mcp, dict) and "godot" in mcp:
        mcp.pop("godot", None)
        if not mcp:
            data.pop("mcp", None)
        _write_text(opencode, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def _create_empty_git_repo(staging_dir: Path) -> None:
    git_dir = staging_dir / ".git"
    for rel in (
        "branches",
        "hooks",
        "info",
        "objects/info",
        "objects/pack",
        "refs/heads",
        "refs/tags",
    ):
        (git_dir / rel).mkdir(parents=True, exist_ok=True)

    _write_text(git_dir / "HEAD", "ref: refs/heads/main\n")
    _write_text(
        git_dir / "config",
        "[core]\n"
        "\trepositoryformatversion = 0\n"
        "\tfilemode = false\n"
        "\tbare = false\n"
        "\tlogallrefupdates = true\n",
    )
    _write_text(
        git_dir / "description",
        "Unnamed repository; edit this file 'description' to name the repository.\n",
    )
    _write_text(
        git_dir / "info" / "exclude",
        "# git ls-files --others --exclude-from=.git/info/exclude\n",
    )


def _write_zip(staging_dir: Path, output: Path) -> None:
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for file in sorted(staging_dir.rglob("*")):
            arcname = file.relative_to(staging_dir).as_posix()
            if file.is_dir():
                archive.write(file, arcname.rstrip("/") + "/")
            elif file.is_file():
                archive.write(file, arcname)


def _write_tgz(staging_dir: Path, output: Path) -> None:
    with tarfile.open(output, "w:gz") as archive:
        archive.add(staging_dir, arcname=".")


def _print_dry_run(files: list[str], output: Path, fmt: str) -> None:
    print("# Export Dry Run")
    print(f"Files: {len(files)}")
    print(f"Output: {output}")
    print(f"Format: {fmt}")
    print(f"Include Tools: {'yes' if INCLUDE_TOOLS else 'no'}")
    print(f"Generated Empty Git Repo: {'yes' if INCLUDE_EMPTY_GIT else 'no'}")
    print("")
    for file in files:
        print(file)


def main() -> int:
    parser = argparse.ArgumentParser(description="导出 Godot V1 Plus 脚手架包")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--format", choices=["zip", "tgz"], default="zip")
    parser.add_argument("--out-dir", default=str(PROJECT_ROOT / "exports"))
    parser.add_argument("--include-tools", action="store_true", help="兼容旧参数：包含 tools/ 下的 portable 工具（现在默认开启）")
    parser.add_argument("--no-tools", action="store_true", help="导出瘦身模板，不包含 tools/ 下的 portable 工具")
    args = parser.parse_args()

    global INCLUDE_TOOLS
    INCLUDE_TOOLS = args.include_tools or not args.no_tools

    files = _included_files()
    code = _read_template_code()
    extension = "zip" if args.format == "zip" else "tar.gz"
    output = Path(args.out_dir).resolve() / f"{code}-{_timestamp()}.{extension}"

    if args.dry_run:
        _print_dry_run(files, output, args.format)
        return 0

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="godot-v1-plus-export-") as temp:
        staging = Path(temp) / code
        staging.mkdir(parents=True, exist_ok=True)
        _copy_to(staging, files)
        _sanitize_generated_project_config(staging)
        if INCLUDE_EMPTY_GIT:
            _create_empty_git_repo(staging)
        if args.format == "zip":
            _write_zip(staging, output)
        else:
            _write_tgz(staging, output)

    size_kb = output.stat().st_size // 1024
    print(f"[OK] 脚手架已导出：{output}（{size_kb} KB，{len(files)} 个文件）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
