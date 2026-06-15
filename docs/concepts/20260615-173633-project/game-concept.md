# 当前游戏事实源

当前模板仍处于空脚手架状态。兼容旧 review 的完整事实源见 `docs/game-concept.md`。

## 当前状态

- 概念ID：`starter-template`
- 玩法蓝图：`starter_template`
- 目标：等待用户通过 `init` 创建新游戏。

## 详细文档索引

- 原始输入：新游戏创建后写入 `docs/design-inputs/<concept-id>/source.md`
- AI 提炼稿：新游戏创建后写入 `docs/design-inputs/<concept-id>/extracted.md`
- 玩法总览：`docs/project/gameplay/README.md`
- 内容单元：`docs/project/gameplay/content-units.md`
- 系统文档：`docs/project/gameplay/systems/`
- 美术方向：`docs/project/art/art-direction.md`
- UI/HUD：`docs/project/ui/hud-spec.md`

## 规则

新游戏 init 时，AI 必须先原样保存用户输入，再提炼出首版设定确认稿。未经用户确认，不得把摘要直接固化为当前游戏设定，也不得开始开发。
