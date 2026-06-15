---
name: godot-ui
description: 当用户要设计或实现 Godot 4 UI/HUD/菜单/弹窗/设置界面、Control 节点层级、Theme、响应式布局、键盘/手柄焦点或 UI 动画时使用。用于补足 Godot 原生 UI 架构和实现规范；若输入是 PSD/PNG/JPG UI 源图或要提取 sprite/layout，先用 ui-studio。
---

# Godot UI

本 skill 改造自 `https://github.com/zate/cc-godot` 的 `godot-ui`，仅保留对本脚手架有用的 Godot Control、Theme、布局和 UI 模式知识；不继承其 Claude 插件、slash command、外部 MCP 路径或通用项目初始化假设。

## 使用边界

- 需要设计 UI 节点层级、HUD、菜单、暂停页、设置页、弹窗、对话框、背包格子、响应式布局、焦点导航、UI 动画时使用本 skill。
- 有 PSD/PNG/JPG UI 源图、sprite sheet、Figma/PSD 转换或布局提取需求时，先使用 `ui-studio`。
- 需要生成 UI 图标、按钮、面板素材时，先用 `asset-prompt-spec` 和 `aistudio-media-generation`，必要时再用 `ui-studio` 提取，最终落到 `assets/ui/`。
- 正式首版 UI 素材必须登记到 `docs/project/art/asset-manifest.json`；如果 UI 仍是 ColorRect/Label/程序化绘制，必须标记为 `placeholder` 或 `procedural`，不能作为 UI 美术完成。
- 只是改玩法状态、数值或结算文案时，不单独启用本 skill；继续用 `vibe-iteration`。

## 脚手架约束

- 默认分工：稳定、编辑器可见的 UI 骨架维护在 `.tscn` 或独立 UI 场景中；动态状态刷新、按钮回调、Tween 和反馈动画留在 `src/ui/Hud.gd` 或对应 UI 脚本。
- 首选修改 `src/ui/Hud.gd` 和已有 UI 骨架；只在需要稳定菜单/弹窗/复用组件时新增 `src/ui/*.gd` 或 `scenes/ui/*.tscn`。
- 不为首版默认引入复杂 UIManager、ThemeManager、InputManager 单例；只有出现 3 个以上可切换界面或明确复用需求时再考虑。
- 不为临时数值或一次性文案修改 `.tscn`；如果需要让 Godot 编辑器用户理解 HUD/菜单结构，或 UI 节点结构已明显超出代码创建的可维护范围，应维护 `.tscn` 或新增小型 UI 场景并说明原因。
- UI 运行时素材必须在 `assets/ui/` 或 `assets/generated/` 下登记/加载，不能直接依赖 `references/` 或 UI Studio 临时目录。
- UI 文案服务玩家目标、状态、反馈和决策，不解释工程结构。
- 影响 UI、素材或体验后，按项目规则运行对应 review，至少包含 `python scripts/art_pipeline_review.py` 和 `python scripts/experience_design_review.py`；完整交付前运行 `python scripts/ai_review.py --strict`。

## Control 设计原则

- 用 `CanvasLayer` 管理 UI 渲染层级，HUD 常用 `layer = 10`，暂停/弹窗可用更高层级。
- 用容器管理布局：`MarginContainer` 控边距，`VBoxContainer`/`HBoxContainer` 控排列，`GridContainer` 控可重排状态块，`CenterContainer` 控居中，`PanelContainer` 控面板背景。
- 优先使用 anchor preset 和 size flags，而不是硬编码绝对坐标。
- 需要响应不同分辨率时，把根 `Control` 设为 full rect，再通过容器、最小尺寸和伸缩标记控制排版。
- 交互控件要考虑 `focus_mode`、`grab_focus()` 和 `ui_accept`/`ui_cancel`，不能只支持鼠标。
- HUD 不要挡住核心玩法区域；按钮和状态条保持少量高信息密度，避免首版 UI 系统膨胀。顶部信息要能在窄屏重排或压缩，中心大提示只用于启动、暂停、结算或决策，实时玩法中应隐藏或降级到底部/角落提示。

## 常用节点

- 布局：`MarginContainer`、`VBoxContainer`、`HBoxContainer`、`GridContainer`、`CenterContainer`、`PanelContainer`、`ScrollContainer`。
- 交互：`Button`、`TextureButton`、`CheckBox`、`OptionButton`、`HSlider`、`ProgressBar`、`ItemList`。
- 展示：`Label`、`RichTextLabel`、`TextureRect`、`NinePatchRect`、`ColorRect`。
- 弹窗：`PopupPanel`、`AcceptDialog` 或自定义 `CanvasLayer + ColorRect + PanelContainer`。

## HUD 推荐层级

```text
CanvasLayer
└── Root Control (full rect, mouse ignore for passive HUD)
    └── MarginContainer (full rect, screen margins)
        └── VBoxContainer
            ├── GridContainer or HBoxContainer (top bar, compact screens can reflow)
            │   ├── TextureRect / Label (objective)
            │   ├── Label / ProgressBar (core status)
            │   ├── Control (horizontal spacer, expand)
            │   └── Label / TextureRect (timer, score, unit info)
            ├── Control (vertical spacer, expand)
            ├── CenterContainer or PanelContainer (message/result)
            ├── Control (vertical spacer, expand)
            └── HBoxContainer (bottom hints, optional buttons)
```

首版 HUD 必须回答 4 件事：

- 当前目标是什么。
- 玩家状态是否安全或危险。
- 进度/分数/资源如何变化。
- 失败、胜利或重开入口在哪里。

## 首版 UI 最低交付标准

如果本轮目标涉及正式游戏首版，UI 必须覆盖当前游戏类型所需的关键玩家信息，而不是固定套用某一种 HUD 模板：

- 入口：玩家知道如何开始、继续、重开或返回。
- 当前状态：玩家能看懂自己的关键状态，例如生命、机会、资源、位置、回合、时间、任务阶段或叙事进度。
- 当前目标：玩家知道现在要做什么。
- 决策界面：如果玩法包含升级、选择、购买、装备、对话或关卡选择，该界面必须像明确可交互的决策界面。
- 阶段反馈：一轮、一区域或一段挑战结束后，玩家知道结果、表现和下一步。

具体 UI 形态按游戏类型选择，不强制所有游戏都有血条、经验条、升级三选一或传统结算页。包含升级/奖励选择的游戏，升级或奖励界面必须具备清晰的卡片、按钮或选项边界，不能只是普通说明文字。

ColorRect、Label 和代码绘制面板可以作为临时结构，但真实首版未声明程序化占位时，必须至少有 HUD 图标、按钮、面板、进度条或状态徽章等 `assets/ui/` 运行时素材证据，并在 `docs/project/art/asset-manifest.json` 中登记 source、runtime_path、runtime_bound 和 screenshot_visible。

编辑器可见性也是脚手架体验的一部分：空模板和正式首版都应在主场景中保留可读的 HUD/菜单骨架和占位文案，让用户打开 Godot 编辑器时能理解 UI 层级；脚本只负责把占位文案刷新为真实运行状态。

防遮挡是 HUD 的默认验收项：不要把超过 360px 的固定最小宽度作为中心面板唯一策略；使用 viewport 宽度比例或运行时 `size_changed` 调整面板、字号和顶栏列数。真实玩法开始后，中心大提示如果不是决策/结算界面，应隐藏或转为底部短提示。

## 菜单和弹窗推荐层级

```text
CanvasLayer
├── ColorRect (full rect, translucent overlay, mouse_filter STOP)
└── CenterContainer (full rect)
    └── PanelContainer
        └── MarginContainer
            └── VBoxContainer
                ├── Label (title)
                ├── Button / OptionButton / Slider rows
                └── HBoxContainer (confirm / cancel)
```

暂停菜单最小按钮集：继续、重新开始、返回标题或退出。设置菜单首版只做真正影响试玩的 1-3 个选项，例如音量、摇屏强度、难度提示，不要默认铺满图形设置。

## Theme 和风格

- 有多处复用 UI 时创建 `.tres` Theme；只有单个 HUD 小改动时可在脚本里少量 `add_theme_*_override`。
- 面板优先用 `StyleBoxFlat` 或 `NinePatchRect`；有正式 UI 素材时优先加载 `assets/ui/` 纹理。
- 颜色至少区分：普通文本、强调文本、危险、成功、背景遮罩、按钮 hover/pressed。
- 小屏可读性优先：正文不低于 14-16px 等效字号，交互目标不小于约 40px。

## 脚本模式

信号连接保持直接，避免为了一个按钮引入管理器。

```gdscript
extends CanvasLayer

@onready var restart_button: Button = %RestartButton
@onready var title_label: Label = %TitleLabel

func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.grab_focus()

func show_result(title: String) -> void:
	title_label.text = title
	modulate.a = 0.0
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
```

## 焦点和输入

- 菜单打开时给第一个主按钮 `grab_focus()`。
- 支持 `ui_cancel` 关闭可关闭菜单，支持 `ui_accept` 触发当前焦点按钮。
- 多列或网格 UI 需要显式设置焦点邻居，避免手柄导航卡住。
- 弹窗打开时遮罩 `mouse_filter = Control.MOUSE_FILTER_STOP`，防止点击穿透。

## 动画和反馈

- 首版优先使用淡入、缩放弹出、按钮轻微 bounce、进度条平滑 tween。
- 动画时长控制在 0.12-0.35 秒，避免拖慢重开和核心操作。
- 重要状态变化同步反馈：文本变化、颜色变化、音效或浮字至少一种。

## 响应式检查

每次新增较大 UI 后，至少人工或自动确认：

- 16:9 桌面尺寸下不遮挡核心玩法。
- 窄屏或浏览器缩放下关键按钮仍可见，顶部目标/状态/提示不溢出。
- 中心提示面板宽度受 viewport 约束，390px 宽截图下不能越界。
- 字号和图标可读。
- 鼠标、键盘 `ui_accept/ui_cancel` 均能操作关键路径。
- Web 导出后无字体、纹理或主题资源加载错误。

## 与其他 skill 协作

- `vibe-iteration`：负责玩法和 HUD 接入，本 skill 只补 UI 结构/风格/交互细节。
- `godot-medium-game-scaffold`：当 UI 属于中小型游戏首版的多个内容单元、进度、结算或菜单闭环时配合使用。
- `ui-studio`：处理 UI 源图提取和 layout 参考。
- `godot-sprite-pipeline`：处理 UI sprite 切分、导入、登记。
- `godot-game-feel-tuning`：处理 UI 反馈弱、按钮没感觉、结算不爽等体验微调。
