# Lessons

## 2026-06-16

- `scripts/godot_quality_tools.py` only checks gdformat; it does not expose a `--format` mode. When formatting is needed, call the same local gdtoolkit runner used by the script instead of assuming `gdformat` is on PATH.
