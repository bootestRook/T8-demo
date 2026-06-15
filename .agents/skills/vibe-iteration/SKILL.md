---
name: vibe-iteration
description: 当用户说继续做、下一轮、做首版、优化体验、变好玩、按反馈改、修问题、打磨首版、最终效果时使用。用于在 Godot AI 游戏脚手架中把模糊需求转成一轮可试玩改动，并持续更新 PM 状态和导出验证。
---

# Vibe Iteration

## 目标

把用户的自然语言反馈转成一轮小而完整的首版改动。每轮都要让项目更接近像样的可交付游戏，而不是只证明技术链路能跑。

## 开始前读取

优先读取：

- 当前 PM 需求信息：`python .agents/skills/pm-agile/scripts/pm_cli.py status` / `info <ID>`
- `docs/game-concept.md`
- `docs/AI_WORKFLOW.md`
- `docs/QUALITY_BAR.md`
- 中度/混合玩法时读取 `docs/GAME_DESIGN_GUIDE.md`
- `src/game/PrototypeState.gd`
- `scenes/Game.gd`
- `src/ui/Hud.gd`

如果涉及素材，再读取：

- `assets/README.md`
- `docs/TOOLCHAIN.md`

## 决策流程

1. 判断当前模式：做首版、修问题、试玩反馈、打磨交付；只有用户明确要求“只做技术验证”时才降级为最小链路验证。
2. 如果目标足够明确，直接实现；如果不明确，最多问 3 个问题。
3. 每轮聚焦最高收益改动；涉及系统级问题时先拆清职责边界，再分步落地。
4. 默认推进完整首版：核心循环、必要系统、至少 3 个有差异内容单元或系统阶段、阶段变化、结算、进度和运行时素材/UI 闭环。
5. 中度/混合玩法可以推进多个必要蓝图；同轮涉及多个大系统时必须写清系统关系、数据边界、UI/素材需求和验收标准。
6. 如果需求会改变玩家看到的角色、敌人、目标、场景、UI、反馈、奖励或动画，自动追加素材包闭环：`art-spec -> asset-pack -> sprite-process -> runtime-bind -> visual-proof`。只改代码但画面仍是占位时，不能宣称正式首版完成。
7. 如果反馈涉及“太简单、没 UI、画面粗糙、不像成品、和概念图差太多”，本轮至少补一项统一视觉资产闭环：没有 PSD/UI 图源时先生成 UI sheet、HUD 图标、按钮或面板，放入 `assets/ui/` 并接入运行时；角色、怪物、场景和 VFX 必须服从同一风格规范。
8. 真实首版素材必须更新 `docs/project/art/asset-manifest.json`，记录 source、prompt/provider、源图、运行时路径、是否透明、是否接入和截图是否可见。`procedural`、`placeholder`、`debug` 只能作为临时状态。
9. 影响 Godot 运行时的改动后，GodotMCP 可用时先执行 `run_project -> get_debug_output -> stop_project` 快速诊断；不可用时继续后续命令行 gate。
10. 改完运行 `python scripts/gameplay_logic_review.py`、`python scripts/art_pipeline_review.py`、`python scripts/experience_design_review.py`、`python scripts/godot_headless_check.py` 和 `python scripts/godot_runtime_log_check.py`。
11. 再运行 `python scripts/export_web.py --json`。
12. 影响玩法、UI、素材或导出时运行 `python scripts/experience_check.py --strict`。
13. 进入人工成果验收前运行 `python scripts/ai_review.py --strict`，FAIL/CONCERNS 不交付人工验收。
14. 更新 PM workspace 的 `notes.md` 和任务状态；稳定结论沉淀到 `docs/game-concept.md` 或相关 docs。
15. 不自动创建 Git 提交；用户明确要求存档点时再运行 `python scripts/git_ai.py checkpoint`。
16. 启动或复用试玩预览：OpenCode 工具可用时执行 `game_preview_game`；否则执行 `python scripts/run_web_preview.py --open --json` 并回报地址。

## 视觉/体验反馈转向规则

如果用户反馈包含以下任一类型，不得直接按普通代码小修处理：

- 看不到角色、怪物、菜单、按钮、HUD。
- UI 丑、UI 和概念图差太多、基本没有 UI。
- 不好玩、没反馈、没感觉、不像游戏。
- 画面像占位、看不懂目标、看不懂怎么开始。

必须先执行：

1. 使用 `godot-runtime-preview-check` 或 `python scripts/experience_check.py --strict` 获取当前运行画面和截图证据。
2. UI 问题启用 `godot-ui`，按当前游戏类型补入口、状态、目标、决策和阶段反馈。
3. 素材问题启用 `asset-prompt-spec`，必要时启用 `aistudio-media-generation` 或 `godot-sprite-pipeline`；如果问题是风格割裂，先补 `docs/project/art/style-guide.md`，再生成同源运行时素材包。
4. 手感问题启用 `godot-game-feel-tuning`。
5. 改后更新 `docs/project/art/asset-manifest.json`，再次运行截图检查和 `python scripts/visual_readability_review.py --strict`，用玩家视角确认是否能看清角色、威胁/目标、菜单、当前目标和下一步。
6. 用户明确表示“不满意”时，自动检查 PASS 只能作为技术证据；PM 需求必须回到 doing，人工验收记录为 FAIL。

## 文件优先级

- 规则和数值：`src/game/PrototypeState.gd`
- 场景表现：`scenes/Game.gd`
- HUD 文案：`src/ui/Hud.gd`
- 输入：`src/game/Player.gd`
- 场景配置：`scenes/Game.tscn`（尽量不改）

## 输出格式

```markdown
完成了：...
试玩方式：已打开试玩预览 / 本地地址：...
验证：python scripts/export_web.py 通过
PM 记录：已更新 / 未更新，原因是 ...
下一步建议：...
```

## 约束

- 新增复杂框架、状态系统、多场景、账号、联网、编辑器、背包或经济时，必须说明玩家价值、职责边界、数据归属、UI/素材需求和验证命令。
- 不从 `references/` 直接加载运行时素材。
- 不修改 `.tscn` 文件（除非绝对必要，且改后验证导出）。
- 面向新手解释"改了哪里、为什么、怎么试玩、怎么回档"。
- 若 `docs/game-concept.md` 仍是"待确认"且本轮目标已明确，先由 AI 自动补写关键信息，不要求用户手动同步文档。
- 默认让用户在浏览器里试玩、在 OpenCode 里反馈；不要要求用户理解导出流程或手动输入命令。
