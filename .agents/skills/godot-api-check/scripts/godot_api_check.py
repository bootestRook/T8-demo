#!/usr/bin/env python3
"""Validate Godot API symbols against an exported extension_api.json."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any


EXIT_FOUND = 0
EXIT_ERROR = 1
EXIT_NOT_FOUND = 2


def load_api(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"API file not found: {path}")
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def find_default_api(start: Path) -> Path | None:
    env_path = os.environ.get("GODOT_EXTENSION_API")
    if env_path:
        return Path(env_path)

    candidates: list[Path] = []
    for base in [start, *start.parents]:
        candidates.append(base / ".godot-api" / "extension_api.json")
        candidates.append(base / "mmp" / ".godot-api" / "extension_api.json")

    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def build_indexes(api: dict[str, Any]) -> dict[str, Any]:
    classes = {item["name"]: item for item in api.get("classes", [])}
    builtin_classes = {item["name"]: item for item in api.get("builtin_classes", [])}
    global_enums = {item["name"]: item for item in api.get("global_enums", [])}
    utility_functions = {item["name"]: item for item in api.get("utility_functions", [])}
    singletons = {item["name"]: item for item in api.get("singletons", [])}
    global_constants = {item["name"]: item for item in api.get("global_constants", [])}

    all_classes = dict(classes)
    all_classes.update(builtin_classes)

    return {
        "classes": classes,
        "builtin_classes": builtin_classes,
        "all_classes": all_classes,
        "global_enums": global_enums,
        "utility_functions": utility_functions,
        "singletons": singletons,
        "global_constants": global_constants,
    }


def trim_description(item: dict[str, Any], limit: int = 280) -> dict[str, Any]:
    result = dict(item)
    for key in ("description", "brief_description"):
        value = result.get(key)
        if isinstance(value, str) and len(value) > limit:
            result[key] = value[:limit].rstrip() + "..."
    return result


def print_json(payload: Any) -> None:
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def find_class(indexes: dict[str, Any], name: str) -> dict[str, Any] | None:
    return indexes["all_classes"].get(name)


def iter_enum_values(enum_item: dict[str, Any]) -> list[dict[str, Any]]:
    return enum_item.get("values", [])


def find_members(class_item: dict[str, Any], name: str, kind: str) -> list[tuple[str, dict[str, Any]]]:
    fields_by_kind = {
        "method": ["methods"],
        "property": ["properties", "members"],
        "member": ["methods", "properties", "members", "signals", "constants", "enums"],
        "signal": ["signals"],
        "constant": ["constants"],
        "enum": ["enums"],
        "operator": ["operators"],
        "constructor": ["constructors"],
        "any": [
            "methods",
            "properties",
            "members",
            "signals",
            "constants",
            "enums",
            "operators",
            "constructors",
        ],
    }

    matches: list[tuple[str, dict[str, Any]]] = []
    for field in fields_by_kind[kind]:
        for item in class_item.get(field, []):
            if str(item.get("name", item.get("index", ""))) == name:
                matches.append((field, item))
            if field == "enums":
                for value in iter_enum_values(item):
                    if value.get("name") == name:
                        matches.append(("enum_values", {"enum": item.get("name"), **value}))
    return matches


def find_member(class_item: dict[str, Any], name: str, kind: str) -> tuple[str, dict[str, Any]] | None:
    matches = find_members(class_item, name, kind)
    return matches[0] if matches else None


def command_class(args: argparse.Namespace, indexes: dict[str, Any]) -> int:
    item = find_class(indexes, args.name)
    if not item:
        print(f"NOT FOUND: class {args.name}")
        return EXIT_NOT_FOUND

    payload = {
        "found": True,
        "kind": "class",
        "name": args.name,
        "api_type": item.get("api_type", "builtin"),
        "inherits": item.get("inherits"),
        "is_instantiable": item.get("is_instantiable"),
        "is_refcounted": item.get("is_refcounted"),
        "brief_description": item.get("brief_description"),
    }
    print_json(payload)
    return EXIT_FOUND


def command_member(args: argparse.Namespace, indexes: dict[str, Any]) -> int:
    class_item = find_class(indexes, args.class_name)
    if not class_item:
        print(f"NOT FOUND: class {args.class_name}")
        return EXIT_NOT_FOUND

    matches = find_members(class_item, args.name, args.kind)
    if not matches:
        print(f"NOT FOUND: {args.kind} {args.class_name}.{args.name}")
        return EXIT_NOT_FOUND

    print_json(
        {
            "found": True,
            "class": args.class_name,
            "name": args.name,
            "match_count": len(matches),
            "matches": [
                {
                    "kind": field,
                    "metadata": trim_description(item),
                }
                for field, item in matches
            ],
        }
    )
    return EXIT_FOUND


def command_enum(args: argparse.Namespace, indexes: dict[str, Any]) -> int:
    if args.class_name:
        class_item = find_class(indexes, args.class_name)
        if not class_item:
            print(f"NOT FOUND: class {args.class_name}")
            return EXIT_NOT_FOUND
        match = find_member(class_item, args.name, "enum")
        if not match:
            print(f"NOT FOUND: enum {args.class_name}.{args.name}")
            return EXIT_NOT_FOUND
        print_json({"found": True, "class": args.class_name, "kind": match[0], "metadata": trim_description(match[1])})
        return EXIT_FOUND

    enum_item = indexes["global_enums"].get(args.name)
    if not enum_item:
        print(f"NOT FOUND: global enum {args.name}")
        return EXIT_NOT_FOUND

    print_json({"found": True, "kind": "global_enum", "name": args.name, "metadata": trim_description(enum_item)})
    return EXIT_FOUND


def command_constant(args: argparse.Namespace, indexes: dict[str, Any]) -> int:
    if args.class_name:
        class_item = find_class(indexes, args.class_name)
        if not class_item:
            print(f"NOT FOUND: class {args.class_name}")
            return EXIT_NOT_FOUND
        match = find_member(class_item, args.name, "constant")
        if not match:
            print(f"NOT FOUND: constant {args.class_name}.{args.name}")
            return EXIT_NOT_FOUND
        print_json({"found": True, "class": args.class_name, "kind": match[0], "metadata": trim_description(match[1])})
        return EXIT_FOUND

    item = indexes["global_constants"].get(args.name)
    if not item:
        print(f"NOT FOUND: global constant {args.name}")
        return EXIT_NOT_FOUND

    print_json({"found": True, "kind": "global_constant", "name": args.name, "metadata": trim_description(item)})
    return EXIT_FOUND


def command_signal(args: argparse.Namespace, indexes: dict[str, Any]) -> int:
    class_item = find_class(indexes, args.class_name)
    if not class_item:
        print(f"NOT FOUND: class {args.class_name}")
        return EXIT_NOT_FOUND

    match = find_member(class_item, args.name, "signal")
    if not match:
        print(f"NOT FOUND: signal {args.class_name}.{args.name}")
        return EXIT_NOT_FOUND

    print_json({"found": True, "class": args.class_name, "kind": match[0], "metadata": trim_description(match[1])})
    return EXIT_FOUND


def command_singleton(args: argparse.Namespace, indexes: dict[str, Any]) -> int:
    item = indexes["singletons"].get(args.name)
    if not item:
        print(f"NOT FOUND: singleton {args.name}")
        return EXIT_NOT_FOUND
    print_json({"found": True, "kind": "singleton", "name": args.name, "metadata": item})
    return EXIT_FOUND


def command_utility(args: argparse.Namespace, indexes: dict[str, Any]) -> int:
    item = indexes["utility_functions"].get(args.name)
    if not item:
        print(f"NOT FOUND: utility function {args.name}")
        return EXIT_NOT_FOUND
    print_json({"found": True, "kind": "utility_function", "name": args.name, "metadata": trim_description(item)})
    return EXIT_FOUND


def command_search(args: argparse.Namespace, indexes: dict[str, Any]) -> int:
    term = args.term.lower()
    results: list[dict[str, Any]] = []

    for class_name, class_item in indexes["all_classes"].items():
        if term in class_name.lower():
            results.append({"kind": "class", "name": class_name})
        for field in ("methods", "properties", "members", "signals", "constants", "enums"):
            for item in class_item.get(field, []):
                item_name = str(item.get("name", ""))
                if term in item_name.lower():
                    results.append({"kind": field, "class": class_name, "name": item_name})
                if field == "enums":
                    for value in iter_enum_values(item):
                        value_name = value.get("name", "")
                        if term in value_name.lower():
                            results.append({"kind": "enum_values", "class": class_name, "enum": item_name, "name": value_name})

    for name in indexes["global_enums"]:
        if term in name.lower():
            results.append({"kind": "global_enum", "name": name})
    for name in indexes["global_constants"]:
        if term in name.lower():
            results.append({"kind": "global_constant", "name": name})
    for name in indexes["singletons"]:
        if term in name.lower():
            results.append({"kind": "singleton", "name": name})
    for name in indexes["utility_functions"]:
        if term in name.lower():
            results.append({"kind": "utility_function", "name": name})

    limited = results[: args.limit]
    print_json({"found": bool(results), "count": len(results), "shown": len(limited), "results": limited})
    return EXIT_FOUND if results else EXIT_NOT_FOUND


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate Godot API symbols from extension_api.json.")
    parser.add_argument("--api", type=Path, help="Path to extension_api.json. Defaults to GODOT_EXTENSION_API or a nearby .godot-api file.")
    parser.add_argument("--cwd", type=Path, default=Path.cwd(), help="Start directory for default API discovery.")

    subparsers = parser.add_subparsers(dest="command", required=True)

    class_parser = subparsers.add_parser("class", help="Check an engine or built-in class.")
    class_parser.add_argument("name")
    class_parser.set_defaults(handler=command_class)

    member_parser = subparsers.add_parser("member", help="Check a class member.")
    member_parser.add_argument("class_name")
    member_parser.add_argument("name")
    member_parser.add_argument("--kind", choices=["any", "member", "method", "property", "signal", "constant", "enum", "operator", "constructor"], default="any")
    member_parser.set_defaults(handler=command_member)

    enum_parser = subparsers.add_parser("enum", help="Check a global or class enum.")
    enum_parser.add_argument("name")
    enum_parser.add_argument("--class", dest="class_name")
    enum_parser.set_defaults(handler=command_enum)

    constant_parser = subparsers.add_parser("constant", help="Check a global or class constant.")
    constant_parser.add_argument("name")
    constant_parser.add_argument("--class", dest="class_name")
    constant_parser.set_defaults(handler=command_constant)

    signal_parser = subparsers.add_parser("signal", help="Check a class signal.")
    signal_parser.add_argument("class_name")
    signal_parser.add_argument("name")
    signal_parser.set_defaults(handler=command_signal)

    singleton_parser = subparsers.add_parser("singleton", help="Check a singleton.")
    singleton_parser.add_argument("name")
    singleton_parser.set_defaults(handler=command_singleton)

    utility_parser = subparsers.add_parser("utility", help="Check a utility function.")
    utility_parser.add_argument("name")
    utility_parser.set_defaults(handler=command_utility)

    search_parser = subparsers.add_parser("search", help="Search symbol names for discovery.")
    search_parser.add_argument("term")
    search_parser.add_argument("--limit", type=int, default=25)
    search_parser.set_defaults(handler=command_search)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    api_path = args.api or find_default_api(args.cwd)
    if not api_path:
        print("ERROR: No extension_api.json found. Set GODOT_EXTENSION_API or pass --api.", file=sys.stderr)
        return EXIT_ERROR

    try:
        api = load_api(api_path)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_ERROR

    indexes = build_indexes(api)
    return args.handler(args, indexes)


if __name__ == "__main__":
    raise SystemExit(main())
