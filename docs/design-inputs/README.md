# 用户原始设定

这里保存用户通过 `init` 或后续讨论提供的原始设定和 AI 提炼稿。

## 目录结构

```text
docs/design-inputs/
  <concept-id>/
    README.md       # 输入索引
    source.md       # 第 1 份用户原始输入，原样保存
    source-002.md   # 第 2 份用户原始输入，原样保存
    extracted.md    # AI 提炼稿和确认后的首版范围
```

## 规则

- 用户给出长设定时，AI 必须先原样保存到 `source.md`。
- 同一个概念多轮补充原始设定时，新增 `source-002.md`、`source-003.md`，不得覆盖旧原文。
- AI 可以提炼、裁剪和总结，但不得用摘要覆盖原始输入。
- 用户确认前，提炼稿只是草案，不得直接进入开发。
- 确认后的稳定规则再写入 `docs/project/` 和兼容入口 `docs/game-concept.md`。
