# 可试玩质量标准

## 首版基础闭环必须达标

- 进入画面 5 秒内知道目标。
- 玩家有一个主要操作。
- 操作后 0.5 秒内有明显反馈。
- 一轮体验有开始、变化、结束和重开。
- HUD 不遮挡核心操作区域。
- HUD 必须有响应式防溢出策略：顶部信息在窄屏可重排或压缩，中心提示面板宽度受 viewport 约束，实时玩法中大提示可隐藏或降级。
- 已锁定玩法和美术风格；美术素材满足 `docs/ART_PIPELINE.md` 的最低覆盖标准，暂用占位时必须在 `docs/game-concept.md` 明确说明。
- 正式首版必须有 `docs/project/art/asset-manifest.json` 素材来源清单；程序化、占位和调试图形不能冒充正式运行时素材。
- 真实首版有 UI 素材闭环：没有 PSD/UI 源图时，AI 也必须生成 HUD 图标、按钮、面板、进度条或状态徽章素材，放入 `assets/ui/` 并在运行时代码中真实加载。
- Web 导出成功。
- Godot headless 场景加载通过，不能有 GDScript parse/load/runtime 启动错误。
- Godot 正常运行日志检查通过，不能有编辑器/F5 运行后才出现的脚本错误、无效调用、资源加载失败或崩溃返回码。
- 浏览器预览无白屏、无控制台阻塞错误。
- 视觉/体验类交付必须有浏览器截图证据；至少包含首屏和运行中画面，涉及决策、升级、胜负或结算时还应包含对应界面截图。
- AI 自动试玩验证点击开始、方向键输入和 WASD 输入；完整交付环境应提供 `agent-browser`。
- 视觉可读性轻量审查通过：`python scripts/visual_readability_review.py --strict` 能找到截图、运行中画面基础像素健康、玩家/威胁或目标/UI 素材证据，检查 HUD 响应式布局风险，且未把程序化占位误标为首版素材。
- 非平凡玩法需要补充一段可复现的试玩链路说明或自定义自动化探针，不能把基础 smoke test 误当完整玩法验证。
- 玩法语义审查通过：有成功/失败/重开，有活动边界，激活的玩法蓝图字段完整，当前概念不会污染新游戏。
- 运行时代码不引用 `references/`。
- GDScript Toolkit 必须通过；GDUnit4 为可选检查，失败或缺失不再默认阻塞成果验收。

基础闭环只证明项目能跑、能玩通一轮、能导出。真实游戏默认继续推进到完整首版，不能把基础闭环当成交付 PASS。

## 完整首版游戏标准

- 有清晰核心循环；可以包含多个系统，但系统关系、数据边界和玩家价值必须明确。
- 至少 3 个关卡、波次、挑战单元或系统阶段，且每个单元有明确差异。
- 玩家能看到进度：当前关卡/波次、最佳成绩或完成状态。
- 有明确结算：胜利、失败、本轮表现、下一步。
- 能继续下一关或重试，不需要刷新页面。
- 30 秒内必须出现可感知变化：阶段升级、威胁变化、奖励诱惑、撤离/倒计时压力或目标转折。
- 动作、射击、生存、平台、跑酷、搜打撤等动态品类必须有关键角色动画证据，不能只用静态图交付。
- 至少存在一个玩家决策压力：风险收益、弹药/资源取舍、位置选择、目标优先级或撤离时机。
- HUD、角色、威胁/目标、场景和 VFX 必须来自同一视觉规范和运行时素材包；概念图、风格候选图和参考图不能直接裁剪当正式运行时素材。
- 需求涉及玩家可见内容时，必须完成素材规格、素材包生成或整理、切图/精灵处理、运行时接入和截图证据；只把 PNG 放入目录不算完成。

## AI Review Gate

每轮改动后运行：

```bash
python scripts/ai_review.py --strict
```

本地迭代需要保留 `CONCERNS` 为 0 时，可临时运行：

```bash
python scripts/ai_review.py
```

只做静态和模板审查时可运行：

```bash
python scripts/ai_review.py --skip-runtime
```

`--skip-runtime` 只能用于本机未安装 Godot 或临时环境不可用的场景；交付前必须补跑完整 review。

AI review 覆盖：

- PM 状态一致性。
- Python、PowerShell 和 OpenCode 插件语法。
- 文档路由和脚本路径是否存在。
- 玩法语义审查：`python scripts/gameplay_logic_review.py`。
- 美术管线审查：`python scripts/art_pipeline_review.py`。
- 运行时素材来源清单：`docs/project/art/asset-manifest.json`，检查正式素材、占位、调试图形和截图可见性是否分清。
- 体验结构审查：`python scripts/experience_design_review.py`，严格门禁中缺内容差异、阶段变化、动画、决策压力或结算反馈时为 `FAIL`。
- 架构边界审查：`python scripts/architecture_review.py`，检查模块清单、模块越界、HUD 核心状态写入、`Game.gd` 膨胀和运行时 `references/` 加载。
- 质量门禁：`python scripts/godot_quality_tools.py --json`，默认覆盖 GDScript Toolkit；GDUnit4 可用 `--run-gdunit` 按需启用。
- Godot headless 场景加载：`python scripts/godot_headless_check.py`。
- Godot 正常运行日志：`python scripts/godot_runtime_log_check.py`，覆盖非 headless 项目进程启动后的真实控制台错误。
- Godot 原生截图检查：`python scripts/godot_native_screenshot_check.py --json`，不经浏览器直接保存 viewport 截图，作为日常开发的快速视觉证据；交付 strict 优先使用 Web 浏览器截图，原生截图只作 fallback。
- 运行时代码不直接加载 `references/`，无明显模板文案。
- 模板导出 dry-run 不包含当前仓库 `.git/` 历史、`.pm/`、`.runtime/`、`html5/`、`exports/`，并标明默认包含 `tools/` 工具包、会生成空 Git 仓库。
- Godot 环境、Web 导出和浏览器体验检查。
- 浏览器体验检查会把截图保存到 `reports/screenshots/`；视觉/体验反馈修复后必须用截图证据复核，而不是只看代码或像素 diff。
- 视觉可读性审查：`python scripts/visual_readability_review.py --strict`，只检查基础证据，不判断美丑。
- `experience_check.py` 默认优先 Playwright Python 浏览器后端，失败后回退 `agent-browser`；浏览器自动化缺失时必须说明风险，不能把它误报为已试玩。
- `experience_check.py --strict` 用于交付门禁；默认模式可用于本地迭代，但 `CONCERNS` 不代表完整通过。
- 依赖优先使用 `tools/` 中的 portable 工具。

开发阶段建议：

- GodotMCP 可用时，影响 Godot 运行时的改动后先执行 `run_project -> get_debug_output -> stop_project` 快速诊断，再进入命令行 gate。
- 多 Agent 模式下，子 Agent 的局部检查只作为合并证据；主 AI 必须在主工作区执行最终 `python scripts/ai_review.py --strict`。

结果处理：

- `PASS`：AI 可以把试玩地址或部署包交给人工成果验收。
- `CONCERNS`：AI 先判断是否能自行修复；不能修复时写清原因和风险。
- `FAIL`：AI 不应进入人工成果验收，必须先修复或明确环境阻塞。

`ai_review.py` 会同时输出 Technical、Art、Gameplay、UX、Human Acceptance 五类结果。Technical PASS 不能覆盖 Art/Gameplay/UX 问题；Human Acceptance 默认是待人工验收，用户明确不满意时应记录为 FAIL 并把 PM 需求拉回 doing。

人工验收只判断玩法、画面、反馈、节奏是否接受，以及是否需要下一轮或确认归档。

## 常见扣分项

- 只有计数，没有目标压力。
- 只有基础闭环，没有 3 个有差异内容单元。
- 动态游戏只有静态角色或程序化摆动，没有动作帧/动画接入证据。
- 有操作反应，但不知道为什么。
- 结束后不知道下一步。
- UI 文案解释工程，而不是解释玩法。
- 画面只有裸色块和调试文本，没有主题化。
- 没有 PSD/UI 设计稿就跳过 UI 工作流，或只有代码绘制文字，没有 `assets/ui/` / HUD sprite 运行时证据。
- 素材从 `references/` 加载。
- 没有运行体验检查。
- 涉及 UI、角色、敌人、场景或可见性反馈时，没有浏览器截图证据就宣称已修复。
- HUD 顶栏固定横排、中心提示固定宽度或缺少 gameplay 降级策略，导致小屏溢出或遮挡主体。
- 中度/混合玩法没有写主循环、激活蓝图、系统关系和系统边界。
