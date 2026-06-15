#!/usr/bin/env python3
"""Start the bundled Godot MCP server over stdio.

This wrapper keeps AI client configs stable across user directories. Client
configs can call this script from the project root; the script resolves Node,
the bundled Coding-Solo server, and Godot from the current checkout.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def _first_file(paths: list[Path]) -> Path | None:
    for path in paths:
        if path.is_file():
            return path
    return None


def _sort_godot_exec_paths(paths: list[Path]) -> list[Path]:
    dedup: list[Path] = []
    seen: set[str] = set()
    for path in paths:
        if not path.is_file():
            continue
        key = str(path).lower()
        if key in seen:
            continue
        seen.add(key)
        dedup.append(path)
    return sorted(
        dedup,
        key=lambda value: (
            0 if "console" in value.name.lower() else 1,
            value.name.lower(),
            str(value).lower(),
        ),
    )


def find_node() -> str | None:
    if sys.platform == "win32":
        local = _first_file([
            PROJECT_ROOT / "tools" / "node" / "node.exe",
            PROJECT_ROOT / "tools" / "node" / "bin" / "node.exe",
        ])
    else:
        local = _first_file([
            PROJECT_ROOT / "tools" / "node" / "bin" / "node",
            PROJECT_ROOT / "tools" / "node" / "node",
        ])
    if local:
        return str(local)
    return shutil.which("node")


def find_mcp_entry() -> Path | None:
    for root in [PROJECT_ROOT / "tools" / "godot-mcp-node", PROJECT_ROOT / "tools" / "godot-mcp"]:
        for entry in (
            root / "node_modules" / "@coding-solo" / "godot-mcp" / "build" / "index.js",
            root / "build" / "index.js",
        ):
            if entry.is_file():
                return entry
    return None


def find_godot() -> str | None:
    for key in ("GODOT_PATH", "GODOT4_PATH"):
        value = os.environ.get(key)
        if value and Path(value).is_file():
            return value

    candidates: list[Path] = []
    for root in [PROJECT_ROOT / "tools" / "godot", PROJECT_ROOT / "tools"]:
        if root.exists():
            candidates += _sort_godot_exec_paths([
                *root.rglob("Godot*.exe"),
                *root.rglob("godot*.exe"),
            ])
    if candidates:
        return str(candidates[0])
    return shutil.which("godot4") or shutil.which("godot")


def main() -> int:
    node = find_node()
    entry = find_mcp_entry()
    godot = find_godot()

    if not node:
        print("GodotMCP startup failed: Node.js was not found.", file=sys.stderr)
        return 1
    if not entry:
        print("GodotMCP startup failed: bundled @coding-solo/godot-mcp was not found.", file=sys.stderr)
        return 1
    if not godot:
        print("GodotMCP startup failed: Godot executable was not found.", file=sys.stderr)
        return 1

    env = os.environ.copy()
    env["GODOT_PATH"] = godot
    return subprocess.run([node, str(entry)], cwd=PROJECT_ROOT, env=env).returncode


if __name__ == "__main__":
    raise SystemExit(main())
