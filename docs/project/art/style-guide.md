# 风格指南

## 概念ID

- `vertical-card-defense-demo`

## 风格锚点

- 当前项目是竖屏 2D 卡牌连锁 + 塔防/幸存者战斗 Demo。
- 视觉方向是科幻教堂防线：下方为玩家与防线阵地，上方为怪物推进区，HUD 与卡牌使用科技卡框、技能流派图标和高对比状态反馈。
- 本文描述当前运行时已经接入的视觉规范；不新增玩法、不改数值、不替换素材。

## 色板

- 主背景：深蓝灰、冷灰、低饱和石材色，用于教堂广场、战场底图和远景压暗层。
- 玩家与可交互反馈：青蓝、电蓝、浅金，用于能量、可出牌、连锁提示和正向反馈。
- 威胁与受击：红、橙红、暗紫，用于怪物、失败压力、受击闪光和燃烧爆炸。
- 流派识别：温压弹偏暖橙红，干冰弹偏冰蓝白，电磁穿刺偏青蓝紫，枪械偏金属灰和枪火黄。
- UI 层级：卡牌底框使用浅色科技面板，费用、名称、插图和描述区保持稳定对比；按钮禁用态降低饱和度但保留轮廓。

## 线条与材质

- 角色、怪物和场景使用清晰轮廓，优先保证 1080x1920 竖屏下的可读性。
- 场景材质偏科幻石材、金属防线和冷色战场；背景低对比，实体和投射物高对比。
- HUD 与卡牌使用硬边科技框、轻描边和明确分区，不混用写实照片、像素风或厚涂 UI。
- 阴影和高光只服务识别，不改变碰撞范围、墙体范围和卡牌命中区域。

## 角色比例

- 玩家英雄固定在防线附近，是防守中心和技能释放源，尺寸高于普通怪物可读阈值。
- 普通怪物从上方向下推进，跑者更窄更快，坦克更宽更厚，精英和 Boss 通过体型、轮廓和色彩体现威胁差异。
- 投射物、爆炸圈、冻结、电磁线和伤害飘字必须覆盖目标关系，但不能遮挡手牌核心文本。
- 升级奖励、牌堆、弃牌堆和结算入口属于 UI 前景层，视觉优先级高于战场背景。

## 场景规则

- 战场采用竖屏纵向推进空间：怪物出生在上方，防线和玩家在下方，墙体表现不改变玩法墙体矩形。
- 内容单元差异通过关卡目标、波次压力、怪物组合和 Boss 压力体现；场景表现保持同一套科幻教堂防线语言。
- `assets/sprites/environment/battlefield_v1.png` 和 `assets/sprites/environment/defense_wall_staging_v1.png` 是当前运行时场景主素材。
- 背景装饰不能抢占怪物、投射物、手牌、能量条和结算 overlay 的视觉优先级。

## UI 形状语言

- HUD 面向竖屏战斗，优先显示关卡、波次、生命/护盾、能量、弹药、手牌、牌堆、弃牌堆和暂停/结算入口。
- 卡牌框、技能图标、费用徽章、连锁提示和奖励选项使用同一套科技面板与清晰分区。
- `assets/ui/cards/card_frame_v1.png` 是当前卡牌模板；`assets/ui/icons_Skill/` 提供温压弹、干冰弹、电磁穿刺、枪械、通用流派图标。
- `assets/ui/hud/` 提供牌堆、弃牌堆、弃整手和暂停图标；`assets/generated/runtime/ui_background_v2/` 提供主菜单与 UI 背景相关运行时素材。

## VFX 气质

- 命中反馈强调短促、明亮、可读：伤害飘字、闪光、震屏、爆炸圈、穿刺线和区域提示要能在移动怪群中辨认。
- 温压弹表现为暖色爆炸和燃烧扩散；干冰弹表现为冰蓝冻结、减速和冰晶；电磁穿刺表现为青蓝穿刺线、爆点和矩阵区域。
- `addons/vfx_library/` 可作为统一 VFX 入口，程序化 VFX 允许存在，但必须遵守同一色彩和层级规则。
- VFX 强度服务出牌、命中、升级、失败/胜利反馈，不覆盖卡牌文字和关键按钮。

## 运行时素材包

- 玩家素材：`assets/sprites/characters/player_hero_v1.png`，由 `AssetRegistry.gd` 和战斗表现层加载。
- 怪物素材：`assets/sprites/monsters/monster_grunt.png`、`monster_runner.png`、`monster_tank.png`、`monster_elite.png`、`monster_boss_cathedral.png`。
- 场景素材：`assets/sprites/environment/battlefield_v1.png`、`assets/sprites/environment/defense_wall_staging_v1.png`。
- UI 素材：`assets/ui/cards/`、`assets/ui/hud/`、`assets/ui/icons/`、`assets/ui/icons_Skill/`。
- 生成源和后处理素材记录在 `assets/generated/runtime/`，运行时绑定状态记录在 `docs/project/art/asset-manifest.json`。
- VFX 和表现 helper 通过 `addons/` 与 `src/game/*Drawer.gd`、`FeedbackDirector.gd`、`AudioDirector.gd` 形成运行时反馈链路。

## 禁止事项

- 不把 `references/`、风格候选图、临时 workspace 文件或概念图裁剪块直接作为运行时素材加载。
- 不把几何占位、纯色块、圆形敌人或调试线条称为正式美术素材。
- 不在本轮同步中替换素材、不改战斗数值、不扩展新玩法入口。
- HUD、角色、怪物、场景和 VFX 不得各自使用冲突的材质、描边、色彩或比例。
