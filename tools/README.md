# Portable 工具目录

这个目录用于放置 Godot V1 Plus 的免安装工具。`init.cmd` 会优先使用这里的内容，不再依赖 `installers/`。

## 支持的稳定结构

```text
tools/
├── python/python.exe
├── node/node.exe
├── node/npm.cmd
├── node/npx.cmd
├── git/cmd/git.exe
├── godot/Godot.exe
├── gdtoolkit/python/                 # 必选，gdtoolkit Python 包
├── agent-browser/agent-browser.exe   # 可选，完整自动试玩用
├── godot-mcp-node/                   # 内置，Coding-Solo/godot-mcp npm 本地包
└── godotmcp/                         # 可选，xulek/godotmcp 本地仓库
```

## 支持的压缩包

可以先直接把这些文件放在 `tools/` 根目录，首次运行 `init.cmd` 时会自动解包：

```text
tools/
├── python-3.x.x-embed-amd64.zip
├── node-v24.x.x-win-x64.zip
├── PortableGit-2.x.x-64-bit.7z.exe
├── Godot_v4.x-stable_win64.exe.zip
└── Godot_v4.x-stable_export_templates.tpz
```

## 使用者入口

双击仓库根目录：

```text
init.cmd
```

脚本会把 Python 解到 `tools/python/`，把 Node.js 解到 `tools/node/`，把 PortableGit 解到 `tools/git/`，把 Godot 解到 `tools/godot/`，然后运行环境检查。

`Node.js` 用于 AI 工具链，不是 Godot 游戏运行时依赖。`tools/node/npx.cmd` 存在后，GodotMCP 等 Node CLI 会优先使用本地 Node；首次通过 `npx` 联网拉包前仍必须先确认。

`agent-browser` 不默认随轻量模板携带。需要完整浏览器自动试玩时，可以把可执行命令放到 `tools/agent-browser/`，或安装到系统 PATH。不要把浏览器 profile、登录态、HAR、截图缓存或 token 放到这里。

`GDScript Toolkit` 是必选质量门禁，`GDUnit4` 是可选测试能力，统一入口是 `python scripts/godot_quality_tools.py --json`。依赖清单见 `spec/quality_tools.json`；准备状态用 `python scripts/setup_quality_tools.py` 检查。首次联网安装或下载 addon 前必须先确认。

默认开箱即用模板会保留 `tools/gdtoolkit/python/`，并把 `addons/gdUnit4/` 一起打包，保证解压后不联网也能跑质量门禁。

`GodotMCP` 默认以内置 `tools/godot-mcp-node/` 提供 Coding-Solo/godot-mcp，本地 Node 可直接运行。`init.cmd` 会运行 `scripts/setup_ai_mcp.py --apply-project`，为 OpenCode、Claude Code 和 Codex 写入当前机器的项目级 MCP 配置。缺少内置 npm 包时，确认联网后运行 `python scripts/setup_godot_mcp.py --provider coding-solo --install-coding-solo --yes` 安装到项目内；如果改用 `npx`、下载外部仓库、全局安装、用户级注册或复制外部 addon，必须先确认。

## 导出模板

普通模板默认包含 `tools/` 下的 portable 工具或工具压缩包，确保小白解压后运行 `init.cmd` 能自动解包。兼容旧命令：

```bash
python scripts/export_template.py --include-tools
```

需要瘦身包时使用：

```bash
python scripts/export_template.py --no-tools
```

如果同时保留压缩包和解包目录，导出工具会优先携带压缩包，排除本机解包生成的 `tools/python/`、`tools/node/`、`tools/git/`、`tools/godot/`，避免重复打包。`tools/gdtoolkit/python/` 是开箱即用质量门禁依赖，`tools/godot-mcp-node/` 是编辑器运行诊断依赖，都会默认保留；外部 xulek GodotMCP 本地仓库目录不会进入干净模板。

不要把账号、token、私有下载器或临时缓存放入这里。
