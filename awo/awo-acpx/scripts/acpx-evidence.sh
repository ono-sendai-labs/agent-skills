#!/usr/bin/env bash
# Capture what a lost turn left behind, in two tiers.
#
# Usage: acpx-evidence.sh --repo DIR --agent NAME --session NAME --out-dir DIR
#                         [--note TEXT]
#
# Writes {out-dir}/kill-evidence/ with:
#
#   NOTES.md            the timeline and the verdict, assembled here
#   sessions-show.txt   lastPrompt vs lastExitAt — the ordering is what makes
#                       the pipe_close/lastExitAt signature informative
#   status.txt          adapter status and pid
#   turn.meta, wrapper-signals.log   which signal killed the wrapper, if any
#   resources.txt       memory, swap, and per-name process counts at the kill
#   jj-st.txt, jj-log.txt, jj-diff-stat.txt   what the repository looked like
#   raw/                out.json, out.err, and the wire-log tail
#
# Everything except raw/ is small, interpreted, and worth keeping: it is what
# §4.7 copies into tracked history. raw/ is the opposite — a 50-line ACP wire
# tail measured 243 KB, because wire lines embed whole file contents — so it
# stays in the gitignored run dir, where it is actually used, during the
# incident. §4.7 MUST NOT copy raw/.
#
# resources.txt exists because the kills are front-loaded — every one landed in
# the first ~2 minutes of a turn, which is when acpx spawns the adapter — and
# adapter spawn under memory pressure is the standing hypothesis. It also
# counts leaked helper processes (dbus-daemon, gnome-keyring-daemon), which
# have been observed accumulating one pair per invocation in the sandbox.

. "$(dirname "$0")/_common.sh"

REPO= AGENT= SESSION= OUTDIR= NOTE=
while [ $# -gt 0 ]; do
  case $1 in
    --repo) REPO=$2; shift 2;;
    --agent) AGENT=$2; shift 2;;
    --session) SESSION=$2; shift 2;;
    --out-dir) OUTDIR=$2; shift 2;;
    --note) NOTE=$2; shift 2;;
    *) die "unknown argument: $1";;
  esac
done
[ -n "$REPO" ] && [ -n "$AGENT" ] && [ -n "$SESSION" ] && [ -n "$OUTDIR" ] \
  || die "usage: $0 --repo DIR --agent NAME --session NAME --out-dir DIR [--note TEXT]"
need acpx; need jj
REPO=$(cd "$REPO" && pwd) || die "repo not a directory: $REPO"
E=$OUTDIR/kill-evidence
mkdir -p "$E/raw" || die "cannot create $E"

acpx --cwd "$REPO" "$AGENT" sessions show "$SESSION" > "$E/sessions-show.txt" 2>&1
acpx --cwd "$REPO" "$AGENT" status -s "$SESSION"     > "$E/status.txt"        2>&1
jj -R "$REPO" st                    > "$E/jj-st.txt"        2>&1
jj -R "$REPO" diff --stat           > "$E/jj-diff-stat.txt" 2>&1
jj -R "$REPO" log -r 'ancestors(@,12)' > "$E/jj-log.txt"    2>&1
for f in turn.meta wrapper-signals.log turn.launch.sh; do
  [ -e "$OUTDIR/$f" ] && cp "$OUTDIR/$f" "$E/$f"
done
for f in out.json out.err; do
  [ -e "$OUTDIR/$f" ] && cp "$OUTDIR/$f" "$E/raw/$f"
done
WIRE=$(wire_log_for "$AGENT" "$SESSION" "$REPO")
[ -n "$WIRE" ] && [ -e "$WIRE" ] && tail -c 262144 "$WIRE" > "$E/raw/wire-tail.ndjson"

{
  echo "# resources at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  free -m 2>/dev/null || true
  echo
  echo "## process counts by name"
  ps -eo comm= 2>/dev/null | sort | uniq -c | sort -rn | head -25
  echo
  echo "## acpx / adapter processes  (pid ppid elapsed_s rss_kb comm args)"
  # Match on comm, not the whole command line: an args-wide grep matches this
  # script's own invocation and reports a spawn that is not there.
  ps -eo pid=,ppid=,etimes=,rss=,comm=,args= 2>/dev/null \
    | awk '$5 ~ /^(acpx|codex|codex-acp|opencode|bun|node)$/ {print substr($0,1,200)}' \
    | grep . || echo "(none)"
} > "$E/resources.txt" 2>&1

TURN_PID=$(turn_pid_in "$OUTDIR")
{
  echo "# Lost turn — $SESSION ($AGENT)"
  echo
  echo "Captured: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  [ -n "$NOTE" ] && { echo; echo "$NOTE"; }
  echo
  echo "## Verdict evidence"
  echo
  if [ -n "$TURN_PID" ]; then
    echo "- turn pid \`$TURN_PID\`: $(proc_alive "$TURN_PID" && echo ALIVE || echo gone)"
  else
    echo "- no turn.pid recorded (turn was not launched by this revision's acpx-prompt.sh)"
  fi
  echo "- stopReason in stream: $(turn_finished_in "$OUTDIR" && echo yes || echo NO)"
  echo "- adapter: $(awk '/^status:|^pid:/{printf "%s ", $0}' "$E/status.txt" 2>/dev/null)"
  echo "- $(grep -E '^(lastPrompt|lastExitAt|disconnectReason)' "$E/sessions-show.txt" 2>/dev/null | tr '\n' ' ')"
  echo "  (lastExitAt AFTER lastPrompt, with no live pid, is a kill. The same"
  echo "   fields in the other order appear on a healthy just-configured session.)"
  if [ -s "$E/wrapper-signals.log" ]; then
    echo "- the wrapper caught a signal:"
    sed 's/^/      /' "$E/wrapper-signals.log"
  else
    echo "- the wrapper logged no signal — it was SIGKILLed, or it outlived the turn"
  fi
  echo "- repository: $(grep -c . "$E/jj-diff-stat.txt" 2>/dev/null) line(s) of jj diff --stat"
} > "$E/NOTES.md"

echo "evidence: $E"
sed -n '/## Verdict evidence/,$p' "$E/NOTES.md"
