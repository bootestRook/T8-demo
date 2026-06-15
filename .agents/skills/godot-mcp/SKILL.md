---
name: godot-mcp
description: 当用户要求添加、配置、检查或使用 GodotMCP、Godot MCP、MCP 编辑器桥接、AI 控制 Godot 编辑器时使用。用于把 GodotMCP 作为可选工具链接入脚手架，不作为游戏运行时依赖。
---

# Godot MCP

## 目标

把 GodotMCP 作为可选 AI 编辑器辅助通道接入 Godot V1 Plus。默认优先使用脚手架内置 `tools/godot-mcp-node/` 本地包，按当前项目和当前 Godot 可执行文件动态生成 MCP 配置；不把私有 MCP 客户端配置写进仓库。

## 流程

1. 先读 `docs/GODOT_MCP.md`。
2. 运行：
   ```bash
   python scripts/check_env.py --json --fast
   ```
3. 生成 MCP 配置：
   ```bash
   python scripts/setup_godot_mcp.py --provider auto
   ```
   为常见 AI 客户端写入项目级配置：
   ```bash
   python scripts/setup_ai_mcp.py --apply-project
   ```
4. 根据需求选择实现：
   - 深度编辑器控制：优先 `xulek/godotmcp`，本地放到 `tools/godotmcp/` 或设置 `GODOT_MCP_ROOT`。
   - 轻量启动/运行/调试：优先用内置 `tools/godot-mcp-node/node_modules/@coding-solo/godot-mcp/build/index.js`；缺失时可退回 `npx @coding-solo/godot-mcp`，但首次执行可能联网下载，必须先确认。
5. 需要安装 xulek Godot 插件时，只能在用户明确要求后运行：
   ```bash
   python scripts/setup_godot_mcp.py --provider xulek --install-addon
   ```
6. 让用户在 Godot 中启用插件；AI 客户端接入后，用 get_godot_version 或 get_project_info 工具做连通性检查。
7. 影响 Godot 运行时的改动后，以及排查“编辑器运行后才报错”时，优先执行 GodotMCP 的 `run_project -> get_debug_output -> stop_project` 快速诊断；随后运行 `python scripts/godot_runtime_log_check.py` 形成命令行 gate，再进入导出和 `ai_review.py --strict`。GodotMCP 不可用时不阻塞普通开发，但必须保留命令行 gate。

## 边界

- 不默认执行 `npm i -g`、`pip install`、`npx`、`git clone`、`codex mcp add`、`claude mcp add` 或系统配置修改；只有用户确认后，才可把第三方包安装到项目内 `tools/` 或写入用户级 AI 配置。
- 不把 token、cookies、客户端私有配置写入项目。
- 不把 GodotMCP 当作运行时代码依赖。
- 通过 GodotMCP 做删除、覆盖、批量资源改名、构建命令等高风险操作前，必须先给出影响范围并获得明确确认。
- 修改项目后仍运行脚手架 review gate；GodotMCP 只能辅助开发，不能替代正常运行日志、导出和体验检查。

## 输出

输出必须包含：

- 当前选择的 provider。
- `scripts/setup_godot_mcp.py` 的检查结论。
- 用户需要复制到 MCP 客户端的配置片段，或说明为什么暂时无法生成可用配置。
- 后续验证命令和需要人工完成的客户端/插件启用步骤。
- 如用户反馈 Godot 编辑器运行后报错，输出必须包含 GodotMCP debug output 和 `scripts/godot_runtime_log_check.py` 的结论；如果 MCP 不可用，说明原因并提供命令行 gate 结果。
