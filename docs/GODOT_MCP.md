# GodotMCP 接入

## 定位

GodotMCP 是可选的编辑器辅助通道，用于让支持 MCP 的 AI 客户端直接读取 Godot 项目、启动编辑器、运行项目、捕获 debug output 或控制场景。它不是游戏运行时依赖，不应写进玩法代码，也不替代 `scripts/godot_headless_check.py`、`scripts/godot_runtime_log_check.py`、`scripts/export_web.py` 和 `scripts/experience_check.py` 这些交付门禁。

脚手架默认内置 `tools/godot-mcp-node/` 作为 Coding-Solo/godot-mcp 的本地 npm 包，不全局安装 Node/Python 包。需要 AI 客户端使用时，用 `scripts/setup_godot_mcp.py` 按当前项目路径和当前 Godot 路径生成 MCP 配置；如果本地包缺失，退回 `npx` 或下载外部依赖前仍必须先由用户确认。

## 支持的接入方式

### xulek/godotmcp

适合需要深度控制 Godot 编辑器的场景，例如编辑场景树、Inspector、资源、动画和运行时观察。推荐把仓库放到：

```text
tools/godotmcp/
```

或设置：

```text
GODOT_MCP_ROOT=/absolute/path/to/godotmcp
```

本地仓库就绪后运行：

```bash
python scripts/setup_godot_mcp.py --provider xulek
```

如果需要把它的 Godot 编辑器插件复制进当前项目：

```bash
python scripts/setup_godot_mcp.py --provider xulek --install-addon
```

然后在 Godot 中启用：

```text
Project -> Project Settings -> Plugins -> Godot MCP Bridge
```

### Coding-Solo/godot-mcp

适合轻量运行和诊断，例如启动 Godot、运行项目、读取调试输出和项目结构。脚手架优先使用内置本地包：

```text
tools/godot-mcp-node/node_modules/@coding-solo/godot-mcp/build/index.js
```

如果本地包不存在，先确认是否允许联网，然后用项目内安装命令恢复：

```bash
python scripts/setup_godot_mcp.py --provider coding-solo --install-coding-solo --yes
```

仍缺包时才退回 `npx @coding-solo/godot-mcp`；脚本会优先使用 `tools/node/npx.cmd`，再回退系统 PATH。首次执行 `npx` 可能联网下载包，AI 不得在未确认时替用户执行。

生成配置：

```bash
python scripts/setup_godot_mcp.py --provider coding-solo
```

本地构建也兼容旧路径：

```text
tools/godot-mcp-node/build/index.js
```

脚本会优先生成本地 `node <当前项目>/tools/godot-mcp-node/.../build/index.js` 配置，不把某个用户机器的绝对路径写进模板源码。

## 检查命令

```bash
python scripts/check_env.py --json
python scripts/setup_godot_mcp.py --provider auto
python scripts/setup_ai_mcp.py --apply-project
python scripts/godot_runtime_log_check.py
```

`check_env.py` 只把 GodotMCP 当作可选能力：缺失时是 `warn`，不会阻塞普通游戏开发、Web 导出或模板导出。`godot_runtime_log_check.py` 是独立 gate，不依赖 MCP 客户端，专门捕获编辑器/F5 运行后才出现的项目进程日志错误。

`setup_ai_mcp.py --apply-project` 会为常见 AI 客户端写入项目级配置：OpenCode 使用当前机器生成的 `opencode.json` `mcp.godot`，Claude Code 使用本地生成的 `.mcp.json`，Codex 使用本地生成的 `.codex/config.toml`。`.mcp.json` 和 `.codex/` 不随模板导出；解压到新机器后由 `init.cmd` 重新生成，避免把 Windows/macOS/Linux 的命令路径写死进模板。OpenCode 和 Claude 项目配置在 Windows 调用 `scripts/godot_mcp_stdio.cmd`，在 macOS/Linux 调用 `sh scripts/godot_mcp_stdio.sh`；Codex 项目配置使用当前机器的绝对 wrapper 路径，避免客户端启动 MCP 时工作目录不在项目根导致相对路径失效。所有入口最终都会进入 `scripts/godot_mcp_stdio.py`，由 wrapper 动态解析当前项目下的 Node、GodotMCP 和 Godot 路径。

## 运行调试工作流

GodotMCP 在本脚手架中优先承担“快速运行诊断”职责。影响 Godot 运行时的改动后，如果 AI 客户端已连接 GodotMCP，先执行：

```text
run_project -> get_debug_output -> stop_project
```

适用改动包括 `*.gd`、`.tscn`、Autoload、资源路径、输入、场景切换、UI/HUD 接入和运行时素材加载。`get_debug_output` 出现脚本错误、资源加载错误、无效调用、空引用或崩溃线索时，AI 必须先修复；若需补充可复现证据，再运行：

```bash
python scripts/godot_runtime_log_check.py --json
```

GodotMCP 是会话内诊断层，不作为最终交付门禁的唯一依据。正式验收仍以 `scripts/godot_runtime_log_check.py`、`scripts/export_web.py`、`scripts/experience_check.py` 和 `scripts/ai_review.py --strict` 为准。

## 强依赖模式（可选）

如果你的团队希望把 GodotMCP 当作开发环境强依赖，可启用强校验：

```bash
python scripts/check_env.py --json --require-godot-mcp
```

或设置环境变量：

```text
GODOT_MCP_REQUIRED=1
```

启用后，只要 GodotMCP 未就绪，`check_env.py` 会返回 `FAIL` 并阻断后续流程。

## 安全边界

- 不把 token、登录态、浏览器 profile、MCP 客户端私有配置写进仓库；`.codex/` 作为本机生成目录默认不提交。
- 不自动执行 `npm i -g`、`pip install`、`npx` 下载或外部仓库 clone；只有用户确认后，才可把第三方包安装到项目内 `tools/`。
- 不把 GodotMCP 当作运行时素材或 gameplay 依赖。
- 使用具备破坏性的 MCP 工具前，先查看 dry-run 或操作计划；删除节点、覆盖文件、批量资源改名、构建命令等动作必须获得明确确认。
- `addons/godot_mcp/` 属于编辑器插件目录；只有在当前项目明确需要深度编辑器桥接时才安装。

## AI 使用流程

1. 读取本文件和 `.agents/skills/godot-mcp/SKILL.md`。
2. 运行 `python scripts/check_env.py --json --fast` 看 Godot、Python 和可选 GodotMCP 状态。
3. 运行 `python scripts/setup_ai_mcp.py --apply-project`，确保项目级 AI 客户端配置已写入。
4. 需要手工片段时，再运行 `python scripts/setup_godot_mcp.py --provider auto`。
5. 用户重启或刷新 AI 客户端后，用 GodotMCP 的 `get_godot_version` 或 `get_project_info` 工具做连通性检查。
6. 排查编辑器运行后才出现的错误时，优先调用 `run_project`、`get_debug_output`、`stop_project`，同时运行 `python scripts/godot_runtime_log_check.py` 留下可复现 gate 结果。
7. 任何 GodotMCP 修改都仍要回到脚手架 review gate：`python scripts/ai_review.py --strict`。
