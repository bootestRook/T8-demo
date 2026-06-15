---
name: godot-playtest-report
description: 为 Godot 4 游戏生成或整理试玩报告。当用户试玩后反馈不好玩、看不懂、操作不顺、需要记录测试结果、分析玩家反馈、决定下一轮改什么时使用。
---

# Godot Playtest Report

## 目标

把一次试玩变成可执行的下一轮迭代计划。

## 模式

- `new`：生成空白试玩记录模板。
- `analyze [path]`：读取已有试玩笔记并整理为结构化报告。
- 无参数：如果用户给了反馈文本，直接整理；否则先输出 `new` 模板。

## 上下文读取

优先读取：

- `docs/game-concept.md`
- `docs/AI_WORKFLOW.md`
- `docs/QUALITY_BAR.md`
- `AGENTS.md`
- `src/game/PrototypeState.gd`
- `scenes/Game.gd`

## 分析规则

把反馈分到这些类别：

- `Blocking`：无法启动、无法操作、无法完成一轮、导出失败。
- `Clarity`：玩家不知道目标、规则、得分、失败原因。
- `Feel`：操作延迟、反馈弱、节奏不对、手感不顺。
- `Content`：缺角色、敌人、关卡、视觉差异、阶段变化、动画或素材。
- `Scope`：需求已经超过首版闭环，需要砍掉或延期。

## 输出格式

```markdown
## Playtest Summary

### What Worked
- ...

### Blocking Issues
- ...

### Findings
| Category | Finding | Evidence | Priority |
|---|---|---|---|

### Next Iteration
- 阻塞问题: ...
- 首版必须修: ...
- 后续增强: ...
- Not Now: ...

### Suggested Skill Route
- 玩法/规则问题：vibe-iteration
- 构建/可玩性检查：godot-smoke-check
- 素材问题：asset-prompt-spec 或 godot-asset-audit
- 太简单/缺动画/不像游戏：godot-medium-game-scaffold + godot-sprite-pipeline + godot-game-feel-tuning
```

默认只输出到对话。用户明确要求保存时，写入 `docs/playtests/playtest-[YYYY-MM-DD].md`。
