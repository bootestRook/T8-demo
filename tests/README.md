# 测试目录约定

这个脚手架默认把 GDScript Toolkit 作为必选门禁；GDUnit4 属于可选测试层。

- `tests/gdunit/`：GDUnit4 单元/场景测试（可选）。需要先把 GDUnit4 addon 放到 `addons/gdUnit4/`。

统一入口：

```bash
python scripts/setup_quality_tools.py
python scripts/godot_quality_tools.py --json
```

未配置 GDScript Toolkit 时，该入口会失败并阻塞 `ai_review.py --strict`；GDUnit4 缺失默认不阻塞。
