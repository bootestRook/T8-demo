#!/usr/bin/env python3
"""Create and validate lightweight sub-agent task packages."""
from __future__ import annotations

import argparse
import json
import re
import sys
from json import JSONDecodeError
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PM_WORKSPACES = PROJECT_ROOT / ".pm" / "workspaces"
VALID_ROLES = {"coordinator", "gameplay", "art-ui", "code-review", "qa-review", "godot-debug", "docs"}
VALID_STATUSES = {"draft", "assigned", "running", "submitted", "accepted", "rejected", "merged"}
DEFAULT_BLOCKED_PATHS = [".pm/project/", ".git/", ".godot/", "html5/", "exports/", "references/"]
AGENT_ARTIFACT_PARTS = (".pm", "workspaces")
WINDOWS_DRIVE_RE = re.compile(r"^[A-Za-z]:/")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


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


def _write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def _workspace_for_demand(demand_id: str) -> Path:
    matches = [
        path
        for path in PM_WORKSPACES.glob(f"*/*{demand_id}*")
        if path.is_dir() and (path / "meta.json").exists()
    ]
    if len(matches) == 1:
        return matches[0]
    if not matches:
        raise SystemExit(f"No PM workspace found for demand {demand_id}.")
    joined = ", ".join(_rel(path) for path in matches)
    raise SystemExit(f"Multiple PM workspaces found for demand {demand_id}: {joined}")


def _safe_slug(value: str) -> str:
    text = re.sub(r"[^A-Za-z0-9_.-]+", "-", value.strip())
    return text.strip("-") or "agent"


def _manifest_path(args: argparse.Namespace) -> Path:
    if args.manifest:
        return Path(args.manifest).resolve()
    workspace = _workspace_for_demand(args.demand_id)
    role = _safe_slug(args.role)
    return workspace / "artifacts" / "agents" / f"{args.task_id}-{role}" / "manifest.json"


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


def _assignment_text(manifest: dict[str, Any]) -> str:
    allowed = "\n".join(f"- `{path}`" for path in manifest["allowed_paths"]) or "- "
    blocked = "\n".join(f"- `{path}`" for path in manifest["blocked_paths"]) or "- "
    gates = "\n".join(f"- `{gate}`" for gate in manifest["required_gates"]) or "- "
    read_first = "\n".join(f"- `{path}`" for path in manifest["read_first"]) or "- `AGENTS.md`"
    return f"""# 子 Agent 任务包

## 基本信息

- Demand ID: {manifest["demand_id"]}
- Task ID: {manifest["task_id"]}
- Role: {manifest["role"]}
- Status: {manifest["status"]}
- Coordinator: {manifest["coordinator"]}

## 目标

{manifest["goal"]}

## 必读上下文

{read_first}

## 允许改动路径

{allowed}

## 禁止改动路径

{blocked}

## 必须交付

- `result.md`：结论、改动摘要、风险和验证结果。
- `changed_files.txt`：触达文件清单。
- `changes.patch`：如有代码或文档改动，提供 patch。
- `logs/`：关键命令输出摘要。

## 建议检查

{gates}

## 执行规则

- 不直接修改 `.pm/project/*.json`。
- 不做 git commit、push、reset、checkout 覆盖或历史改写。
- 不删除文件或目录，不全局安装依赖，不修改系统配置。
- 如需越过允许路径，先在 `result.md` 中说明，不自行扩大范围。
"""


def _validate_manifest(data: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["manifest must be a JSON object"]
    required = ["demand_id", "task_id", "role", "status", "goal", "allowed_paths", "blocked_paths"]
    for key in required:
        if key not in data:
            errors.append(f"missing field: {key}")
    role = data.get("role")
    if role not in VALID_ROLES:
        errors.append(f"invalid role: {role}")
    status = data.get("status")
    if status not in VALID_STATUSES:
        errors.append(f"invalid status: {status}")
    path_values: list[str] = []
    allowed: list[str] = []
    for key in ["allowed_paths", "blocked_paths", "read_first", "required_gates"]:
        value = data.get(key, [])
        if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
            errors.append(f"{key} must be a list of strings")
            continue
        if key == "allowed_paths":
            allowed = [_normalize_path(path) for path in value]
        if key in {"allowed_paths", "blocked_paths"}:
            path_values += [_normalize_path(path) for path in value]
    if not allowed:
        errors.append("allowed_paths must not be empty")
    for path in path_values:
        if not _is_project_relative(path):
            errors.append(f"path must be project-relative: {path}")
    return errors


def cmd_create(args: argparse.Namespace) -> int:
    if args.role not in VALID_ROLES:
        print(json.dumps({"ok": False, "error": f"invalid role: {args.role}"}, ensure_ascii=False))
        return 1
    manifest_path = _manifest_path(args)
    task_dir = manifest_path.parent
    location_errors = _validate_manifest_location(manifest_path)
    if location_errors:
        print(json.dumps({"ok": False, "errors": location_errors}, ensure_ascii=False, indent=2))
        return 1
    protected_existing = [
        path for path in [manifest_path, task_dir / "assignment.md", task_dir / "changed_files.txt", task_dir / "result.md"]
        if path.exists()
    ]
    if protected_existing and not args.force:
        print(
            json.dumps(
                {
                    "ok": False,
                    "error": "task package already exists; rerun with --force to overwrite manifest and assignment",
                    "existing": [_rel(path) for path in protected_existing],
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 1
    allowed = [_normalize_path(path) for path in args.allowed_path]
    blocked = [_normalize_path(path) for path in (args.blocked_path or DEFAULT_BLOCKED_PATHS)]
    read_first = [_normalize_path(path) for path in (args.read_first or ["AGENTS.md", "docs/MULTI_AGENT_WORKFLOW.md"])]
    manifest = {
        "schema_version": 1,
        "demand_id": args.demand_id,
        "task_id": args.task_id,
        "role": args.role,
        "status": args.status,
        "goal": args.goal,
        "coordinator": args.coordinator,
        "allowed_paths": allowed,
        "blocked_paths": blocked,
        "read_first": read_first,
        "required_gates": args.required_gate,
        "created_at": _now(),
        "updated_at": _now(),
    }
    errors = _validate_manifest(manifest)
    if errors:
        print(json.dumps({"ok": False, "errors": errors}, ensure_ascii=False, indent=2))
        return 1
    task_dir.mkdir(parents=True, exist_ok=True)
    _write_json(manifest_path, manifest)
    _write_text(task_dir / "assignment.md", _assignment_text(manifest))
    changed_files_path = task_dir / "changed_files.txt"
    if not changed_files_path.exists():
        _write_text(changed_files_path, "")
    (task_dir / "logs").mkdir(exist_ok=True)
    print(
        json.dumps(
            {
                "ok": True,
                "manifest": _rel(manifest_path),
                "assignment": _rel(task_dir / "assignment.md"),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    path = Path(args.manifest).resolve()
    if not path.exists():
        print(json.dumps({"ok": False, "error": f"manifest not found: {path}"}, ensure_ascii=False))
        return 1
    data, read_error = _read_json_result(path)
    if read_error:
        print(json.dumps({"ok": False, "manifest": _rel(path), "errors": [read_error], "warnings": []}, ensure_ascii=False, indent=2))
        return 1
    errors = _validate_manifest_location(path) + _validate_manifest(data)
    manifest_data = data if isinstance(data, dict) else {}
    result_path = path.parent / "result.md"
    changed_files_path = path.parent / "changed_files.txt"
    warnings: list[str] = []
    if manifest_data.get("status") in {"submitted", "accepted", "merged"} and not result_path.exists():
        errors.append("submitted tasks require result.md")
    if manifest_data.get("status") in {"submitted", "accepted", "merged"} and not changed_files_path.exists():
        errors.append("submitted tasks require changed_files.txt")
    if not (path.parent / "assignment.md").exists():
        warnings.append("assignment.md is missing")
    print(
        json.dumps(
            {
                "ok": not errors,
                "manifest": _rel(path),
                "errors": errors,
                "warnings": warnings,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0 if not errors else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    create = sub.add_parser("create", help="Create a sub-agent task package")
    create.add_argument("--demand-id", required=True)
    create.add_argument("--task-id", required=True)
    create.add_argument("--role", required=True, choices=sorted(VALID_ROLES))
    create.add_argument("--goal", required=True)
    create.add_argument("--coordinator", default="codex")
    create.add_argument("--status", default="draft", choices=sorted(VALID_STATUSES))
    create.add_argument("--allowed-path", action="append", required=True)
    create.add_argument("--blocked-path", action="append")
    create.add_argument("--read-first", action="append")
    create.add_argument("--required-gate", action="append", default=[])
    create.add_argument("--manifest")
    create.add_argument("--force", action="store_true", help="Overwrite an existing manifest and assignment")
    create.set_defaults(func=cmd_create)

    check = sub.add_parser("check", help="Validate a sub-agent task manifest")
    check.add_argument("--manifest", required=True)
    check.set_defaults(func=cmd_check)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
