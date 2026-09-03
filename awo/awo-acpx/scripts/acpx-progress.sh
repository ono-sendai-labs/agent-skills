#!/usr/bin/env bash
# Answer "is this turn still making progress?" without disturbing it.
#
# Usage: acpx-progress.sh --repo DIR --agent NAME --session NAME [--out-dir DIR]
#
# Exit status:
#   0  working    — new ACP events within --idle-warn seconds
#   1  stalled    — alive but no new events for longer than --idle-warn
#   3  idle       — no turn in flight (finished, or never started)
#
# Liveness is defined as growth of the ACP wire log, NOT as `status -s` saying
# `running`. A pipe-closed adapter has been observed reporting `running` with a
# live pid for five minutes after its turn was already dead, and the reverse —
# `disconnectReason: pipe_close` with a lastExitAt — appears on a healthy
# session that has merely been configured and not yet prompted. Neither field
# discriminates. Event growth does.

. "$(dirname "$0")/_common.sh"

REPO= AGENT= SESSION= OUTDIR= IDLE_WARN=900
while [ $# -gt 0 ]; do
  case $1 in
    --repo) REPO=$2; shift 2;;
    --agent) AGENT=$2; shift 2;;
    --session) SESSION=$2; shift 2;;
    --out-dir) OUTDIR=$2; shift 2;;
    --idle-warn) IDLE_WARN=$2; shift 2;;
    *) die "unknown argument: $1";;
  esac
done
[ -n "$REPO" ] && [ -n "$AGENT" ] && [ -n "$SESSION" ] \
  || die "usage: $0 --repo DIR --agent NAME --session NAME [--out-dir DIR] [--idle-warn SEC]"
need acpx; need python3
REPO=$(cd "$REPO" && pwd) || die "repo not a directory: $REPO"

WIRE=$(wire_log_for "$AGENT" "$SESSION" "$REPO")
STATUS=$(acpx --cwd "$REPO" "$AGENT" status -s "$SESSION" 2>/dev/null)
THREAD=$(printf '%s\n' "$STATUS" | awk '/^status:/{print $2}')
PID=$(printf '%s\n' "$STATUS" | awk '/^pid:/{print $2}')

echo "session:   $SESSION"
echo "adapter:   status=${THREAD:-?} pid=${PID:-?}   (advisory only — not a liveness test)"

if [ -z "$WIRE" ] || [ ! -e "$WIRE" ]; then
  echo "wire log:  (none yet)"
  exit 3
fi
WIRE_AGE=$(mtime_age "$WIRE")
echo "wire log:  $WIRE"
echo "last event: ${WIRE_AGE}s ago"

if [ -n "$OUTDIR" ] && [ -e "$OUTDIR/out.json" ]; then
  echo "turn out:  $(wc -l < "$OUTDIR/out.json") lines, last written $(mtime_age "$OUTDIR/out.json")s ago"
  if grep -q '"stopReason"' "$OUTDIR/out.json" 2>/dev/null; then
    echo "verdict:   IDLE — this turn's stream carries a terminal stopReason"
    exit 3
  fi
fi

python3 - "$WIRE" <<'PY'
import json, sys
last_tool, n_tools, n_msgs = None, 0, 0
for line in open(sys.argv[1], errors="replace"):
    try: d = json.loads(line)
    except Exception: continue
    u = ((d.get("params") or {}).get("update") or {}) if isinstance(d.get("params"), dict) else {}
    su = u.get("sessionUpdate")
    if su in ("tool_call", "tool_call_update"):
        n_tools += 1
        last_tool = u.get("title") or u.get("toolCallId") or last_tool
    elif su == "agent_message_chunk":
        n_msgs += 1
print(f"activity:  {n_tools} tool events, {n_msgs} message chunks")
if last_tool:
    print(f"last tool: {str(last_tool)[:140]}")
PY

if [ "$WIRE_AGE" -gt "$IDLE_WARN" ]; then
  echo "verdict:   STALLED — no ACP event for ${WIRE_AGE}s (threshold ${IDLE_WARN}s)"
  exit 1
fi
echo "verdict:   WORKING"
exit 0
