#!/usr/bin/env python3
"""Configure project AI clients to use the bundled GodotMCP server.

Default mode is dry-run. Project mode writes only repository-local config.
User mode may call AI client CLIs and should be used only after explicit
confirmation because it changes the user's personal AI configuration.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SERVER_NAME = "godot"
USER_SERVER_NAME = "godot-v1-plus"
BEGIN_MARKER = "# BEGIN GODOT V1 PLUS MCP"
END_MARKER = "# END GODOT V1 PLUS MCP"


class ConfigReadError(RuntimeError):
    """Raised when an existing config cannot be safely merged."""


def _rel(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def _read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise ConfigReadError(f"{_rel(path)} 不是有效 JSON，已停止写入以避免覆盖用户配置：{exc}") from exc
    if not isinstance(data, dict):
        raise ConfigReadError(f"{_rel(path)} 顶层必须是 JSON object，已停止写入。")
    return data


def _project_command() -> list[str]:
    if sys.platform == "win32":
        return ["cmd", "/c", "scripts/godot_mcp_stdio.cmd"]
    return ["sh", "scripts/godot_mcp_stdio.sh"]


def _codex_project_command() -> list[str]:
    # Codex may start project-level MCP servers without the repository root as cwd.
    # Use an absolute wrapper path for the ignored, machine-local .codex config.
    return _user_command()


def _user_command() -> list[str]:
    if sys.platform == "win32":
        return ["cmd", "/c", str((PROJECT_ROOT / "scripts" / "godot_mcp_stdio.cmd").resolve())]
    return ["sh", str((PROJECT_ROOT / "scripts" / "godot_mcp_stdio.sh").resolve())]


def _json_project_server() -> dict[str, Any]:
    return {
        "type": "local",
        "command": _project_command(),
        "enabled": True,
        "timeout": 15000,
    }


def _claude_project_server() -> dict[str, Any]:
    command = _project_command()
    return {
        "command": command[0],
        "args": command[1:],
    }


def _toml_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def _toml_array(values: list[str]) -> str:
    return "[" + ", ".join(_toml_string(value) for value in values) + "]"


def _codex_block(command: list[str]) -> str:
    return "\n".join([
        BEGIN_MARKER,
        "[mcp_servers.godot]",
        'type = "stdio"',
        f"command = {_toml_string(command[0])}",
        f"args = {_toml_array(command[1:])}",
        END_MARKER,
        "",
    ])


def _replace_marked_or_table_block(text: str, block: str) -> str:
    marked = re.compile(
        rf"{re.escape(BEGIN_MARKER)}.*?{re.escape(END_MARKER)}\n?",
        flags=re.DOTALL,
    )
    if marked.search(text):
        return marked.sub(lambda _match: block, text).rstrip() + "\n"

    table = re.compile(
        r"(?ms)^\[mcp_servers\.godot\]\n.*?(?=^\[[^\]]+\]\n|\Z)"
    )
    text = table.sub("", text).rstrip()
    return (text + "\n\n" + block).lstrip()


def plan_project_opencode() -> dict[str, Any]:
    return {
        "client": "opencode",
        "path": _rel(PROJECT_ROOT / "opencode.json"),
        "config": {"mcp": {SERVER_NAME: _json_project_server()}},
    }


def apply_project_opencode() -> dict[str, Any]:
    path = PROJECT_ROOT / "opencode.json"
    data = _read_json(path)
    if not data:
        data = {"$schema": "https://opencode.ai/config.json"}
    mcp = data.get("mcp")
    if not isinstance(mcp, dict):
        mcp = {}
    mcp[SERVER_NAME] = _json_project_server()
    data["mcp"] = mcp
    _write_text(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    return {"client": "opencode", "path": _rel(path), "status": "updated"}


def plan_project_claude() -> dict[str, Any]:
    return {
        "client": "claude",
        "path": _rel(PROJECT_ROOT / ".mcp.json"),
        "config": {"mcpServers": {SERVER_NAME: _claude_project_server()}},
    }


def apply_project_claude() -> dict[str, Any]:
    path = PROJECT_ROOT / ".mcp.json"
    data = _read_json(path)
    servers = data.get("mcpServers")
    if not isinstance(servers, dict):
        servers = {}
    servers[SERVER_NAME] = _claude_project_server()
    data["mcpServers"] = servers
    _write_text(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    return {"client": "claude", "path": _rel(path), "status": "updated"}


def plan_project_codex() -> dict[str, Any]:
    return {
        "client": "codex",
        "path": _rel(PROJECT_ROOT / ".codex" / "config.toml"),
        "config": _codex_block(_codex_project_command()).strip(),
    }


def apply_project_codex() -> dict[str, Any]:
    path = PROJECT_ROOT / ".codex" / "config.toml"
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    updated = _replace_marked_or_table_block(text, _codex_block(_codex_project_command()))
    _write_text(path, updated)
    validation = validate_codex_project_config(path)
    if validation["status"] == "failed":
        if text:
            _write_text(path, text)
        else:
            path.unlink(missing_ok=True)
        status = "failed"
    else:
        status = "updated"
    return {"client": "codex", "path": _rel(path), "status": status, "validation": validation}


def validate_codex_project_config(path: Path) -> dict[str, str]:
    try:
        import tomllib  # type: ignore[import-not-found]
    except Exception:
        tomllib = None  # type: ignore[assignment]

    if tomllib is not None:
        try:
            tomllib.loads(path.read_text(encoding="utf-8"))
            return {"status": "ok", "detail": "tomllib parse passed"}
        except Exception as exc:
            return {"status": "failed", "detail": f"TOML parse failed: {exc}"}

    codex = shutil.which("codex")
    if codex:
        ok, text = _run([codex, "mcp", "list"])
        return {"status": "ok" if ok else "failed", "detail": text or "codex mcp list passed"}

    return {"status": "unchecked", "detail": "tomllib/codex command unavailable"}


def _run(command: list[str]) -> tuple[bool, str]:
    try:
        result = subprocess.run(
            command,
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=60,
        )
        return result.returncode == 0, (result.stdout or "").strip()
    except Exception as exc:
        return False, str(exc)


def apply_user_codex() -> dict[str, Any]:
    codex = shutil.which("codex")
    if not codex:
        return {"client": "codex", "scope": "user", "status": "skipped", "detail": "codex command not found"}
    command = _user_command()
    _run([codex, "mcp", "remove", USER_SERVER_NAME])
    ok, text = _run([codex, "mcp", "add", USER_SERVER_NAME, "--", *command])
    return {"client": "codex", "scope": "user", "status": "updated" if ok else "failed", "detail": text}


def apply_user_claude() -> dict[str, Any]:
    claude = shutil.which("claude")
    if not claude:
        return {"client": "claude", "scope": "user", "status": "skipped", "detail": "claude command not found"}
    command = _user_command()
    ok, text = _run([claude, "mcp", "add", USER_SERVER_NAME, "--", *command])
    return {"client": "claude", "scope": "user", "status": "updated" if ok else "failed", "detail": text}


def selected_clients(value: str) -> list[str]:
    if value == "all":
        return ["opencode", "claude", "codex"]
    return [value]


def _call_apply(func) -> dict[str, Any]:
    try:
        return func()
    except ConfigReadError as exc:
        return {"status": "failed", "detail": str(exc)}
    except Exception as exc:
        return {"status": "failed", "detail": str(exc)}


def main() -> int:
    parser = argparse.ArgumentParser(description="为 AI 客户端配置 GodotMCP")
    parser.add_argument("--client", choices=["all", "opencode", "claude", "codex"], default="all")
    parser.add_argument("--apply-project", action="store_true", help="写入项目内配置文件")
    parser.add_argument("--apply-user", action="store_true", help="写入用户级 AI 客户端配置或调用客户端 CLI")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    clients = selected_clients(args.client)
    dry_run = not args.apply_project and not args.apply_user
    results: list[dict[str, Any]] = []

    for client in clients:
        if dry_run:
            if client == "opencode":
                results.append(plan_project_opencode())
            elif client == "claude":
                results.append(plan_project_claude())
            elif client == "codex":
                results.append(plan_project_codex())
            continue

        if args.apply_project:
            if client == "opencode":
                item = _call_apply(apply_project_opencode)
                item.setdefault("client", "opencode")
                results.append(item)
            elif client == "claude":
                item = _call_apply(apply_project_claude)
                item.setdefault("client", "claude")
                results.append(item)
            elif client == "codex":
                item = _call_apply(apply_project_codex)
                item.setdefault("client", "codex")
                results.append(item)

        if args.apply_user:
            if client == "codex":
                results.append(apply_user_codex())
            elif client == "claude":
                results.append(apply_user_claude())
            elif client == "opencode":
                results.append({
                    "client": "opencode",
                    "scope": "user",
                    "status": "skipped",
                    "detail": "OpenCode uses project opencode.json in this scaffold",
                })

    payload = {
        "status": "ok" if all(item.get("status") != "failed" for item in results) else "failed",
        "mode": "dry-run" if dry_run else "apply",
        "project_command": _project_command(),
        "user_command": _user_command(),
        "results": results,
    }

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print("## AI MCP Setup")
        print("")
        print(f"- Mode: {payload['mode']}")
        print(f"- Project command: {' '.join(_project_command())}")
        print("")
        for item in results:
            print(f"- {item.get('client')}: {item.get('status', 'planned')} {item.get('path', item.get('detail', ''))}")
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
