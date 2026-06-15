---
name: godot-runtime-preview-check
description: 当用户说打开预览、浏览器里看一下、运行时检查、白屏、控制台报错、手机/桌面实际效果或自动试玩验证时使用。用于 Godot Web 游戏的浏览器运行时检查。
---

# Godot Runtime Preview Check

## 目标

确认项目不是只“导出通过”，而是在浏览器里真的能打开、能操作、没有明显白屏或控制台错误。

## 开始前

读取：

- `AGENTS.md`
- `docs/game-concept.md`
- `src/game/PrototypeState.gd`
- `scenes/Game.gd`
- `src/ui/Hud.gd`

## 自动流程

1. 运行 `python scripts/export_web.py --json`。
2. 启动或复用预览：`python scripts/run_web_preview.py --open --json`。
3. 继续运行 `python scripts/experience_check.py --strict`；进入交付前再运行 `python scripts/ai_review.py --strict`。
4. 如果浏览器自动化不可用，AI 标记为 CONCERNS 并给出风险；人工只在最终成果验收时试玩。

## 手动检查项

- 页面能打开，无白屏。
- 浏览器控制台没有红色运行时错误。
- 按 Space 或点击能开始。
- WASD/方向键有移动反馈。
- 一轮能成功、失败或重开。
- HUD 不遮挡主要玩法区域。
- 运行时素材不从 `references/` 加载。

## 输出格式

```markdown
## Runtime Preview Check

- Web 导出：PASS / FAIL
- 试玩预览：已打开 / 已返回地址 / 未能启动
- 页面启动：PASS / NOT RUN / FAIL
- 核心操作：PASS / NOT RUN / FAIL
- 控制台错误：PASS / NOT RUN / FAIL

结论：PASS / CONCERNS / FAIL
下一步：...
```

## 约束

- 默认只检查，不改代码。
- 如果用户明确说“直接修”，再切到 `vibe-iteration` 或对应 Godot skill 修复。
