#!/usr/bin/env python3
"""
环境检测脚本 — godot-v1 模板
检测 Python 版本、Godot 可执行文件、Export Templates 安装状态、Git
输出格式：[OK] / [FAIL] / [WARN] / [NEXT]

可选参数：
- --json
- --fast
- --require-godot-mcp（或环境变量 GODOT_MCP_REQUIRED=1）
"""
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

MIN_PYTHON = (3, 8)
REQUIRED_GODOT_MAJOR = 4

EXPORT_TEMPLATES_MARKER = Path(__file__).parent.parent / ".godot-export-templates-ready"
PROJECT_ROOT = Path(__file__).parent.parent
RUNNER = PROJECT_ROOT / "scripts" / "run_python_entrypoint.py"
AGENT_BROWSER_ENV_KEY = "AGENT_BROWSER_PATH"
GODOT_MCP_ENV_KEY = "GODOT_MCP_ROOT"
GODOT_MCP_REQUIRED_ENV_KEY = "GODOT_MCP_REQUIRED"
NODE_EXE_ENV_KEY = "NODE_EXE_PATH"
GDLINT_ENV_KEY = "GDLINT_PATH"
GDFORMAT_ENV_KEY = "GDFORMAT_PATH"

JSON_OUTPUT = "--json" in sys.argv
FAST_MODE = "--fast" in sys.argv
REQUIRE_GODOT_MCP = "--require-godot-mcp" in sys.argv or (
    os.environ.get(GODOT_MCP_REQUIRED_ENV_KEY, "").strip().lower() in {"1", "true", "yes", "on"}
)


def out(level: str, message: str) -> None:
    if not JSON_OUTPUT:
        print(f"[{level}] {message}")


def _infer_godot_version_from_path(path: str) -> str:
    match = re.search(r"Godot_v?(\d+(?:\.\d+){1,3})", path, re.IGNORECASE)
    if match:
        return f"{match.group(1)} (fast check)"
    return "4.x (fast check)"


def _sort_godot_exec_paths(paths: list[Path]) -> list[str]:
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
            Path(value).name.lower(),
            value.lower(),
        ),
    )


def find_godot() -> tuple[str | None, str | None]:
    candidates = []

    env_path = os.environ.get("GODOT4_PATH")
    if env_path:
        candidates.append(env_path)

    godot_dir = PROJECT_ROOT / "tools" / "godot"
    if godot_dir.exists():
        candidates += _sort_godot_exec_paths([
            *godot_dir.rglob("Godot*.exe"),
            *godot_dir.rglob("godot*.exe"),
        ])

    tools_dir = PROJECT_ROOT / "tools"
    if tools_dir.exists():
        candidates += _sort_godot_exec_paths([
            *tools_dir.glob("Godot*.exe"),
            *tools_dir.glob("godot*.exe"),
        ])

    candidates += ["godot4", "godot"]

    if sys.platform == "win32":
        import glob
        for pattern in [
            r"C:\Program Files\Godot\Godot_v4*_stable_win64_console.exe",
            r"C:\Program Files (x86)\Godot\Godot_v4*_stable_win64_console.exe",
            r"C:\Program Files\Godot\Godot_v4*_stable_win64.exe",
            r"C:\Program Files (x86)\Godot\Godot_v4*_stable_win64.exe",
        ]:
            candidates += glob.glob(pattern)
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

    for candidate in candidates:
        resolved = shutil.which(candidate) or (Path(candidate).is_file() and candidate)
        if not resolved:
            continue
        if FAST_MODE:
            return str(resolved), _infer_godot_version_from_path(str(resolved))
        try:
            result = subprocess.run(
                [resolved, "--version"],
                capture_output=True, text=True, timeout=5,
            )
            version_str = (result.stdout or result.stderr or "").strip().splitlines()[0]
            return resolved, version_str
        except Exception:
            continue

    return None, None


def find_git() -> tuple[str | None, str | None]:
    candidates = []
    for path in [
        PROJECT_ROOT / "tools" / "git" / "cmd" / "git.exe",
        PROJECT_ROOT / "tools" / "git" / "bin" / "git.exe",
        PROJECT_ROOT / "tools" / "PortableGit" / "cmd" / "git.exe",
    ]:
        candidates.append(str(path))
    candidates.append("git")

    for candidate in candidates:
        resolved = shutil.which(candidate) or (Path(candidate).is_file() and candidate)
        if not resolved:
            continue
        if FAST_MODE:
            return str(resolved), "git found (fast check)"
        try:
            result = subprocess.run(
                [resolved, "--version"],
                capture_output=True, text=True, timeout=5,
            )
            version = (result.stdout or result.stderr or "").strip()
            if version:
                return str(resolved), version
        except Exception:
            continue
    return None, None


def _command_version(command: list[str], timeout: int = 5) -> str:
    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    return (result.stdout or result.stderr or "").strip().splitlines()[0]


def _find_node_command(command_name: str, env_key: str = "") -> str | None:
    candidates: list[str] = []
    if env_key and os.environ.get(env_key):
        candidates.append(os.environ[env_key])

    tools_node = PROJECT_ROOT / "tools" / "node"
    if sys.platform == "win32":
        candidates += [
            str(tools_node / f"{command_name}.exe"),
            str(tools_node / f"{command_name}.cmd"),
            str(tools_node / "bin" / f"{command_name}.exe"),
            str(tools_node / "bin" / f"{command_name}.cmd"),
        ]
    else:
        candidates += [
            str(tools_node / command_name),
            str(tools_node / "bin" / command_name),
        ]
    candidates.append(command_name)

    for candidate in candidates:
        resolved = shutil.which(candidate) or (Path(candidate).is_file() and candidate)
        if resolved:
            return str(resolved)
    return None


def has_node_package() -> bool:
    tools = PROJECT_ROOT / "tools"
    if not tools.exists():
        return False
    return any(tools.glob("node-v*-win-*.zip"))


def find_nodejs() -> dict:
    node = _find_node_command("node", NODE_EXE_ENV_KEY)
    npm = _find_node_command("npm")
    npx = _find_node_command("npx")
    if not node:
        return {
            "status": "warn",
            "path": "",
            "npm": npm or "",
            "npx": npx or "",
            "detail": "package available" if has_node_package() else "not found",
        }
    if FAST_MODE:
        return {
            "status": "ok",
            "path": node,
            "npm": npm or "",
            "npx": npx or "",
            "detail": "node found (fast check)",
        }
    try:
        version = _command_version([node, "--version"])
    except Exception:
        version = "node available"
    return {
        "status": "ok",
        "path": node,
        "npm": npm or "",
        "npx": npx or "",
        "detail": version,
    }


def _agent_browser_command(path: str) -> list[str]:
    if sys.platform == "win32" and path.lower().endswith(".ps1"):
        return ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", path]
    return [path]


def find_agent_browser() -> tuple[str | None, str | None]:
    candidates: list[str] = []
    env_path = os.environ.get(AGENT_BROWSER_ENV_KEY)
    if env_path:
        candidates.append(env_path)

    tools_agent = PROJECT_ROOT / "tools" / "agent-browser"
    if sys.platform == "win32":
        candidates += [
            str(tools_agent / "agent-browser.exe"),
            str(tools_agent / "agent-browser.cmd"),
            str(tools_agent / "agent-browser.ps1"),
        ]
    else:
        candidates += [
            str(tools_agent / "agent-browser"),
            str(tools_agent / "bin" / "agent-browser"),
        ]
    candidates.append("agent-browser")

    for candidate in candidates:
        resolved = shutil.which(candidate) or (Path(candidate).is_file() and candidate)
        if not resolved:
            continue
        if FAST_MODE:
            return str(resolved), "agent-browser found (fast check)"
        try:
            result = subprocess.run(
                _agent_browser_command(str(resolved)) + ["--version"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            version = (result.stdout or result.stderr or "").strip().splitlines()[0]
            return str(resolved), version or "agent-browser available"
        except Exception:
            continue
    return None, None


def _path_variants(base: Path, command_name: str) -> list[Path]:
    if sys.platform == "win32":
        return [
            base / command_name,
            base / f"{command_name}.exe",
            base / f"{command_name}.cmd",
            base / f"{command_name}.bat",
        ]
    return [base / command_name]


def _find_optional_command(command_name: str, env_key: str, extra_dirs: list[Path]) -> str | None:
    candidates: list[str] = []
    env_path = os.environ.get(env_key)
    if env_path:
        candidates.append(env_path)
    for directory in extra_dirs:
        for path in _path_variants(directory, command_name):
            candidates.append(str(path))
    candidates.append(command_name)

    for candidate in candidates:
        resolved = shutil.which(candidate) or (Path(candidate).is_file() and candidate)
        if resolved:
            return str(resolved)
    return None


def _python_entry_available(target: Path, entry: str) -> bool:
    if not target.exists() or not RUNNER.is_file():
        return False
    script = (
        "import importlib.metadata as m, sys; "
        "eps=m.entry_points(); "
        f"matches=eps.select(group='console_scripts', name='{entry}') "
        f"if hasattr(eps, 'select') else [ep for ep in eps.get('console_scripts', []) if ep.name == '{entry}']; "
        "sys.exit(0 if list(matches) else 1)"
    )
    try:
        result = subprocess.run(
            [sys.executable, "-c", script],
            capture_output=True,
            text=True,
            timeout=10,
            env={**os.environ, "PYTHONPATH": str(target)},
        )
    except Exception:
        return False
    return result.returncode == 0


def _python_entry_command(target: Path, entry: str) -> str:
    return subprocess.list2cmdline([sys.executable, str(RUNNER), "--target", str(target), entry])


def find_gdscript_toolkit() -> dict:
    dirs = [
        PROJECT_ROOT / "tools" / "gdtoolkit" / "Scripts",
        PROJECT_ROOT / "tools" / "gdtoolkit" / "bin",
        PROJECT_ROOT / "tools" / "python" / "Scripts",
    ]
    gdlint = _find_optional_command("gdlint", GDLINT_ENV_KEY, dirs)
    gdformat = _find_optional_command("gdformat", GDFORMAT_ENV_KEY, dirs)
    target = PROJECT_ROOT / "tools" / "gdtoolkit" / "python"
    if not gdlint and _python_entry_available(target, "gdlint"):
        gdlint = _python_entry_command(target, "gdlint")
    if not gdformat and _python_entry_available(target, "gdformat"):
        gdformat = _python_entry_command(target, "gdformat")
    if gdlint or gdformat:
        return {
            "status": "ok" if gdlint and gdformat else "fail",
            "gdlint": gdlint or "",
            "gdformat": gdformat or "",
            "detail": "gdlint/gdformat available via command or local runner" if gdlint and gdformat else "partial gdtoolkit commands found",
            "next": "" if gdlint and gdformat else "python scripts/setup_quality_tools.py --install --yes",
        }
    return {
        "status": "fail",
        "gdlint": "",
        "gdformat": "",
        "detail": "required but not configured",
        "next": "python scripts/setup_quality_tools.py --install --yes",
    }


def find_gdunit4() -> dict:
    for rel in (
        Path("addons") / "gdUnit4" / "bin" / "GdUnitCmdTool.gd",
        Path("addons") / "gdunit4" / "bin" / "GdUnitCmdTool.gd",
    ):
        path = PROJECT_ROOT / rel
        if path.is_file():
            return {"status": "ok", "path": str(path), "detail": "addon command line tool found", "next": ""}
    return {
        "status": "warn",
        "path": "",
        "detail": "optional addon not configured",
        "next": "python scripts/setup_quality_tools.py --install-gdunit --yes",
    }


def find_godot_mcp() -> dict:
    roots: list[Path] = []
    env_root = os.environ.get(GODOT_MCP_ENV_KEY)
    if env_root:
        roots.append(Path(env_root))
    roots.extend([
        PROJECT_ROOT / "tools" / "godotmcp",
        PROJECT_ROOT / "tools" / "godot-mcp",
    ])

    project_addon = PROJECT_ROOT / "addons" / "godot_mcp"
    for root in roots:
        server = root / "server" / "godot_mcp_server.py"
        addon = root / "addons" / "godot_mcp"
        if server.is_file():
            if project_addon.is_dir():
                return {
                    "status": "ok",
                    "provider": "xulek/godotmcp",
                    "path": str(server),
                    "detail": "server and project addon found",
                }
            if addon.is_dir():
                return {
                    "status": "warn",
                    "provider": "xulek/godotmcp",
                    "path": str(server),
                    "detail": "server found; run setup_godot_mcp.py --provider xulek --install-addon",
                }
            return {
                "status": "warn",
                "provider": "xulek/godotmcp",
                "path": str(server),
                "detail": "server found; addon source not found",
            }

    for root in [
        PROJECT_ROOT / "tools" / "godot-mcp-node",
        PROJECT_ROOT / "tools" / "godot-mcp",
    ]:
        entry = _find_coding_solo_entry(root)
        if entry:
            node = _find_node_command("node")
            return {
                "status": "ok" if node else "warn",
                "provider": "Coding-Solo/godot-mcp",
                "path": str(entry),
                "detail": "local npm package found" if node else "local npm package found; node not found",
            }

    npx = _find_node_command("npx")
    if npx:
        return {
            "status": "warn",
            "provider": "Coding-Solo/godot-mcp",
            "path": npx,
            "detail": "npx available; first @coding-solo/godot-mcp run may require network confirmation",
        }

    return {
        "status": "warn",
        "provider": "",
        "path": "",
        "detail": "not configured",
    }


def _find_coding_solo_entry(root: Path) -> Path | None:
    for entry in (
        root / "build" / "index.js",
        root / "node_modules" / "@coding-solo" / "godot-mcp" / "build" / "index.js",
    ):
        if entry.is_file():
            return entry
    return None


def template_version(godot_version: str | None) -> str | None:
    if not godot_version:
        return None
    parts = godot_version.split(".")
    if len(parts) >= 4 and parts[0].isdigit() and parts[1].isdigit():
        return ".".join(parts[:4])
    return None


def has_web_export_template(path: Path) -> bool:
    return any(
        (path / name).exists()
        for name in ("web_nothreads_release.zip", "web_release.zip", "web_dlink_release.zip")
    )


def has_export_template_package() -> bool:
    tools = PROJECT_ROOT / "tools"
    if not tools.exists():
        return False
    return any(tools.glob("Godot_v4*_export_templates.tpz"))


def check_export_templates(godot_version: str | None = None) -> bool:
    if FAST_MODE:
        return EXPORT_TEMPLATES_MARKER.exists()

    if sys.platform == "win32":
        base = Path(os.environ.get("APPDATA", "")) / "Godot" / "export_templates"
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support" / "Godot" / "export_templates"
    else:
        base = Path.home() / ".local" / "share" / "godot" / "export_templates"

    if not base.exists():
        return False

    expected = template_version(godot_version)
    if expected:
        return has_web_export_template(base / expected)

    return any(has_web_export_template(p) for p in base.iterdir() if p.is_dir())


def main() -> int:
    results: list[dict] = []
    exit_code = 0

    # Python 版本
    py_ver = sys.version_info[:2]
    if py_ver >= MIN_PYTHON:
        out("OK", f"Python {sys.version.split()[0]}")
        results.append({"check": "python", "status": "ok", "detail": sys.version.split()[0]})
    else:
        out("FAIL", f"需要 Python {MIN_PYTHON[0]}.{MIN_PYTHON[1]}+，当前是 {py_ver[0]}.{py_ver[1]}")
        results.append({"check": "python", "status": "fail"})
        exit_code = 1

    # Godot
    godot_path, godot_version = find_godot()
    if godot_path and godot_version:
        major = int(godot_version.split(".")[0]) if godot_version[0].isdigit() else 0
        if major >= REQUIRED_GODOT_MAJOR:
            out("OK", f"Godot {godot_version} ({godot_path})")
            results.append({"check": "godot", "status": "ok", "path": godot_path, "version": godot_version})
        else:
            out("FAIL", f"需要 Godot 4.x，当前是 {godot_version}")
            results.append({"check": "godot", "status": "fail", "detail": godot_version})
            exit_code = 1
    else:
        out("FAIL", "未找到 Godot 4 可执行文件")
        out("NEXT", "把 Godot portable zip 放入 tools/ 后运行 init.cmd；兜底才设置 GODOT4_PATH=/path/to/godot")
        results.append({"check": "godot", "status": "fail", "detail": "not found"})
        exit_code = 1

    # Export Templates
    if check_export_templates(godot_version):
        out("OK", "Godot Export Templates 已安装")
        results.append({"check": "export_templates", "status": "ok"})
    elif FAST_MODE and has_export_template_package():
        out("WARN", "检测到 Export Templates 离线包，运行 init.cmd 可安装")
        results.append({"check": "export_templates", "status": "warn", "detail": "package available"})
    else:
        out("WARN", "未检测到 Godot Export Templates（Web 导出需要）")
        out("NEXT", "把 Godot_v4.x-stable_export_templates.tpz 放入 tools/ 后运行 init.cmd")
        out("NEXT", "安装完成后运行 python scripts/setup_godot.py 写入标记")
        results.append({"check": "export_templates", "status": "warn", "detail": "not installed"})

    # Git
    git_path, git_version = find_git()
    if git_path and git_version:
        out("OK", f"{git_version} ({git_path})")
        results.append({"check": "git", "status": "ok", "path": git_path, "detail": git_version})
    else:
        out("WARN", "未检测到 Git（需要本地存档点时再安装并运行 python scripts/git_ai.py init）")
        results.append({"check": "git", "status": "warn", "detail": "not found"})

    nodejs = find_nodejs()
    if nodejs["status"] == "ok":
        out("OK", f"Node.js {nodejs['detail']} ({nodejs['path']})")
        results.append({"check": "nodejs", **nodejs})
    elif nodejs["detail"] == "package available":
        out("WARN", "检测到 Node.js portable zip，运行 init.cmd 可解包到 tools/node/")
        results.append({"check": "nodejs", **nodejs})
    else:
        out("WARN", "未检测到 Node.js（GodotMCP npx、部分 AI 工具会降级）")
        results.append({"check": "nodejs", **nodejs})

    agent_path, agent_version = find_agent_browser()
    if agent_path and agent_version:
        out("OK", f"{agent_version} ({agent_path})")
        results.append({"check": "agent_browser", "status": "ok", "path": agent_path, "detail": agent_version})
    else:
        out("WARN", "未检测到 agent-browser（自动试玩会降级为 CONCERNS；完整交付建议安装或放入 tools/agent-browser/）")
        results.append({"check": "agent_browser", "status": "warn", "detail": "not found"})

    gdtoolkit = find_gdscript_toolkit()
    if gdtoolkit["status"] == "ok":
        out("OK", f"GDScript Toolkit 可用：gdlint={gdtoolkit['gdlint']} gdformat={gdtoolkit['gdformat']}")
    else:
        out("FAIL", f"GDScript Toolkit 必选但未配置：{gdtoolkit['detail']}")
        if gdtoolkit.get("next"):
            out("NEXT", gdtoolkit["next"])
        exit_code = 1
    results.append({"check": "gdscript_toolkit", **gdtoolkit})

    gdunit4 = find_gdunit4()
    if gdunit4["status"] == "ok":
        out("OK", f"GDUnit4 可用：{gdunit4['path']}")
    else:
        out("WARN", f"GDUnit4 可选未配置：{gdunit4['detail']}")
        if gdunit4.get("next"):
            out("NEXT", gdunit4["next"])
    results.append({"check": "gdunit4", **gdunit4})

    godot_mcp = find_godot_mcp()
    if godot_mcp["status"] == "ok":
        out("OK", f"GodotMCP 可用：{godot_mcp['provider']} ({godot_mcp['detail']})")
        results.append({"check": "godot_mcp", **{**godot_mcp, "required": REQUIRE_GODOT_MCP}})
    elif REQUIRE_GODOT_MCP:
        out("FAIL", f"GodotMCP 为强依赖但未就绪：{godot_mcp['detail']}")
        out("NEXT", "运行 python scripts/setup_godot_mcp.py --provider auto 完成配置")
        results.append({"check": "godot_mcp", **{**godot_mcp, "status": "fail", "required": True}})
        exit_code = 1
    else:
        out("WARN", f"GodotMCP 未完全配置（可选）：{godot_mcp['detail']}")
        out("NEXT", "需要 MCP 编辑器桥接时运行 python scripts/setup_godot_mcp.py --provider auto")
        results.append({"check": "godot_mcp", **{**godot_mcp, "required": False}})

    if not JSON_OUTPUT:
        if exit_code:
            print("\n环境未就绪，请按上方 [NEXT] 提示处理后再继续。")
        else:
            print("\n环境检查完成。下一步：python scripts/export_web.py")

    if JSON_OUTPUT:
        print(json.dumps({"exit_code": exit_code, "checks": results}, ensure_ascii=False, indent=2))

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
