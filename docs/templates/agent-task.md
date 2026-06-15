# 子 Agent 任务包

## 基本信息

- Demand ID:
- Task ID:
- Role:
- Status: draft
- Coordinator:

## 目标

简明描述本任务要完成什么，以及不做什么。

## 必读上下文

- `AGENTS.md`
- `docs/MULTI_AGENT_WORKFLOW.md`

## 允许改动路径

- 

## 禁止改动路径

- `.pm/project/`
- `.git/`
- `.godot/`
- `html5/`
- `exports/`
- `references/`

## 交付物

- `result.md`：结论、改动摘要、风险和验证结果。
- `changed_files.txt`：触达文件清单。
- `changes.patch`：如有代码或文档改动，提供 patch。
- `logs/`：关键命令输出摘要。

## 必须遵守

- 不直接修改 PM 项目级 JSON。
- 不做 git commit、push、reset、checkout 覆盖或历史改写。
- 不删除文件或目录。
- 不全局安装依赖，不修改系统配置。
- 如需越过允许路径，先在结果中说明，不自行扩大范围。

## 建议检查

- `python scripts/godot_quality_tools.py --json`
- `python scripts/ai_review.py --skip-runtime`

## 结果摘要

子 Agent 完成后在 `result.md` 中填写。
