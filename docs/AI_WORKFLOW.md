# AI 工作流

## 目标

让 AI 从自然语言开始，稳定完成 Godot 2D 游戏的玩法、美术、素材、开发、测试、自动审查、反馈、迭代和 Web 部署。人工默认只参与需求输入、危险操作确认和最终成果验收。

## 1. 初始化

用户输入 `init` 后，AI 必须：

- 默认只读取 `AGENTS.md`、`docs/project-map.md`、`docs/game-concept.md`、`template.json`；其他文档按需读取。
- Windows 首启如果 `tools/` 中的 portable 依赖尚未解包，AI 先运行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-cn.ps1 -InitPm -AutoInstallMissing`，或让用户双击 `init.cmd`。
- 首启流程会运行 `python scripts/setup_ai_mcp.py --apply-project`，为 OpenCode、Claude Code 和 Codex 写入项目级 GodotMCP 配置；用户级全局配置只在用户明确要求时执行。
- 再运行 `python scripts/check_env.py --json --fast`；完整检查留到 `ai_review.py` 或导出前执行。
- 确认玩法方向、目标层级和平台。
- 让用户选择 2-3 个适合玩法的美术方向。
- 使用 `asset-prompt-spec` 写 prompt，再用 `scripts/generate_style_candidates.py` 生成 3 张风格候选图，默认 provider 为 `gpt-image-2`。
- 用户选定风格后，把玩法、平台、目标层级、首版内容单元目标、选中候选图、风格规则和系统边界固化到 `docs/game-concept.md`。
- 开始全新游戏时，先用 `scripts/new_game_concept.py` 生成新的概念ID，并把上一版设定归档到 `docs/concepts/`，避免不同游戏互相污染。
- 使用 `docs/GAME_DESIGN_GUIDE.md` 生成完整首版计划，并同步列出首版美术素材落地计划。
- 中度或混合玩法从 `docs/GAME_DESIGN_GUIDE.md` 选择激活蓝图，并写入 `docs/game-concept.md`。
- 使用 `.agents/skills/pm-agile` 创建或接续需求。

## 1.1 上下文接力

长流程不能依赖聊天上下文保存约定。AI 在新会话、跨线程继续、自动压缩前后或长任务暂停恢复时，必须按下面顺序恢复状态：

1. 运行 PM 状态检查，定位当前 doing / blocked / review 需求。
2. 对具体需求运行 `pm_cli.py info <ID>`，读取 `summary.read_first`。
3. 读取 `AGENTS.md`、`docs/project-map.md`、`summary.read_first` 列出的文件和当前需求 workspace 的 `notes.md`。
4. 如果发现稳定结论只存在于 `.pm/` 或聊天记录中，先同步到 `docs/project/`、脚手架文档或项目地图，再继续执行。

当会话内容过大、即将压缩、需要换线程或暂停时，使用 `pm handoff save` 保存当前任务、下一步、阻塞、关键产物和必须先读文件；恢复时使用 `pm handoff resume`。不要把压缩摘要当作唯一事实源。

`docs/project-map.md` 由 `python scripts/generate_project_map.py` 生成。新增稳定目录、核心脚本或长期文档后，先更新脚本，再重生成项目地图。

## 2. 玩法确认

优先让用户从这些方向选择：

- 躲避生存
- 点击收集
- 拖拽合成
- 弹射射击
- 平台跳跃
- 复刻参考
- AI 给 3 个建议

首版基础闭环保留一个核心操作、一个主要反馈、一个结束条件和一个重开方式，用来验证链路。真实游戏默认继续推进到完整首版：围绕用户创意实现核心循环、必要系统、至少 3 个精细关卡、章节、波次、挑战或系统阶段；内容差异可以来自布局、节奏、敌人/目标组合、数值、奖励、阶段压力、系统组合或失败压力。

## 3. 美术确认

AI 必须先确认美术策略，并在首启阶段生成风格候选：

- AI 风格候选：用 `asset-prompt-spec` 写规格，再用 `scripts/generate_style_candidates.py` 生成 3 张候选图，默认 provider `gpt-image-2`。
- 运行时素材落地：用户选中候选图后，按 `docs/ART_PIPELINE.md` 的最低覆盖标准接入当前主题素材；如果暂时程序化占位，`docs/game-concept.md` 必须写入 `素材落地状态：程序化占位`。
- 参考图和 UI 处理：主体/背景分层用 `ui-layer-split`；UI PNG/JPG/PSD 的 sprite/layout 提取用 `ui-studio`。
- 占位图形：只作为媒体 API 不可用或用户明确选择跳过美术时的兜底方案，必须在 `docs/game-concept.md` 标明未锁定最终美术。
- 统一视觉包：概念图只作为风格锚点；锁定风格后必须生成或整理玩家、威胁/目标、场景、HUD/UI 和核心 VFX 的同源运行时素材包。HUD 不能由纯色块临时凑，角色/怪物不能从概念图随意裁剪；需要提取时必须走 `ui-layer-split` 或 `ui-studio`，最终产物进入 `assets/`。

首启阶段只生成风格板、关键画面或少量种子素材；风格候选必须由用户选择后才进入首版开发。首版开发阶段要围绕当前玩法生成同源运行时素材包，而不是让 HUD、角色、怪物和场景各自临时生成。
风格候选图不是运行时素材；只登记候选图路径但画面仍是纯程序化图形时，review 应标记 `CONCERNS`。

## 4. 首版内容与美术计划

首版计划必须把玩法内容和美术内容放在同一张清单里：

- 内容单元：默认做至少 3 个精细内容单元或系统阶段；第 1 个内容单元可先完成基础闭环，但不能作为真实游戏交付。
- 关卡/章节差异：每个内容单元写清空间、节奏、敌人/目标、奖励、失败压力或教学目的的差异。
- 素材规格：按玩法和系统列出最高收益素材，写清用途、尺寸、透明背景、帧数、落地路径和是否需要切图；同一轮素材必须遵循统一视觉规范。
- 素材包闭环：需求只要改变玩家看到的角色、敌人、目标、场景、UI、反馈或奖励，自动追加 `art-spec -> asset-pack -> sprite-process -> runtime-bind -> visual-proof`。
- 运行时接入：正式素材必须进入 `assets/`，由 `AssetRegistry.gd` 或运行时代码真实加载；`references/` 和 `style_candidates/` 不能直接当成已接入素材。
- 素材来源清单：正式首版必须维护 `docs/project/art/asset-manifest.json`，记录 source、prompt、provider、源图、运行时路径、透明背景、接入状态和截图可见性；程序化、占位和调试图形不能计入正式素材完成。
- UI 内容：真实游戏首版必须规划并接入 HUD 图标、按钮、面板、进度条或状态徽章之一；用户没有 PSD/UI 设计稿时，AI 先生成 UI sheet 或独立 UI sprite，再走 `assets/ui/` 和 HUD 接入，不得用“没有 UI 源图”作为跳过理由。
- HUD 布局：顶部目标/状态/提示必须支持窄屏重排或长文本压缩；中心大提示只用于启动、暂停、结算或决策，实时玩法中必须隐藏、降级或改为小型提示，避免遮挡核心操作区。
- 动画帧：动作、射击、生存、平台、跑酷、搜打撤等动态品类必须规划关键角色动画，先用 `godot-sprite-pipeline` 处理 spritesheet/动画条，再接入 Godot。

## 5. 开发

默认优先改：

- `src/game/PrototypeState.gd`
- `scenes/Game.gd`
- `src/ui/Hud.gd`

需要游戏能力时按职责启用：

- `src/game/GameEvents.gd`
- `src/game/AchievementStore.gd`
- `src/game/ContentUnits.gd`
- `src/game/ProgressStore.gd`
- `src/game/AudioDirector.gd`
- `src/game/FeedbackDirector.gd`
- `src/game/AssetRegistry.gd`

### 多 Agent 分派

当任务适合并行时，使用 `docs/MULTI_AGENT_WORKFLOW.md` 的主从协作模式：

- 主 AI 先拆任务并创建子 Agent 任务包。
- 子 Agent 只处理任务包声明的目标和允许路径。
- 主 AI 是唯一 PM 状态写入者和最终合并者。
- 子 Agent 结果必须包含触达文件、验证结果和风险说明。
- 主 AI 合并前可运行 `python scripts/agent_task.py check --manifest <manifest.json>` 和 `python scripts/agent_merge.py check --manifest <manifest.json> --patch <changes.patch>`。
- 合并后仍按本工作流运行 Godot、Web 和 AI review gate。

### Skill 和规范边界

- Skill 只负责可复用流程、脚本、工具调用和检查步骤。
- 当前游戏事实、玩法规则、系统边界、美术风格、UI 约束和示例索引必须沉淀到 `docs/project/`、脚手架流程文档或 `docs/project-map.md`。
- Skill 执行过程中产生的稳定结论，验收前必须同步到对应长期文档；不能只留在 Skill 输出、聊天记录或 `.pm/` 临时记录里。
- 用户给出的实现指令如果和 `AGENTS.md`、项目地图或长期文档冲突，AI 必须先说明冲突并给出更稳妥路径；如果用户坚持，仍要记录风险和验收影响。

## 6. 测试

影响 Godot 运行时的改动（例如 `*.gd`、`.tscn`、Autoload、资源路径、输入、场景切换、UI/HUD 接入）后，这一步是必做项；如果当前 AI 客户端已接入 GodotMCP，AI 应先执行一轮快速诊断：

```text
run_project -> get_debug_output -> stop_project
```

这一步用于尽早发现 GDScript 运行后才暴露的问题，例如空引用、无效调用、信号参数不匹配、资源路径错误和场景实例化失败。GodotMCP 不可用时不阻塞普通开发，但必须继续执行命令行检查。GodotMCP debug output 出现错误时，AI 需要先修复；若需补充可复现证据，再运行 `python scripts/godot_runtime_log_check.py --json`。

每轮改动后至少运行：

```bash
python scripts/export_web.py --json
```

质量工具门禁默认只强制 GDScript Toolkit。每轮改动后运行统一入口：

```bash
python scripts/godot_quality_tools.py --json
```

这个入口默认覆盖：

- GDScript Toolkit：用 `gdlint` 和 `gdformat --check` 检查 `src/`、`scenes/` 下的 GDScript；不自动改格式。
- GDUnit4：可选，传入 `--run-gdunit` 时通过 `addons/gdUnit4/bin/GdUnitCmdTool.gd` 运行 `tests/gdunit/` 或 `test/`。

缺少 GDScript Toolkit 时结果必须是 `FAIL`。GDUnit4 缺失默认不阻断。可用 `python scripts/setup_quality_tools.py` 检查准备状态；联网安装或下载 addon 前必须先获得确认。

影响玩法、UI、素材、导出时继续运行：

```bash
python scripts/experience_check.py --strict
```

`experience_check.py` 是 Web 自动试玩：它会导出 Web、启动预览，并用浏览器自动化打开页面、检查控制台/canvas/像素健康，验证点击 canvas 能开始、方向键/WASD 输入不报错，并执行一段通用输入链路探针。默认 `--browser-backend auto` 优先使用 Playwright Python，失败后回退 `agent-browser`；也可显式传 `--browser-backend playwright`、`agent-browser` 或 `none`。浏览器自动化不可用时，体验检查会标记为 `CONCERNS`，需要说明自动试玩层不可用。
体验检查会把首屏、运行中、输入探针和移动端截图保存到 `reports/screenshots/`，并在 JSON 输出中列出路径。视觉/体验反馈修复不能只依赖像素 diff，必须查看这些截图。

`godot_native_screenshot_check.py` 直接运行 Godot 主场景并由 Godot 自己保存 viewport 截图，用于日常开发快速确认原生运行、截图链路和基础像素健康，不依赖浏览器、窗口焦点或系统截图。它不替代 Web 检查；在 `ai_review.py` 中仅当 Web 体验检查没有产出截图时作为 fallback，避免无条件增加一次 Godot GUI 启动。

本地快速迭代需要保留 `CONCERNS` 为 0 时，可临时运行：

```bash
python scripts/experience_check.py
```

如果刚执行过 `export_web.py`，可复用已有 html5 产物，避免重复导出：

```bash
python scripts/experience_check.py --skip-export
```

涉及 UI、角色/敌人可见性、画面风格或“看不见/看不懂/不像游戏”的反馈时，继续运行：

```bash
python scripts/visual_readability_review.py --strict
```

该脚本只检查截图证据、基础像素健康、运行时视觉素材角色覆盖、HUD 响应式布局风险和 UI 占位风险，不判断主观美丑。

## 7. AI 自动 Review

每轮改动后，AI 必须先自审，不把未通过的结果交给人工验收：

```bash
python scripts/ai_review.py --strict
```

本地快速迭代需要保留 `CONCERNS` 为 0 时，可临时运行：

```bash
python scripts/ai_review.py
```

`ai_review.py` 覆盖：

- PM 状态一致性。
- Python 脚本语法。
- 文档中的 skill 路由和脚本命令是否存在。
- `docs/project-map.md` 是否可由 `scripts/generate_project_map.py` 重生成，并作为新会话接力入口。
- 多 Agent 工作流、角色模板、任务包模板和轻量检查脚本是否存在。
- 运行时模板文案和 `references/` 误加载。
- `art_pipeline_review.py` 美术管线审查：provider、media_api 命令、风格候选到运行时素材落地。
- 真实游戏未声明程序化占位时，`art_pipeline_review.py` 会检查玩家、威胁/目标、UI/HUD sprite 覆盖和 `docs/project/art/asset-manifest.json` 来源清单；已有运行时素材但缺少 UI 引用，或素材清单仍含程序化/占位/调试素材时视为阻断项。
- `gameplay_logic_review.py` 玩法语义审查：胜负、边界、输入、数值、重开、概念隔离。
- `experience_design_review.py` 体验结构审查：完整首版内容单元、差异、阶段变化、动画证据、决策压力和结算反馈。
- `visual_readability_review.py` 视觉可读性审查：检查 `reports/screenshots/` 中的首屏/运行中截图、基础像素健康、玩家/威胁或目标/UI 素材证据、HUD 固定宽度/不可重排/缺少玩法降级等响应式风险，以及是否把程序化占位误当正式首版素材。
- `architecture_review.py` 架构边界审查：模块清单、层级越界、HUD 写规则、`Game.gd` 膨胀和运行时参考资源边界。
- `godot_quality_tools.py` 质量门禁：默认 GDScript Toolkit，GDUnit4 可选。
- `godot_headless_check.py` 场景加载审查：GDScript parse/load/runtime 启动错误。
- `godot_runtime_log_check.py` 正常运行日志审查：模拟编辑器/F5 运行后的项目进程，捕获脚本错误、无效调用、资源加载失败和崩溃返回码。
- `godot_native_screenshot_check.py` 原生运行截图审查：不经浏览器直接运行 Godot，并保存首屏、运行中和输入后的 viewport 截图；默认只作诊断/fallback，不替代 Web 浏览器截图。
- 模板导出 dry-run 是否混入过程目录，并确认导出包会生成空 Git 仓库。
- Godot 环境、Web 导出和体验检查。

如果本机没有 Godot 4 或 Export Templates，AI 要把这标记为环境阻塞，而不是让用户做过程 review。

## 8. 人工成果验收

人工只看最终成果：

- 浏览器试玩地址或部署 zip。
- 当前玩法目标是否达成。
- 首版内容单元、系统阶段或挑战是否有可感知差异。
- 美术/手感/内容是否满意。
- 是否接受本轮成果并允许归档。

人工不需要逐项确认中间任务、代码 diff、导出 dry-run 或自动化日志；这些由 AI review 负责。

## 9. 反馈

试玩反馈分类：

- Blocking bug：白屏、报错、卡死、无法操作。
- Clarity：目标、规则、提示不清楚。
- Feel：手感、节奏、反馈弱。
- Content：画面、素材、关卡少、缺动画、内容单元差异不足。
- Scope：新增系统、平台能力、账号联网、排行榜、编辑器或内容规模变化。

每轮只处理最影响体验的 1-3 个问题。
当反馈属于 Clarity、Feel 或 Content 且涉及可见性、UI、角色、敌人、场景、风格偏差时，用户反馈优先级高于自动门禁 PASS；AI 必须先截图复核，再选择 `godot-ui`、`asset-prompt-spec`、`aistudio-media-generation`、`godot-sprite-pipeline` 或 `godot-game-feel-tuning`。
如果用户明确说“不满意、不好玩、像占位、UI 差、没素材、没动画、看不懂”，PM 状态必须从 review 拉回 doing，并把人工验收按 FAIL 记录。自动 `ai_review.py PASS` 只能作为技术证据，不能覆盖人工反馈。

## 10. 部署

Web 导出和打包：

```bash
python scripts/export_web.py --json
python scripts/godot_headless_check.py
python scripts/godot_runtime_log_check.py
python scripts/run_web_preview.py --open --json
python scripts/package_dist.py --json
```

产物在 `exports/`，zip 内 `index.html` 位于根目录。

导出脚手架模板前先 dry-run：

```bash
python scripts/export_template.py --dry-run
```

离线依赖和 portable 工具说明见 `docs/TOOLCHAIN.md`。
