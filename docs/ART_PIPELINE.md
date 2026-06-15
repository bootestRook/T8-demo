# 美术与素材流程

## 原则

- 先用玩法目标决定美术，不先堆素材。
- 首版先做成套关键视觉：玩家、主要敌人/目标、场地、核心 UI、关键反馈，并优先覆盖完整首版的内容单元和系统阶段。
- 概念图只作为风格锚点；HUD、角色、怪物、场景和 VFX 必须来自同一视觉规范和运行时素材包，不能各自临时生成或随意裁剪。
- 生成图默认 provider：`gpt-image-2`。
- 运行时素材放 `assets/`，参考资料放 `references/`。

## 图片生成

使用 `.agents/skills/aistudio-media-generation`：

```bash
python .agents/skills/aistudio-media-generation/scripts/media_api.py generate --provider gpt-image-2 --prompt-file prompt.txt --options-file options.json --wait --output downloads --download-dir assets/generated/runtime
```

推荐选项：

- 透明角色/道具：`{"size":"1024x1024","background":"transparent","format":"png"}`
- 横屏背景：`{"size":"1536x1024","background":"opaque","format":"png"}`
- 竖屏背景：`{"size":"1024x1536","background":"opaque","format":"png"}`

## 常用提示词

初始化：

```text
init
```

快速首版：

```text
做一个 2D 完整游戏首版：核心玩法是【玩法】，先确认平台和美术方向，生成 3 张风格候选图让我选择，风格定稿后再做至少 3 个有差异内容单元或系统阶段、结算、进度和反馈，能导出到浏览器试玩。
```

完整首版游戏：

```text
按完整首版游戏做：核心循环、必要系统、至少 3 个内容单元或系统阶段，有胜负结算、本地进度和基础特效。基础闭环只是首版的一部分，交付前要补齐内容差异、系统边界、同源视觉资产和体验结构门禁。
```

生成素材：

```text
请用 aistudio-media-generation 生成【素材类型】，provider 使用 gpt-image-2，尺寸【尺寸】，背景【透明/不透明】，风格保持【风格描述】。
```

试玩反馈：

```text
试玩反馈：【看不懂/不好玩/反馈弱/画面粗糙/太简单/没动画/报错】。请先分类；如果是太简单、没动画、风格割裂或不像游戏，按完整首版补内容差异、系统决策、阶段变化、同源视觉资产、动画和结算反馈，改完运行 Web 导出、体验检查和体验结构审查。
```

## 首启风格定稿

`init` 阶段确认玩法后，AI 必须先生成 3 张风格候选图让用户选择：

1. 根据玩法给出 2-3 个美术方向。
2. 用户选定方向后，用 `asset-prompt-spec` 写风格板规格。
3. 用 `aistudio-media-generation` 和 `gpt-image-2` 生成 3 张候选图。
4. 首选命令：`python scripts/generate_style_candidates.py --prompt-file prompt.txt --provider gpt-image-2 --size 1536x1024 --count 3`。
5. 候选图放入 `assets/generated/style_candidates/`。
6. 用户选择 A/B/C 后，把选中路径、色彩、镜头、角色比例、UI 气质写入 `docs/game-concept.md`。
7. 首版开发前，把风格候选转成运行时视觉规范和同源素材包：沉淀 `docs/project/art/style-guide.md`，再生成或整理当前主题的玩家、主要威胁/目标、场地、HUD/UI 和核心 VFX 素材，必要时为关键角色生成 1-2 个动作、每个动作 4-6 帧，放入 `assets/generated/runtime/`、`assets/sprites/` 或 `assets/ui/`，并在运行时代码中真实加载。
8. 如果媒体服务不可用且用户同意继续，必须在 `docs/game-concept.md` 写入 `素材落地状态：程序化占位`，否则 review 会给 `CONCERNS`。

风格未锁定前，不批量生成角色、敌人、UI 或完整 spritesheet。风格锁定后，动态品类不能只用静态图交付。
风格候选图只作为参考或种子，不要只登记 `assets/generated/style_candidates/` 的候选图就宣称美术已接入。
不要把 JPG 概念图裁剪块、风格候选图或参考图直接接入运行时；确实需要提取主体、前后景或 UI sprite 时，必须用 `ui-layer-split` 或 `ui-studio` 输出透明 PNG/WebP/atlas，再整理到 `assets/`。

## 风格指南与同源视觉包

风格锁定后，AI 必须先把概念图提炼成可执行视觉规范，再生成运行时素材：

- `docs/project/art/style-guide.md`：色板、线条、材质、阴影、角色比例、怪物轮廓、UI 形状语言、按钮/面板规则、VFX 气质。
- `docs/project/art/asset-manifest.json`：运行时素材来源清单，记录每个素材的来源、prompt、provider、路径、是否接入和截图可见性。
- `assets/sprites/`：玩家、怪物、目标、道具、场景交互物。
- `assets/ui/`：HUD 图标、按钮、面板、进度条、状态徽章、结算界面素材。
- `assets/generated/runtime/`：生成源图、spritesheet、背景或待切分素材。
- `AssetRegistry.gd` 或运行时代码：登记并真实加载上述素材。

如果 HUD 是代码色块、角色是从概念图硬切、怪物是另一个风格生成图、背景又是第三种风格，必须判定为视觉资产闭环失败。修复方向是统一 style guide，重新生成或整理同源运行时素材包。

## 素材来源清单

正式首版的运行时素材必须登记到 `docs/project/art/asset-manifest.json`。该清单不是美术文档摘要，而是 review 可读取的证据文件，用来区分正式素材、程序化占位和调试图形。

最小格式：

```json
{
  "version": 1,
  "assets": [
    {
      "id": "player_walk",
      "role": "player_actor",
      "source": "ai_generated",
      "prompt_file": "docs/project/art/prompts/player-walk.md",
      "provider": "gpt-image-2",
      "source_path": "assets/generated/runtime/player-walk-sheet.png",
      "runtime_path": "assets/sprites/player/walk/frame-001.png",
      "transparent_background": true,
      "runtime_bound": true,
      "screenshot_visible": true
    }
  ]
}
```

`source` 只能使用：

- `ai_generated`：AI 生成或 AI 生成后切图整理。
- `hand_drawn`：人工绘制或用户提供且授权使用。
- `third_party`：第三方授权素材。
- `procedural`：代码生成图形。
- `placeholder`：临时占位。
- `debug`：调试图形。

`procedural`、`placeholder`、`debug` 只能支持试玩迭代，不能计入正式首版美术完成。真实首版未声明程序化占位时，缺少 `asset-manifest.json` 或清单仍含临时素材，严格 review 应阻断交付。

## 素材包闭环

用户需求只要会改变玩家看到的角色、敌人、目标、场景、UI、反馈或奖励，就必须把普通开发流程扩展为素材包闭环：

1. `art-spec`：定义本轮 1-3 类最高收益素材，写清用途、尺寸、透明背景、帧数、落地路径和验收截图。
2. `asset-pack`：用 `asset-prompt-spec` 和 `aistudio-media-generation` 生成或整理正式素材源图，保存 prompt 和 provider。
3. `sprite-process`：对 spritesheet、UI sheet 或外部 PNG 做切图、去背景、裁边、统一命名和尺寸，输出到 `assets/sprites/` 或 `assets/ui/`。
4. `runtime-bind`：通过 `AssetRegistry.gd`、`Hud.gd`、表现脚本或场景资源真实加载 `res://assets/...`。
5. `visual-proof`：运行预览并保留截图，更新 `asset-manifest.json` 的 `runtime_bound` 和 `screenshot_visible`。

不要求每轮生成完整资源库，但首版每个可见内容单元至少要有与当前玩法相关的正式运行时素材证据；否则只能标记为“程序化占位版”。

## 首版内容单元美术整合

首版的美术管线必须和关卡/章节计划一起做，不把素材留到最后补：

1. 先列出本轮 3 个内容单元；可以先做完整的第 1 个内容单元，但必须标明不是交付终点。
2. 为每个内容单元写清视觉差异：场地、色彩、主要威胁/目标、奖励、UI 状态或反馈强度。
3. 静态素材按同一风格规范生成或处理最高收益素材，优先是玩家、主要威胁/目标、场地/背景、核心 UI/VFX。
4. 动态品类需要动画时，先确定种子帧和帧规格，再生成 1-2 个动作、每个动作 4-6 帧的矩阵 spritesheet，最后通过 `scripts/process_spritesheet.py` 清理、切帧、对齐并输出到 `assets/sprites/<角色>/<动作>/`。
5. 正式素材必须在运行时代码中真实加载；仅有风格候选图、参考图或未接入 PNG 不算完成。

首版允许用同一套玩家素材贯穿 3 个内容单元，但每个内容单元至少要在布局、目标组合、场地、奖励、阶段压力或反馈强度上体现差异。

## 运行时素材覆盖

用户已锁定风格候选、选择继续做真实项目，且未声明程序化占位时，首版不能只接入背景、地图或一张主视觉。最低覆盖应能在运行时代码中看到这些证据，并服务于当前 3 个内容单元：

- 主角/玩家素材：`player`、`hero`、`avatar` 等路径或 AssetRegistry ID。
- 压力或目标素材：敌人、障碍、平台、收集物、奖励或终点，按玩法选择其一到两类。
- 场地或关卡差异素材：背景、地块、房间、平台、路线、章节视觉标记或配置中的视觉差异。
- 核心 UI 素材或 UI 风格证据：`assets/ui/` 下的 HUD、按钮、面板、图标或经 `ui-studio` 提取的 sprite。

只生成地图/背景但主角、敌人/目标和 UI 仍是纯程序化图形时，视为素材落地不足。媒体服务不可用时可以继续做玩法，但必须把 `素材落地状态：程序化占位` 写入 `docs/game-concept.md`，并在下一轮反馈中优先补素材。

## 精灵流程

1. 先生成或确认一张种子帧。
2. 以种子帧为角色身份锚点，为每个动作单独生成矩阵 spritesheet。4 帧默认 `2x2`，6 帧默认 `2x3`，9 帧默认 `3x3`；角色、敌人、NPC 和召唤物不默认使用原始 `1x4` 横条。
3. 每格等宽等高，主体在安全区内，背景为透明或纯 `#FF00FF` 洋红，不带文字、UI、场景或格线。
4. 用 `scripts/process_spritesheet.py` 清理洋红背景、裁边、切帧、统一缩放和对齐。
5. 玩家、敌人和 NPC 默认使用 `--align feet --shared-scale --reject-edge-touch`，确保底部锚点和帧间比例一致。
6. 放入 `assets/sprites/<角色>/<动作>/`。
7. 在 Godot 中接入 `SpriteFrames` 或按帧加载。
8. 更新 `docs/project/art/asset-manifest.json`：源图、切图输出、`postprocess_meta`、source、是否透明背景、是否接入、截图是否可见。

规则网格 spritesheet 可用：

```bash
python scripts/process_spritesheet.py assets/generated/runtime/player-walk-sheet.png \
  --rows 2 --cols 2 \
  --out-dir assets/sprites/player/walk \
  --output-width 128 --output-height 128 \
  --align feet --shared-scale --reject-edge-touch \
  --prompt-file docs/project/art/prompts/player-walk.md
```

如果生成模型难以稳定保持格子安全区，先生成布局参考图：

```bash
python scripts/make_sprite_layout_guide.py --rows 2 --cols 2 --output assets/generated/runtime/player-walk-guide.png
```

布局参考图只用于约束网格、边距和安全区；最终素材不得保留参考图的线框、文字、标签或背景。

玩家和主角的攻击身体帧不应混入大范围刀光、枪口火焰、弹道、命中特效、烟尘、长拖尾。宽特效会压缩主体比例，应拆成 `fx`、`projectile` 或 `impact` 单独生成、单独接入。

正式动画素材的 `pipeline-meta.json` 必须满足：

- `edge_touch_frames` 为空。
- `frames` 数量等于 `rows * cols`。
- 玩家、敌人、NPC 等主体动画记录 `shared_scale: true`。
- `runtime_path` 指向 `assets/sprites/` 或 `assets/ui/` 下的透明 PNG。

## 地图与 Prop Pack 流程

可玩地图不能只交付一张烘焙大图。根据玩法至少拆出这些层或数据：

- `base`：只包含地面、道路、水体、低矮地表纹理和不可交互底图。
- `props`：透明 PNG 道具，按坐标摆放，必要时参与 Y-sort。
- `actors`：玩家、NPC、敌人、拾取物和移动对象，不烘焙进 base。
- `foreground`：需要盖住角色的前景遮挡层。
- `collision`：矩形、圆、椭圆或多边形元数据，不从 PNG bbox 自动推导。
- `zones`：遭遇区、休息点、出口、触发区、对话区等元数据。
- `preview`：base + props 的扁平 QA 图，只用于视觉验收。

分层地图流程：

1. 先生成 foundation/base，只允许地面和路线，不包含树、门、箱子、NPC、敌人、UI、宝箱、陷阱或需要碰撞/交互的物体。
2. 生成 dressed reference 作为摆放参考，但不把它直接当运行时地图。
3. 对小型静态道具用 prop pack；大型、宽长、碰撞精确或剧情关键物体单独生成。
4. 使用 `scripts/extract_prop_pack.py` 输出透明道具和 `prop-pack.json`。
5. 编写 placement JSON，包含 `x`、`y`、`w`、`h`、`sortY`、`layer`。
6. 使用 `scripts/compose_layered_map_preview.py` 合成 QA 预览。
7. 在 Godot 场景或表现脚本中加载 base、props、碰撞和 zones；运行截图确认玩家视角可读。

Prop pack 只适合小型紧凑静态道具，例如石头、草丛、木箱、桶、小灯、小告示、蘑菇、碎片。不得把平台、地板、桥、墙、梯子、门、建筑、大树、长陷阱、道路、传送点、build pad 或任何需要精确碰撞对齐的物体塞进方形 prop pack。

提取示例：

```bash
python scripts/extract_prop_pack.py assets/generated/runtime/forest-props-sheet.png \
  --rows 3 --cols 3 \
  --labels rock,shrub,log,lamp,sign,flowers,stump,crate,grass \
  --out-dir assets/sprites/props/forest \
  --reject-edge-touch
```

预览合成示例：

```bash
python scripts/compose_layered_map_preview.py \
  --base assets/generated/runtime/forest-base.png \
  --placements docs/project/art/forest-props-placement.json \
  --output assets/generated/runtime/forest-layered-preview.png \
  --report assets/generated/runtime/forest-layered-preview.json
```

`prop-pack.json` 必须登记到 `asset-manifest.json` 的 `prop_pack_meta` 字段；审查会阻断 `edge_touch_props` 非空或没有 accepted 道具的 prop pack。

## UI 流程

- 真实游戏首版默认需要 UI 内容：HUD 图标、按钮、面板、进度条或状态徽章至少覆盖当前玩法；不能因为用户没有 PSD/UI 设计稿就跳过。
- 用户没有 UI 源图时，先用 `asset-prompt-spec` 和 `aistudio-media-generation` 生成一张小型 UI sheet 或 2-3 个独立 UI sprite，再放入 `assets/ui/` 并接入 HUD。
- UI 视觉必须服从当前 `style-guide.md`；HUD 不得与角色、怪物、场景使用明显冲突的材质、描边、色彩或比例。
- PNG/JPG 设计图或 sprite sheet 提取 sprite/layout：用 `.agents/skills/ui-studio`。
- PSD 拆分 sprite 或转 Figma：用 `.agents/skills/ui-studio`。
- 背景/前景/主体分层或抠图：用 `.agents/skills/ui-layer-split`。
- 最终产物放到 `assets/ui/`，临时 workspace 不进入运行时。
- 风格候选图不默认进入 UI 工具；只有需要从图中提取 UI sprite/layout 或主体分层时才用对应 skill。
- 运行时必须能看到 `res://assets/ui/...` 或 HUD/UI sprite 的真实引用；只用代码画文字和色块不算 UI 素材闭环完成。

推荐闭环：

1. `asset-prompt-spec`：定义 HUD 图标、按钮、面板或 UI sheet 的用途、尺寸、透明背景和落地路径。
2. `aistudio-media-generation`：生成 UI 源图或独立 sprite。
3. `ui-studio`：当源图是 UI sheet、PNG/JPG 设计图或 PSD 时提取 sprite/layout。
4. `assets/ui/`：保存最终运行时 PNG/WebP。
5. `AssetRegistry.gd`、`Hud.gd` 或运行时代码：真实加载 `res://assets/ui/...`。
6. `python scripts/art_pipeline_review.py`：验证主角/威胁/目标/UI 覆盖。

## VFX

内置 `addons/vfx_library/`：

- `VFX.screen_shake()`
- `VFX.flash_white()`
- `VFX.spawn_damage_number()`
- `VFX.spawn_energy_burst()`
- `VFX.create_dash_trail()`

项目代码优先通过 `FeedbackDirector.gd` 调用，不在玩法状态里直接依赖 VFX。

## 空脚手架素材

模板不再预置默认游戏素材。新游戏立项后，应先锁定 `docs/game-concept.md` 的美术方向，再生成或接入新的运行时素材。
