#!/usr/bin/env python3
"""运行安装到本仓库 tools/ 下的 Python console_scripts 入口。"""
from __future__ import annotations

import argparse
import importlib.metadata as metadata
import sys
from pathlib import Path
from typing import Sequence

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")


def _entry_points(name: str) -> list[metadata.EntryPoint]:
    eps = metadata.entry_points()
    if hasattr(eps, "select"):
        return list(eps.select(group="console_scripts", name=name))
    return [ep for ep in eps.get("console_scripts", []) if ep.name == name]


def _insert_paths(paths: Sequence[str]) -> None:
    for raw in reversed(paths):
        path = str(Path(raw).resolve())
        if path not in sys.path:
            sys.path.insert(0, path)


def main() -> int:
    parser = argparse.ArgumentParser(description="运行本地 target 目录中的 Python entry point")
    parser.add_argument("--target", action="append", default=[], help="包含 site-packages 的目录，可重复")
    parser.add_argument("entry", help="console_scripts 入口名称，例如 gdlint、gdformat、pytest")
    parser.add_argument("entry_args", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    _insert_paths(args.target)
    matches = _entry_points(args.entry)
    if not matches:
        print(f"[FAIL] 未找到 Python entry point：{args.entry}", file=sys.stderr)
        return 1

    sys.argv = [args.entry, *args.entry_args]
    try:
        result = matches[0].load()()
    except SystemExit as exc:
        code = exc.code
        return int(code) if isinstance(code, int) else 1
    return int(result or 0)


if __name__ == "__main__":
    raise SystemExit(main())
