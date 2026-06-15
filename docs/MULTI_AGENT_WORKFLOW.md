# 多 Agent 主从协作工作流

## 定位

本脚手架支持“主 AI 编排，子 Agent 执行，主 AI 合并”的协作模式。主 AI 是唯一的需求状态写入者、冲突裁决者和最终合并者；子 Agent 负责受限范围内的分析、补丁、素材规格、诊断或验证结果。

第一版目标是让多 Agent 可靠协作，不做外部 AI CLI 自动启动平台，也不让多个 Agent 同时直接抢主工作区。

## 角色

| 角色 | 职责 | 常见输出 |
|---|---|---|
| Coordinator | 拆需求、分配任务、检查路径边界、合并结果、运行最终门禁 | 任务包、合并记录、验收结论 |
| Gameplay | 玩法规则、输入、场景同步、数值、胜负和重开 | GDScript 补丁、局部验证结果 |
| Art-UI | 素材规格、UI/HUD、运行时素材路径和美术落地证据 | prompt、素材清单、UI/HUD 接入补丁 |
| Code-Review | 代码职责边界、可维护性、GDScript 风险和最小修复建议 | Findings、风险分级、修复建议、局部门禁建议 |
| QA-Review | 静态审查、运行检查、Web 导出、体验检查和风险归类 | 检查报告、失败项定位 |
| Godot-Debug | GodotMCP 或命令行运行诊断、debug output 分析 | 运行日志、错误定位、复现步骤 |
| Docs | 工作流、说明文档、模板和新手入口一致性 | 文档补丁、命令索引检查 |

## 主 AI 职责

- 先读项目上下文，再决定是否需要派发子 Agent。
- 每个子任务必须有明确目标、允许改动路径、禁止改动路径和交付物。
- 子 Agent 之间的写入范围不能重叠；无法避免重叠时，该任务由主 AI 本地完成。
- 主 AI 负责读取子 Agent 结果、判断冲突、合并补丁、更新 PM 记录。
- 子 Agent 的局部检查不能替代主工作区最终门禁。
- 进入人工验收前必须运行 `python scripts/ai_review.py --strict`。

## 子 Agent 规则

- 子 Agent 只能处理任务包声明的目标。
- 子 Agent 不直接修改 `.pm/project/*.json`，也不擅自归档、提交、推送或重置仓库。
- 子 Agent 不删除文件，不做破坏性 git 操作，不全局安装依赖。
- 如需越过 `allowed_paths`，必须在结果中说明原因，由主 AI 决定是否接纳。
- 完成后必须交付变更摘要、触达文件、验证命令和风险说明。

## 任务生命周期

| 状态 | 含义 |
|---|---|
| draft | 主 AI 正在定义任务包 |
| assigned | 已分配给子 Agent |
| running | 子 Agent 正在执行 |
| submitted | 子 Agent 已提交结果，等待主 AI 检查 |
| accepted | 主 AI 接受结果，准备合并 |
| rejected | 主 AI 拒收结果，需要重做或转为人工处理 |
| merged | 主 AI 已合并到主工作区 |

PM 的 `todo / doing / done / future` 仍是需求内任务的高层状态；子 Agent 的细粒度状态放在任务包 manifest 中。

## 任务包

任务包默认放在当前需求 workspace：

```text
.pm/workspaces/<owner>/<demand>/artifacts/agents/<task_id>-<role>/
```

推荐文件：

```text
assignment.md       # 给子 Agent 的任务说明
manifest.json       # 机器可读边界和状态
result.md           # 子 Agent 结果
changed_files.txt   # 触达文件清单
changes.patch       # 可选补丁
logs/               # 检查输出摘要
```

`allowed_paths` 和 `blocked_paths` 必须使用项目相对路径。`references/` 不能作为运行时加载路径；`.pm/project/`、`.git/`、`.godot/`、`html5/`、`exports/` 默认禁止子 Agent 修改。

## 合并策略

第一版采用主 AI 串行合并：

1. 检查 `manifest.json` 状态和任务目标。
2. 检查 `changed_files.txt` 或 patch 文件是否越过 `allowed_paths`。
3. 对 patch 执行 dry-run 检查。
4. 若与已合并任务冲突，由主 AI决定重排、手工合并或拒收。
5. 合并后记录到 `notes.md`，再运行对应局部门禁。
6. 全部合并后运行 `python scripts/ai_review.py --strict`。

子 Agent 可以在隔离 worktree 中工作，但最终 patch 必须由主 AI 应用到主工作区。使用 `git worktree`、批量移动或删除前仍按仓库安全规则确认风险。

## GodotMCP 使用

GodotMCP 是诊断辅助，不是合并依据。子 Agent 可在自己的工作区使用 GodotMCP 做 `run_project -> get_debug_output -> stop_project`，但最终必须由主工作区执行命令行门禁：

```bash
python scripts/godot_runtime_log_check.py
python scripts/export_web.py --json
python scripts/experience_check.py --strict
python scripts/ai_review.py --strict
```

并发运行多个 Godot 进程可能触发显卡、端口或文件锁问题。第一版只要求主工作区最终运行完整 gate。

## 适合派发的任务

- 只读代码调查、文档一致性检查、失败日志定位。
- 合并前代码审查，尤其是职责边界、GDScript 写法和最小修复建议。
- 明确文件边界的玩法小改动。
- 独立 UI/HUD 或素材管线检查。
- Web 导出、体验检查和报告整理。

## 不适合派发的任务

- 需要同时改 `PrototypeState.gd`、`Game.gd`、`Hud.gd` 且边界不清的核心重构。
- 需要删除、批量移动、全局安装、历史改写或生产 API 的高风险操作。
- 需要主 AI 立即依赖结果的关键路径任务。
- 多个子 Agent 同时改同一文件的任务。

## 第一版命令

```bash
python scripts/agent_task.py create --demand-id <ID> --task-id T-01 --role gameplay --goal "..." --allowed-path src/game/PrototypeState.gd
python scripts/agent_task.py check --manifest <manifest.json>
python scripts/agent_merge.py check --manifest <manifest.json> --patch <changes.patch>
```

这些命令只做任务包生成、范围校验和 patch dry-run，不启动外部 AI，也不替代 PM CLI。
