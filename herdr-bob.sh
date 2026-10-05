#!/bin/sh
# Reports IBM Bob (Bob Shell) state and resume command to herdr.
#
# Register this script for Bob's SessionStart, UserPromptSubmit, PreToolUse
# and Stop hooks (see install.py). Bob pipes one JSON payload on stdin with
# session_id, cwd and hook_event_name.
#
# Contract: https://herdr.dev/docs/add-herdr-support/
# - does nothing outside herdr
# - never writes to stdout (Bob adds SessionStart/UserPromptSubmit stdout to
#   the model context)
# - always exits 0 quickly so Bob is never blocked

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
[ -n "${HERDR_SOCKET_PATH:-}" ] || exit 0
if [ -n "${HERDR_BIN_PATH:-}" ]; then
    [ -x "$HERDR_BIN_PATH" ] || exit 0
else
    command -v herdr >/dev/null 2>&1 || exit 0
fi
command -v python3 >/dev/null 2>&1 || exit 0

python3 -c '
import json
import os
import subprocess
import sys
import time

SOURCE = "bob-hooks"
AGENT = "bob"
STATES = {
    "SessionStart": "idle",
    "UserPromptSubmit": "working",
    "PreToolUse": "working",
    "Stop": "idle",
}

def run(args):
    try:
        return subprocess.run(
            args,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1,
            check=False,
        ).returncode
    except Exception:
        return 1

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)

# Opt-in debugging: HERDR_BOB_DEBUG_LOG=/path/to/file records each event.
debug_log = os.environ.get("HERDR_BOB_DEBUG_LOG")
if debug_log:
    try:
        with open(debug_log, "a") as log:
            log.write(json.dumps({
                "event": payload.get("hook_event_name"),
                "session_id": payload.get("session_id"),
                "source": payload.get("source"),
            }) + "\n")
    except Exception:
        pass

state = STATES.get(payload.get("hook_event_name"))
if state is None:
    sys.exit(0)

herdr = os.environ.get("HERDR_BIN_PATH") or "herdr"
args = [
    herdr, "pane", "report-agent", os.environ["HERDR_PANE_ID"],
    "--source", SOURCE, "--agent", AGENT,
    "--state", state, "--seq", str(time.time_ns()),
]

session_id = payload.get("session_id")
if (
    payload.get("hook_event_name") == "SessionStart"
    and isinstance(session_id, str)
    and session_id
    and "\x27" not in session_id
):
    args += ["--agent-session-id", session_id]
    # Resume argv needs herdr >= 0.9.2; older versions reject trailing args,
    # so fall back to a plain session report.
    if run(args + ["--", "bob", "--resume", session_id]) == 0:
        sys.exit(0)
    seq_index = args.index("--seq") + 1
    args[seq_index] = str(time.time_ns())

run(args)
' 2>/dev/null >/dev/null || true
exit 0
