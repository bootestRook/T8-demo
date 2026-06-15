# Godot V1 Plus

Godot V1 Plus 是一个纯 AI 驱动的 Godot 4 2D 游戏脚手架，面向 OpenCode、Codex、Claude Code 等 AI 编程工具。

目标不是展示 Godot 全部 API，而是让新手通过自然语言完成一款可在浏览器试玩和部署的 2D 完整首版游戏：默认首版要包含核心循环、必要系统、至少 3 个有差异内容单元或系统阶段、主题化素材、反馈、结算、进度、测试和反馈迭代。

脚手架不局限于简单类型。用户可以提出肉鸽、搜打撤、塔防、模拟经营、RTS、自走棋、养成、背包、暗黑刷装、跑酷、LD 关卡设计或混合玩法；AI 会先把创意拆成主循环和系统蓝图，再实现首版第一个完整内容单元。

当前模板不再内置默认游戏。主场景只显示中性启动提示，避免 AI 误沿用模板角色、玩法、素材或数值；输入 `init` 后再创建新的游戏概念和完整首版计划。

## 第一次使用

Windows 用户可以先双击：

```text
init.cmd
```

脚本会优先使用 `tools/` 中的 portable 工具或工具压缩包，并自动解包整理到稳定路径。完成后，在 AI 工具对话框输入：

```text
init
```

AI 会读取 `AGENTS.md`、检查环境、询问玩法方向和平台；确认美术方向后会生成 3 张风格候选图，等你选定后再按游戏设计指南创建完整首版计划。

## 常用命令

```bash
python scripts/check_env.py --json --fast
python scripts/check_env.py --json
python scripts/check_env.py --json --require-godot-mcp
python scripts/generate_project_map.py
python scripts/setup_godot_mcp.py --provider auto
python scripts/setup_ai_mcp.py --apply-project
python scripts/agent_task.py create --demand-id <ID> --task-id T-01 --role gameplay --goal "..." --allowed-path src/game/PrototypeState.gd
python scripts/agent_task.py check --manifest <manifest.json>
python scripts/agent_merge.py check --manifest <manifest.json> --patch <changes.patch>
python scripts/setup_quality_tools.py
python scripts/setup_quality_tools.py --install --yes
python scripts/setup_quality_tools.py --install-gdunit --yes
python scripts/godot_quality_tools.py --json
python scripts/gameplay_logic_review.py
python scripts/art_pipeline_review.py
python scripts/experience_design_review.py
python scripts/architecture_review.py
python scripts/godot_headless_check.py
python scripts/godot_runtime_log_check.py
python scripts/export_web.py --json
python scripts/run_web_preview.py --open --json
python scripts/experience_check.py --skip-export
python scripts/experience_check.py --strict
python scripts/ai_review.py --strict
python scripts/package_dist.py --json
python scripts/export_template.py --dry-run
```

如果 Windows 机器没有系统 Python，先运行 `init.cmd`，再把上面的 `python` 换成：

```text
tools/python/python.exe
```

## Godot 编辑器运行

- 打开 Godot 4，导入项目根目录的 `project.godot`。
- 在编辑器中按 `F5` 直接运行当前项目，不需要先导出 Web。
- 调试阶段可优先用编辑器运行；AI 排查编辑器运行报错时先跑 `python scripts/godot_runtime_log_check.py`，或用 GodotMCP 抓取 debug output。交付前再跑 Web 链路：`python scripts/export_web.py --json`、`python scripts/experience_check.py --strict`、`python scripts/ai_review.py --strict`。

## 目录

- `.agents/skills/`：内置 AI 工作流和工具 skill。
- `.agents/roles/`：多 Agent 主从协作角色说明。
- `assets/`：游戏运行时素材。
- `addons/vfx_library/`：内置 Godot VFX Library。
- `docs/`：收束后的工作流、游戏设计、美术、质量标准和工具链文档。
- `docs/project-map.md`：AI 最小导航，记录目录职责、关键文件、示例索引和接力读取规则。
- `references/`：参考资料，不作为运行时加载目录。
- `scenes/`：Godot 场景。
- `scripts/`：环境检查、质量门禁、Web 导出、预览、体验检查、打包、模板导出脚本。
- `spec/`：机器可读模板规格，给 AI 判断来源和初始边界。
- `spec/gameplay_blueprints.json`：机器可读玩法/中度系统蓝图，供 AI review 和 init 使用。
- `spec/module_catalog.json`：机器可读可拔插模块清单，供 AI 选择模块和检查边界。
- `src/game/`：玩法、反馈、音频、进度和素材清单。
- `src/game/modules/`：可拔插游戏模块，覆盖玩家控制、生成器、拾取、背包、装备、任务、对话、波次、菜单、场景切换和教程提示；新游戏确认玩法后按系统边界接入。
- `src/ui/`：HUD 和中文字体初始化。
- `tools/`：portable 工具目录，可放 Python、Node.js、Git、Godot、Export Templates、可选 `agent-browser` 和本地 GodotMCP。默认导出的开箱即用脚手架会携带这里的工具包。

本地过程目录不会进入干净模板：当前仓库 `.git/` 历史、`.godot/`、`.pm/`、`.runtime/`、`html5/`、`exports/`、本机解包生成的 `tools/python/`、`tools/node/`、`tools/git/`、`tools/godot/`。默认开箱即用模板会保留 `tools/gdtoolkit/python/`、`tools/godot-mcp-node/` 和 `addons/gdUnit4/`，让质量门禁和编辑器运行诊断离线可跑。导出包会生成一个新的空 `.git/`，用于小白直接拥有 AI 存档点能力。

## AI 开发原则

- 当前模板无内置游戏；先锁定玩法和美术风格，再完成一个 30 秒到 3 分钟能玩懂的完整首版。只做技术验证必须由用户明确要求，不作为真实游戏交付目标。
- 新会话先查 PM 状态；长流程接力先用 `pm_cli.py info <ID>` 获取 `read_first`，再读 `AGENTS.md`、`docs/project-map.md` 和 PM 的 `read_first`。不要依赖聊天上下文保存长期约定。新增稳定目录、核心脚本或长期文档后运行 `python scripts/generate_project_map.py`。
- 多 Agent 模式采用主 AI 编排、子 Agent 执行、主 AI 合并；流程见 `docs/MULTI_AGENT_WORKFLOW.md`，子 Agent 不直接改 `.pm/project/*.json` 或最终放行成果。
- `init` 默认只走快速环境检查；完整检查由 `python scripts/ai_review.py --strict` 在交付前执行。
- 正常优先改 `src/game/PrototypeState.gd`、`scenes/Game.gd`、`src/ui/Hud.gd`。
- AI 判断模块边界先读 `docs/ARCHITECTURE_RULES.md`；常见玩法接入步骤见 `docs/AI_RECIPES.md`。
- 通用事件、反馈、音效、成就和资源路径分别由 `GameEvents`、`FeedbackDirector`、`AudioDirector`、`AchievementStore`、`AssetRegistry` 统一承接。
- 生成图片默认使用平台 provider：`gpt-image-2`；首启风格候选优先用 `scripts/generate_style_candidates.py`。
- UI 设计图/sprite 提取使用 `ui-studio`；主体抠图或前后景分层使用 `ui-layer-split`。没有 PSD/UI 源图时，AI 应先生成 UI sheet、HUD 图标、按钮或面板素材，再接入 `assets/ui/`。
- 概念图只作为风格锚点；风格锁定后必须生成同源运行时视觉包，HUD、角色、怪物/目标、场景和 VFX 不得各自临时拼贴或直接裁剪候选图。
- 每轮改完后导出 Web，并在交付前运行严格体验检查。
- `scripts/godot_quality_tools.py` 默认强制运行 GDScript Toolkit；GDUnit4 为可选检查（`--run-gdunit` 启用），不会再默认阻塞 AI review。
- 浏览器自动试玩使用可选 `agent-browser`；轻量模板不默认携带浏览器二进制，完整 QA 环境建议安装或放入 `tools/agent-browser/`。
- Node.js 可用 `node-v24.x.x-win-x64.zip` 内聚到 `tools/`，首启自动解包到 `tools/node/`，供 GodotMCP 和 Node CLI 使用。
- GodotMCP 是内置的可选编辑器桥接能力；`init.cmd` 会自动运行 `python scripts/setup_ai_mcp.py --apply-project`，为 OpenCode、Claude Code 和 Codex 生成当前机器的项目级 MCP 配置。缺少内置 npm 包时，确认联网后运行 `python scripts/setup_godot_mcp.py --provider coding-solo --install-coding-solo --yes` 安装到项目内 `tools/godot-mcp-node/`。用户级全局注册必须显式执行 `python scripts/setup_ai_mcp.py --client codex --apply-user` 或 `python scripts/setup_ai_mcp.py --client claude --apply-user`。
- 离线依赖和首启流程见 `docs/TOOLCHAIN.md`。

更多细节见 `START_HERE.md`、`docs/AI_WORKFLOW.md` 和 `docs/GAME_DESIGN_GUIDE.md`。
