# 通用流派图标生成规格

## Asset Spec: school_icon_common

- Role: 通用流派卡牌的默认卡面图标。
- Source: `procedural_local_generation`
- Prompt file: `docs/project/art/prompts/school_icon_common.md`
- Provider: `local_pil_after_aistudio_timeout`
- Runtime path: `assets/ui/icons_Skill/icon_keji_tongyong.png`
- Godot load path: `res://assets/ui/icons_Skill/icon_keji_tongyong.png`
- Source reference: `assets/ui/icons_Skill/icon_keji_wenyadan.png`, `icon_keji_ganbingdan.png`, `icon_keji_diancichuanci.png`, `icon_keji_qiang.png`
- Size: `116x116`
- Format: `PNG`
- Background: source file uses solid magenta `#FF00FF`; runtime file uses transparent background.
- Style: high-saturation sci-fi card icon, bright rim light, compact readable silhouette, matching existing skill icons.
- Needs slicing: no
- Manifest entry: `docs/project/art/asset-manifest.json`
- Must include: universal tactical emblem, blue/gold energy highlights, readable shape at small card scale.
- Must avoid: text, letters, photo realism, noisy background, square frame, mismatched flat UI style.
- Godot usage: `load("res://assets/ui/icons_Skill/icon_keji_tongyong.png")`

## Prompt

Create a square sci-fi game skill icon matching the existing Godot card school icons: a compact universal tactical emblem made from four glowing energy shards around a bright central core, blue and gold highlights, strong rim lighting, semi-3D painted style, readable at 116x116. Place it on a pure solid magenta background `#FF00FF` for easy chroma-key cutout. No text, no letters, no frame, no UI label, no complex scene background.
