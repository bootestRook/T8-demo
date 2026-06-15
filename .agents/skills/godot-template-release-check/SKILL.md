---
name: godot-template-release-check
description: 当用户要导出脚手架、发布模板、发给别人、做离线包、检查模板是否干净、确认新手能不能从零启动时使用。用于 Godot 4 AI 游戏脚手架发布前检查，覆盖导出内容、环境检查、文档入口、Git/缓存排除和首启流程。
---

# Godot Template Release Check

## 目标

确认这个项目作为脚手架分发给小白时是干净、可启动、可导出、可继续让 AI 接手的。

## 检查前读取

- `README.md`
- `START_HERE.md`
- `AGENTS.md`
- `project.godot`
- `.gitignore`
- `scripts/export_web.py`
- `scripts/export_template.py`
- `docs/AI_WORKFLOW.md`

## 自动检查

按顺序运行：

1. `python scripts/check_env.py --json`
2. `python scripts/export_template.py --dry-run`
3. `python scripts/setup_godot.py`（确认 Export Templates 标记文件存在）

## 检查项

- 导出产物不携带当前仓库 `.git` 历史；允许包含导出脚本生成的空 `.git` 仓库。
- 导出产物不包含 `html5/`、`.import`、`.pm/`。
- 默认导出产物应包含 `tools/` 下的 portable 工具包或工具压缩包；瘦身包必须显式使用 `--no-tools`。
- `project.godot` 中 Autoload 配置正确（PrototypeState 已注册）。
- `START_HERE.md` 首入口是 OpenCode 输入 `init`。
- `project-init` 首启流程可覆盖环境检查、Export Templates 引导、玩法确认、风格候选生成和 `docs/game-concept.md` 固化。
- `game_export_game` 和 `game_preview_game` 是推荐导出/试玩入口；不再提供旧原型工具别名。
- `docs/AI_WORKFLOW.md` 与 `AGENTS.md` 的入口命令一致。
- `.tscn` 文件未被手动修改过（正常 AI 工作流不应改 .tscn）。
- 主场景节点数不超过 12 个；超过时说明是否由 HUD 基础节点导致。
- `assets/` 中无无解释的大文件；CJK 字体可作为中文显示的明确例外，其他单文件 > 2 MB 提示。

## 输出格式

```markdown
## Template Release Check

### Automated
| Check | Result | Note |
|---|---|---|

### Packaging
| Item | Result | Note |
|---|---|---|

### Release Readiness
Verdict: PASS / CONCERNS / FAIL

### Fix Before Export
- ...
```

## 约束

- 不直接删除文件，除非用户明确要求。
- 不执行真实导出或提交，除非用户明确要求。
- 发现大文件或敏感文件时先报告路径和建议。
