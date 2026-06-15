# PM Agile 详细参考

SKILL.md 未覆盖的边界情况和字段说明。通常不需要读取此文件。

## 目录结构

```
.pm/project/
  backlog.json          # 活跃需求索引
  archived.json         # 已归档需求
.pm/workspaces/
  <owner>/
    YYYY-MM-DD-<ID>-<标识>/
      meta.json         # 需求摘要
      todo.json         # 任务列表
      notes.md          # 摘要、当前状态、风险、artifacts 索引（agent 读写）
      artifacts/        # 详细规格、执行日志、决策、验证、复盘等 PM 细节（按需子目录）
  archived/<owner>/     # 归档后 workspace
.pm/local/
  current-role.json     # 当前用户名
持久性产物/            # 需沉淀到项目中的产出物（具体路径和分类见 AGENTS.md「文件入口」和 PM 规则）
```

状态边界：`backlog.json`、`archived.json`、`meta.json`、`todo.json`、handoff 状态和 workspace 迁移只能通过 `pm_cli.py` 修改；`notes.md` 是 Agent 可直接读写的摘要索引文档；详细规格、进度、决策、验证和复盘记录写入 `artifacts/` 下的独立 Markdown，并在 notes.md 索引。

## JSON 字段定义

字段 schema 见 `templates/` 下同名 `.json` 文件。以下仅列出关键语义。

### backlog.json

- `overview`：项目概览（current_phase / top_goal / main_risk）
- `demands[]`：需求数组，每个含 demand_id / title / owner / priority / status / deps / related_docs / workspace_path / remark
- `planning_conclusions[]`：活跃决策摘要字符串数组；需求归档后需从此处清理对应条目

### archived.json

- `demands[]`：与 backlog 同结构 + `archive_date`；status 固定 `done` 或 `cancelled`

### meta.json

- 顶层：demand_id / title / owner / priority / created_date / last_updated / demand_status / workspace_status / deps / related_docs / workspace_path
- `summary`：current_task / next_task / block / done_criteria / read_first / products / manual_step（是/否）/ followup
- summary 各字段不可省略；current_task/next_task 无任务时写 `无`；归档后 current_task/next_task 清为 `无`

### todo.json

- `sections`：todo[] / doing[] / done[] / future[]
- todo 项：task_id / content / priority / status / next_step / product
- doing 项：task_id / content / start_time / block / next_step / product
- done 项：task_id / content / complete_time / verify_method / verify_result / product
- future 项：task_id / content / status / trigger_condition
- 同一 task_id 不得出现在多个 section；future 不计入收口条件

### current-role.json

- username / member_name / default_workspace

## 归档规则

1. 所有任务完成后需求进入 review，**归档必须由用户显式确认**，AI 不得擅自执行
2. 用户确认归档后：需求从 backlog 移到 archived
3. workspace 从 `workspaces/<owner>/` 迁入 `workspaces/archived/<owner>/`
4. meta.json 更新：workspace_status=archived、workspace_path=归档路径、current_task/next_task=无
5. 活跃 backlog 只保留 planning/todo/doing/blocked/review
6. 归档时 `pm_cli.py archive` 自动清理 backlog.json 的 `planning_conclusions` 中包含该需求 ID 的条目
7. 归档前评估持久性产物：需更新则更新；无需更新则说明原因并写明原因（在 notes.md 记录"无需更新（原因）"）

## 文档分层

- workspace：执行过程、中间产物、阶段性推演
- notes.md：摘要索引，只放需求摘要、当前状态、风险和 artifacts 索引
- artifacts/：详细规格、执行日志、决策记录、验证记录、复盘和归档/取消说明
- 稳定产出物：需沉淀到项目中的长期有效产出（具体分类和路径由项目 AGENTS.md 定义）
- 沉淀前须整理重写，去掉阶段语境、任务拆解、方案对比痕迹
- 不直接复制 workspace 中间稿作为稳定产出物
- 当前有效产出必须在 meta.json 或 notes.md 中显式索引引用
- 已失效产出迁入 artifacts/archive/

## pm check AI 补充项

脚本 check 覆盖：状态合法性、路径合规、字段完整性、todo 重复任务。
AI 额外检查：
- 持久性产物是否混入过程化内容
- notes.md 是否混入大段任务明细
- doing 需求关联文档是否过期（meta.json last_updated 差 >7 天给提示）

## pm abort 半成品处置

| 产出类型 | 处置 |
|----------|------|
| 已合并到代码库的变更 | notes.md 记录已合并内容 |
| workspace 内中间稿 | 保留在 artifacts/archive/，notes.md 加索引 |
| 已沉淀到项目的持久性产物 | 有效则保留；过期则文档顶部加取消说明；废弃则 notes.md 记录原因 |

notes.md 取消记录须写明：取消原因、产出处置决策、是否有可复用内容。

## 简写规则

省略 ID 时取唯一 doing 需求；多个 doing 展示标题+当前任务+下一步，支持自然语言选择；仍歧义时要求指定 ID；无 doing 则提示可执行列表。

## 迁移

`pm_cli.py migrate-from-md` 从旧版 .md 一次性转 .json。旧文件保留，确认无误后手动删除。
