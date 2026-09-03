#!/usr/bin/env bash
# Answer "is this turn still making progress?" without disturbing it.
#
# Usage: acpx-progress.sh --repo DIR --agent NAME --session NAME [--out-dir DIR]
#                         [--idle-warn SEC] [--dead-after SEC]
#
# Exit status:
#   0  working    — new ACP events within --idle-warn seconds
#   1  stalled    — alive but no new events for longer than --idle-warn
#   3  idle       — no turn in flight (finished, or never started)
#   4  DEAD       — the turn's process is gone and it never produced a
#                   stopReason. The turn is over and it was lost. Recover.
#
# The `dead` verdict exists because RUN 3 spent about four minutes per kill
# proving something this script already had the evidence for. Without it the
# script reports WORKING for a turn with no process behind it — for --idle-warn
# seconds, then STALLED forever, and it NEVER reports idle, because idle means
# "a stopReason arrived" and a killed turn is exactly the turn that has none.
# §Recovering's old "poll until it reports 3" was therefore unreachable on the
# one path it was written for.
#
# Liveness is growth of the ACP wire log, NOT `status -s` saying `running`. A
# pipe-closed adapter has been observed reporting `running` with a live pid for
# five minutes after its turn was already dead, and the reverse —
# `disconnectReason: pipe_close` with a lastExitAt — appears on a healthy
# session that has merely been configured and not yet prompted. Neither field
# discriminates. Event growth does.
#
# Death is different, and it is decidable: `turn.pid` (written by
# acpx-prompt.sh, the pid of the acpx client itself) either exists as a process
# or it does not. `pid: -` in `status -s` plus a wire log that has stopped
# growing is not advisory — there is nothing left to produce an event.

. "$(dirname "$0")/_common.sh"

REPO= AGENT= SESSION= OUTDIR= IDLE_WARN=900 DEAD_AFTER=60
while [ $# -gt 0 ]; do
  case $1 in
    --repo) REPO=$2; shift 2;;
    --agent) AGENT=$2; shift 2;;
    --session) SESSION=$2; shift 2;;
    --out-dir) OUTDIR=$2; shift 2;;
    --idle-warn) IDLE_WARN=$2; shift 2;;
    --dead-after) DEAD_AFTER=$2; shift 2;;
    *) die "unknown argument: $1";;
  esac
done
[ -n "$REPO" ] && [ -n "$AGENT" ] && [ -n "$SESSION" ] \
  || die "usage: $0 --repo DIR --agent NAME --session NAME [--out-dir DIR] [--idle-warn SEC] [--dead-after SEC]"
need acpx; need python3
REPO=$(cd "$REPO" && pwd) || die "repo not a directory: $REPO"

WIRE=$(wire_log_for "$AGENT" "$SESSION" "$REPO")
STATUS=$(acpx --cwd "$REPO" "$AGENT" status -s "$SESSION" 2>/dev/null)
THREAD=$(printf '%s\n' "$STATUS" | awk '/^status:/{print $2}')
PID=$(printf '%s\n' "$STATUS" | awk '/^pid:/{print $2}')

TURN_PID= TURN_STATE=
if [ -n "$OUTDIR" ]; then
  TURN_PID=$(turn_pid_in "$OUTDIR")
  if [ -n "$TURN_PID" ]; then
    proc_alive "$TURN_PID" && TURN_STATE=alive || TURN_STATE=gone
  fi
fi

echo "session:   $SESSION"
echo "adapter:   status=${THREAD:-?} pid=${PID:-?}   (status is advisory; pid is not)"
[ -n "$TURN_PID" ] && echo "turn:      pid $TURN_PID $TURN_STATE"

if [ -z "$WIRE" ] || [ ! -e "$WIRE" ]; then
  echo "wire log:  (none yet)"
  # A recorded turn pid that is already gone with no wire log at all is a turn
  # that died before it said anything — the front-loaded kill this skill sees.
  if [ "$TURN_STATE" = gone ] && ! turn_finished_in "$OUTDIR"; then
    echo "verdict:   DEAD — turn process gone, no events, no stopReason"
    exit 4
  fi
  exit 3
fi
WIRE_AGE=$(mtime_age "$WIRE")
echo "wire log:  $WIRE"
echo "last event: ${WIRE_AGE}s ago"

if [ -n "$OUTDIR" ] && [ -e "$OUTDIR/out.json" ]; then
  echo "turn out:  $(wc -l < "$OUTDIR/out.json") lines, last written $(mtime_age "$OUTDIR/out.json")s ago"
  if turn_finished_in "$OUTDIR"; then
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

# Death, before stall or work: no stopReason has arrived (checked above) and
# nothing is left that could produce one.
if [ "$TURN_STATE" = gone ]; then
  echo "verdict:   DEAD — turn process $TURN_PID is gone and the stream carries no stopReason"
  echo "           (last event ${WIRE_AGE}s ago; capture evidence and recover per §Recovering)"
  exit 4
fi
if [ -z "$TURN_PID" ] && [ "${PID:-−}" = "-" ] && [ "$WIRE_AGE" -gt "$DEAD_AFTER" ]; then
  echo "verdict:   DEAD — no adapter pid and no ACP event for ${WIRE_AGE}s (threshold ${DEAD_AFTER}s)"
  echo "           (no turn.pid recorded, so this rests on \`status -s\` reporting no pid)"
  exit 4
fi

if [ "$WIRE_AGE" -gt "$IDLE_WARN" ]; then
  echo "verdict:   STALLED — no ACP event for ${WIRE_AGE}s (threshold ${IDLE_WARN}s)"
  exit 1
fi
echo "verdict:   WORKING"
exit 0
