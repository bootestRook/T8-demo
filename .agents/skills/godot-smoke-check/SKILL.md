---
name: godot-smoke-check
description: 在 Godot 4 游戏脚手架中做轻量冒烟检查。当用户要确认项目能不能跑、改完后检查、导出前检查、试玩前自测、QA 前检查时使用。运行环境和导出检查，并输出新手可执行的手动试玩清单与 PASS/CONCERNS/FAIL 结论。
---

# Godot Smoke Check

## 目标

用最少步骤确认当前游戏是否能继续交给下一轮开发或试玩。

## 检查前

1. 读取 `AGENTS.md`、`README.md`。
2. 读取 `docs/game-concept.md`、`docs/AI_WORKFLOW.md`、`docs/QUALITY_BAR.md`。

## 自动检查

按顺序执行：

1. `python scripts/check_env.py`
2. 如果提示 Export Templates 未安装，引导用户安装后再检查
3. `python scripts/godot_headless_check.py`
4. `python scripts/godot_runtime_log_check.py`
5. `python scripts/export_web.py`
6. `python scripts/experience_check.py --strict`

如果 Python 或 Godot 不可用，提示用户安装。

`godot_runtime_log_check.py` 用非 headless 模式运行项目数秒，捕获用户在 Godot 编辑器按 F5 后更容易遇到的脚本错误、无效调用、资源加载失败和崩溃返回码。`experience_check.py` 是默认 AI 自动试玩流程：启动或复用 Web 预览，用 `agent-browser` 打开页面，检查控制台错误、桌面/窄屏 canvas、像素健康，并执行“点击 canvas 开始”、方向键/WASD 输入和通用输入链路探针。人工只在最终成果验收时试玩。

## 手动试玩清单

启动预览服务器：`python scripts/run_web_preview.py --open --json`，浏览器打开返回的本地 URL。检查：

- 游戏页面能打开，无白屏。
- 浏览器控制台没有明显运行时错误。
- 点击或按空格能开始。
- 核心操作能触发可见反馈。
- 操作反馈在 0.5 秒内出现。
- 一轮游戏有开始、变化、结束或重开方式。
- HUD 文案不遮挡主要玩法区域。
- 如果接入了素材，运行时路径来自 `assets/`，不是直接从 `references/` 加载。
- 玩法目标仍符合 `docs/game-concept.md` 和 `docs/GAME_DESIGN_GUIDE.md` 的首版范围。

## 输出格式

```markdown
## Godot Smoke Check

### 自动检查
| 项目 | 结果 | 说明 |
|---|---|---|
| check_env | PASS/FAIL | ... |
| export_web | PASS/FAIL | ... |

### 手动试玩
| 检查项 | 结果 | 说明 |
|---|---|---|
| 页面启动 | PASS/NOT RUN/FAIL | ... |
| 核心操作 | PASS/NOT RUN/FAIL | ... |
| 反馈清晰 | PASS/NOT RUN/FAIL | ... |
| 结束/重开 | PASS/NOT RUN/FAIL | ... |
| 素材加载 | PASS/NOT RUN/FAIL | ... |

### 结论
**Verdict: PASS / CONCERNS / FAIL**

### 下一步
- 阻塞问题: ...
- 后续增强: ...
```

## 判定规则

- `PASS`：环境检查和导出通过，手动试玩没有阻塞问题。
- `CONCERNS`：导出通过，但存在体验、布局、素材或范围风险。
- `FAIL`：环境检查或导出失败，或核心玩法无法启动/无法操作。
