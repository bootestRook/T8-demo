# 从这里开始

第一次打开项目时，Windows 用户先双击根目录：

```text
init.cmd
```

如果项目随包携带了 `tools/` portable 依赖，脚本会优先使用它们，并自动解包到稳定路径。完成后，在 OpenCode、Codex 或 Claude Code 对话框输入：

```text
init
```

AI 会自动完成这些事：

- 快速检查 Python、Godot 4、Export Templates、Git。
- 解释当前脚手架能做什么。
- 询问你想做什么游戏。
- 默认按完整游戏首版规划：核心循环、必要系统、至少 3 个有差异内容单元或系统阶段、结算、进度和反馈。
- 根据玩法给出 2-3 个美术方向。
- 使用 AI 图片生成 3 张风格候选图，让你选择并固化。
- 创建 PM 任务板并输出完整首版计划；基础闭环是首版的一部分，不单独作为交付目标。

模板不再自带默认游戏；主场景只用于验证 Godot/Web 启动。请输入 `init` 创建新的玩法、风格、素材计划和完整首版。

你也可以直接说更复杂的创意，例如“肉鸽背包暗黑刷装”“搜打撤塔防”“模拟经营加自走棋”。AI 会先帮你拆成主循环和系统蓝图，再推进第一个完整内容单元。

## 直接在 Godot 编辑器运行

1. 打开 Godot 4。
2. 导入本项目根目录 `project.godot`。
3. 按 `F5` 运行项目，或按 `F6` 运行当前场景。
4. 如果只想快速改玩法，优先用编辑器运行；交付前再跑 Web 导出和严格体验检查。

## 你可以这样说

```text
做一个竖屏躲避生存游戏，Q 版卡通风格，能在浏览器试玩
```

```text
我还没想好，给我 3 个适合 Godot 2D 的玩法建议
```

```text
试玩反馈：目标不清楚，受伤反馈太弱，画面有点像占位符
```

## 推荐流程

1. 输入 `init`。
2. 选择玩法方向。
3. 选择目标层级和平台。
4. 选择美术方向。
5. 等 AI 生成 3 张风格候选图。
6. 选择 A/B/C 或要求重生成。
7. 风格固化后让 AI 做完整首版。
8. 运行或让 AI 打开 Web 预览。
9. 试玩后直接说哪里不好。
10. AI 按反馈迭代，并自动完成 review。
11. 你只验收最终浏览器效果。
12. 满意后打包 Web zip。

## 文件放哪里

- 游戏素材：`assets/`
- AI 生成图片：`assets/generated/`
- 精灵图：`assets/sprites/`
- UI sprite：`assets/ui/`
- 没有 UI 设计稿：先生成 UI sheet、HUD 图标、按钮或面板素材，再接入 `assets/ui/`。
- 概念图只做风格锚点：HUD、角色、怪物、场景和 VFX 必须生成同源运行时素材包，不能直接裁剪候选图当正式素材。
- 自动化测试：`tests/`
- 原始参考：`references/`
- Godot 特效：`addons/vfx_library/`
- GodotMCP 说明：`docs/GODOT_MCP.md`；`init.cmd` 会自动写入项目级 AI MCP 配置，重启或刷新 AI 客户端后生效。
- 当前设定：`docs/game-concept.md`
- 玩法与中度系统蓝图：`docs/GAME_DESIGN_GUIDE.md`
- 历史设定归档：`docs/concepts/`
- AI 工作流：`.agents/skills/`
- portable 工具和可选 GodotMCP：`tools/`

不要让运行时代码直接加载 `references/`。
