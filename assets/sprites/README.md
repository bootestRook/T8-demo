# 精灵素材

角色、敌人、道具和特效帧放在这里。

推荐结构：

```text
assets/sprites/player/idle/
assets/sprites/player/walk/
assets/sprites/enemy/slime/idle/
```

切图可使用：

```bash
python scripts/slice_spritesheet.py <sheet.png> --frame-width 64 --frame-height 64 --out-dir assets/sprites/player/walk
```
