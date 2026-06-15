---
name: agent-browser
description: Browser automation CLI for AI agents. Use when the user asks to open or test a website, automate a browser, take screenshots, inspect console errors, or verify a Godot Web build in a real browser. In this scaffold, prefer running scripts/experience_check.py first; use direct agent-browser commands for extra diagnosis.
---

# Agent Browser

## Role In This Scaffold

`agent-browser` is the recommended browser automation tool for Godot Web runtime checks. It is used by `scripts/experience_check.py` when available to:

- open the local Web preview URL;
- inspect page and Godot console errors;
- verify canvas size and pixel health;
- click the canvas to start;
- send Arrow/WASD input and a short generic interaction sequence.

Do not make normal game development depend on browser automation. If `agent-browser` is missing, `experience_check.py` reports `CONCERNS` and the AI must explain that the browser automation layer is unavailable.

## Availability

The project looks for `agent-browser` in this order:

1. `AGENT_BROWSER_PATH`
2. `tools/agent-browser/agent-browser.exe`
3. `tools/agent-browser/agent-browser.cmd`
4. `tools/agent-browser/agent-browser.ps1`
5. system `PATH`

The default clean scaffold does not bundle Chrome or `agent-browser` binaries. This keeps the template small and avoids platform-specific browser payloads. A full offline QA package may place a portable `agent-browser` command under `tools/agent-browser/`.

## Preferred Workflow

For Godot Web projects, prefer the deterministic project scripts:

```bash
python scripts/export_web.py --json
python scripts/run_web_preview.py --json
python scripts/experience_check.py --strict
python scripts/ai_review.py --strict
```

Use direct CLI commands only when investigating a runtime issue:

```bash
agent-browser batch "open http://localhost:8090" "snapshot -i" "screenshot"
agent-browser errors
agent-browser console
agent-browser set viewport 390 844
agent-browser click canvas
agent-browser press ArrowRight
agent-browser keyboard type d
agent-browser close
```

## Installation Guidance

If the CLI is missing, tell the user the options instead of silently installing:

```bash
npm i -g agent-browser
agent-browser install
```

or use another supported installation method from the upstream tool. Installing globally, downloading Chrome, or changing system configuration requires explicit user confirmation.

## Safety

- Do not store browser state, cookies, auth files, or credentials in the repository.
- Add any state files, screenshots, HAR files, and browser profiles to ignored local paths.
- Close sessions after diagnostics with `agent-browser close` or `agent-browser close --all`.
- For destructive website actions, ask for explicit confirmation before clicking final submit/delete/payment controls.
