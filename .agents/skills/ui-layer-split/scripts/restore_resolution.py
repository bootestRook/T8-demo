"""
restore_resolution.py
---------------------
Upscale layer-split alpha masks back to the original image resolution,
then composite with original RGB pixels to produce full-resolution RGBA layers.

Usage:
    python restore_resolution.py <original_image> <layers_dir> <output_dir>

Example:
    python restore_resolution.py art-ui/foo.png art-ui/foo_layers1024 art-ui/foo_layers_final
"""

import sys
import os
from PIL import Image


def restore(src: str, layers_dir: str, out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)

    orig = Image.open(src).convert("RGBA")
    W, H = orig.size
    print(f"Original: {W}x{H}")

    pngs = sorted(f for f in os.listdir(layers_dir) if f.endswith(".png"))
    if not pngs:
        print("No PNG files found in layers_dir.")
        sys.exit(1)

    for fname in pngs:
        layer = Image.open(os.path.join(layers_dir, fname)).convert("RGBA")
        lw, lh = layer.size

        if (lw, lh) == (W, H):
            # Already at original resolution, just copy
            layer.save(os.path.join(out_dir, fname))
        else:
            # Upscale alpha with LANCZOS, composite over original RGB
            alpha_up = layer.resize((W, H), Image.LANCZOS)
            r, g, b, _ = orig.split()
            _, _, _, a = alpha_up.split()
            result = Image.merge("RGBA", (r, g, b, a))
            result.save(os.path.join(out_dir, fname))

        print(f"  {fname}: {lw}x{lh} -> {W}x{H}")

    print(f"\nDone. {len(pngs)} layers saved to: {out_dir}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(1)
    restore(sys.argv[1], sys.argv[2], sys.argv[3])
