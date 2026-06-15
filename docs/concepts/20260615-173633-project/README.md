# 当前游戏项目文档

这里保存当前游戏本身的长期设定。AI 开发玩法、内容、美术和 UI 时优先读取本目录，而不是直接读取脚手架流程文档。

## 推荐读取顺序

0. `../project-map.md`：项目最小导航、目录职责、示例索引和接力读取规则。
1. `game-concept.md`：当前游戏事实源摘要和详细文档索引。
2. `gameplay/README.md`：核心循环、首版范围和启用系统。
3. `gameplay/systems/`：按系统拆分的规则。
4. `gameplay/content-units.md`：首版 3 个内容单元和差异。
5. `art/art-direction.md`、`ui/hud-spec.md`：美术和 UI 约束。

## 写入规则

- 稳定游戏设定写入本目录。
- 用户原始长设定保存在 `docs/design-inputs/<concept-id>/source.md`。
- AI 提炼稿保存在 `docs/design-inputs/<concept-id>/extracted.md`。
- 开发过程、任务状态和临时推演写入 `.pm/`，不要污染本目录。
- 系统变多时，每个系统单独成文档；不要把技能、背包、敌人、经济和成长全部塞到一个文件。
- 创建全新游戏概念时，旧的 `docs/project/` 会归档到 `docs/concepts/<timestamp>-project/`，再生成干净的新项目文档，避免旧系统污染新游戏。
- 新增稳定目录、核心脚本或长期文档时，更新 `scripts/generate_project_map.py` 并重生成 `docs/project-map.md`。
