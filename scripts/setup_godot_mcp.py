#!/usr/bin/env python3
"""
GodotMCP 配置生成脚本。

脚本不下载依赖、不全局安装包、不修改 AI 客户端配置；默认只输出可复制的
MCP server 配置。只有显式传入 --install-addon 时，才会把本地
tools/godotmcp/addons/godot_mcp/ 复制到项目 addons/godot_mcp/。
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import shutil
import sys
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_XULEK_ROOT = PROJECT_ROOT / "tools" / "godotmcp"
ALT_XULEK_ROOT = PROJECT_ROOT / "tools" / "godot-mcp"
GODOT_WS_URL = "ws://127.0.0.1:49631"
CODING_SOLO_PACKAGE = "@coding-solo/godot-mcp@0.1.1"

sys.path.insert(0, str(PROJECT_ROOT / "scripts"))
from godot_locator import find_godot  # noqa: E402


def _as_posix(path: Path) -> str:
    return path.resolve().as_posix()


def _find_command(names: list[str]) -> str | None:
    local_dirs: list[Path] = []
    if sys.platform == "win32":
        local_dirs.append(PROJECT_ROOT / "tools" / "node")
    else:
        local_dirs.extend([
            PROJECT_ROOT / "tools" / "node" / "bin",
            PROJECT_ROOT / "tools" / "node",
        ])

    for directory in local_dirs:
        for name in names:
            candidate = directory / name
            if candidate.is_file():
                return _as_posix(candidate)

    for name in names:
        resolved = shutil.which(name)
        if resolved:
            return resolved
    return None


def _find_python() -> str:
    if sys.platform == "win32":
        portable = PROJECT_ROOT / "tools" / "python" / "python.exe"
    else:
        portable = PROJECT_ROOT / "tools" / "python" / "bin" / "python"
    if portable.is_file():
        return _as_posix(portable)
    return sys.executable or "python"


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


def _find_godot() -> str | None:
    godot = find_godot()
    return godot.replace("\\", "/") if godot else None


def _godot_mcp_roots() -> list[Path]:
    roots: list[Path] = []
    env_root = os.environ.get("GODOT_MCP_ROOT")
    if env_root:
        roots.append(Path(env_root))
    roots.extend([DEFAULT_XULEK_ROOT, ALT_XULEK_ROOT])
    return roots


def _find_xulek_root() -> Path | None:
    for root in _godot_mcp_roots():
        if (root / "server" / "godot_mcp_server.py").is_file():
            return root
    return None


def _find_local_coding_solo_root() -> Path | None:
    for root in [PROJECT_ROOT / "tools" / "godot-mcp-node", PROJECT_ROOT / "tools" / "godot-mcp"]:
        if _find_local_coding_solo_entry(root):
            return root
    return None


def _find_local_coding_solo_entry(root: Path) -> Path | None:
    for entry in (
        root / "build" / "index.js",
        root / "node_modules" / "@coding-solo" / "godot-mcp" / "build" / "index.js",
    ):
        if entry.is_file():
            return entry
    return None


def _check(name: str, ok: bool, detail: str) -> dict[str, Any]:
    return {"name": name, "status": "ok" if ok else "warn", "detail": detail}


def _xulek_report() -> dict[str, Any]:
    root = _find_xulek_root()
    expected_root = root or DEFAULT_XULEK_ROOT
    server_path = expected_root / "server" / "godot_mcp_server.py"
    addon_src = expected_root / "addons" / "godot_mcp"
    addon_dst = PROJECT_ROOT / "addons" / "godot_mcp"

    checks = [
        _check(
            "server",
            server_path.is_file(),
            _as_posix(server_path) if server_path.is_file() else "未找到 tools/godotmcp/server/godot_mcp_server.py",
        ),
        _check(
            "addon_source",
            addon_src.is_dir(),
            _as_posix(addon_src) if addon_src.is_dir() else "未找到 tools/godotmcp/addons/godot_mcp/",
        ),
        _check(
            "project_addon",
            addon_dst.is_dir(),
            _as_posix(addon_dst) if addon_dst.is_dir() else "项目尚未安装 addons/godot_mcp/",
        ),
    ]

    config = {
        "mcpServers": {
            "godot": {
                "command": _find_python(),
                "args": [_as_posix(server_path)],
                "env": {
                    "GODOT_WS_URL": GODOT_WS_URL,
                    "GODOT_MCP_ENABLE_GUARDS": "1",
                    "GODOT_MCP_BUILD_COMMAND_ALLOWLIST": "godot,godot4",
                },
            }
        }
    }
    return {
        "provider": "xulek/godotmcp",
        "config_available": root is not None,
        "ready": all(item["status"] == "ok" for item in checks),
        "mcpServers": config["mcpServers"],
        "checks": checks,
        "next_steps": [
            "把 xulek/godotmcp 放到 tools/godotmcp/，或设置 GODOT_MCP_ROOT。",
            "运行 python scripts/setup_godot_mcp.py --provider xulek --install-addon 复制编辑器插件。",
            "在 Godot 中启用 Project Settings -> Plugins -> Godot MCP Bridge。",
            "把输出的 mcpServers 片段加入你的 AI 客户端 MCP 配置。",
        ],
    }


def _coding_solo_report() -> dict[str, Any]:
    local_root = _find_local_coding_solo_root()
    node = _find_command(["node.exe", "node"])
    npx = _find_command(["npx.cmd", "npx"])
    godot_path = _find_godot()

    local_server_ready = bool(local_root and node)
    npx_available = bool(npx)
    if local_server_ready:
        entry = _find_local_coding_solo_entry(local_root)
        command = node
        args = [_as_posix(entry)] if entry else []
        source_detail = _as_posix(entry) if entry else "未找到本地 build/index.js"
        source_status = "ok"
    else:
        command = npx or "npx"
        args = ["@coding-solo/godot-mcp"]
        source_detail = npx or "未找到 npx；首次使用 npx 可能需要联网下载包"
        source_status = "warn"

    env: dict[str, str] = {}
    if godot_path:
        env["GODOT_PATH"] = godot_path

    config: dict[str, Any] = {
        "command": command,
        "args": args,
    }
    if env:
        config["env"] = env

    checks = [
        {"name": "server_command", "status": source_status, "detail": source_detail},
        _check("godot_path", bool(godot_path), godot_path or "未找到 Godot；可设置 GODOT4_PATH 或 GODOT_PATH"),
    ]

    next_steps = [
        "把输出的 mcpServers 片段加入你的 AI 客户端 MCP 配置。",
        "重启或刷新 AI 客户端后，调用 get_godot_version 或 get_project_info 做连通性检查。",
        "排查编辑器运行问题时，优先调用 run_project、get_debug_output、stop_project 获取真实日志。",
    ] if local_server_ready else [
        "确认允许 npx 按需下载 @coding-solo/godot-mcp，或把本地构建放到 tools/godot-mcp-node/。",
        "把输出的 mcpServers 片段加入你的 AI 客户端 MCP 配置。",
        "让 AI 客户端调用 get_godot_version 或 get_project_info 做连通性检查。",
    ]

    return {
        "provider": "Coding-Solo/godot-mcp",
        "config_available": local_server_ready or npx_available,
        "ready": local_server_ready and bool(godot_path),
        "mcpServers": {"godot": config},
        "checks": checks,
        "next_steps": next_steps,
    }


def _select_report(provider: str) -> dict[str, Any]:
    if provider == "xulek":
        return _xulek_report()
    if provider == "coding-solo":
        return _coding_solo_report()

    xulek = _xulek_report()
    if xulek["ready"]:
        return xulek
    coding_solo = _coding_solo_report()
    if coding_solo["ready"]:
        return coding_solo
    if coding_solo.get("config_available"):
        return coding_solo
    return xulek


def _install_xulek_addon() -> dict[str, Any]:
    root = _find_xulek_root()
    if not root:
        return {"installed": False, "detail": "未找到 tools/godotmcp/server/godot_mcp_server.py"}

    src = root / "addons" / "godot_mcp"
    dst = PROJECT_ROOT / "addons" / "godot_mcp"
    if not src.is_dir():
        return {"installed": False, "detail": f"未找到 {src.as_posix()}"}
    if dst.exists():
        return {"installed": True, "detail": f"已存在 {dst.as_posix()}，未覆盖。"}

    shutil.copytree(src, dst)
    return {"installed": True, "detail": f"已复制到 {dst.as_posix()}"}


def _install_coding_solo_package(yes: bool) -> dict[str, Any]:
    root = PROJECT_ROOT / "tools" / "godot-mcp-node"
    existing = _find_local_coding_solo_entry(root)
    if existing:
        return {"installed": True, "detail": f"已存在 {existing.as_posix()}，未重复安装。"}
    if not yes:
        return {
            "installed": False,
            "detail": "安装 @coding-solo/godot-mcp 需要联网；确认后运行 python scripts/setup_godot_mcp.py --provider coding-solo --install-coding-solo --yes",
        }

    npm = _find_command(["npm.cmd", "npm"])
    if not npm:
        return {"installed": False, "detail": "未找到 npm；请先准备 Node.js，或把 node-v*-win-x64.zip 放入 tools/ 后运行 init.cmd。"}

    root.mkdir(parents=True, exist_ok=True)
    try:
        result = subprocess.run(
            [npm, "install", "--prefix", _as_posix(root), CODING_SOLO_PACKAGE],
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=240,
        )
    except Exception as exc:
        return {"installed": False, "detail": str(exc)}

    entry = _find_local_coding_solo_entry(root)
    if result.returncode == 0 and entry:
        return {"installed": True, "detail": f"已安装到 {entry.as_posix()}"}
    return {"installed": False, "detail": (result.stdout or "npm install failed").strip()}


def _print_text(report: dict[str, Any]) -> None:
    status = "OK" if report["ready"] else "WARN"
    print(f"[{status}] GodotMCP provider: {report['provider']}")
    print("")
    for item in report["checks"]:
        prefix = "OK" if item["status"] == "ok" else "WARN"
        print(f"[{prefix}] {item['name']}: {item['detail']}")
    print("")
    print("MCP 配置片段：")
    print(json.dumps({"mcpServers": report["mcpServers"]}, ensure_ascii=False, indent=2))
    if report.get("addon_install"):
        print("")
        print(f"Addon: {report['addon_install']['detail']}")
    if report.get("coding_solo_install"):
        print("")
        print(f"Coding-Solo install: {report['coding_solo_install']['detail']}")
    print("")
    print("下一步：")
    for step in report["next_steps"]:
        print(f"- {step}")


def main() -> int:
    parser = argparse.ArgumentParser(description="生成 GodotMCP 的 MCP client 配置")
    parser.add_argument("--provider", choices=["auto", "xulek", "coding-solo"], default="auto")
    parser.add_argument("--install-addon", action="store_true", help="仅 xulek/godotmcp：从 tools/godotmcp/ 复制 Godot 编辑器插件")
    parser.add_argument("--install-coding-solo", action="store_true", help="安装 @coding-solo/godot-mcp 到项目内 tools/godot-mcp-node/")
    parser.add_argument("--yes", action="store_true", help="确认执行需要联网或写入项目 tools/ 的安装操作")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    coding_solo_install: dict[str, Any] | None = None
    if args.install_coding_solo:
        coding_solo_install = _install_coding_solo_package(args.yes)
        args.provider = "coding-solo"

    report = _select_report(args.provider)
    if coding_solo_install is not None:
        report["coding_solo_install"] = coding_solo_install
    if args.install_addon:
        if args.provider not in {"auto", "xulek"}:
            report["addon_install"] = {"installed": False, "detail": "--install-addon 只适用于 xulek/godotmcp。"}
        else:
            report["addon_install"] = _install_xulek_addon()
            report = _xulek_report() | {"addon_install": report["addon_install"]}

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        _print_text(report)
    return 0 if report["ready"] or report.get("config_available") else 1


if __name__ == "__main__":
    raise SystemExit(main())
