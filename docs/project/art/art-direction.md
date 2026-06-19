# 美术方向

## 当前锁定风格

- 概念ID：`vertical-card-defense-demo`
- 项目类型：竖屏 2D 卡牌连锁 + 塔防/幸存者战斗 Demo。
- 风格方向：科幻教堂防线。战场保持冷色、低对比、纵向推进；玩家、防线、怪物、卡牌和 VFX 使用高对比科技视觉，保证手机竖屏可读。

## 运行时素材状态

- 玩家、怪物、战场、防线、卡牌框、HUD 图标和技能流派图标已经落在 `assets/` 或 `addons/`。
- 生成源、后处理文件和运行时绑定记录由 `docs/project/art/asset-manifest.json` 追踪。
- 当前同步不替换图片、不改资源导入、不调整战斗数值，只修正文档事实源。

## 素材计划

- 玩家：保留 `assets/sprites/characters/player_hero_v1.png`，继续作为防线中心角色。
- 怪物：保留 `assets/sprites/monsters/` 下普通、跑者、坦克、精英和教堂 Boss 素材。
- 场景：保留 `assets/sprites/environment/battlefield_v1.png` 与 `defense_wall_staging_v1.png`。
- UI：保留 `assets/ui/cards/`、`assets/ui/hud/`、`assets/ui/icons/`、`assets/ui/icons_Skill/`。
- VFX：保留现有程序化表现、`addons/vfx_library/` 和表现 helper 的统一反馈语言。

## 运行时素材要求

- 运行时代码只能加载 `assets/` 或 `addons/` 中的素材。
- `references/` 只作为参考资料，不允许被运行时代码直接加载。
- HUD、角色、怪物、场景和 VFX 必须服从 `docs/project/art/style-guide.md` 的同一视觉规范。
- 新增或替换正式素材时，必须同步 `docs/project/art/asset-manifest.json`，并通过运行截图证明在玩家视角可见。
