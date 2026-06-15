---
name: project-init
description: 当用户在 OpenCode、Codex、Claude Code 对话框输入 init、初始化、第一次使用、开始做游戏、启动项目、不知道怎么开始、帮我装好环境时必须使用。作为 Godot 4 AI 游戏脚手架首启总控，负责项目理解、环境检查、PM 工作流初始化、玩法确认、美术风格候选生成和首版游戏目标固化。
---

# Project Init (Godot 4)

## 目标

帮助没有代码能力的新手完成第一次项目启动、环境准备、玩法定位、美术方向选择、风格候选图生成和首版游戏目标固化。用户只需要输入 `init`，AI 负责读项目、跑检查、初始化 PM 工作流，并用选择题把项目从“想法”推进到“可执行的中小型 2D 游戏首版计划”。

默认 `init` 不直接实现玩法代码；但会保存用户原始设定、生成 AI 提炼稿、让用户确认首版范围、生成或准备美术风格候选图，并在用户确认后更新 `docs/game-concept.md` 和 `docs/project/`。只有用户明确说“开始做首版”或“直接实现”时，AI 才进入开发阶段。真实游戏默认目标是完整首版。

## 首入口定位

- AI 工具对话框是主入口：用户输入 `init` 后，本 skill 作为首启总控接管。
- `init.cmd` 是 Windows 兜底入口：仅在 AI 工具无法执行命令、portable 工具需要解包、或用户还没有打开 AI 工具时使用。
- 对用户使用“游戏项目”“首版”“风格候选”“试玩”“存档点”“运行游戏需要的工具包”等表达，少用 `Python`、`Godot`、`Git`、`export` 等技术词。

## 工作流

1. 快速读取最小上下文：
   - `AGENTS.md`
   - `docs/game-concept.md`
   - `docs/project/game-concept.md`（如果存在）
   - `template.json`
2. 按需延迟读取文档，不在 init 热路径一次性展开：
   - 玩法不清楚，或用户提出肉鸽、搜打撤、塔防、经营、RTS、自走棋、养成、背包、暗黑、跑酷、LD 或混合玩法时，读 `docs/GAME_DESIGN_GUIDE.md`。
   - 需要机器可读蓝图 ID 和 review 规则时读 `spec/gameplay_blueprints.json`。
   - 美术候选生成前读 `docs/ART_PIPELINE.md`。
   - 环境失败时读 `docs/TOOLCHAIN.md`。
   - 用户要求完整流程说明时读 `START_HERE.md` 和 `docs/AI_WORKFLOW.md`。
   - 复刻参考时先读取用户提供的 `references/` 文件和 `spec/spec.json`；如果目录为空，按用户描述拆解。
   - 开始写代码后才读 `src/game/PrototypeState.gd`、`scenes/Game.gd`、`src/ui/Hud.gd`。
3. 先做快速环境检测并记录结果：
   - 执行 `python scripts/check_env.py --json --fast`。
   - 执行 `python scripts/setup_ai_mcp.py --apply-project`，写入项目级 GodotMCP 配置；不自动执行用户级 `codex mcp add` 或 `claude mcp add`。
   - 快速检查只确认 Python、Godot/Git 可执行入口和 Export Templates 标记，不启动 Godot/Git 子进程。
   - 如果是在 Windows 且 `tools/` 下存在 portable 工具压缩包，但 `tools/python/`、`tools/git/` 或 `tools/godot/` 尚未解包，AI 必须先运行：
     `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-cn.ps1 -InitPm -AutoInstallMissing`
     该脚本会自动写入项目级 AI MCP 配置；然后再执行环境检查。不要只提示用户设置 `GODOT4_PATH`。
   - 如果 `python` 不可用但 `tools/python-*-embed-*.zip` 存在，也先运行上述 bootstrap；不要直接结束 init。
   - 完整验证交给 `python scripts/ai_review.py --strict` 或导出前检查。
   - Python、Git、Godot 或 Export Templates 缺失时，优先提示用户运行 `init.cmd` 或把 portable 压缩包放到 `tools/`。
   - 不再引导 `installers/` 安装包链路。
   - Export Templates 缺失时，优先使用 `tools/Godot_v4.x-stable_export_templates.tpz`；仍缺失时才提示用户在 Godot 编辑器中安装。
4. 初始化 PM 工作流：
   - 执行 `python .agents/skills/pm-agile/scripts/pm_cli.py init-backlog`。
   - 不自动执行 `git commit`；需要存档点时必须由用户明确要求。
5. 用小白能理解的语言输出项目现状、已完成事项、缺失信息和下一步。
6. 接收玩法方向、平台和用户详细设定；如果用户已经描述清楚，先原样保存，再复述为可执行目标。目标层级默认是完整游戏首版，只有用户明确要求“只做技术验证/快速验证”时才降级。
   - 不要把中度创意压扁成简单类型；先识别主循环和 1-3 个系统蓝图。
7. 生成“首版设定确认稿”，把用户输入拆成概念设定、游戏系统设定和开发需求范围，并明确首版保留项、系统边界和待确认问题。用户可以反复讨论；未经用户确认，不得把摘要固化为事实源，也不得进入开发。
8. 询问美术方向；AI 必须给 2-3 个适合该玩法的风格方向，而不是只问“要什么风格”。
9. 用户选定或确认美术方向后，使用 `asset-prompt-spec` 生成风格候选规格，再使用 `scripts/generate_style_candidates.py` 生成 3 张风格候选图：
   - 默认 provider 固定为 `gpt-image-2`。
   - 候选图输出到 `assets/generated/style_candidates/`。
   - 默认尺寸用 `1536x1024` 横图；竖屏游戏可用 `1024x1536`。
   - 只生成风格板、关键画面或主视觉候选，不生成完整资产库。
   - 如果缺少 `MEDIA_API_KEY` 或媒体服务不可用，输出候选 prompt 和阻塞原因，等待用户补齐运行时凭证或选择“先用占位风格继续”。
10. 展示 3 张候选图的本地路径和简短差异，让用户选择 A/B/C 或要求重生成。
11. 用户确认首版设定和选择风格后，AI 使用 `scripts/new_game_concept.py` 创建新的概念ID，先把上一版 `docs/game-concept.md` 归档到 `docs/concepts/`，再固化玩法、目标层级、平台、美术风格、选中候选图路径、首版内容单元目标、玩法不变量、禁止污染项、首版交付范围和系统边界。
    - 同时写入 `docs/project/` 分层文档：`game-concept.md`、`gameplay/README.md`、`gameplay/content-units.md`、`gameplay/systems/`、`art/art-direction.md`、`ui/hud-spec.md`。
    - 用户原始长设定必须保存在 `docs/design-inputs/<concept-id>/source.md`；AI 提炼稿必须保存在 `docs/design-inputs/<concept-id>/extracted.md`。
    - 风格候选图只作为参考或种子，不等于运行时素材。
    - 风格锁定后必须沉淀 `docs/project/art/style-guide.md` 或等效风格规则；HUD、角色、怪物/目标、场景和 VFX 必须按同一视觉规范生成或整理。
    - 首版开发前必须生成或接入 1-3 个当前主题运行时素材，并在 `AssetRegistry.gd` 或运行时代码中真实加载；其中真实首版默认包含 HUD 图标、按钮、面板、进度条或状态徽章之一。
    - 没有 PSD/UI 设计稿时，AI 先生成 UI sheet 或独立 UI sprite，再放入 `assets/ui/` 接入 HUD；不得把“没有 UI 源图”作为跳过 UI 工作流的理由。
    - 不得把 JPG 概念图裁剪块、`style_candidates/` 候选图、`references/` 参考图或临时 workspace 文件直接接入运行时；需要提取时走 `ui-layer-split` 或 `ui-studio` 后落到 `assets/`。
    - 如果媒体服务不可用且用户选择先继续，必须把 `素材落地状态：程序化占位` 写入 `docs/game-concept.md`。
12. 结尾只给一个自然下一步：询问是否开始做完整首版。首版默认至少 3 个精细关卡、章节、波次、挑战或系统阶段。

## 设定保存与确认

如果用户提供详细设定、系统描述、技能列表、角色设定、世界观、参考游戏或长文本，AI 必须先保存原文，再提炼确认：

1. 生成或沿用概念ID。
2. 把用户原始输入原样保存到 `docs/design-inputs/<concept-id>/source.md`；同一概念多轮补充时保存为 `source-002.md`、`source-003.md`，不得覆盖旧原文：
   ```powershell
   python scripts/design_input.py --goal "一句话目标" --source-file "<原始设定文件>"
   ```
   如果原始输入只在对话中，AI 可以先把内容整理成临时文件再运行脚本；不要直接丢弃原文。
3. 输出首版设定确认稿，至少包含：
   - 概念设定：题材、幻想、目标体验、美术方向、参考。
   - 游戏系统设定：核心循环、操作反馈、胜负条件、启用系统、技能/敌人/道具/成长/经济等边界。
   - 首版内容：3 个内容单元和差异。
   - 系统边界：本版实现什么、分阶段实现什么、哪些能力需要独立模块或后续验收。
   - 开发需求：第一轮要实现的可试玩目标和验收标准。
4. 把 AI 提炼稿保存到 `docs/design-inputs/<concept-id>/extracted.md`。
5. 等用户明确确认。用户要求修改时，继续讨论并更新提炼稿；不要开始开发。
6. 用户确认后，再调用 `scripts/new_game_concept.py` 固化 `docs/game-concept.md` 和 `docs/project/`；脚本会把上一版 `docs/project/` 归档到 `docs/concepts/<timestamp>-project/`，避免旧系统文档污染新概念。

硬约束：

- 未经用户确认，不得把摘要覆盖为当前事实源。
- 不得把用户原始长设定压缩成几行后丢弃。
- 概念设定、游戏系统设定和开发需求必须分层保存：原始设定在 `docs/design-inputs/`，稳定系统规格在 `docs/project/`，开发过程在 `.pm/`。

## 启动表单

`init` 不要直接抛开放式问题。优先使用 AI 工具的 question 表单能力，让用户先选方向。

如果 question 工具可用，第一步提问：

```text
你想做哪类 2D 游戏？
```

推荐选项：

- `俯视动作`：玩家移动躲敌、碰撞得分、撑过倒计时。
- `平台跳跃`：玩家跳跃移动、到达终点或收集物品。
- `弹射射击`：玩家瞄准发射、击中目标得分。
- `躲避生存`：玩家移动躲开危险、坚持到计时结束。
- `拖拽合成`：玩家拖动物品合成更高级目标。
- `点击收集`：玩家点击/触摸目标、收集分数或连击。
- `复刻参考`：用户已有参考游戏或截图，先按参考拆首轮可玩目标。
- `中度混合玩法`：肉鸽、搜打撤、塔防、经营、RTS、自走棋、养成、背包、暗黑、跑酷或组合玩法，先拆主循环和系统蓝图。
- `还没想好`：AI 给 3 个最小可玩建议让用户选。

第二步最多再问 3 个问题：

- 平台：电脑鼠标键盘、手机触屏，还是都要？
- 目标层级：默认完整游戏首版；是否只做技术验证？
- 是否有参考：有截图/链接/游戏名，还是完全原创？

第三步必须确认美术方向。AI 根据玩法给 2-3 个具体方向，例如：

- `Q 版卡通`：适合躲避、收集、轻动作，读图快，反馈夸张。
- `像素街机`：适合平台跳跃、弹射射击、复古节奏。
- `手绘童话`：适合合成、探索、轻策略。
- `霓虹赛博`：适合动作、弹幕、节奏。
- `极简几何`：适合先验证规则，但仍要有明确色彩和视觉语言。

确认后必须进入风格候选生成，不直接跳到写代码。

## 风格候选生成

先使用 `asset-prompt-spec` 产出一份风格板素材规格，最少包含：

```markdown
## Asset Spec: style-candidates

- Role: 首版游戏美术风格候选
- Runtime path: `assets/generated/style_candidates/`
- Size: `1536x1024` 或 `1024x1536`
- Count: 3
- Style: 用户选定方向 + AI 补充的色彩、镜头、角色和 UI 氛围
- Must include: 主角、主要威胁/目标、场景氛围、HUD 风格暗示
- Must avoid: 文字、复杂菜单、不可读小物件、完整资产库堆砌
```

把 prompt 保存为 `prompt.txt`，再使用包装脚本生成候选图：

```powershell
python scripts/generate_style_candidates.py --prompt-file prompt.txt --provider gpt-image-2 --size 1536x1024 --count 3
```

该脚本内部会调用 `aistudio-media-generation`，并使用 `media_api.py` 支持的下载参数：

```powershell
python .agents/skills/aistudio-media-generation/scripts/media_api.py generate --provider gpt-image-2 --prompt-file <prompt文件> --options-file <options文件> --wait --output downloads --download-dir <候选图目录>
```

输出后让用户选择：

```text
这 3 张是风格候选：
A: assets/generated/style_candidates/...
B: assets/generated/style_candidates/...
C: assets/generated/style_candidates/...

请选择 A/B/C，或说“重生成，偏向更可爱/更暗黑/更像像素风”。
```

用户选择后，把风格锁定写入 `docs/game-concept.md`，包括：

- 新的概念ID。
- 玩法蓝图 ID，例如 `roguelite`、`inventory_backpack`、`tower_defense`。
- 玩法类型。
- 平台。
- 目标层级：默认完整游戏首版。
- 首版内容单元目标：默认至少 3 个精细内容单元、挑战或系统阶段，并写清差异。
- 本轮美术素材计划：围绕首版内容单元列出 1-3 类最高收益静态素材，动态品类补 1-2 个小批量动作帧。
- UI 素材计划：至少列出 HUD 图标、按钮、面板、进度条或状态徽章之一；没有 UI 源图时写明“生成 UI sheet 后接入 `assets/ui/`”。
- 选中风格候选图路径。
- 色彩、角色比例、镜头、UI 气质。
- 玩法不变量：操作、反馈、胜负、边界、重开。
- 禁止污染项：上一版角色/胜负/美术/数值不得自动沿用。
- 首批需要生成或接入的关键素材。

推荐用脚本写入，避免第二次建游戏时概念混杂：

```powershell
python scripts/new_game_concept.py `
  --goal "一句话目标" `
  --platform "浏览器 Web" `
  --level "完整游戏首版" `
  --art-style "选中的美术风格" `
  --style-candidate "assets/generated/style_candidates/xxx.png" `
  --runtime-art-status "待生成运行时素材" `
  --content-units "第 1 个内容单元：教学核心操作和基础胜负；第 2 个内容单元：改变布局、目标组合或节奏；第 3 个内容单元：加入阶段压力、奖励诱惑、系统组合或失败压力" `
  --runtime-art-plan "玩家素材；主要威胁/目标素材；场地或核心 UI/VFX 素材；动态品类补关键角色 1-2 个动作帧" `
  --source-doc "docs/design-inputs/<concept-id>/source.md" `
  --extracted-doc "docs/design-inputs/<concept-id>/extracted.md" `
  --systems "技能系统；敌人系统；进度系统；按玩法需要补充背包、经济、联网或编辑器系统" `
  --deferred-systems "分阶段实现的系统切片、后续内容包或需要单独验收的扩展能力" `
  --blueprints "roguelite,inventory_backpack" `
  --core-action "玩家最常做的 1 个动作" `
  --feedback "操作后的 0.5 秒内反馈" `
  --end-condition "成功/失败/一轮结束条件" `
  --invariant "最不能被后续迭代破坏的玩法规则"
```

## Export Templates 安装引导

Export Templates 只需安装一次。引导流程：

1. AI 检测到 Export Templates 未安装时，输出：
   ```text
   首次导出 Web 版本时需要 Export Templates。
   优先做法：把 Godot_v4.x-stable_export_templates.tpz 放到 tools/，然后双击 init.cmd。
   兜底做法：打开 Godot 编辑器，菜单 Editor → Manage Export Templates → Download。
   ```
2. 用户确认已安装后，AI 执行 `python scripts/setup_godot.py --mark` 写入标记。
3. 后续 `check_env.py` 检测到标记直接跳过，不再提示。

## 兜底问题

如果用户已经跳过表单，再用这些问题补齐缺口。最多问 5 个：

- 目标：你想复刻某个游戏、明显魔改，还是只借鉴核心玩法？
- 操作：玩家最常做的 1 个动作是什么？
- 反馈：玩家操作后立刻看到什么变化？
- 结束：怎样算成功、失败或一轮结束？
- 美术：你更偏向哪种风格？如果不确定，我会给 3 个方向并生成候选图。

## 输出格式

```markdown
## Init 结果

### 项目现状
- ...

### 环境状态
- Python: PASS / FAIL
- Godot 4: PASS / FAIL
- Export Templates: PASS / FAIL
- Git: PASS / FAIL
- AI 已完成：...

### 游戏方向
- 一句话目标：...
- 玩法类型：...
- 平台：...
- 目标层级：...
- 首版内容单元：3 个关卡/章节/波次/挑战及差异

### 美术风格
- 候选方向：...
- 已生成候选图：A/B/C 路径
- 待用户选择：A/B/C 或重生成

### AI 已自动写入
- `docs/design-inputs/<concept-id>/source.md`：用户原始设定
- `docs/design-inputs/<concept-id>/extracted.md`：AI 提炼稿
- `docs/game-concept.md`：兼容旧 review 的事实源
- `docs/project/`：分层项目文档

### 下一步
- 先选择风格候选；风格锁定后回复“开始做首版”，我就开始做完整首版。
```

## 约束

- `init` 阶段默认只读业务代码，但可以保存设定输入、生成风格候选图，并在用户确认后更新 `docs/game-concept.md` 和 `docs/project/`。
- 风格未锁定前，不开始实现玩法代码，除非用户明确选择“先用占位风格继续”。
- 首版设定确认前，不开始实现玩法代码，也不把 AI 摘要覆盖为事实源。
- 开始全新游戏时必须生成新概念ID，并归档上一版设定；只有用户明确说“继续魔改当前 Demo”时才沿用旧概念。
- 中度/混合玩法可以实现多个必要系统；必须写清主循环、系统关系、数据边界、UI/素材需求和验收标准。
- 完整首版包含至少 3 个精细内容单元、挑战或系统阶段；内容差异可以来自布局、节奏、目标组合、数值、奖励、阶段压力、系统组合或失败压力。
- 不自动下载工具或修改系统配置；优先使用 `tools/` portable 依赖。
- 不把 `references/` 作为运行时素材目录；运行时素材放 `assets/`。
- 不要只把 `assets/generated/style_candidates/` 的候选图登记到 `AssetRegistry.gd` 就声称美术已接入；必须生成/切分出运行时素材并在画面中真实渲染，或明确标记程序化占位。
- 不要因为用户没有 PSD、PNG UI 设计稿或成套 UI 源文件就跳过 UI；真实首版需要 AI 自行生成 UI sheet、HUD 图标、按钮或面板素材并接入 `assets/ui/`。
- 禁止自动创建 Git 提交；`git commit`、`git push`、`git reset --hard` 必须由用户明确确认。
