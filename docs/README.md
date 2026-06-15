# 文档入口

本仓库的文档分为两类：当前游戏项目文档和脚手架流程文档。AI 开发玩法、UI、素材或内容时，优先读取 `docs/project/`；只有需要工具链、导出、质量门禁或 AI 协作流程时，才读取根目录下的脚手架文档。

## 当前游戏项目

- `docs/project-map.md`：AI 最小导航，记录目录职责、关键文件、示例索引和接力读取规则；由 `python scripts/generate_project_map.py` 生成。
- `docs/game-concept.md`：兼容旧脚本和 review 的当前游戏事实源。
- `docs/project/game-concept.md`：新结构下的当前游戏摘要和索引。
- `docs/project/gameplay/`：玩法、系统、内容单元和数值。
- `docs/project/art/`：美术方向和素材计划。
- `docs/project/ui/`：HUD、菜单和 UI 流程。
- `docs/design-inputs/`：用户原始输入和 AI 提炼稿，原文不得被摘要覆盖。

## 脚手架流程

- `docs/AI_WORKFLOW.md`：AI 从 init 到发布的完整工作流。
- `docs/GAME_DESIGN_GUIDE.md`：玩法拆解和中度/混合玩法蓝图。
- `docs/ART_PIPELINE.md`：美术生成、切分、落地和审查。
- `docs/QUALITY_BAR.md`：交付门禁和体验标准。
- `docs/TOOLCHAIN.md`：工具链、环境和本地存档点。
- `docs/GODOT_MCP.md`：GodotMCP 编辑器桥接。
- `docs/ARCHITECTURE_RULES.md`、`docs/MODULES.md`、`docs/AI_RECIPES.md`：代码架构和模块规则。
- `docs/MULTI_AGENT_WORKFLOW.md`：多 Agent 协作。

新增稳定目录、核心脚本或长期文档后，先更新 `scripts/generate_project_map.py`，再运行 `python scripts/generate_project_map.py` 重生成项目地图。

## 信息分层

- 概念设定：回答“这是一个什么游戏”，放在 `docs/design-inputs/` 和 `docs/project/game-concept.md`。
- 游戏系统设定：回答“规则是什么”，放在 `docs/project/gameplay/`。
- 开发需求：回答“这一轮做什么”，放在 `.pm/`。

不要把用户原始长设定、系统细节和开发任务全部塞进 `docs/game-concept.md`。`docs/game-concept.md` 只保留当前开发必须遵守的核心事实，并指向更详细的项目文档。
