#!/usr/bin/env python3
"""Project-local Godot executable discovery."""
from __future__ import annotations

import glob
import os
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
GODOT_ENV_KEYS = ("GODOT4_PATH", "GODOT_PATH")
LOCAL_PATH_FILES = (
    PROJECT_ROOT / "tools" / "godot_path.txt",
    PROJECT_ROOT / ".godot-path",
)


def sort_godot_exec_paths(paths: list[Path]) -> list[str]:
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
            1 if "mono" in value.lower() else 0,
            Path(value).name.lower(),
            value.lower(),
        ),
    )


def _local_path_candidates() -> list[str]:
    candidates: list[str] = []
    for path_file in LOCAL_PATH_FILES:
        if not path_file.is_file():
            continue
        for line in path_file.read_text(encoding="utf-8", errors="replace").splitlines():
            text = line.strip().strip('"')
            if text and not text.startswith("#"):
                candidates.append(text)
    return candidates


def _project_tool_candidates() -> list[str]:
    candidates: list[str] = []
    for root in (PROJECT_ROOT / "tools" / "godot", PROJECT_ROOT / "tools"):
        if root.exists():
            candidates += sort_godot_exec_paths([
                *root.rglob("Godot*.exe"),
                *root.rglob("godot*.exe"),
            ])
    return candidates


def _platform_candidates() -> list[str]:
    candidates: list[str] = ["godot4", "godot"]
    if sys.platform == "win32":
        patterns = [
            r"C:\Program Files\Godot\Godot_v4*_stable_win64_console.exe",
            r"C:\Program Files (x86)\Godot\Godot_v4*_stable_win64_console.exe",
            r"C:\Program Files\Godot\Godot_v4*_stable_win64.exe",
            r"C:\Program Files (x86)\Godot\Godot_v4*_stable_win64.exe",
        ]
        for drive in ("D", "E", "F", "G"):
            patterns.extend([
                rf"{drive}:\godot\**\Godot_v4*_stable_win64_console.exe",
                rf"{drive}:\godot\**\Godot_v4*_stable_win64.exe",
                rf"{drive}:\Godot\**\Godot_v4*_stable_win64_console.exe",
                rf"{drive}:\Godot\**\Godot_v4*_stable_win64.exe",
            ])
        for pattern in patterns:
            candidates += glob.glob(pattern, recursive=True)
    elif sys.platform == "darwin":
        candidates += [
            "/Applications/Godot.app/Contents/MacOS/Godot",
            "/Applications/Godot_4.app/Contents/MacOS/Godot",
        ]
    else:
        candidates += [
            str(Path.home() / ".local/bin/godot4"),
            str(Path.home() / ".local/bin/godot"),
            "/usr/local/bin/godot4",
            "/usr/local/bin/godot",
        ]
    return candidates


def find_godot(hint: str = "") -> str | None:
    candidates: list[str] = []
    if hint:
        candidates.append(hint)
    for key in GODOT_ENV_KEYS:
        value = os.environ.get(key)
        if value:
            candidates.append(value)
    candidates += _local_path_candidates()
    candidates += _project_tool_candidates()
    candidates += _platform_candidates()

    for candidate in candidates:
        resolved = shutil.which(candidate) or (Path(candidate).is_file() and candidate)
        if resolved:
            return str(resolved)
    return None


def godot_version(godot: str, timeout: int = 5) -> str | None:
    try:
        result = subprocess.run(
            [godot, "--version"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except Exception:
        return None
    return (result.stdout or result.stderr or "").strip().splitlines()[0]
