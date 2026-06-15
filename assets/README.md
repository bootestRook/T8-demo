# 运行时素材目录

将 Godot 运行时使用的图片、音频、JSON 等素材放在这里。

## 与 references/ 的区别

- `assets/`：Godot 运行时加载的素材，通过 `load("res://assets/...")` 访问
- `references/`：规格包导出的原始游戏资料（截图、AI 总结等），仅供参考，不作为运行时素材

## 命名建议

```
assets/
├── generated/    AI 生成图的首选落点
├── sprites/      角色、敌人、道具帧
├── ui/           UI sprite、图标、按钮
├── audio/        音效（OGG/WAV/MP3）
└── data/         JSON 配置
```

接入素材后让 AI 使用 `godot-asset-audit` skill 检查路径。
