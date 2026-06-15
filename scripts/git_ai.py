#!/usr/bin/env python3
"""
Git 检查点管理 — godot-v1-plus 脚手架
子命令：init / checkpoint / rollback / doctor
面向新手：checkpoint = 存档点，rollback = 回档
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

POLICY_FILE = Path(__file__).parent.parent / ".ai-git-policy.json"
PROJECT_ROOT = Path(__file__).parent.parent


def find_git() -> str:
    candidates = [
        PROJECT_ROOT / "tools" / "git" / "cmd" / "git.exe",
        PROJECT_ROOT / "tools" / "git" / "bin" / "git.exe",
        PROJECT_ROOT / "tools" / "PortableGit" / "cmd" / "git.exe",
        "git",
    ]
    for candidate in candidates:
        text = str(candidate)
        resolved = shutil.which(text) or (Path(text).is_file() and text)
        if resolved:
            return str(resolved)
    return "git"


def run(args: list[str]) -> tuple[int, str, str]:
    result = subprocess.run(args, capture_output=True, text=True, cwd=PROJECT_ROOT)
    return result.returncode, result.stdout.strip(), result.stderr.strip()


def git(*args: str) -> tuple[int, str, str]:
    return run([find_git()] + list(args))


def read_policy() -> dict:
    if POLICY_FILE.exists():
        try:
            return json.loads(POLICY_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {"autoCommit": False, "commitOnSessionIdle": False, "includeUntracked": True, "messagePrefix": "ai"}


def write_policy(policy: dict) -> None:
    POLICY_FILE.write_text(json.dumps(policy, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def is_git_repo() -> bool:
    code, _, _ = git("rev-parse", "--git-dir")
    return code == 0


def cmd_init(args: argparse.Namespace) -> int:
    if is_git_repo():
        print("[OK] Git 仓库已存在")
    else:
        code, _, err = git("init")
        if code != 0:
            print(f"[FAIL] git init 失败：{err}")
            return 1
        print("[OK] Git 仓库已初始化")

    policy = read_policy()
    policy["autoCommit"] = bool(args.enable_ai_auto_commit)
    policy["commitOnSessionIdle"] = bool(args.enable_ai_auto_commit)
    write_policy(policy)
    print(f"[OK] .ai-git-policy.json 已写入（autoCommit={policy['autoCommit']}）")

    code, status_out, _ = git("status", "--porcelain")
    if status_out and args.create_initial_commit:
        git("add", "-A")
        code, _, err = git("commit", "-m", "ai: initial commit")
        if code == 0:
            print("[OK] 初始存档点已创建")
        else:
            print(f"[WARN] 初始提交失败：{err}")
    elif status_out:
        print("[INFO] 检测到未提交文件；未自动创建提交。需要存档点时请显式运行 checkpoint。")

    return 0


def cmd_checkpoint(args: argparse.Namespace) -> int:
    if not is_git_repo():
        print("[FAIL] 不是 Git 仓库，请先运行：python scripts/git_ai.py init")
        return 1

    _, status_out, _ = git("status", "--porcelain")
    if not status_out:
        print("[INFO] 没有变更，无需创建存档点")
        return 0

    policy = read_policy()
    prefix = policy.get("messagePrefix", "ai")
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    message = args.message or f"{prefix}: checkpoint {timestamp}"

    if policy.get("includeUntracked", True):
        git("add", "-A")
    else:
        git("add", "-u")

    code, _, err = git("commit", "-m", message)
    if code == 0:
        print(f"[OK] 存档点已创建：{message}")
        return 0
    else:
        print(f"[FAIL] 提交失败：{err}")
        return 1


def cmd_rollback(args: argparse.Namespace) -> int:
    if not is_git_repo():
        print("[FAIL] 不是 Git 仓库")
        return 1

    _, log_out, _ = git("log", "--oneline", "-5")
    print("最近存档点：")
    print(log_out or "（暂无）")

    if not args.yes:
        print("\n回档会用 git revert 撤销最近一次提交（不删除历史）")
        print("确认请运行：python scripts/git_ai.py rollback --yes")
        return 0

    code, _, err = git("revert", "HEAD", "--no-edit")
    if code == 0:
        print("[OK] 已回档到上一个存档点")
        return 0
    else:
        print(f"[FAIL] 回档失败：{err}")
        return 1


def cmd_doctor(args: argparse.Namespace) -> int:
    if not is_git_repo():
        print("[WARN] 不是 Git 仓库")
        print("[NEXT] 运行：python scripts/git_ai.py init")
        return 0

    _, log_out, _ = git("log", "--oneline", "-1")
    if log_out:
        print(f"[OK] 最新存档点：{log_out}")
    else:
        print("[WARN] Git 仓库存在但暂无提交")

    policy = read_policy()
    print(f"[INFO] autoCommit={policy.get('autoCommit')}，messagePrefix={policy.get('messagePrefix')}")

    _, status_out, _ = git("status", "--porcelain")
    if status_out:
        print(f"[INFO] 有 {len(status_out.splitlines())} 个文件未存档")
    else:
        print("[OK] 所有变更已存档")

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Godot 游戏 Git 存档管理")
    sub = parser.add_subparsers(dest="command")

    p_init = sub.add_parser("init")
    p_init.add_argument("--enable-ai-auto-commit", action="store_true")
    p_init.add_argument("--create-initial-commit", action="store_true")

    p_cp = sub.add_parser("checkpoint")
    p_cp.add_argument("--message", "-m", default="")

    p_rb = sub.add_parser("rollback")
    p_rb.add_argument("--yes", action="store_true")

    sub.add_parser("doctor")

    args = parser.parse_args()

    if args.command == "init":
        return cmd_init(args)
    elif args.command == "checkpoint":
        return cmd_checkpoint(args)
    elif args.command == "rollback":
        return cmd_rollback(args)
    elif args.command == "doctor":
        return cmd_doctor(args)
    else:
        parser.print_help()
        return 0


if __name__ == "__main__":
    sys.exit(main())
