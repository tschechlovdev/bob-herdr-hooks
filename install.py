#!/usr/bin/env python3
"""Add or remove the herdr reporter in Bob's global hooks.

Usage: install.py [--uninstall]

Edits ~/.bob/settings/settings.json in place and keeps every other key.
Re-running is safe: existing herdr-bob.sh entries are replaced, not duplicated.
"""
import json
import os
import shlex
import sys
from pathlib import Path

EVENTS = ["SessionStart", "UserPromptSubmit", "PreToolUse", "Stop"]
SCRIPT = Path(__file__).resolve().with_name("herdr-bob.sh")
SETTINGS = Path.home() / ".bob" / "settings" / "settings.json"
COMMAND = "sh " + shlex.quote(str(SCRIPT))


def is_ours(handler):
    return handler.get("type") == "command" and SCRIPT.name in handler.get("command", "")


def strip_ours(hooks):
    for event in list(hooks):
        groups = []
        for group in hooks[event]:
            kept = [h for h in group.get("hooks", []) if not is_ours(h)]
            if kept:
                groups.append({**group, "hooks": kept})
        if groups:
            hooks[event] = groups
        else:
            del hooks[event]


def main():
    uninstall = "--uninstall" in sys.argv[1:]
    settings = json.loads(SETTINGS.read_text()) if SETTINGS.exists() else {}
    hooks = settings.get("hooks", {})
    strip_ours(hooks)

    if not uninstall:
        for event in EVENTS:
            hooks.setdefault(event, []).append(
                {"hooks": [{"type": "command", "command": COMMAND, "timeout": 5}]}
            )

    if hooks:
        settings["hooks"] = hooks
    else:
        settings.pop("hooks", None)

    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    tmp = SETTINGS.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(settings, indent=2) + "\n")
    os.replace(tmp, SETTINGS)
    print(("removed from " if uninstall else "installed into ") + str(SETTINGS))


if __name__ == "__main__":
    main()
