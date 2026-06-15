---
name: godot-medium-game-scaffold
description: 当用户想把 Godot 游戏推进到中小型 2D 首版、补齐音频/资源/VFX/关卡或波次/进度/结算能力、规划 3-5 个内容单元，或要求“从脚手架代码到 skill 全面补齐”时使用。保持项目轻量、可试玩、可继续迭代。
---

# Godot Medium Game Scaffold

## 目标

把当前 Godot 4 项目推进到“AI 能继续做完整 2D 游戏”的首版结构。重点是核心循环、必要系统、内容单元、反馈、进度、结算、统一视觉资产和 Web 交付，而不是展示 Godot 全部 API。

## 开始前

1. 使用 `pm-agile` 查看或创建需求：`python .agents/skills/pm-agile/scripts/pm_cli.py status`。
2. 读取：
   - `AGENTS.md`
   - `docs/AI_WORKFLOW.md`
   - `docs/GAME_DESIGN_GUIDE.md`
   - `docs/ART_PIPELINE.md`
   - `docs/QUALITY_BAR.md`
   - `docs/game-concept.md`
   - `src/game/PrototypeState.gd`
   - `scenes/Game.gd`
   - `src/ui/Hud.gd`
   - `src/game/ContentUnits.gd`
   - `src/game/ProgressStore.gd`
   - `src/game/FeedbackDirector.gd`
   - `src/game/AudioDirector.gd`
   - `src/game/AssetRegistry.gd`

## 能力边界

完整首版默认：

- 一个清晰主循环；中度/混合玩法可以包含多个必要系统，但必须写清系统关系和数据边界。
- 至少 3 个精细内容单元、挑战或系统阶段，差异来自布局、节奏、目标组合、敌人/威胁、奖励、阶段压力、系统组合或失败压力。
- 明确目标、胜负、重开/继续和结算反馈。
- 简单本地进度：当前内容单元、完成状态、最佳成绩或下一步。
- 基础音效、震屏/闪白/浮字或命中特效。
- HUD/UI 素材闭环：真实首版至少有 HUD 图标、按钮、面板、进度条或状态徽章之一，放入 `assets/ui/` 并在运行时真实加载；没有 UI 源图时先生成 UI sheet 或独立 sprite。
- 统一视觉资产闭环：概念图只作为风格锚点；玩家、威胁/目标、场景、HUD/UI 和核心 VFX 必须来自同一 style guide 和运行时素材包，不得直接裁剪候选图当正式素材。
- 动作、射击、生存、平台、跑酷、搜打撤等动态品类必须有关键角色动画证据。
- `python scripts/export_web.py --json` 通过。

首版基础闭环：

- 一个核心操作、一轮胜负、重开和导出链路必须成立。
- 这只是首版的一部分，不能替代 3 个内容单元、UI/素材、结算和进度。

后续增强：

- BGM 和真实音效。
- 更多图片、spritesheet、UI sprite。
- 扩展到 4-5 个内容单元和更完整本地进度。
- 结算页、暂停页、设置页的轻量版本。

允许的中度蓝图：

- 肉鸽/局外成长：`roguelite`
- 搜打撤：`extraction`
- 塔防：`tower_defense`
- 模拟经营：`sim_management`
- RTS：`rts`
- 自走棋：`auto_chess`
- 养成/修炼：`cultivation`
- 背包/格子构筑：`inventory_backpack`
- 暗黑刷装：`loot_arpg`
- 跑酷：`parkour`
- LD/关卡设计：`level_design`
- 多玩法融合：`hybrid`

系统扩展原则：

- 账号、云存档、联网排行榜、付费、关卡编辑器、复杂经济、背包、ECS、大型状态机、TileMap、Navigation、Lighting 或 shader 都可以按玩法目标接入。
- 接入前必须写清玩家价值、职责边界、数据归属、UI/素材需求、运行时证据和验证方式。
- 不为展示 API 而接入系统；系统必须服务当前游戏目标或用户明确要求。

## 推荐文件职责

- `PrototypeState.gd`：规则、分数、生命、时间、胜负状态。
- `Game.gd`：节点编排、输入、碰撞、表现同步。
- `Hud.gd`：只显示状态和玩家提示。
- `ContentUnits.gd`：3-5 个轻量内容单元配置。
- `ProgressStore.gd`：本地最好成绩和完成状态。
- `FeedbackDirector.gd`：震屏、闪白、浮字、命中特效入口。
- `AudioDirector.gd`：程序化音效或真实音频播放入口。
- `AssetRegistry.gd`：运行时素材路径清单。

## 实施顺序

1. 先保证第一个内容单元完整可玩，作为首版基础验收点。
2. 将激活蓝图、首版 3 个内容单元目标和美术素材计划写入 `docs/game-concept.md`。
3. 补第二和第三个内容单元、挑战或系统阶段，差异可以通过布局、节奏、目标组合、数值、奖励、阶段压力、系统组合或失败压力形成。
4. 再把数值抽到 `ContentUnits.gd` 或单一职责模块。
5. 再接进度、结算、继续下一关。
6. 同步补音效、VFX、真实素材、UI sprite 和手感反馈；动态品类不要把动画帧留到后续增强，UI 也不要因为没有 PSD/设计稿而留空。风格割裂时先补 style guide，再重建同源运行时素材包。

## 验收

```bash
python scripts/gameplay_logic_review.py
python scripts/art_pipeline_review.py
python scripts/experience_design_review.py
python scripts/godot_headless_check.py
python scripts/export_web.py --json
python scripts/experience_check.py --strict
python scripts/ai_review.py --strict
```

如果本机 Godot 环境不可用，允许先运行静态 gate：

```bash
python scripts/ai_review.py --skip-runtime
```

但成果验收前必须补跑完整 `python scripts/ai_review.py --strict`。人工只验收最终试玩效果，不参与中间 review。
