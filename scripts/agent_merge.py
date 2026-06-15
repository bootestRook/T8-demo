#!/usr/bin/env python3
"""Validate sub-agent patches before the coordinator applies them."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from json import JSONDecodeError
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
VALID_ROLES = {"coordinator", "gameplay", "art-ui", "code-review", "qa-review", "godot-debug", "docs"}
MERGEABLE_STATUSES = {"submitted", "accepted"}
AGENT_ARTIFACT_PARTS = (".pm", "workspaces")
WINDOWS_DRIVE_RE = re.compile(r"^[A-Za-z]:/")


def _rel(path: Path) -> str:
    try:
        return path.relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def _normalize_path(value: str) -> str:
    text = value.strip().replace("\\", "/")
    while text.startswith("./"):
        text = text[2:]
    return text


def _is_windows_absolute_form(value: str) -> bool:
    normalized = _normalize_path(value)
    return bool(WINDOWS_DRIVE_RE.match(normalized)) or normalized.startswith("//")


def _has_parent_segment(value: str) -> bool:
    return any(part == ".." for part in _normalize_path(value).split("/"))


def _is_project_relative(value: str) -> bool:
    normalized = _normalize_path(value)
    return (
        bool(normalized)
        and not Path(normalized).is_absolute()
        and not _is_windows_absolute_form(normalized)
        and not _has_parent_segment(normalized)
    )


def _read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _read_json_result(path: Path) -> tuple[Any | None, str | None]:
    try:
        return _read_json(path), None
    except JSONDecodeError as exc:
        return None, f"invalid JSON in {path}: line {exc.lineno} column {exc.colno}: {exc.msg}"


def _validate_manifest_location(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        rel = path.resolve().relative_to(PROJECT_ROOT)
    except ValueError:
        return [f"manifest must stay inside project: {path}"]
    parts = rel.parts
    if (
        len(parts) != 8
        or parts[0:2] != AGENT_ARTIFACT_PARTS
        or parts[4:6] != ("artifacts", "agents")
        or any(not part for part in (parts[2], parts[3], parts[6], parts[7]))
    ):
        errors.append("manifest must be under .pm/workspaces/<owner>/<demand>/artifacts/agents/")
    if parts and parts[-1] != "manifest.json":
        errors.append("manifest file name must be manifest.json")
    return errors


def _path_matches(path: str, patterns: list[str]) -> bool:
    normalized = _normalize_path(path)
    for raw in patterns:
        pattern = _normalize_path(raw)
        if not pattern:
            continue
        if pattern.endswith("/"):
            if normalized.startswith(pattern):
                return True
        elif normalized == pattern or normalized.startswith(pattern.rstrip("/") + "/"):
            return True
    return False


def _paths_from_patch(text: str) -> list[str]:
    paths: set[str] = set()
    for line in text.splitlines():
        if line.startswith("+++ ") or line.startswith("--- "):
            value = line[4:].strip()
            if value == "/dev/null":
                continue
            if value.startswith('"') and value.endswith('"'):
                value = value[1:-1]
            value = re.sub(r"^[ab]/", "", value)
            if value:
                paths.add(_normalize_path(value))
    return sorted(paths)


def _validate_manifest(data: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["manifest must be a JSON object"]
    required = ["demand_id", "task_id", "role", "status", "goal", "allowed_paths", "blocked_paths"]
    for key in required:
        if key not in data:
            errors.append(f"missing field: {key}")
    if data.get("role") not in VALID_ROLES:
        errors.append(f"invalid role: {data.get('role')}")
    if data.get("status") not in MERGEABLE_STATUSES:
        errors.append(f"manifest status must be submitted or accepted: {data.get('status')}")
    for key in ["allowed_paths", "blocked_paths"]:
        value = data.get(key, [])
        if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
            errors.append(f"{key} must be a list of strings")
            continue
        for path in value:
            if not _is_project_relative(path):
                errors.append(f"path must be project-relative: {path}")
    if not data.get("allowed_paths"):
        errors.append("allowed_paths must not be empty")
    return errors


def _string_list(value: Any) -> list[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        return []
    return value


def _git_apply_check(patch: Path) -> tuple[bool, str]:
    proc = subprocess.run(
        ["git", "apply", "--check", str(patch)],
        cwd=PROJECT_ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=60,
    )
    return proc.returncode == 0, proc.stdout.strip()


def cmd_check(args: argparse.Namespace) -> int:
    manifest_path = Path(args.manifest).resolve()
    patch_path = Path(args.patch).resolve()
    if not manifest_path.exists():
        print(json.dumps({"ok": False, "error": f"manifest not found: {manifest_path}"}, ensure_ascii=False))
        return 1
    if not patch_path.exists():
        print(json.dumps({"ok": False, "error": f"patch not found: {patch_path}"}, ensure_ascii=False))
        return 1

    manifest, read_error = _read_json_result(manifest_path)
    if read_error:
        print(
            json.dumps(
                {
                    "ok": False,
                    "manifest": _rel(manifest_path),
                    "patch": _rel(patch_path),
                    "touched_files": [],
                    "errors": [read_error],
                    "git_apply_check": {
                        "ok": False,
                        "output": "",
                    },
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 1
    manifest_data = manifest if isinstance(manifest, dict) else {}
    allowed = _string_list(manifest_data.get("allowed_paths", []))
    blocked = _string_list(manifest_data.get("blocked_paths", []))
    patch_text = patch_path.read_text(encoding="utf-8", errors="replace")
    touched = _paths_from_patch(patch_text)

    errors: list[str] = _validate_manifest_location(manifest_path) + _validate_manifest(manifest)
    if not touched:
        errors.append("patch does not touch any files")
    for path in touched:
        if not _is_project_relative(path):
            errors.append(f"patch path must be project-relative: {path}")
        if _path_matches(path, blocked):
            errors.append(f"blocked path touched: {path}")
        if not _path_matches(path, allowed):
            errors.append(f"path outside allowed_paths: {path}")

    apply_ok = False
    apply_output = ""
    if not errors:
        apply_ok, apply_output = _git_apply_check(patch_path)
        if not apply_ok:
            errors.append("git apply --check failed")

    print(
        json.dumps(
            {
                "ok": not errors,
                "manifest": _rel(manifest_path),
                "patch": _rel(patch_path),
                "touched_files": touched,
                "errors": errors,
                "git_apply_check": {
                    "ok": apply_ok,
                    "output": apply_output,
                },
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0 if not errors else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    check = sub.add_parser("check", help="Validate a patch against a task manifest")
    check.add_argument("--manifest", required=True)
    check.add_argument("--patch", required=True)
    check.set_defaults(func=cmd_check)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
