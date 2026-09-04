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
# THE TURN IS DETACHED, DELIBERATELY -- BUT THAT IS NOT A GUARANTEE. The
# orchestrating harness kills backgrounded calls in the first ~60s after launch.
# A host-side syscall trace shows `claude` issuing one killpg on this wrapper's
# process group followed by kill(pid, SIGTERM) on every descendant it can
# enumerate. `setsid` defeats the killpg -- confirmed, the turn holds its own
# SID and PGID -- but NOT the per-pid tree walk, which has been observed taking
# the wrapper, the turn, the whole adapter chain and this script's own poll
# `sleep` in a single 210us burst.
#
# So the turn survives the wrapper only sometimes, and exit 11 means "the
# wrapper died", not "the turn lived". The caller MUST check acpx-progress.sh
# before reattaching. What does hold unconditionally is that out.json is
# streamed, so a killed turn still leaves its partial transcript on disk.
# Reparenting to pid 1 (a double fork) is the only mechanism observed to
# survive the tree walk; it is deliberately not done here.
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
  # Report what is true, not what we hope. The harness kills by walking the process tree and
  # signalling each descendant by pid, so it crosses the setsid boundary: the turn is killed
  # with the wrapper as often as not. Saying "unaffected" unconditionally -- in the same
  # invocation whose own log line records the turn already dead -- misled the orchestrator.
  # NOTE: this read can still race the kill. The whole burst lands in ~200us, so the turn's
  # own SIGTERM may not have been delivered yet and we will report 'alive' for a turn that
  # is about to die. acpx-progress.sh is the authoritative check; this line is a hint.
  local turn_state
  turn_state=$(proc_alive "$TURN_PID" && echo alive || echo gone)
  {
    printf '%s SIG%s after %ss; turn pid %s %s; parent %s %s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$(( $(date +%s) - START ))" \
      "$TURN_PID" "$turn_state" \
      "$PPID" "$(proc_alive "$PPID" && echo alive || echo gone)"
    ps -o pid=,ppid=,etimes=,rss=,comm= -p "$TURN_PID" 2>/dev/null
  } >> "$SIGLOG"
  if [ "$turn_state" = alive ]; then
    echo "WRAPPER KILLED by SIG$1 — turn pid $TURN_PID is still alive." >&2
    echo "Reattach with: $HERE/acpx-await.sh --out-dir $OUTDIR" >&2
  else
    echo "WRAPPER KILLED by SIG$1 — turn pid $TURN_PID is ALSO GONE; the turn was lost." >&2
    echo "Do NOT reattach. Confirm with:" >&2
    echo "  $HERE/acpx-progress.sh --repo $REPO --agent $AGENT --session $SESSION --out-dir $OUTDIR" >&2
    echo "Partial transcript (streamed, survives the kill): $OUT" >&2
  fi
  exit 11
}
trap 'on_signal TERM' TERM
trap 'on_signal INT'  INT
trap 'on_signal HUP'  HUP

# Poll rather than `wait`: the turn is in another session and is not our child.
# A short sleep keeps the traps responsive.
while proc_alive "$TURN_PID"; do sleep 2; done

python3 "$HERE/_summarize.py" "$OUT" "$OUTDIR" "$(( $(date +%s) - START ))" "$SESSION"
