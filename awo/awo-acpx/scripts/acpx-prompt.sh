#!/usr/bin/env bash
# Run one turn against an existing acpx session and report whether it FINISHED.
#
# Usage: acpx-prompt.sh --repo DIR --agent NAME --session NAME \
#                       --prompt-file PATH --out-dir DIR
#
# Exit status describes the TURN, not the acpx client:
#   0   the turn completed  (a terminal result line with a stopReason arrived)
#   10  the turn ended without a stopReason — it is detached, so it may still be
#       running. Do NOT prompt this session again and do NOT touch the working
#       copy until acpx-progress.sh says idle (3) or dead (4)
#   11  THIS WRAPPER was killed; the turn was NOT. Reattach with
#       acpx-await.sh --out-dir DIR
#   2   usage error
#
# THE TURN IS DETACHED, DELIBERATELY. The orchestrating harness has been
# observed killing backgrounded calls ~17-141s after launch, taking unrelated
# background tasks (a bare `sleep`) with them in the same instant, and every
# such kill destroyed an agent turn that had done nothing wrong. So acpx runs
# under `setsid`, in its own process session: a kill aimed at this wrapper's
# process group cannot reach it. The wrapper is only a waiter. If the waiter
# dies the turn keeps writing out.json and can be picked back up by
# acpx-await.sh — turn loss becomes supervision loss, which is recoverable.
#
# This is NOT the "double-backgrounding" the skill forbids. The wrapper blocks
# until the turn is over, so the harness's completion notification still means
# the turn finished. It is the kill path, not the wait path, that changes.
#
# Why not acpx's own exit code: acpx returns 0 with empty output when its
# --timeout fires mid-turn, and 0 when the client is pipe-closed after any
# assistant text has arrived. Verified on 0.13.2. The only sound completion
# signal is the terminal JSON-RPC result carrying "stopReason".
#
# Output format is json (not quiet) deliberately: quiet buffers every chunk and
# flushes only on the stop reason, so a killed turn leaves ZERO bytes, and its
# concatenated messages carry no delimiters. json streams each ACP message as it
# arrives, so the file doubles as a live progress feed and survives a kill.

. "$(dirname "$0")/_common.sh"
HERE=$(cd "$(dirname "$0")" && pwd)

REPO= AGENT= SESSION= PROMPT= OUTDIR=
while [ $# -gt 0 ]; do
  case $1 in
    --repo) REPO=$2; shift 2;;
    --agent) AGENT=$2; shift 2;;
    --session) SESSION=$2; shift 2;;
    --prompt-file) PROMPT=$2; shift 2;;
    --out-dir) OUTDIR=$2; shift 2;;
    *) die "unknown argument: $1";;
  esac
done
[ -n "$REPO" ] && [ -n "$AGENT" ] && [ -n "$SESSION" ] && [ -n "$PROMPT" ] && [ -n "$OUTDIR" ] \
  || die "usage: $0 --repo DIR --agent NAME --session NAME --prompt-file PATH --out-dir DIR"
need acpx; need python3; need setsid
REPO=$(cd "$REPO" && pwd) || die "repo not a directory: $REPO"
[ -f "$PROMPT" ] || die "prompt file not found: $PROMPT"
mkdir -p "$OUTDIR" || die "cannot create out dir: $OUTDIR"

OUT=$OUTDIR/out.json ERR=$OUTDIR/out.err
PIDF=$OUTDIR/turn.pid META=$OUTDIR/turn.meta
LAUNCH=$OUTDIR/turn.launch.sh SIGLOG=$OUTDIR/wrapper-signals.log
rm -f "$PIDF"

# The launcher is written out rather than inlined so the exact command that ran
# is part of the forensic record, and so `exec` makes the recorded pid the acpx
# pid itself rather than a shell wrapping it.
{
  printf '#!/usr/bin/env bash\n'
  printf 'echo $$ > %s\n' "$(printf '%q' "$PIDF")"
  printf 'exec acpx --approve-all --format json --suppress-reads --ttl 0 --cwd %s %s -s %s --file %s > %s 2> %s\n' \
    "$(printf '%q' "$REPO")" "$(printf '%q' "$AGENT")" "$(printf '%q' "$SESSION")" \
    "$(printf '%q' "$PROMPT")" "$(printf '%q' "$OUT")" "$(printf '%q' "$ERR")"
} > "$LAUNCH"
chmod +x "$LAUNCH"

START=$(date +%s)
# No --timeout, by design. Bound the turn by supervision (acpx-progress.sh),
# never by a client-side deadline that destroys in-flight work.
setsid bash "$LAUNCH" </dev/null >/dev/null 2>&1 &
for _ in $(seq 1 100); do [ -s "$PIDF" ] && break; sleep 0.1; done
TURN_PID=$(turn_pid_in "$OUTDIR")
[ -n "$TURN_PID" ] || die "detached turn did not report a pid; see $ERR"

{
  echo "session=$SESSION"
  echo "agent=$AGENT"
  echo "repo=$REPO"
  echo "prompt=$PROMPT"
  echo "turn_pid=$TURN_PID"
  echo "wrapper_pid=$$"
  echo "wrapper_ppid=$PPID"
  echo "start_epoch=$START"
  echo "start_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$META"
echo "turn detached: pid $TURN_PID (session $SESSION)"

# Record what killed us, if anything catchable does. A harness kill has been
# indistinguishable from an explicit stop from inside the session; the signal,
# its timing, and whether our parent outlived us are the evidence that would
# name it. SIGKILL cannot be trapped — an absent log with a dead wrapper is
# itself the finding.
on_signal() {
  {
    printf '%s SIG%s after %ss; turn pid %s %s; parent %s %s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$(( $(date +%s) - START ))" \
      "$TURN_PID" "$(proc_alive "$TURN_PID" && echo alive || echo gone)" \
      "$PPID" "$(proc_alive "$PPID" && echo alive || echo gone)"
    ps -o pid=,ppid=,etimes=,rss=,comm= -p "$TURN_PID" 2>/dev/null
  } >> "$SIGLOG"
  echo "WRAPPER KILLED by SIG$1 — the turn is detached and unaffected." >&2
  echo "Reattach with: $HERE/acpx-await.sh --out-dir $OUTDIR" >&2
  exit 11
}
trap 'on_signal TERM' TERM
trap 'on_signal INT'  INT
trap 'on_signal HUP'  HUP

# Poll rather than `wait`: the turn is in another session and is not our child.
# A short sleep keeps the traps responsive.
while proc_alive "$TURN_PID"; do sleep 2; done

python3 "$HERE/_summarize.py" "$OUT" "$OUTDIR" "$(( $(date +%s) - START ))" "$SESSION"
