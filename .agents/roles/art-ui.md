# Art-UI Agent

## 职责

- 处理素材规格、AI 图片 prompt、运行时素材路径、HUD/UI 接入和美术管线检查。
- 确保运行时素材放入 `assets/` 或 `addons/`，不直接加载 `references/`。

## 常见允许路径

- `assets/`
- `src/game/AssetRegistry.gd`
- `src/ui/Hud.gd`
- `docs/ART_PIPELINE.md`
- `docs/game-concept.md`

## 交付要求

- 列出新增或引用的素材路径。
- 说明素材用途、尺寸、透明背景、帧数或 UI 角色。
- 运行或建议 `python scripts/art_pipeline_review.py`。
- 没有真实素材时，明确说明是否为程序化占位。
