#!/usr/bin/env python3
"""Summarize recent Windows Godot access-violation crash evidence."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
WER_ARCHIVE = Path("C:/ProgramData/Microsoft/Windows/WER/ReportArchive")
SUSPICIOUS_MODULE_NAMES = {
    "winhafnt64.dll",
    "winhadnt64.dll",
    "dtframe64.dll",
    "dtsframe64.dll",
    "tijtdrvd64.dll",
    "tmailhook64.dll",
    "winncap364.dll",
}


def _read_text(path: Path) -> str:
    data = path.read_bytes()
    for encoding in ("utf-16", "utf-8", "gb18030"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


def _parse_wer(path: Path) -> dict[str, Any]:
    text = _read_text(path)
    values: dict[str, str] = {}
    modules: list[str] = []
    for line in text.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key.startswith("LoadedModule["):
            modules.append(value.strip())
        else:
            values[key.strip()] = value.strip()

    suspicious = [
        module for module in modules
        if Path(module).name.lower() in SUSPICIOUS_MODULE_NAMES
    ]
    return {
        "report": str(path),
        "app": values.get("Sig[0].Value") or values.get("NsAppName") or "",
        "exception_code": (values.get("Sig[6].Value") or "").lower(),
        "exception_offset": (values.get("Sig[7].Value") or "").lower(),
        "app_path": values.get("AppPath") or values.get("UI[2]") or "",
        "fault_module": values.get("Sig[3].Value") or "",
        "bucket_id": values.get("Response.BucketId") or "",
        "legacy_bucket_id": values.get("Response.LegacyBucketId") or "",
        "suspicious_modules": suspicious,
        "loaded_module_count": len(modules),
        "last_write_time": datetime.fromtimestamp(path.stat().st_mtime).isoformat(timespec="seconds"),
    }


def _recent_wer_reports(days: int) -> list[dict[str, Any]]:
    if sys.platform != "win32" or not WER_ARCHIVE.exists():
        return []
    cutoff = datetime.now() - timedelta(days=max(1, days))
    reports: list[dict[str, Any]] = []
    for directory in WER_ARCHIVE.glob("AppCrash_Godot*"):
        if not directory.is_dir():
            continue
        if datetime.fromtimestamp(directory.stat().st_mtime) < cutoff:
            continue
        report = directory / "Report.wer"
        if not report.exists():
            continue
        try:
            parsed = _parse_wer(report)
        except Exception as exc:
            parsed = {
                "report": str(report),
                "parse_error": str(exc),
                "last_write_time": datetime.fromtimestamp(report.stat().st_mtime).isoformat(timespec="seconds"),
            }
        reports.append(parsed)
    reports.sort(key=lambda item: str(item.get("last_write_time") or ""), reverse=True)
    return reports


def _event_log_crashes(days: int) -> list[dict[str, str]]:
    if sys.platform != "win32":
        return []
    ps = (
        f"$since=(Get-Date).AddDays(-{max(1, days)});"
        "Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=$since} "
        "-ErrorAction SilentlyContinue | "
        "Where-Object { $_.ProviderName -in @('Application Error','Windows Error Reporting') "
        "-and $_.Message -match 'Godot' -and $_.Message -match 'c0000005|0xc0000005' } | "
        "Select-Object -First 30 TimeCreated,ProviderName,Id,Message | ConvertTo-Json -Depth 4"
    )
    try:
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps],
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=20,
            check=False,
        )
    except Exception:
        return []
    if result.returncode != 0 or not result.stdout.strip():
        return []
    try:
        parsed = json.loads(result.stdout)
    except Exception:
        return []
    if isinstance(parsed, dict):
        parsed = [parsed]
    events: list[dict[str, str]] = []
    if not isinstance(parsed, list):
        return events
    for item in parsed:
        if not isinstance(item, dict):
            continue
        message = str(item.get("Message") or "")
        offset = ""
        path = ""
        offset_match = re.search(r"(?:错误偏移量|P8):\s*(?:0x)?([0-9a-fA-F]+)", message)
        if offset_match:
            offset = offset_match.group(1).lower()
        path_match = re.search(r"(?:错误应用程序路径|AppPath):\s*(.+)", message)
        if path_match:
            path = path_match.group(1).strip()
        events.append({
            "time": str(item.get("TimeCreated") or ""),
            "provider": str(item.get("ProviderName") or ""),
            "id": str(item.get("Id") or ""),
            "offset": offset,
            "path": path,
        })
    return events


def build_report(days: int) -> dict[str, Any]:
    wer_reports = _recent_wer_reports(days)
    event_crashes = _event_log_crashes(days)
    suspicious_modules = sorted({
        Path(module).name
        for report in wer_reports
        for module in report.get("suspicious_modules", [])
    })
    offsets = sorted({
        str(report.get("exception_offset") or "")
        for report in wer_reports
        if report.get("exception_offset")
    })
    paths = sorted({
        str(report.get("app_path") or "")
        for report in wer_reports
        if report.get("app_path")
    })
    likely_external = bool(suspicious_modules)
    status = "CONCERNS" if wer_reports or event_crashes else "PASS"
    recommendation = (
        "发现 Godot 0xC0000005 与系统级注入模块同现；建议将 Godot 加入相关安全/管控软件排除项，"
        "或临时禁用注入组件后复测。脚手架自动化应减少非必要 GUI Godot 启动，并优先使用 console/headless/Web 检查。"
        if likely_external else
        "未在 WER 中发现已知注入模块；若仍复现，请收集 dump 或尝试不同 rendering-driver/GPU 驱动。"
    )
    return {
        "status": status,
        "days": days,
        "wer_report_count": len(wer_reports),
        "event_crash_count": len(event_crashes),
        "likely_external_injection": likely_external,
        "suspicious_modules": suspicious_modules,
        "exception_offsets": offsets,
        "app_paths": paths[:12],
        "latest_reports": wer_reports[:5],
        "latest_events": event_crashes[:8],
        "recommendation": recommendation,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Godot Windows 崩溃诊断")
    parser.add_argument("--days", type=int, default=14, help="回看最近多少天")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    report = build_report(args.days)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print("## Godot Crash Diagnostics")
        print(f"- Result: {report['status']}")
        print(f"- WER reports: {report['wer_report_count']}")
        print(f"- Event crashes: {report['event_crash_count']}")
        print(f"- Likely external injection: {report['likely_external_injection']}")
        if report["suspicious_modules"]:
            print("- Suspicious modules: " + ", ".join(report["suspicious_modules"]))
        if report["exception_offsets"]:
            print("- Offsets: " + ", ".join(report["exception_offsets"]))
        print("- Recommendation: " + report["recommendation"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
