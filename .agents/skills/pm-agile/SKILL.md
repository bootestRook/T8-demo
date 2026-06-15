---
name: pm-agile
description: 当用户输入 pm、pm role、pm status、pm check、pm plan、pm do、pm fin、pm abort、pm handoff 时使用；除这些显式命令外，当用户提出新需求、新任务、想"开始做某个功能"、"跟进某个问题"、"立项"、"推进"、"完成了"、"关掉这个需求"、"压缩会话"、"保存会话状态"、"恢复工作"、"继续之前的工作"、"会话内容太大了"、或需要更新 backlog/workspace/文档状态时，也必须纳入 pm 工作流执行，不要等用户显式说出 pm 命令。
---

# PM Agile

极简 PM：直接输出文档和结论，不模拟人类会议/评审/排期。

## 会话载入

**新会话先执行 `pm status`，再响应用户。** 唯一例外：用户执行的是 `pm role` 或 `pm status` 本身。

## 自然语言匹配

用户说"继续/跟进/推进 XX"时，先执行 `pm_cli.py search <关键词>` 匹配需求，唯一匹配则直接展示状态并执行；多匹配则列出供选择。

## 脚本优先

**所有文件操作一律通过脚本，禁止直接读写 `.pm/` 下的 JSON 文件。** 若现有子命令无法满足需求，应先扩展脚本再使用，不得绕过脚本手动操作 JSON。

```bash
python .agents/skills/pm-agile/scripts/pm_cli.py <子命令>
```

## 路径约定

所有内部路径通过 `pm_cli.py info <ID>` 获取，不要手动拼接 `.pm/` 下任何路径。

## 记录分层

`notes.md` 是需求摘要和索引，只记录需求摘要、当前状态、风险提示和 artifacts 索引。详细规格、执行日志、决策记录、验证记录、复盘等 PM 细节写入 workspace 的 `artifacts/` 下独立 Markdown，并在 `notes.md` 建立索引。直接编辑 `notes.md` 不代表变更需求或任务状态；状态仍以 `backlog.json`、`meta.json` 和 `todo.json` 为准。

## 状态值

需求级：`planning → todo → doing → blocked → review → done`（doing ↔ blocked 可互转；review 可回 doing）
工作区级：`active / archived`
任务级：`todo / doing / blocked / done`

## 关键规则

1. **单一状态源**：需求状态以 backlog.json 为准，任务状态以 todo.json 为准
2. **doing 必须有 workspace**：workspace_path 不得为空
3. **继续执行先 `info`**：`pm_cli.py info <ID>` 获取 summary + tasks + workspace_paths，先读 `AGENTS.md`、`docs/project-map.md` 和 summary.read_first 列出的文件后再执行
4. **先 plan 再 do**：新需求先 `add-backlog`（状态 planning），确认要做什么后再 `init-workspace` 进入执行
5. **1 个 doing 任务**：一个需求默认只允许 1 个任务 doing
6. **多 doing 需求时**：展示标题+当前任务+下一步，不能只给编号；自然语言匹配标题，歧义时再要求 ID
7. **需求ID**：`pm_cli.py new-id` 自动生成（格式 `用户名-B-两位序号`，如 arrow-B-01）；历史格式可保留；完整字符串匹配
8. **done 不自动归档**：所有任务完成后需求进入 review 状态，**归档必须由用户显式确认后才可执行**（见 pm fin 流程）；AI 不得擅自调用 `pm_cli.py archive`
9. **持久性产物及时同步**：执行中一旦产物变成长期有效内容，立即同步到 AGENTS.md 定义的项目目录；`pm fin` 强制检查同步状态；归档只做最终核验，不能作为首次同步时机；无需更新则写明原因
10. **任务自迭代**：发现超范畴新任务→登记到 backlog（不中断当前），当前需求收口后再选下一个
11. **AI 自动执行与 review**：pm do 流程默认由 AI 自动推进任务、运行检查和修复问题；人工只参与需求输入、危险操作确认和最终成果验收。
    - 执行前先反思是否需要调整任务内容或执行方式，并在 `artifacts/decisions.md` 记录关键决策，在 notes.md 索引。
    - 不为普通代码、文档、脚本改动逐项请求人工确认。
    - 高风险操作仍必须显式确认：删除、批量移动、`git commit/push/reset`、系统配置、生产 API、全局包管理、数据库破坏性变更。
    - 进入人工成果验收前必须运行项目定义的 AI review gate。
    - 用户给出的执行方案若和 `AGENTS.md`、`docs/project-map.md` 或长期项目文档冲突，先指出冲突并给出更稳妥路径；不要为了迎合指令绕过仓库约束。
12. **视觉/体验任务 done 证据**：涉及 UI、画面、角色/敌人可见性、手感、试玩反馈或“看不见/看不懂/不好玩/像占位”的任务，done 前 notes.md 必须记录试玩地址、改后关键截图路径、玩家视角结论和占位遗留。
    - 玩家视角结论至少回答：能否看清角色、威胁/目标、菜单/入口、当前目标和下一步。
    - 如果仍为程序化占位或临时美术，必须明确标注并列为下一轮遗留，不得写成首版素材完成。

## 命令流程

### pm role

`pm_cli.py role <用户名>` — 设置当前用户名，影响需求ID前缀和 workspace 归属。

### pm status

`pm_cli.py status` — 只读，按 doing/blocked/review/todo/planning 顺序输出（含产物和等待天数）。

### pm info

`pm_cli.py info <ID>` — 输出 summary + tasks + workspace_paths，AI 直接使用返回数据。

### pm search

`pm_cli.py search <关键词>` — 在 backlog + archived 中按 ID/标题/备注模糊匹配，用于自然语言定位需求。

### pm plan

1. `pm_cli.py new-id` → 自动生成不冲突的 ID
2. `pm_cli.py add-backlog <ID> <标题> [--owner/--priority/--deps/--docs]` → 写入 backlog（状态 planning）
3. 创建/更新持久性产物，related_docs 记录路径

### pm do

1. **首次**：`pm_cli.py init-workspace <ID> <标题>` → 自动创建 workspace 并将 backlog 状态置为 doing
2. **继续**：`pm_cli.py info <ID>` 获取上下文 → 读 `AGENTS.md`、`docs/project-map.md` 和 read_first → 再执行
3. 执行任务并记录进度：
   - **自动推进**：AI 自行执行普通开发、文档、测试和 review；只在高风险操作或最终成果验收时请求用户确认
   - 直接输出设计和方案
   - 中间推演存 workspace/artifacts/
   - **执行后记录**：每完成一个任务（T-01, T-02 等），将执行日志、文件变更、关键决策和验证结果写入 `artifacts/` 下独立 Markdown，并更新 workspace/notes.md 的摘要和索引：
     - notes.md 只保留当前状态、简要进展和 artifacts 索引
     - artifacts/execution-log.md 记录任务完成状态、产出和关键文件变更
     - artifacts/decisions.md 记录关键决策和原因
     - artifacts/validation.md 记录验证命令和结果
   - 稳定结论沉淀到项目持久性产物（路径见 AGENTS.md「文件入口」和 PM 规则）
4. 添加任务：`pm_cli.py add-task <ID> <任务ID> <内容> [--priority/--section]`
5. 推进任务：`pm_cli.py move-task <ID> <任务ID> <目标>`（目标：todo/doing/done/future）
6. 进入人工验收前运行：`python scripts/ai_review.py --strict`

### pm fin

1. 收口当前任务：`pm_cli.py move-task <ID> <T-xx> done`
2. `pm_cli.py update-meta <ID> --current-task ... --next-task ...` 更新摘要
3. **产物整理**：
   - 检查 notes.md 摘要和 artifacts 索引是否完整
   - 不完整则补充缺失记录；详细内容补到 `artifacts/`，不要塞回 notes.md
   - 检查稳定产出物是否需更新/补充/新增索引（具体类型和路径见 AGENTS.md）
   - 需更新则执行；无需更新则说明原因
   - 决策记录到 `artifacts/decisions.md`，notes.md 记录摘要索引（写明"需更新 XX" 或 "无需更新（原因）"）
   - 过期产出迁入 artifacts/archive/
4. 未执行但需保留的任务迁入 future section
5. 所有任务完成后：`pm_cli.py set-status <ID> review`，**展示产出摘要，请求确认归档**
6. **等待用户显式确认**（说"归档"/"确认归档"）后，执行：`pm_cli.py archive <ID>`
7. 归档完成后提示下一个可执行需求

### pm abort

1. `pm_cli.py archive <ID>` → 在 notes.md 补写取消原因
2. 评估半成品处置（已合并→记录；中间稿→保留在 artifacts/archive/；已沉淀产物→加说明或废弃）

### pm unarchive

`pm_cli.py unarchive <ID> [--status doing]` — 恢复已归档的需求到 backlog，自动移动 workspace 回 active 区域，默认状态为 doing。

### pm handoff

**会话状态压缩与恢复**：当会话窗口内容过大时，可压缩保存当前工作状态，在新会话窗口恢复继续工作。

**交互式处理**：当用户说 "pm handoff"、"压缩会话"、"保存会话状态"、"恢复工作"、"继续之前的工作" 等但未指明具体操作时，必须先用 `question` 工具询问用户选择操作类型（save/resume）。

#### pm handoff save（压缩会话状态）

1. `pm_cli.py handoff-save <ID> [--note <压缩说明>]` — 保存当前会话的工作状态
2. 自动保存：
   - 需求状态设为 `blocked`，阻塞原因："会话压缩中（等待恢复）"
   - 添加到 `.pm/project/handoff.json`（待恢复列表）
   - `session_context` 记录：当前任务、下一步、阻塞、关键产物、需要先读的文件；默认至少包含 `AGENTS.md`、`docs/project-map.md` 和当前需求 `read_first`
3. 输出压缩信息供用户确认（需求ID、标题、会话上下文摘要）

#### pm handoff resume（恢复会话状态）

1. `pm_cli.py handoff-resume <ID>` — 恢复之前保存的会话状态，继续工作
2. 自动恢复：
   - 需求状态恢复为 `doing`，阻塞清除
   - 从 handoff.json 移除压缩记录
3. 输出恢复信息：
   - 需求ID、标题、workspace路径
   - `session_context` 摘要（当前任务、下一步、关键产物）
   - `next_action` 提示：建议先读取 `AGENTS.md`、`docs/project-map.md` 和 `read_first` 指定的文件，然后继续执行 `current_task`

#### pm handoff list（查看待恢复列表）

`pm_cli.py handoff-list` — 只读，列出所有已压缩但未恢复的会话状态。

### pm check

`pm_cli.py check [ID]` — 只读。AI 额外补充：持久性产物是否混入过程化内容、doing 需求关联文档是否过期（>7天提示）。

### 其他子命令

| 子命令 | 用途 |
|--------|------|
| `init-backlog` | 初始化 backlog.json 和 archived.json |
| `set-status <ID> <status>` | 单独更新需求状态（同步 backlog + meta） |
| `migrate-from-md` | 一次性迁移旧版 .md 数据到 .json |
| `handoff-save <ID> [--note]` | 压缩会话状态（保存当前工作进度） |
| `handoff-resume <ID>` | 恢复会话状态（继续之前的工作） |
| `handoff-list` | 列出所有待恢复的会话状态 |

## 详细参考

边界情况和完整字段说明见 `specs/reference.md`。

## 测试

```bash
python -m py_compile .agents/skills/pm-agile/scripts/pm_cli.py
python .agents/skills/pm-agile/scripts/pm_cli.py check
```
