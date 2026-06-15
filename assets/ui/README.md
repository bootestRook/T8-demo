# UI 素材

UI sprite、按钮、图标、面板纹理放在这里。

PNG/JPG/PSD 来源的 UI 或 sprite sheet 优先通过 `.agents/skills/ui-studio` 提取；背景/前景/主体分层或抠图优先通过 `.agents/skills/ui-layer-split` 处理。

如果用户没有 UI 设计稿，AI 应先用 `asset-prompt-spec` 和 `aistudio-media-generation` 生成 HUD 图标、按钮、面板、进度条或小型 UI sheet，再把最终 sprite 放到本目录并接入 `Hud.gd` 或 `AssetRegistry.gd`。

风格候选图不是 UI 源文件；只有需要从候选图中提取 UI 元素或做主体分层时才进入对应工具。
