#!/usr/bin/env bash
# Close an acpx session, or sweep every session this skill owns.
#
# Usage: acpx-close.sh --repo DIR --agent NAME --session NAME
#        acpx-close.sh --repo DIR --sweep [--slug SLUG]
#
# With --ttl 0 the queue owner never reaps itself, so closing is mandatory
# rather than hygiene: an unclosed session holds a live adapter process for the
# lifetime of the machine. Sweep at every step boundary and on every abort path.

. "$(dirname "$0")/_common.sh"

REPO= AGENT= SESSION= SWEEP=0 SLUG=
while [ $# -gt 0 ]; do
  case $1 in
    --repo) REPO=$2; shift 2;;
    --agent) AGENT=$2; shift 2;;
    --session) SESSION=$2; shift 2;;
    --slug) SLUG=$2; shift 2;;
    --sweep) SWEEP=1; shift;;
    *) die "unknown argument: $1";;
  esac
done
[ -n "$REPO" ] || die "usage: $0 --repo DIR (--agent NAME --session NAME | --sweep [--slug SLUG])"
need acpx; need python3
REPO=$(cd "$REPO" && pwd) || die "repo not a directory: $REPO"

if [ "$SWEEP" = 0 ]; then
  [ -n "$AGENT" ] && [ -n "$SESSION" ] || die "--agent and --session are required without --sweep"
  acpx --cwd "$REPO" "$AGENT" sessions close "$SESSION" && echo "closed $SESSION"
  exit $?
fi

# Sweep: every open session named awo-* for this repo, across configured agents.
PATTERN="awo-"
[ -n "$SLUG" ] && PATTERN="awo-.*$SLUG"
AGENTS=$(acpx config show | python3 -c 'import json,sys; print(" ".join((json.load(sys.stdin).get("agents") or {}).keys()))')
found=0
for a in $AGENTS; do
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    echo "sweeping $a/$name"
    acpx --cwd "$REPO" "$a" sessions close "$name" >/dev/null 2>&1 && found=$((found+1))
  done < <(acpx --cwd "$REPO" "$a" sessions list --local 2>/dev/null \
             | grep -v '\[closed\]' | awk -F'\t' -v r="$REPO" '$3==r{print $2}' | grep -E "$PATTERN")
done
echo "swept $found session(s)"
