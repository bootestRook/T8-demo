#!/usr/bin/env python3
"""Shared runtime asset coverage helpers for scaffold review scripts."""
from __future__ import annotations

import re
import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ASSET_MANIFEST_REL_PATH = "docs/project/art/asset-manifest.json"
FORMAL_ASSET_SOURCES = {"ai_generated", "hand_drawn", "third_party"}
TEMPORARY_ASSET_SOURCES = {"procedural", "placeholder", "debug"}
VALID_ASSET_SOURCES = FORMAL_ASSET_SOURCES | TEMPORARY_ASSET_SOURCES
RUNTIME_SCAN_PATHS = [
    PROJECT_ROOT / "project.godot",
    PROJECT_ROOT / "export_presets.cfg",
    PROJECT_ROOT / "src",
    PROJECT_ROOT / "scenes",
]
RUNTIME_SOURCE_EXTENSIONS = {".gd", ".tscn", ".tres", ".cfg", ".godot"}
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
AUDIO_EXTENSIONS = {".ogg", ".mp3", ".wav"}
POSTPROCESS_META_KEYS = ("postprocess_meta", "pipeline_meta", "processing_meta")
PROP_PACK_META_KEYS = ("prop_pack_meta", "prop_manifest")
ALLOWED_META_PREFIXES = ("assets/", "docs/project/art/")
ROLE_KEYWORDS = {
    "player_actor": ["player", "hero", "avatar", "protagonist", "character", "主角", "玩家"],
    "challenge_actor": [
        "enemy",
        "monster",
        "foe",
        "boss",
        "hazard",
        "obstacle",
        "platform",
        "spring",
        "trap",
        "spike",
        "威胁",
        "敌人",
        "怪物",
        "平台",
        "弹簧",
    ],
    "objective_pickup": [
        "pickup",
        "collect",
        "coin",
        "star",
        "goal",
        "target",
        "gem",
        "key",
        "reward",
        "目标",
        "收集",
        "星星",
    ],
    "ui_skin": [
        "assets/ui/",
    ],
    "background_map": [
        "background",
        "bg",
        "map",
        "terrain",
        "level",
        "scene",
        "sky",
        "cloud",
        "tile",
        "背景",
        "地图",
        "场景",
    ],
}


def rel(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def safe_read(path: Path) -> str:
    if not path.exists() or not path.is_file():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def runtime_source_files() -> list[Path]:
    files: list[Path] = []
    for path in RUNTIME_SCAN_PATHS:
        if not path.exists():
            continue
        if path.is_file() and path.suffix in RUNTIME_SOURCE_EXTENSIONS:
            files.append(path)
        elif path.is_dir():
            files.extend(
                file for file in path.rglob("*")
                if file.is_file() and file.suffix in RUNTIME_SOURCE_EXTENSIONS
            )
    return sorted(files)


def asset_inventory() -> dict[str, object]:
    assets_dir = PROJECT_ROOT / "assets"
    buckets: dict[str, list[str]] = {
        "images": [],
        "audio": [],
        "generated_style_candidates": [],
        "generated_runtime": [],
        "sprites_non_demo": [],
        "ui": [],
    }
    if assets_dir.exists():
        for file in sorted(assets_dir.rglob("*")):
            if not file.is_file() or file.name.endswith(".import"):
                continue
            path = rel(file)
            suffix = file.suffix.lower()
            if suffix in IMAGE_EXTENSIONS:
                buckets["images"].append(path)
                if path.startswith("assets/generated/style_candidates/"):
                    buckets["generated_style_candidates"].append(path)
                elif path.startswith("assets/generated/"):
                    buckets["generated_runtime"].append(path)
                elif path.startswith("assets/sprites/"):
                    buckets["sprites_non_demo"].append(path)
                elif path.startswith("assets/ui/"):
                    buckets["ui"].append(path)
            elif suffix in AUDIO_EXTENSIONS:
                buckets["audio"].append(path)

    return {
        "counts": {name: len(items) for name, items in buckets.items()},
        "samples": {name: items[:20] for name, items in buckets.items() if items},
    }


def runtime_asset_references(include_audio: bool = False) -> dict[str, list[str]]:
    refs: dict[str, list[str]] = {}
    allowed = IMAGE_EXTENSIONS | (AUDIO_EXTENSIONS if include_audio else set())
    pattern = re.compile(r"res://assets/[A-Za-z0-9_\-./]+")
    for file in runtime_source_files():
        for line_number, line in enumerate(safe_read(file).splitlines(), start=1):
            for match in pattern.findall(line.replace("\\", "/")):
                path = match.removeprefix("res://")
                if Path(path).suffix.lower() not in allowed:
                    continue
                refs.setdefault(path, []).append(f"{rel(file)}:{line_number}")
    return refs


def existing_runtime_asset_references(refs: dict[str, list[str]]) -> dict[str, list[str]]:
    return {
        path: locations
        for path, locations in refs.items()
        if (PROJECT_ROOT / path).is_file()
    }


def missing_runtime_assets(refs: dict[str, list[str]]) -> dict[str, list[str]]:
    return {
        path: locations
        for path, locations in refs.items()
        if not (PROJECT_ROOT / path).is_file()
    }


def role_coverage(refs: dict[str, list[str]]) -> dict[str, list[str]]:
    result = {role: [] for role in ROLE_KEYWORDS}
    for path, locations in refs.items():
        if Path(path).suffix.lower() not in IMAGE_EXTENSIONS:
            continue
        if path.startswith("assets/ui/"):
            result["ui_skin"].append(f"{path} @ {locations[0]}")
            continue
        haystack = path.lower()
        for role, keywords in ROLE_KEYWORDS.items():
            if role == "ui_skin":
                continue
            if any(keyword.lower() in haystack for keyword in keywords):
                result[role].append(f"{path} @ {locations[0]}")
    return result


def generated_runtime_refs(refs: dict[str, list[str]]) -> list[str]:
    return [
        path for path in refs
        if path.startswith("assets/generated/") and "assets/generated/style_candidates/" not in path
    ]


def asset_manifest_path() -> Path:
    return PROJECT_ROOT / ASSET_MANIFEST_REL_PATH


def load_asset_manifest(path: Path | None = None) -> tuple[dict[str, object] | None, list[str]]:
    manifest_path = path or asset_manifest_path()
    if not manifest_path.exists():
        return None, []
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as exc:
        return None, [f"{ASSET_MANIFEST_REL_PATH} 不是合法 JSON：{exc}"]
    if not isinstance(data, dict):
        return None, [f"{ASSET_MANIFEST_REL_PATH} 顶层必须是 object。"]
    assets = data.get("assets")
    if not isinstance(assets, list):
        return data, [f"{ASSET_MANIFEST_REL_PATH} 必须包含 assets 数组。"]
    return data, []


def _manifest_asset_path(asset: dict[str, object]) -> str:
    value = str(asset.get("runtime_path") or asset.get("godot_path") or "")
    return value.replace("res://", "").replace("\\", "/")


def _manifest_asset_role(asset: dict[str, object]) -> str:
    return str(asset.get("role") or asset.get("category") or "").strip().lower()


def _manifest_asset_source(asset: dict[str, object]) -> str:
    return str(asset.get("source") or asset.get("source_type") or "").strip().lower()


def _manifest_optional_path(asset: dict[str, object], keys: tuple[str, ...]) -> str:
    for key in keys:
        value = str(asset.get(key) or "").strip()
        if value:
            return value.replace("res://", "").replace("\\", "/")
    return ""


def _is_safe_project_meta_path(path: str) -> bool:
    candidate = Path(path)
    normalized = path.replace("\\", "/")
    if candidate.is_absolute() or ".." in candidate.parts:
        return False
    return any(normalized.startswith(prefix) for prefix in ALLOWED_META_PREFIXES)


def _path_parts(path: str) -> list[str]:
    return [part.lower() for part in Path(path.replace("\\", "/")).parts]


def _requires_shared_scale(asset: dict[str, object]) -> bool:
    role = _manifest_asset_role(asset)
    path = _manifest_asset_path(asset).lower()
    parts = _path_parts(path)
    body_markers = [
        "player",
        "hero",
        "avatar",
        "character",
        "enemy",
        "monster",
        "foe",
        "boss",
        "npc",
        "creature",
        "summon",
        "主角",
        "玩家",
        "敌人",
        "怪物",
        "角色",
    ]
    non_body_roles = {"ui_skin", "fx", "vfx", "projectile", "impact", "prop", "background_map"}
    non_body_parts = {"ui", "hud", "fx", "vfx", "projectile", "impact", "props", "prop", "background", "map", "maps"}
    if role in non_body_roles or path.startswith("assets/ui/") or any(part in non_body_parts for part in parts):
        return False
    haystack = f"{role} {' '.join(parts)}"
    return any(marker in haystack for marker in body_markers)


def _positive_int(value: object) -> int | None:
    try:
        parsed = int(value or 0)
    except (TypeError, ValueError):
        return None
    return parsed if parsed > 0 else None


def manifest_role_coverage(
    manifest: dict[str, object] | None,
    refs: dict[str, list[str]] | None = None,
) -> dict[str, list[str]]:
    result = {role: [] for role in ROLE_KEYWORDS}
    if not manifest:
        return result
    assets = manifest.get("assets")
    if not isinstance(assets, list):
        return result
    ref_paths = set(refs or {})
    if not ref_paths:
        return result
    for raw_asset in assets:
        if not isinstance(raw_asset, dict):
            continue
        source = _manifest_asset_source(raw_asset)
        if source in TEMPORARY_ASSET_SOURCES:
            continue
        path = _manifest_asset_path(raw_asset)
        if source not in FORMAL_ASSET_SOURCES:
            continue
        if not bool(raw_asset.get("runtime_bound")):
            continue
        if not path or not (PROJECT_ROOT / path).is_file():
            continue
        if path not in ref_paths:
            continue
        role_text = _manifest_asset_role(raw_asset)
        haystack = f"{role_text} {path}".lower()
        for role, keywords in ROLE_KEYWORDS.items():
            if role == "ui_skin" and path.startswith("assets/ui/"):
                result[role].append(path or str(raw_asset.get("id") or "unnamed"))
                continue
            if any(keyword.lower() in haystack for keyword in keywords):
                result[role].append(path or str(raw_asset.get("id") or "unnamed"))
    return result


def validate_asset_manifest(
    manifest: dict[str, object] | None,
    refs: dict[str, list[str]] | None = None,
) -> dict[str, object]:
    if manifest is None:
        return {
            "exists": False,
            "errors": [],
            "warnings": [],
            "formal_assets": [],
            "formal_runtime_assets": [],
            "temporary_assets": [],
            "role_coverage": manifest_role_coverage(None, refs),
        }

    errors: list[str] = []
    warnings: list[str] = []
    formal_assets: list[str] = []
    formal_runtime_assets: list[str] = []
    temporary_assets: list[str] = []
    postprocess_errors: list[str] = []
    postprocess_warnings: list[str] = []
    assets = manifest.get("assets")
    if not isinstance(assets, list):
        errors.append("assets 必须是数组。")
        assets = []

    ref_paths = set(refs or {})
    for index, raw_asset in enumerate(assets, start=1):
        if not isinstance(raw_asset, dict):
            errors.append(f"assets[{index}] 必须是 object。")
            continue
        asset_id = str(raw_asset.get("id") or f"assets[{index}]")
        source = _manifest_asset_source(raw_asset)
        path = _manifest_asset_path(raw_asset)
        postprocess_meta = _manifest_optional_path(raw_asset, POSTPROCESS_META_KEYS)
        prop_pack_meta = _manifest_optional_path(raw_asset, PROP_PACK_META_KEYS)
        runtime_bound = bool(raw_asset.get("runtime_bound"))
        screenshot_visible = bool(raw_asset.get("screenshot_visible"))

        if not source:
            errors.append(f"{asset_id} 缺少 source。")
        elif source not in VALID_ASSET_SOURCES:
            errors.append(f"{asset_id} source 非法：{source}。")

        if source in FORMAL_ASSET_SOURCES:
            formal_assets.append(asset_id)
            if (
                runtime_bound
                and path
                and (PROJECT_ROOT / path).is_file()
                and path in ref_paths
                and screenshot_visible
            ):
                formal_runtime_assets.append(asset_id)
        elif source in TEMPORARY_ASSET_SOURCES:
            temporary_assets.append(asset_id)

        if not path:
            errors.append(f"{asset_id} 缺少 runtime_path 或 godot_path。")
            continue
        if path.startswith("references/") or "assets/generated/style_candidates/" in path:
            errors.append(f"{asset_id} 不能把 references 或 style_candidates 当运行时素材：{path}。")
        if not (path.startswith("assets/") or path.startswith("addons/")):
            errors.append(f"{asset_id} 运行时素材路径必须位于 assets/ 或 addons/：{path}。")
        if runtime_bound and not (PROJECT_ROOT / path).exists():
            errors.append(f"{asset_id} 声明已接入但文件不存在：{path}。")
        if runtime_bound and ref_paths and path not in ref_paths:
            warnings.append(f"{asset_id} 声明已接入，但运行时代码未发现引用：{path}。")
        if source in FORMAL_ASSET_SOURCES and runtime_bound and not screenshot_visible:
            warnings.append(f"{asset_id} 是正式素材且已接入，但未标记截图可见。")
        if source in TEMPORARY_ASSET_SOURCES and runtime_bound:
            warnings.append(f"{asset_id} 仍是 {source}，不能计入正式首版素材完成。")

        if postprocess_meta:
            if not _is_safe_project_meta_path(postprocess_meta):
                postprocess_errors.append(
                    f"{asset_id} postprocess_meta 必须是项目内相对路径，且位于 assets/ 或 docs/project/art/：{postprocess_meta}。"
                )
                meta_path = None
            else:
                meta_path = PROJECT_ROOT / postprocess_meta
            if meta_path is None:
                pass
            elif not meta_path.is_file():
                postprocess_errors.append(f"{asset_id} postprocess_meta 文件不存在：{postprocess_meta}。")
            else:
                try:
                    meta = json.loads(meta_path.read_text(encoding="utf-8"))
                except Exception as exc:
                    postprocess_errors.append(f"{asset_id} postprocess_meta 不是合法 JSON：{exc}。")
                else:
                    edge_touch_frames = meta.get("edge_touch_frames", [])
                    if edge_touch_frames:
                        postprocess_errors.append(f"{asset_id} 后处理发现帧触边：{edge_touch_frames}。")
                    rows = _positive_int(meta.get("rows"))
                    cols = _positive_int(meta.get("cols"))
                    frames = meta.get("frames")
                    if rows is None or cols is None:
                        postprocess_errors.append(f"{asset_id} postprocess_meta rows/cols 必须是正整数。")
                    elif not isinstance(frames, list) or len(frames) != rows * cols:
                        postprocess_errors.append(f"{asset_id} postprocess_meta 帧数量与 rows/cols 不一致。")
                    if source in FORMAL_ASSET_SOURCES and _requires_shared_scale(raw_asset) and not bool(meta.get("shared_scale")):
                        postprocess_warnings.append(f"{asset_id} 动画素材未记录 shared_scale；角色帧可能存在缩放漂移。")

        if prop_pack_meta:
            if not _is_safe_project_meta_path(prop_pack_meta):
                postprocess_errors.append(
                    f"{asset_id} prop_pack_meta 必须是项目内相对路径，且位于 assets/ 或 docs/project/art/：{prop_pack_meta}。"
                )
                prop_meta_path = None
            else:
                prop_meta_path = PROJECT_ROOT / prop_pack_meta
            if prop_meta_path is None:
                pass
            elif not prop_meta_path.is_file():
                postprocess_errors.append(f"{asset_id} prop_pack_meta 文件不存在：{prop_pack_meta}。")
            else:
                try:
                    prop_meta = json.loads(prop_meta_path.read_text(encoding="utf-8"))
                except Exception as exc:
                    postprocess_errors.append(f"{asset_id} prop_pack_meta 不是合法 JSON：{exc}。")
                else:
                    edge_touch_props = prop_meta.get("edge_touch_props", [])
                    if edge_touch_props:
                        postprocess_errors.append(f"{asset_id} prop pack 发现道具触边：{edge_touch_props}。")
                    if not prop_meta.get("accepted"):
                        postprocess_errors.append(f"{asset_id} prop pack 没有 accepted 道具。")

    return {
        "exists": True,
        "errors": errors + postprocess_errors,
        "warnings": warnings + postprocess_warnings,
        "formal_assets": formal_assets,
        "formal_runtime_assets": formal_runtime_assets,
        "temporary_assets": temporary_assets,
        "role_coverage": manifest_role_coverage(manifest, refs),
    }
