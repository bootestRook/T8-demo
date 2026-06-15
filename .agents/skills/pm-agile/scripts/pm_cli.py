#!/usr/bin/env python3
"""
pm-agile core workflow CLI.
All data files are JSON. The skill layer never touches the raw format.

Usage:
    python pm_cli.py <command> [args...]

Commands:
    role <username>              Set current username
    init-backlog                 Initialize .pm/project/backlog.json and archived.json
    init-workspace <demand_id> <title> [owner]
                                 Create workspace dir with meta/todo/notes/artifacts
    archive <demand_id>          Archive demand (move workspace, update backlog/archived)
    unarchive <demand_id> [--status doing]
                                 Restore archived demand to backlog
    check [demand_id]            Check status consistency and path compliance
    status                       Print current doing/blocked/review status summary
    new-id [username]            Generate next available demand ID (e.g. arrow-B-03)
    set-status <demand_id> <status>
                                 Update demand status (sync backlog + meta.json)
    update-meta <demand_id> [--current-task ...]
                                 Update workspace/meta.json summary fields
    move-task <demand_id> <task_id> <target>
                                 Move task to target section (todo/doing/done/future)
    add-backlog <demand_id> <title> [--owner ...]
                                 Add new demand to backlog
    add-task <demand_id> <task_id> <content> [--priority P1] [--section todo]
                                 Add a new task to todo.json
    migrate-from-md              One-time migration: convert existing .md data to .json
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import shutil
import sys
from datetime import date
from pathlib import Path
from typing import Any


def _ensure_utf8_stdout() -> None:
    if sys.platform == "win32":
        try:
            sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
            sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")
        except Exception:
            pass


SKILL_DIR = Path(__file__).resolve().parent.parent
ROOT = Path(os.environ.get("PM_ROOT", "")).resolve() if os.environ.get("PM_ROOT") else SKILL_DIR.parents[2]

PM_PROJECT = ROOT / ".pm" / "project"
PM_WORKSPACES = ROOT / ".pm" / "workspaces"
PM_ARCHIVED = PM_WORKSPACES / "archived"
PM_LOCAL = ROOT / ".pm" / "local"
TEMPLATES = SKILL_DIR / "templates"


def _today() -> str:
    return date.today().isoformat()


def _read_json(path: Path) -> Any:
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8")
    text = re.sub(r",\s*([}\]])", r"\1", text)
    decoder = json.JSONDecoder()
    try:
        obj, end = decoder.raw_decode(text)
        if text[end:].strip():
            raise json.JSONDecodeError("Extra data", text, end)
        return obj
    except json.JSONDecodeError:
        pass
    return json.loads(text)


def _write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    content = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    tmp = path.with_suffix(".tmp")
    tmp.write_text(content, encoding="utf-8", newline="\n")
    try:
        tmp.replace(path)
    except OSError:
        path.write_text(content, encoding="utf-8", newline="\n")
        tmp.unlink(missing_ok=True)


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def _current_role() -> str | None:
    role_data = _read_json(PM_LOCAL / "current-role.json")
    if role_data:
        return role_data.get("username")
    return None


VALID_DEMAND_STATUSES = {"planning", "todo", "doing", "blocked", "review", "done"}
VALID_WORKSPACE_STATUSES = {"active", "archived"}
VALID_TASK_STATUSES = {"todo", "doing", "blocked", "done"}


def _default_backlog() -> dict:
    return {
        "overview": {
            "current_phase": "",
            "top_goal": "",
            "main_risk": "",
        },
        "demands": [],
        "planning_conclusions": [],
    }


def _default_archived() -> dict:
    return {
        "demands": [],
    }


def _default_handoff() -> dict:
    return {
        "handoffs": [],
    }


def _read_handoff() -> dict:
    handoff_path = PM_PROJECT / "handoff.json"
    data = _read_json(handoff_path)
    if data is None:
        data = _default_handoff()
        _write_json(handoff_path, data)
    return data


def _write_handoff(data: dict) -> None:
    handoff_path = PM_PROJECT / "handoff.json"
    _write_json(handoff_path, data)


def _find_handoff_by_id(handoff_data: dict, demand_id: str) -> dict | None:
    for handoff in handoff_data.get("handoffs", []):
        if handoff.get("demand_id") == demand_id:
            return handoff
    return None


def _remove_handoff_by_id(handoff_data: dict, demand_id: str) -> bool:
    handoffs = handoff_data.get("handoffs", [])
    for i, handoff in enumerate(handoffs):
        if handoff.get("demand_id") == demand_id:
            handoffs.pop(i)
            return True
    return False


def _default_meta(demand_id: str = "", title: str = "", owner: str = "") -> dict:
    return {
        "demand_id": demand_id,
        "title": title,
        "owner": owner,
        "priority": "P1",
        "created_date": _today(),
        "last_updated": _today(),
        "demand_status": "planning",
        "workspace_status": "active",
        "deps": "",
        "related_docs": "",
        "workspace_path": "",
        "summary": {
            "current_task": "无",
            "next_task": "无",
            "block": "无",
            "done_criteria": "",
            "read_first": "无",
            "products": "无",
            "manual_step": "否",
            "followup": "无",
        },
    }


def _default_todo(demand_id: str = "", title: str = "", owner: str = "") -> dict:
    return {
        "demand_id": demand_id,
        "title": title,
        "owner": owner,
        "sections": {
            "todo": [],
            "doing": [],
            "done": [],
            "future": [],
        },
    }


def _default_notes_md(demand_id: str = "", title: str = "", owner: str = "") -> str:
    return (
        f"# 需求摘要与索引\n\n"
        f"- 需求ID：{demand_id}\n"
        f"- 需求标题：{title}\n"
        f"- 负责人：{owner}\n\n"
        f"## 需求摘要\n\n- \n\n"
        f"## 当前状态\n\n- 当前任务：\n- 下一步：\n- 阻塞：无\n\n"
        f"## 风险与说明\n\n- \n\n"
        f"## 相关产物索引\n\n"
        f"- 详细规格：artifacts/spec.md\n"
        f"- 执行日志：artifacts/execution-log.md\n"
        f"- 决策记录：artifacts/decisions.md\n"
        f"- 验证记录：artifacts/validation.md\n"
        f"- 归档/取消说明：artifacts/archive/\n\n"
        f"## 简要进度\n\n- \n\n"
        f"## 备注\n\n- 详细 PM 记录不得直接写入 notes.md；请写入 artifacts/*.md 后在上方索引。\n"
    )


def _ensure_artifact_files(ws_path: Path) -> None:
    artifacts = ws_path / "artifacts"
    artifacts.mkdir(parents=True, exist_ok=True)
    (artifacts / "archive").mkdir(parents=True, exist_ok=True)
    defaults = {
        "spec.md": "# 详细规格\n\n- \n",
        "execution-log.md": "# 执行日志\n\n- \n",
        "decisions.md": "# 决策记录\n\n- \n",
        "validation.md": "# 验证记录\n\n- \n",
    }
    for name, content in defaults.items():
        path = artifacts / name
        if not path.exists():
            _write_text(path, content)


def _find_demand_in_backlog(demand_id: str) -> dict | None:
    backlog = _read_json(PM_PROJECT / "backlog.json")
    if not backlog:
        return None
    for d in backlog.get("demands", []):
        if d.get("demand_id") == demand_id:
            return d
    return None


def _find_demand_in_archived(demand_id: str) -> dict | None:
    archived = _read_json(PM_PROJECT / "archived.json")
    if not archived:
        return None
    for d in archived.get("demands", []):
        if d.get("demand_id") == demand_id:
            return d
    return None


def _find_demand_anywhere(demand_id: str) -> dict | None:
    return _find_demand_in_backlog(demand_id) or _find_demand_in_archived(demand_id)


def _save_backlog(backlog: dict) -> None:
    _write_json(PM_PROJECT / "backlog.json", backlog)


def _save_archived(archived: dict) -> None:
    _write_json(PM_PROJECT / "archived.json", archived)


def _workspace_path(owner: str, demand_id: str, title: str) -> Path:
    safe_title = re.sub(r"[^\w\u4e00-\u9fff-]", "", title)[:20]
    dirname = f"{_today()}-{demand_id}-{safe_title}"
    return PM_WORKSPACES / owner / dirname


def _meta_path_for_demand(demand_id: str) -> Path | None:
    demand = _find_demand_in_backlog(demand_id)
    if not demand:
        return None
    ws = demand.get("workspace_path", "")
    if not ws or ws in {"—", "-", ""}:
        return None
    return ROOT / ws.replace("/", "\\") / "meta.json"


def _todo_path_for_demand(demand_id: str) -> Path | None:
    demand = _find_demand_in_backlog(demand_id)
    if not demand:
        return None
    ws = demand.get("workspace_path", "")
    if not ws or ws in {"—", "-", ""}:
        return None
    return ROOT / ws.replace("/", "\\") / "todo.json"


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_role(args: argparse.Namespace) -> int:
    username = args.username
    data = {
        "username": username,
        "member_name": username,
        "default_workspace": f".pm/workspaces/{username}/",
    }
    _write_json(PM_LOCAL / "current-role.json", data)
    print(json.dumps({"ok": True, "username": username}, ensure_ascii=False))
    return 0


def cmd_init_backlog(_args: argparse.Namespace) -> int:
    PM_PROJECT.mkdir(parents=True, exist_ok=True)
    backlog_path = PM_PROJECT / "backlog.json"
    archived_path = PM_PROJECT / "archived.json"
    handoff_path = PM_PROJECT / "handoff.json"
    results: list[str] = []
    if not backlog_path.exists():
        _write_json(backlog_path, _default_backlog())
        results.append(f"已创建: {backlog_path}")
    if not archived_path.exists():
        _write_json(archived_path, _default_archived())
        results.append(f"已创建: {archived_path}")
    if not handoff_path.exists():
        _write_json(handoff_path, _default_handoff())
        results.append(f"已创建: {handoff_path}")
    print(json.dumps({"ok": True, "results": results}, ensure_ascii=False))
    return 0


def cmd_init_workspace(args: argparse.Namespace) -> int:
    demand_id: str = args.demand_id
    title: str = args.title
    owner: str = args.owner or _current_role() or ""
    if not owner:
        print(json.dumps({"ok": False, "error": "未指定负责人，且未设置当前用户名。请先执行: pm_cli.py role <用户名>"}, ensure_ascii=False))
        return 1

    PM_PROJECT.mkdir(parents=True, exist_ok=True)

    backlog_path = PM_PROJECT / "backlog.json"
    if not backlog_path.exists():
        _write_json(backlog_path, _default_backlog())

    archived_path = PM_PROJECT / "archived.json"
    if not archived_path.exists():
        _write_json(archived_path, _default_archived())

    ws_path = _workspace_path(owner, demand_id, title)
    if ws_path.exists():
        _ensure_artifact_files(ws_path)
        print(json.dumps({"ok": True, "workspace": str(ws_path), "note": "工作区已存在"}, ensure_ascii=False))
        return 0

    ws_path.mkdir(parents=True, exist_ok=True)
    (ws_path / "artifacts").mkdir(parents=True, exist_ok=True)
    _ensure_artifact_files(ws_path)

    rel_path = str(ws_path.relative_to(ROOT)).replace("\\", "/")

    meta = _default_meta(demand_id, title, owner)
    meta["demand_status"] = "doing"
    meta["workspace_path"] = rel_path
    _write_json(ws_path / "meta.json", meta)

    todo = _default_todo(demand_id, title, owner)
    _write_json(ws_path / "todo.json", todo)

    _write_text(ws_path / "notes.md", _default_notes_md(demand_id, title, owner))

    backlog = _read_json(backlog_path) or _default_backlog()
    existing = None
    for d in backlog.get("demands", []):
        if d.get("demand_id") == demand_id:
            existing = d
            break

    if existing:
        existing["status"] = "doing"
        existing["workspace_path"] = rel_path
    else:
        backlog.setdefault("demands", []).append({
            "demand_id": demand_id,
            "title": title,
            "owner": owner,
            "priority": "P1",
            "status": "doing",
            "deps": "",
            "related_docs": "",
            "workspace_path": rel_path,
            "remark": "",
        })

    _save_backlog(backlog)

    print(json.dumps({"ok": True, "workspace": str(ws_path), "files": ["meta.json", "todo.json", "notes.md", "artifacts/"]}, ensure_ascii=False))
    return 0


def cmd_archive(args: argparse.Namespace) -> int:
    demand_id: str = args.demand_id
    backlog = _read_json(PM_PROJECT / "backlog.json")
    if not backlog:
        print(json.dumps({"ok": False, "error": "backlog.json 不存在"}, ensure_ascii=False))
        return 1

    demand = None
    demand_idx = None
    for i, d in enumerate(backlog.get("demands", [])):
        if d.get("demand_id") == demand_id:
            demand = d
            demand_idx = i
            break

    if not demand:
        print(json.dumps({"ok": False, "error": f"backlog 中未找到需求 {demand_id}"}, ensure_ascii=False))
        return 1

    owner = demand.get("owner") or _current_role() or "unknown"
    ws_raw = demand.get("workspace_path", "").strip("`")
    ws_path = ROOT / ws_raw.replace("/", "\\") if ws_raw and ws_raw not in {"—", "-", ""} else None

    if not ws_path or not ws_path.exists():
        search_root = PM_WORKSPACES / owner
        found_paths = [
            d for d in search_root.iterdir()
            if d.is_dir() and demand_id in d.name
        ] if search_root.exists() else []
        if len(found_paths) == 1:
            ws_path = found_paths[0]
        elif len(found_paths) > 1:
            print(json.dumps({"ok": False, "error": "找到多个匹配 workspace，请手动指定", "paths": [str(p.relative_to(ROOT)) for p in found_paths]}, ensure_ascii=False))
            return 1
        else:
            print(json.dumps({"ok": False, "error": f"工作区不存在且无法自动定位 (backlog 路径: {ws_raw!r})"}, ensure_ascii=False))
            return 1

    if "archived" not in str(ws_path).replace("\\", "/").split("/"):
        archived_ws = PM_ARCHIVED / owner / ws_path.name
        if archived_ws.exists():
            shutil.rmtree(archived_ws, ignore_errors=True)
        shutil.move(str(ws_path), str(archived_ws))
        ws_path = archived_ws
        rel_path = str(archived_ws.relative_to(ROOT)).replace("\\", "/")
    else:
        rel_path = ws_raw

    meta_path = ws_path / "meta.json"
    if meta_path.exists():
        meta = _read_json(meta_path)
        if meta:
            meta["demand_status"] = "done"
            meta["workspace_status"] = "archived"
            meta["workspace_path"] = rel_path
            meta["summary"]["current_task"] = "无"
            meta["summary"]["next_task"] = "无"
            meta["last_updated"] = _today()
            _write_json(meta_path, meta)

    backlog["demands"].pop(demand_idx)

    cleaned = [c for c in backlog.get("planning_conclusions", []) if demand_id not in c]
    cleaned_conclusions = len(cleaned) != len(backlog.get("planning_conclusions", []))
    if cleaned_conclusions:
        backlog["planning_conclusions"] = cleaned

    _save_backlog(backlog)

    archived = _read_json(PM_PROJECT / "archived.json") or _default_archived()
    archive_entry = dict(demand)
    archive_entry["status"] = "done"
    archive_entry["workspace_path"] = rel_path
    archive_entry["archive_date"] = _today()
    archived.setdefault("demands", []).append(archive_entry)
    _save_archived(archived)

    print(json.dumps({"ok": True, "demand_id": demand_id, "workspace": str(ws_path), "cleaned_conclusions": cleaned_conclusions}, ensure_ascii=False))
    return 0


def cmd_unarchive(args: argparse.Namespace) -> int:
    """恢复已归档的需求到 backlog，并移动 workspace 回 active 区域"""
    demand_id: str = args.demand_id
    target_status: str = args.status

    if target_status not in VALID_DEMAND_STATUSES:
        print(json.dumps({"ok": False, "error": f"非法状态 '{target_status}'，允许值: {', '.join(sorted(VALID_DEMAND_STATUSES))}"}, ensure_ascii=False))
        return 1

    archived = _read_json(PM_PROJECT / "archived.json")
    if not archived:
        print(json.dumps({"ok": False, "error": "archived.json 不存在"}, ensure_ascii=False))
        return 1

    demand = None
    demand_idx = -1
    for idx, d in enumerate(archived.get("demands", [])):
        if d.get("demand_id") == demand_id:
            demand = d
            demand_idx = idx
            break

    if not demand:
        print(json.dumps({"ok": False, "error": f"archived.json 中未找到需求 {demand_id}"}, ensure_ascii=False))
        return 1

    owner = demand.get("owner", "unknown")
    ws_raw = demand.get("workspace_path", "").strip("`")
    
    if not ws_raw or ws_raw in {"—", "-", ""}:
        print(json.dumps({"ok": False, "error": f"需求 {demand_id} 无工作区路径"}, ensure_ascii=False))
        return 1

    ws_path = ROOT / ws_raw.replace("/", "\\")
    if not ws_path.exists():
        print(json.dumps({"ok": False, "error": f"工作区不存在: {ws_path}"}, ensure_ascii=False))
        return 1

    if "archived" in str(ws_path).replace("\\", "/").split("/"):
        active_ws = PM_WORKSPACES / owner / ws_path.name
        if active_ws.exists():
            shutil.rmtree(active_ws, ignore_errors=True)
        active_ws.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(ws_path), str(active_ws))
        ws_path = active_ws
        rel_path = str(active_ws.relative_to(ROOT)).replace("\\", "/")
    else:
        rel_path = ws_raw

    meta_path = ws_path / "meta.json"
    if meta_path.exists():
        meta = _read_json(meta_path)
        if meta:
            meta["demand_status"] = target_status
            meta["workspace_status"] = "active"
            meta["workspace_path"] = rel_path
            meta["last_updated"] = _today()
            _write_json(meta_path, meta)

    archived["demands"].pop(demand_idx)
    _save_archived(archived)

    backlog = _read_json(PM_PROJECT / "backlog.json") or _default_backlog()
    backlog_entry = dict(demand)
    backlog_entry["status"] = target_status
    backlog_entry["workspace_path"] = rel_path
    if "archive_date" in backlog_entry:
        del backlog_entry["archive_date"]
    
    backlog.setdefault("demands", []).append(backlog_entry)
    _save_backlog(backlog)

    print(json.dumps({"ok": True, "demand_id": demand_id, "status": target_status, "workspace": rel_path}, ensure_ascii=False))
    return 0


def cmd_new_id(args: argparse.Namespace) -> int:
    username: str | None = getattr(args, "username", None) or _current_role()
    prefix = f"{username}-B-" if username else "B-"

    used_numbers: list[int] = []
    for path in [PM_PROJECT / "backlog.json", PM_PROJECT / "archived.json"]:
        data = _read_json(path)
        if data:
            for d in data.get("demands", []):
                did = d.get("demand_id", "")
                if did.startswith(prefix):
                    suffix = did[len(prefix):]
                    if suffix.isdigit():
                        used_numbers.append(int(suffix))

    next_num = max(used_numbers, default=0) + 1
    new_id = f"{prefix}{next_num:02d}"
    print(json.dumps({"ok": True, "demand_id": new_id}, ensure_ascii=False))
    return 0


def cmd_set_status(args: argparse.Namespace) -> int:
    demand_id: str = args.demand_id
    new_status: str = args.status
    if new_status not in VALID_DEMAND_STATUSES:
        print(json.dumps({"ok": False, "error": f"非法状态 '{new_status}'，允许值: {', '.join(sorted(VALID_DEMAND_STATUSES))}"}, ensure_ascii=False))
        return 1

    backlog = _read_json(PM_PROJECT / "backlog.json")
    if not backlog:
        print(json.dumps({"ok": False, "error": "backlog.json 不存在"}, ensure_ascii=False))
        return 1

    demand = None
    for d in backlog.get("demands", []):
        if d.get("demand_id") == demand_id:
            demand = d
            break

    if not demand:
        print(json.dumps({"ok": False, "error": f"backlog 中未找到需求 {demand_id}"}, ensure_ascii=False))
        return 1

    demand["status"] = new_status
    _save_backlog(backlog)

    meta_updated = False
    ws_raw = demand.get("workspace_path", "").strip("`")
    if ws_raw and ws_raw not in {"—", "-", ""}:
        meta_path = ROOT / ws_raw.replace("/", "\\") / "meta.json"
        if meta_path.exists():
            meta = _read_json(meta_path)
            if meta:
                meta["demand_status"] = new_status
                meta["last_updated"] = _today()
                _write_json(meta_path, meta)
                meta_updated = True

    print(json.dumps({"ok": True, "demand_id": demand_id, "status": new_status, "meta_updated": meta_updated}, ensure_ascii=False))
    return 0


def cmd_update_meta(args: argparse.Namespace) -> int:
    demand_id: str = args.demand_id
    demand = _find_demand_in_backlog(demand_id)
    if not demand:
        print(json.dumps({"ok": False, "error": f"backlog 中未找到需求 {demand_id}"}, ensure_ascii=False))
        return 1

    ws_raw = demand.get("workspace_path", "").strip("`")
    if not ws_raw or ws_raw in {"—", "-", ""}:
        print(json.dumps({"ok": False, "error": f"需求 {demand_id} 无工作区路径"}, ensure_ascii=False))
        return 1

    meta_path = ROOT / ws_raw.replace("/", "\\") / "meta.json"
    if not meta_path.exists():
        print(json.dumps({"ok": False, "error": f"meta.json 不存在: {meta_path}"}, ensure_ascii=False))
        return 1

    meta = _read_json(meta_path)
    if not meta:
        print(json.dumps({"ok": False, "error": f"meta.json 解析失败: {meta_path}"}, ensure_ascii=False))
        return 1

    field_map = {
        "current_task": "current_task",
        "next_task": "next_task",
        "block": "block",
        "done_criteria": "done_criteria",
        "read_first": "read_first",
        "products": "products",
        "manual_step": "manual_step",
        "followup": "followup",
    }

    updated_fields: dict[str, str] = {}
    for arg_name, json_key in field_map.items():
        value = getattr(args, arg_name, None)
        if value is not None:
            meta["summary"][json_key] = value
            updated_fields[json_key] = value

    meta["last_updated"] = _today()

    if updated_fields:
        _write_json(meta_path, meta)
    print(json.dumps({"ok": True, "demand_id": demand_id, "updated": updated_fields}, ensure_ascii=False))
    return 0


def cmd_move_task(args: argparse.Namespace) -> int:
    demand_id: str = args.demand_id
    task_id: str = args.task_id
    target_section: str = args.target

    if target_section not in {"todo", "doing", "done", "future"}:
        print(json.dumps({"ok": False, "error": f"非法目标 section '{target_section}'，允许值: todo/doing/done/future"}, ensure_ascii=False))
        return 1

    todo_path = _todo_path_for_demand(demand_id)
    if not todo_path:
        print(json.dumps({"ok": False, "error": f"未找到需求 {demand_id} 的 todo.json"}, ensure_ascii=False))
        return 1
    if not todo_path.exists():
        print(json.dumps({"ok": False, "error": f"todo.json 不存在: {todo_path}"}, ensure_ascii=False))
        return 1

    todo = _read_json(todo_path)
    if not todo:
        print(json.dumps({"ok": False, "error": "todo.json 解析失败"}, ensure_ascii=False))
        return 1

    source_section: str | None = None
    source_task: dict | None = None
    for sec_name, tasks in todo.get("sections", {}).items():
        for t in tasks:
            if t.get("task_id") == task_id:
                source_section = sec_name
                source_task = t
                break
        if source_task:
            break

    if not source_task:
        print(json.dumps({"ok": False, "error": f"未找到任务 {task_id}"}, ensure_ascii=False))
        return 1

    if source_section == target_section:
        print(json.dumps({"ok": True, "task_id": task_id, "from": source_section, "to": target_section, "note": "已在目标 section"}, ensure_ascii=False))
        return 0

    todo["sections"][source_section] = [t for t in todo["sections"][source_section] if t.get("task_id") != task_id]

    target_task = dict(source_task)
    target_task["status"] = target_section if target_section in {"todo", "doing", "done"} else "todo"
    
    if target_section == "doing":
        target_task.setdefault("start_time", _today())
    elif target_section == "done":
        target_task.setdefault("complete_time", _today())

    todo.setdefault("sections", {}).setdefault(target_section, []).append(target_task)
    _write_json(todo_path, todo)

    print(json.dumps({"ok": True, "task_id": task_id, "from": source_section, "to": target_section}, ensure_ascii=False))
    return 0


def cmd_add_task(args: argparse.Namespace) -> int:
    demand_id: str = args.demand_id
    task_id: str = args.task_id
    content: str = args.content
    priority: str = args.priority
    section: str = args.section

    if section not in {"todo", "doing", "done", "future"}:
        print(json.dumps({"ok": False, "error": f"非法 section '{section}'，允许值: todo/doing/done/future"}, ensure_ascii=False))
        return 1

    todo_path = _todo_path_for_demand(demand_id)
    if not todo_path:
        print(json.dumps({"ok": False, "error": f"未找到需求 {demand_id} 的 todo.json"}, ensure_ascii=False))
        return 1
    if not todo_path.exists():
        print(json.dumps({"ok": False, "error": f"todo.json 不存在: {todo_path}"}, ensure_ascii=False))
        return 1

    todo = _read_json(todo_path)
    if not todo:
        print(json.dumps({"ok": False, "error": "todo.json 解析失败"}, ensure_ascii=False))
        return 1

    for sec_name, tasks in todo.get("sections", {}).items():
        for t in tasks:
            if t.get("task_id") == task_id:
                print(json.dumps({"ok": False, "error": f"任务ID {task_id} 已存在于 {sec_name}"}, ensure_ascii=False))
                return 1

    task: dict[str, Any] = {
        "task_id": task_id,
        "content": content,
        "priority": priority,
    }

    if section == "todo":
        task["status"] = "todo"
        task["next_step"] = ""
        task["product"] = ""
    elif section == "doing":
        task["start_time"] = _today()
        task["block"] = ""
        task["next_step"] = ""
        task["product"] = ""
    elif section == "done":
        task["complete_time"] = _today()
        task["verify_method"] = ""
        task["verify_result"] = ""
        task["product"] = ""
    elif section == "future":
        task["status"] = "todo"
        task["trigger_condition"] = ""

    todo.setdefault("sections", {}).setdefault(section, []).append(task)
    _write_json(todo_path, todo)

    print(json.dumps({"ok": True, "task_id": task_id, "section": section}, ensure_ascii=False))
    return 0


def cmd_add_backlog(args: argparse.Namespace) -> int:
    demand_id: str = args.demand_id
    title: str = args.title
    owner: str = args.owner or _current_role() or "未指定"
    priority: str = args.priority
    deps: str = args.deps or ""
    docs: str = args.docs or ""

    PM_PROJECT.mkdir(parents=True, exist_ok=True)

    backlog_path = PM_PROJECT / "backlog.json"
    backlog = _read_json(backlog_path)
    if not backlog:
        backlog = _default_backlog()
        _write_json(backlog_path, backlog)

    for d in backlog.get("demands", []):
        if d.get("demand_id") == demand_id:
            print(json.dumps({"ok": False, "error": f"需求 {demand_id} 已存在于 backlog"}, ensure_ascii=False))
            return 1

    backlog.setdefault("demands", []).append({
        "demand_id": demand_id,
        "title": title,
        "owner": owner,
        "priority": priority,
        "status": "planning",
        "deps": deps,
        "related_docs": docs,
        "workspace_path": "",
        "remark": "",
    })
    _save_backlog(backlog)
    print(json.dumps({"ok": True, "demand_id": demand_id, "title": title, "status": "planning"}, ensure_ascii=False))
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    demand_id: str | None = args.demand_id
    issues: list[str] = []

    backlog = _read_json(PM_PROJECT / "backlog.json")
    if backlog:
        for d in backlog.get("demands", []):
            if demand_id and d.get("demand_id") != demand_id:
                continue
            status = d.get("status", "")
            if status not in VALID_DEMAND_STATUSES:
                issues.append(f"[{d.get('demand_id')}] 非法需求状态: {status}")
            if status == "doing" and not d.get("workspace_path"):
                issues.append(f"[{d.get('demand_id')}] doing 状态但工作区路径为空")
            ws = d.get("workspace_path", "")
            if ws and "/archived/" in ws:
                issues.append(f"[{d.get('demand_id')}] 活跃 backlog 中出现 archived 路径")

    if PM_WORKSPACES.exists():
        for meta_file in PM_WORKSPACES.rglob("meta.json"):
            ws_root = meta_file.parent
            rel = str(ws_root.relative_to(ROOT)).replace("\\", "/")
            parts = rel.split("/")
            if len(parts) < 4:
                continue
            if parts[2] == "archived":
                if len(parts) < 5:
                    issues.append(f"[路径] 归档路径缺少成员名层: {rel}")
                elif not re.match(r"^\d{4}-\d{2}-\d{2}-", parts[4]):
                    issues.append(f"[路径] 归档路径目录名格式错误（缺日期前缀）: {rel}")
            else:
                if re.match(r"^\d{4}-\d{2}-\d{2}-", parts[2]):
                    issues.append(f"[路径] 活跃 workspace 缺少成员名层: {rel}")
                elif not re.match(r"^\d{4}-\d{2}-\d{2}-", parts[3]):
                    issues.append(f"[路径] 活跃路径目录名格式错误（缺日期前缀）: {rel}")

    if PM_WORKSPACES.exists():
        for meta_file in PM_WORKSPACES.rglob("meta.json"):
            rel = str(meta_file.relative_to(ROOT)).replace("\\", "/")
            if demand_id and demand_id not in rel:
                continue
            meta = _read_json(meta_file)
            if not meta:
                issues.append(f"[{rel}] meta.json 解析失败")
                continue
            required_fields = [
                "demand_id", "title", "owner", "priority", "created_date",
                "last_updated", "demand_status", "workspace_status", "deps",
                "related_docs", "workspace_path",
            ]
            for field in required_fields:
                if field not in meta:
                    issues.append(f"[{rel}] 缺失字段: {field}")
            summary = meta.get("summary", {})
            required_summary = [
                "current_task", "next_task", "block", "done_criteria",
                "read_first", "products", "manual_step", "followup",
            ]
            for field in required_summary:
                if field not in summary:
                    issues.append(f"[{rel}] summary 缺失字段: {field}")

    if PM_WORKSPACES.exists():
        for todo_file in PM_WORKSPACES.rglob("todo.json"):
            rel = str(todo_file.relative_to(ROOT)).replace("\\", "/")
            if demand_id and demand_id not in rel:
                continue
            todo = _read_json(todo_file)
            if not todo:
                continue
            seen: set[str] = set()
            for sec_name, tasks in todo.get("sections", {}).items():
                for t in tasks:
                    tid = t.get("task_id", "")
                    if tid in seen:
                        issues.append(f"[{rel}] 重复任务ID: {tid}")
                    seen.add(tid)

    if issues:
        print(json.dumps({"ok": False, "issues": issues}, ensure_ascii=False, indent=2))
        return 1
    print(json.dumps({"ok": True, "issues": []}, ensure_ascii=False))
    return 0


def cmd_search(args: argparse.Namespace) -> int:
    keyword: str = args.keyword
    results: list[dict] = []

    for path in [PM_PROJECT / "backlog.json", PM_PROJECT / "archived.json"]:
        data = _read_json(path)
        if not data:
            continue
        for d in data.get("demands", []):
            did = d.get("demand_id", "")
            title = d.get("title", "")
            remark = d.get("remark", "")
            if keyword.lower() in did.lower() or keyword.lower() in title.lower() or keyword.lower() in remark.lower():
                results.append({
                    "demand_id": did,
                    "title": title,
                    "status": d.get("status", ""),
                })

    if not results:
        print(json.dumps({"ok": False, "error": f"未找到匹配 '{keyword}' 的需求"}, ensure_ascii=False))
        return 1

    print(json.dumps({"ok": True, "results": results}, ensure_ascii=False, indent=2))
    return 0


def cmd_info(args: argparse.Namespace) -> int:
    demand_id: str = args.demand_id
    demand = _find_demand_anywhere(demand_id)
    if not demand:
        print(json.dumps({"ok": False, "error": f"未找到需求 {demand_id}"}, ensure_ascii=False))
        return 1

    ws_raw = demand.get("workspace_path", "").strip("`")
    ws_abs = ROOT / ws_raw.replace("/", "\\") if ws_raw and ws_raw not in {"—", "-", ""} else None

    meta = None
    if ws_abs and ws_abs.exists():
        meta = _read_json(ws_abs / "meta.json")

    days_waiting = 0
    last_updated = meta.get("last_updated", "") if meta else ""
    if last_updated:
        try:
            days_waiting = (date.today() - date.fromisoformat(last_updated)).days
        except ValueError:
            pass

    result: dict[str, Any] = {
        "demand_id": demand_id,
        "title": demand.get("title", ""),
        "owner": demand.get("owner", ""),
        "status": demand.get("status", ""),
        "days_waiting": days_waiting,
    }

    if meta:
        result["summary"] = meta.get("summary", {})

    if ws_abs and ws_abs.exists():
        todo = _read_json(ws_abs / "todo.json")
        if todo:
            result["tasks"] = todo.get("sections", {})

    ws_paths: list[str] = []
    if ws_raw and ws_raw not in {"—", "-", ""}:
        ws_paths.append(f"{ws_raw}/notes.md")
        if ws_abs and (ws_abs / "artifacts").exists():
            ws_paths.append(f"{ws_raw}/artifacts/")
    result["workspace_paths"] = ws_paths

    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def cmd_status(_args: argparse.Namespace) -> int:
    backlog = _read_json(PM_PROJECT / "backlog.json")
    if not backlog:
        print(json.dumps({"error": "backlog.json 不存在"}, ensure_ascii=False))
        return 1

    demands = backlog.get("demands", [])

    def _get_meta_summary(workspace_path: str) -> dict | None:
        ws = workspace_path.strip("`").replace("/", "\\")
        meta = ROOT / ws / "meta.json"
        return _read_json(meta)

    def _get_block_reason(workspace_path: str) -> str:
        ws = workspace_path.strip("`").replace("/", "\\")
        notes_path = ROOT / ws / "notes.md"
        if not notes_path.exists():
            return ""
        lines = notes_path.read_text(encoding="utf-8").splitlines()
        in_section = False
        for line in lines:
            if line.startswith("## 当前遗留"):
                in_section = True
                continue
            if in_section:
                if line.startswith("## "):
                    break
                stripped = line.strip().lstrip("- ").strip()
                if stripped:
                    return stripped
        return ""

    def _days_waiting(meta: dict | None) -> int:
        if not meta:
            return 0
        last = meta.get("last_updated", "")
        if not last:
            return 0
        try:
            diff = (date.today() - date.fromisoformat(last)).days
            return diff if diff > 0 else 0
        except ValueError:
            return 0

    result: dict[str, Any] = {}

    doing_list = []
    for d in demands:
        if d.get("status") != "doing":
            continue
        meta = _get_meta_summary(d.get("workspace_path", ""))
        entry: dict[str, Any] = {
            "demand_id": d["demand_id"],
            "title": d.get("title", ""),
        }
        if meta:
            s = meta.get("summary", {})
            entry["current_task"] = s.get("current_task", "无")
            entry["next_task"] = s.get("next_task", "无")
            p = s.get("products", "")
            entry["products"] = p if p and p != "无" else ""
        doing_list.append(entry)
    if doing_list:
        result["doing"] = doing_list

    blocked_list = []
    for d in demands:
        if d.get("status") != "blocked":
            continue
        reason = _get_block_reason(d.get("workspace_path", ""))
        entry = {
            "demand_id": d["demand_id"],
            "title": d.get("title", ""),
            "block_reason": reason,
        }
        blocked_list.append(entry)
    if blocked_list:
        result["blocked"] = blocked_list

    review_list = []
    for d in demands:
        if d.get("status") != "review":
            continue
        meta = _get_meta_summary(d.get("workspace_path", ""))
        entry: dict[str, Any] = {
            "demand_id": d["demand_id"],
            "title": d.get("title", ""),
            "days_waiting": _days_waiting(meta),
        }
        if meta:
            p = meta.get("summary", {}).get("products", "")
            entry["products"] = p if p and p != "无" else ""
        review_list.append(entry)
    if review_list:
        result["review"] = review_list

    todo_list = []
    for d in demands:
        if d.get("status") not in {"todo", "planning"}:
            continue
        todo_list.append({
            "demand_id": d["demand_id"],
            "title": d.get("title", ""),
            "status": d.get("status", ""),
        })
    if todo_list:
        result["todo"] = todo_list

    if not result:
        result = {"message": "当前无活跃需求"}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


# ---------------------------------------------------------------------------
# Migration: MD → JSON
# ---------------------------------------------------------------------------

def cmd_migrate_from_md(_args: argparse.Namespace) -> int:
    """One-time migration: convert existing .md data to .json."""
    migrated = 0
    details: list[str] = []

    # Migrate current-role.md → current-role.json
    role_md = PM_LOCAL / "current-role.md"
    if role_md.exists():
        username = None
        for line in role_md.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("- 当前用户名：") or line.startswith("- 当前用户名:"):
                username = line.split("：", 1)[-1].split(":", 1)[-1].strip()
        if username:
            data = {
                "username": username,
                "member_name": username,
                "default_workspace": f".pm/workspaces/{username}/",
            }
            _write_json(PM_LOCAL / "current-role.json", data)
            migrated += 1
            details.append(f"current-role.md → current-role.json (username={username})")

    # Migrate backlog.md → backlog.json
    backlog_md = PM_PROJECT / "backlog.md"
    if backlog_md.exists():
        text = backlog_md.read_text(encoding="utf-8")
        overview = {}
        for line in text.splitlines():
            stripped = line.strip()
            if stripped.startswith("- 当前阶段：") or stripped.startswith("- 当前阶段:"):
                overview["current_phase"] = stripped.split("：", 1)[-1].split(":", 1)[-1].strip()
            elif stripped.startswith("- 当前最重要目标：") or stripped.startswith("- 当前最重要目标:"):
                overview["top_goal"] = stripped.split("：", 1)[-1].split(":", 1)[-1].strip()
            elif stripped.startswith("- 当前主要风险：") or stripped.startswith("- 当前主要风险:"):
                overview["main_risk"] = stripped.split("：", 1)[-1].split(":", 1)[-1].strip()

        demands = []
        for line in text.splitlines():
            if not line.startswith("|") or line.startswith("| ---"):
                continue
            parts = [p.strip() for p in line.split("|")]
            if len(parts) < 10:
                continue
            if parts[1] in {"需求ID", "需求ID "}:
                continue
            demands.append({
                "demand_id": parts[1],
                "title": parts[2],
                "owner": parts[3],
                "priority": parts[4],
                "status": parts[5],
                "deps": parts[6] if parts[6] not in {"—", "-"} else "",
                "related_docs": parts[7] if parts[7] not in {"—", "-"} else "",
                "workspace_path": parts[8].strip("`"),
                "remark": parts[9],
            })

        planning_conclusions = []
        in_pc = False
        for line in text.splitlines():
            stripped = line.strip()
            if stripped == "## 规划结论":
                in_pc = True
                continue
            if in_pc and stripped.startswith("## "):
                in_pc = False
                continue
            if in_pc and stripped.startswith("- "):
                planning_conclusions.append(stripped[2:])

        backlog_json = {
            "overview": overview,
            "demands": demands,
            "planning_conclusions": planning_conclusions,
        }
        _write_json(PM_PROJECT / "backlog.json", backlog_json)
        migrated += 1
        details.append(f"backlog.md → backlog.json ({len(demands)} 条需求)")

    # Migrate archived.md → archived.json
    archived_md = PM_PROJECT / "archived.md"
    if archived_md.exists():
        text = archived_md.read_text(encoding="utf-8")
        demands = []
        for line in text.splitlines():
            if not line.startswith("|") or line.startswith("| ---"):
                continue
            parts = [p.strip() for p in line.split("|")]
            if len(parts) < 11:
                continue
            if parts[1] in {"需求ID", "需求ID "}:
                continue
            demands.append({
                "demand_id": parts[1],
                "title": parts[2],
                "owner": parts[3],
                "priority": parts[4],
                "status": parts[5],
                "deps": parts[6] if parts[6] not in {"—", "-"} else "",
                "related_docs": parts[7] if parts[7] not in {"—", "-"} else "",
                "workspace_path": parts[8].strip("`"),
                "archive_date": parts[9],
                "remark": parts[10],
            })

        archived_json = {"demands": demands}
        _write_json(PM_PROJECT / "archived.json", archived_json)
        migrated += 1
        details.append(f"archived.md → archived.json ({len(demands)} 条需求)")

    # Migrate workspace meta.md → meta.json, todo.md → todo.json
    if PM_WORKSPACES.exists():
        for ws_dir in PM_WORKSPACES.rglob("meta.md"):
            ws_root = ws_dir.parent
            rel = str(ws_root.relative_to(ROOT)).replace("\\", "/")
            details.append(f"workspace: {rel}")

            # meta.md → meta.json
            if ws_root.joinpath("meta.md").exists():
                meta_text = ws_root.joinpath("meta.md").read_text(encoding="utf-8")
                meta = {}
                summary = {}
                in_summary = False
                for line in meta_text.splitlines():
                    stripped = line.strip()
                    if stripped == "## 当前执行摘要":
                        in_summary = True
                        continue
                    if in_summary and stripped.startswith("## "):
                        in_summary = False
                    if not stripped.startswith("- "):
                        continue
                    key_val = stripped[2:]
                    if "：" in key_val:
                        key, val = key_val.split("：", 1)
                    elif ":" in key_val:
                        key, val = key_val.split(":", 1)
                    else:
                        continue
                    key = key.strip()
                    val = val.strip()

                    field_map = {
                        "需求ID": "demand_id",
                        "需求标题": "title",
                        "负责人": "owner",
                        "优先级": "priority",
                        "创建日期": "created_date",
                        "最后更新": "last_updated",
                        "需求状态": "demand_status",
                        "工作区状态": "workspace_status",
                        "依赖需求": "deps",
                        "关联文档": "related_docs",
                        "工作区路径": "workspace_path",
                    }
                    summary_map = {
                        "当前任务": "current_task",
                        "下一任务": "next_task",
                        "阻塞": "block",
                        "完成判定": "done_criteria",
                        "先读文档": "read_first",
                        "当前有效产物": "products",
                        "人工步骤": "manual_step",
                        "后续接续需求": "followup",
                    }

                    if in_summary and key in summary_map:
                        summary[summary_map[key]] = val
                    elif key in field_map:
                        if field_map[key] == "workspace_path":
                            val = val.strip("`")
                        meta[field_map[key]] = val

                meta["summary"] = summary
                _write_json(ws_root / "meta.json", meta)
                migrated += 1

            # todo.md → todo.json
            todo_md = ws_root / "todo.md"
            if todo_md.exists():
                todo_text = todo_md.read_text(encoding="utf-8")
                todo_data = {
                    "demand_id": "",
                    "title": "",
                    "owner": "",
                    "sections": {
                        "todo": [],
                        "doing": [],
                        "done": [],
                        "future": [],
                    },
                }

                current_section = None
                for line in todo_text.splitlines():
                    stripped = line.strip()
                    if stripped.startswith("- 需求ID：") or stripped.startswith("- 需求ID:"):
                        todo_data["demand_id"] = stripped.split("：", 1)[-1].split(":", 1)[-1].strip()
                    elif stripped.startswith("- 需求标题：") or stripped.startswith("- 需求标题:"):
                        todo_data["title"] = stripped.split("：", 1)[-1].split(":", 1)[-1].strip()
                    elif stripped.startswith("- 负责人：") or stripped.startswith("- 负责人:"):
                        todo_data["owner"] = stripped.split("：", 1)[-1].split(":", 1)[-1].strip()
                    elif stripped == "## 待处理":
                        current_section = "todo"
                    elif stripped == "## 进行中":
                        current_section = "doing"
                    elif stripped == "## 已完成":
                        current_section = "done"
                    elif stripped == "## 后续/二期":
                        current_section = "future"
                    elif stripped.startswith("## "):
                        current_section = None
                    elif stripped.startswith("|") and not stripped.startswith("| ---") and current_section:
                        parts = [p.strip() for p in stripped.split("|")]
                        if not parts[1] or parts[1].startswith("任务ID"):
                            continue
                        if current_section == "todo":
                            todo_data["sections"]["todo"].append({
                                "task_id": parts[1],
                                "content": parts[2],
                                "priority": parts[3],
                                "status": parts[4],
                                "next_step": parts[5] if len(parts) > 5 else "",
                                "product": parts[6] if len(parts) > 6 else "",
                            })
                        elif current_section == "doing":
                            todo_data["sections"]["doing"].append({
                                "task_id": parts[1],
                                "content": parts[2],
                                "start_time": parts[3] if len(parts) > 3 else "",
                                "block": parts[4] if len(parts) > 4 else "",
                                "next_step": parts[5] if len(parts) > 5 else "",
                                "product": parts[6] if len(parts) > 6 else "",
                            })
                        elif current_section == "done":
                            todo_data["sections"]["done"].append({
                                "task_id": parts[1],
                                "content": parts[2],
                                "complete_time": parts[3] if len(parts) > 3 else "",
                                "verify_method": parts[4] if len(parts) > 4 else "",
                                "verify_result": parts[5] if len(parts) > 5 else "",
                                "product": parts[6] if len(parts) > 6 else "",
                            })
                        elif current_section == "future":
                            todo_data["sections"]["future"].append({
                                "task_id": parts[1],
                                "content": parts[2],
                                "status": parts[3] if len(parts) > 3 else "todo",
                                "trigger_condition": parts[4] if len(parts) > 4 else "",
                            })

                _write_json(ws_root / "todo.json", todo_data)
                migrated += 1

            # notes.md 保持不变（自由文本，agent 直接读写）
            # 迁移时只需删除已有的 notes.json（如果之前错误创建了），
            # 原始 notes.md 无需任何转换

    print(json.dumps({"ok": True, "migrated": migrated, "details": details}, ensure_ascii=False, indent=2))
    return 0


# ---------------------------------------------------------------------------
# Handoff workflow (session state compression & recovery)
# ---------------------------------------------------------------------------

def cmd_handoff_save(args: argparse.Namespace) -> int:
    """Save current demand state for session recovery."""
    demand_id = args.demand_id
    note = args.note or ""
    
    backlog = _read_json(PM_PROJECT / "backlog.json") or _default_backlog()
    demand = None
    for d in backlog.get("demands", []):
        if d.get("demand_id") == demand_id:
            demand = d
            break
    
    if not demand:
        print(json.dumps({"ok": False, "error": f"需求 {demand_id} 不存在于 backlog"}, ensure_ascii=False, indent=2))
        return 1
    
    workspace_path = demand.get("workspace_path", "")
    if not workspace_path:
        print(json.dumps({"ok": False, "error": f"需求 {demand_id} 没有 workspace"}, ensure_ascii=False, indent=2))
        return 1
    
    meta_path = ROOT / workspace_path.replace("/", "\\") / "meta.json"
    meta = _read_json(meta_path)
    if not meta:
        print(json.dumps({"ok": False, "error": f"无法读取 meta.json"}, ensure_ascii=False, indent=2))
        return 1
    
    current_owner = meta.get("owner", "")
    title = meta.get("title", "")
    summary = meta.get("summary", {})
    
    session_context = {
        "current_task": summary.get("current_task", "无"),
        "next_task": summary.get("next_task", "无"),
        "block": summary.get("block", "无"),
        "products": summary.get("products", "无"),
        "read_first": summary.get("read_first", "无"),
        "key_files": [],
    }
    
    handoff_data = _read_handoff()
    existing = _find_handoff_by_id(handoff_data, demand_id)
    
    handoff_entry = {
        "demand_id": demand_id,
        "title": title,
        "owner": current_owner,
        "handoff_date": _today(),
        "handoff_note": note,
        "workspace_path": workspace_path,
        "session_context": session_context,
    }
    
    if existing:
        handoff_data["handoffs"][handoff_data["handoffs"].index(existing)] = handoff_entry
    else:
        handoff_data["handoffs"].append(handoff_entry)
    
    _write_handoff(handoff_data)
    
    meta["demand_status"] = "blocked"
    meta["summary"]["block"] = "会话压缩中（等待恢复）"
    meta["last_updated"] = _today()
    _write_json(meta_path, meta)
    
    for d in backlog.get("demands", []):
        if d.get("demand_id") == demand_id:
            d["status"] = "blocked"
    _write_json(PM_PROJECT / "backlog.json", backlog)
    
    result = {
        "ok": True,
        "demand_id": demand_id,
        "title": title,
        "owner": current_owner,
        "workspace_path": workspace_path,
        "session_context": session_context,
        "status": "blocked",
        "message": f"需求 {demand_id} 会话状态已压缩保存",
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def cmd_handoff_resume(args: argparse.Namespace) -> int:
    """Resume a compressed session state and continue work."""
    demand_id = args.demand_id
    
    handoff_data = _read_handoff()
    handoff = _find_handoff_by_id(handoff_data, demand_id)
    
    if not handoff:
        print(json.dumps({"ok": False, "error": f"需求 {demand_id} 不在会话压缩列表中"}, ensure_ascii=False, indent=2))
        return 1
    
    workspace_path = handoff.get("workspace_path", "")
    session_context = handoff.get("session_context", {})
    meta_path = ROOT / workspace_path.replace("/", "\\") / "meta.json"
    meta = _read_json(meta_path)
    
    if not meta:
        print(json.dumps({"ok": False, "error": f"无法读取 meta.json"}, ensure_ascii=False, indent=2))
        return 1
    
    owner = meta.get("owner", "")
    title = meta.get("title", "")
    
    meta["demand_status"] = "doing"
    meta["summary"]["block"] = "无"
    meta["last_updated"] = _today()
    _write_json(meta_path, meta)
    
    backlog = _read_json(PM_PROJECT / "backlog.json") or _default_backlog()
    for d in backlog.get("demands", []):
        if d.get("demand_id") == demand_id:
            d["status"] = "doing"
    _write_json(PM_PROJECT / "backlog.json", backlog)
    
    _remove_handoff_by_id(handoff_data, demand_id)
    _write_handoff(handoff_data)
    
    result = {
        "ok": True,
        "demand_id": demand_id,
        "title": title,
        "owner": owner,
        "workspace_path": workspace_path,
        "session_context": session_context,
        "status": "doing",
        "message": f"需求 {demand_id} 会话状态已恢复",
        "next_action": f"建议先读取 session_context.read_first 指定的文件，然后继续执行 session_context.current_task",
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def cmd_handoff_list(_args: argparse.Namespace) -> int:
    """List all compressed session states."""
    handoff_data = _read_handoff()
    handoffs = handoff_data.get("handoffs", [])
    
    if not handoffs:
        print(json.dumps({"ok": True, "message": "当前无待恢复的会话状态"}, ensure_ascii=False, indent=2))
        return 0
    
    result = {
        "ok": True,
        "handoffs": handoffs,
        "count": len(handoffs),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


# ---------------------------------------------------------------------------
# CLI entry
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="pm-agile core workflow CLI (JSON backend)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_role = sub.add_parser("role", help="设置当前用户名")
    p_role.add_argument("username")
    p_role.set_defaults(func=cmd_role)

    p_init = sub.add_parser("init-backlog", help="初始化 backlog 和 archived")
    p_init.set_defaults(func=cmd_init_backlog)

    p_ws = sub.add_parser("init-workspace", help="创建 workspace")
    p_ws.add_argument("demand_id")
    p_ws.add_argument("title")
    p_ws.add_argument("owner", nargs="?", default=None)
    p_ws.set_defaults(func=cmd_init_workspace)

    p_archive = sub.add_parser("archive", help="归档需求")
    p_archive.add_argument("demand_id")
    p_archive.set_defaults(func=cmd_archive)

    p_unarchive = sub.add_parser("unarchive", help="恢复已归档的需求")
    p_unarchive.add_argument("demand_id")
    p_unarchive.add_argument("--status", default="doing", help="恢复后的状态 (默认: doing)")
    p_unarchive.set_defaults(func=cmd_unarchive)

    p_set = sub.add_parser("set-status", help="更新需求状态（同步 backlog 和 meta.json）")
    p_set.add_argument("demand_id")
    p_set.add_argument("status", help="planning/todo/doing/blocked/review/done")
    p_set.set_defaults(func=cmd_set_status)

    p_check = sub.add_parser("check", help="检查状态一致性")
    p_check.add_argument("demand_id", nargs="?", default=None)
    p_check.set_defaults(func=cmd_check)

    p_info = sub.add_parser("info", help="查看需求详情及关键文件路径")
    p_info.add_argument("demand_id")
    p_info.set_defaults(func=cmd_info)

    p_search = sub.add_parser("search", help="按关键词搜索需求")
    p_search.add_argument("keyword")
    p_search.set_defaults(func=cmd_search)

    p_status = sub.add_parser("status", help="查看当前状态")
    p_status.set_defaults(func=cmd_status)

    p_newid = sub.add_parser("new-id", help="生成下一个可用需求ID（按用户名维度）")
    p_newid.add_argument("username", nargs="?", default=None, help="用户名（省略时取 current-role）")
    p_newid.set_defaults(func=cmd_new_id)

    p_meta = sub.add_parser("update-meta", help="更新 workspace/meta.json 摘要字段")
    p_meta.add_argument("demand_id")
    p_meta.add_argument("--current-task", dest="current_task", default=None, help="当前任务")
    p_meta.add_argument("--next-task", dest="next_task", default=None, help="下一任务")
    p_meta.add_argument("--block", default=None, help="阻塞")
    p_meta.add_argument("--done-criteria", dest="done_criteria", default=None, help="完成判定")
    p_meta.add_argument("--read-first", dest="read_first", default=None, help="先读文档")
    p_meta.add_argument("--products", default=None, help="当前有效产物")
    p_meta.add_argument("--manual-step", dest="manual_step", default=None, help="人工步骤")
    p_meta.add_argument("--followup", default=None, help="后续接续需求")
    p_meta.set_defaults(func=cmd_update_meta)

    p_move = sub.add_parser("move-task", help="移动任务到目标 section")
    p_move.add_argument("demand_id")
    p_move.add_argument("task_id", help="任务ID（如 T-01）")
    p_move.add_argument("target", help="目标 section: todo/doing/done/future")
    p_move.set_defaults(func=cmd_move_task)

    p_add_task = sub.add_parser("add-task", help="添加新任务到 todo.json")
    p_add_task.add_argument("demand_id")
    p_add_task.add_argument("task_id", help="任务ID（如 T-01）")
    p_add_task.add_argument("content", help="任务内容")
    p_add_task.add_argument("--priority", default="P1", help="优先级")
    p_add_task.add_argument("--section", default="todo", help="目标 section: todo/doing/done/future")
    p_add_task.set_defaults(func=cmd_add_task)

    p_add = sub.add_parser("add-backlog", help="向 backlog 添加新需求")
    p_add.add_argument("demand_id")
    p_add.add_argument("title")
    p_add.add_argument("--owner", default=None, help="负责人（省略时取 current-role）")
    p_add.add_argument("--priority", default="P1", help="优先级")
    p_add.add_argument("--deps", default=None, help="依赖需求（逗号分隔）")
    p_add.add_argument("--docs", default=None, help="关联文档（逗号分隔）")
    p_add.set_defaults(func=cmd_add_backlog)

    p_migrate = sub.add_parser("migrate-from-md", help="从 .md 格式迁移到 .json")
    p_migrate.set_defaults(func=cmd_migrate_from_md)

    p_handoff_save = sub.add_parser("handoff-save", help="压缩会话状态（保存当前工作进度）")
    p_handoff_save.add_argument("demand_id")
    p_handoff_save.add_argument("--note", default="", help="压缩说明（可选）")
    p_handoff_save.set_defaults(func=cmd_handoff_save)

    p_handoff_resume = sub.add_parser("handoff-resume", help="恢复会话状态（继续之前的工作）")
    p_handoff_resume.add_argument("demand_id")
    p_handoff_resume.set_defaults(func=cmd_handoff_resume)

    p_handoff_list = sub.add_parser("handoff-list", help="列出所有待恢复的会话状态")
    p_handoff_list.set_defaults(func=cmd_handoff_list)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    _ensure_utf8_stdout()
    sys.exit(main())
