---
name: godot-game-feel-tuning
description: 当用户说手感不好、反馈弱、不够爽、不好玩、节奏慢、太难/太简单、想优化体验、点击没感觉、动画不明显时使用。用于 Godot 4 游戏的手感、节奏、反馈和体验缺口调优。
---

# Godot Game Feel Tuning

## 目标

把"能玩"打磨成"玩家知道自己做了什么，而且愿意再试一次"。如果反馈只是手感弱，调核心操作、反馈、节奏和结束/重开；如果反馈是“不好玩、太简单、没动画、不像游戏”，必须升级到完整首版缺口处理，补内容差异、阶段变化、关键动画、系统决策或结算反馈。

## 开始前读取

- 当前 PM 需求信息：`python .agents/skills/pm-agile/scripts/pm_cli.py status`
- `docs/game-concept.md`
- `docs/QUALITY_BAR.md`
- `src/game/PrototypeState.gd`
- `scenes/Game.gd`
- `src/ui/Hud.gd`

## 反馈分类

- 目标不清：不知道要做什么。
- 操作不顺：不知道怎么操作，或输入太难。
- 反馈弱：按了有变化但不明显。
- 节奏慢：等待太久、目标推进无聊。
- 难度不合适：太容易或太挫败。
- 结束弱：完成/失败后不知道下一步。
- 太简单：缺内容单元差异、阶段变化、系统决策或决策压力。
- 没动画：动态品类缺关键角色动作帧或运行时动画接入。

## 调参优先级

1. 先让目标和成功/失败条件更清楚。
2. 再增强操作后 0.5 秒内的可见反馈。
3. 再调整目标数值、倒计时、速度、生成间隔等节奏参数。
4. 如果问题是太简单、系统缺失或没动画，不只调数值；转入 `godot-medium-game-scaffold` / `godot-sprite-pipeline`，补完整首版结构、必要系统或同源视觉资产。

## 每轮改动限制

- 聚焦最高收益点；但“完整首版缺口”可以作为一个打包问题，集中补内容单元差异、阶段变化、关键动画或必要系统中的最高风险项。
- 优先改已有文件：`PrototypeState.gd`、`Game.gd`、`Hud.gd`。
- 需要新增关卡编辑器、背包、经济、联网或其他系统来解决体验问题时，先写清玩家价值、职责边界、数据归属、UI/素材需求和验证方式，再实现最小可验收切片。
- 改完运行 `python scripts/experience_design_review.py`、`python scripts/export_web.py --json` 和 `python scripts/experience_check.py --strict`；进入交付前运行 `python scripts/ai_review.py --strict`。

## 输出格式

```markdown
## Game Feel Tuning

完成了：...
为什么这样调：...
试玩方式：已导出并启动预览 / 本地地址：...
验证：experience_design_review、export_web、experience_check 通过
下一轮优先看：...
```
