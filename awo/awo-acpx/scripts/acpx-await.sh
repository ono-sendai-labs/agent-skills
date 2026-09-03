#!/usr/bin/env bash
# Reattach to a detached turn and wait for it, after supervision was lost.
#
# Usage: acpx-await.sh --out-dir DIR [--poll SEC]
#
# Exit status is acpx-prompt.sh's, and means the same thing:
#   0   the turn completed  (terminal stopReason in the stream)
#   10  the turn is over and produced no stopReason — it really was lost
#   11  THIS waiter was killed; the turn is still running. Reattach again
#   2   usage error
#
# acpx-prompt.sh runs the turn under `setsid`, so a kill aimed at the wrapper
# does not reach the turn. When the harness kills the backgrounded wrapper
# (exit 11, or no exit at all if it was SIGKILLed), the turn is still writing
# out.json. Run this — backgrounded, exactly like the original call — and the
# round continues where it left off. The cost of a harness kill is then one
# reattach, not a destroyed turn.
#
# Everything it needs is in the round directory: turn.pid and turn.meta.

. "$(dirname "$0")/_common.sh"
HERE=$(cd "$(dirname "$0")" && pwd)

OUTDIR= POLL=2
while [ $# -gt 0 ]; do
  case $1 in
    --out-dir) OUTDIR=$2; shift 2;;
    --poll) POLL=$2; shift 2;;
    *) die "unknown argument: $1";;
  esac
done
[ -n "$OUTDIR" ] || die "usage: $0 --out-dir DIR [--poll SEC]"
need python3
[ -d "$OUTDIR" ] || die "no such round directory: $OUTDIR"
[ -e "$OUTDIR/turn.meta" ] || die "no turn.meta in $OUTDIR — that turn was not launched detached"

SESSION=$(awk -F= '/^session=/{print $2}' "$OUTDIR/turn.meta")
START=$(awk -F= '/^start_epoch=/{print $2}' "$OUTDIR/turn.meta")
TURN_PID=$(turn_pid_in "$OUTDIR")
: "${START:=$(date +%s)}"

on_signal() {
  {
    printf '%s waiter SIG%s; turn pid %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" \
      "$TURN_PID" "$(proc_alive "$TURN_PID" && echo alive || echo gone)"
  } >> "$OUTDIR/wrapper-signals.log"
  echo "WAITER KILLED by SIG$1 — the turn is detached and unaffected." >&2
  echo "Reattach with: $HERE/acpx-await.sh --out-dir $OUTDIR" >&2
  exit 11
}
trap 'on_signal TERM' TERM
trap 'on_signal INT'  INT
trap 'on_signal HUP'  HUP

if proc_alive "$TURN_PID"; then
  echo "reattached to turn pid $TURN_PID (session ${SESSION:-?}), running $(( $(date +%s) - START ))s"
else
  echo "turn pid ${TURN_PID:-?} is already gone; summarising what it left"
fi
while proc_alive "$TURN_PID"; do sleep "$POLL"; done

python3 "$HERE/_summarize.py" "$OUTDIR/out.json" "$OUTDIR" "$(( $(date +%s) - START ))" "${SESSION:-?}"
