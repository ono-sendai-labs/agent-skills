#!/usr/bin/env bash
# Run one turn against an existing acpx session and report whether it FINISHED.
#
# Usage: acpx-prompt.sh --repo DIR --agent NAME --session NAME \
#                       --prompt-file PATH --out-dir DIR
#
# Exit status describes the TURN, not the acpx client:
#   0   the turn completed  (a terminal result line with a stopReason arrived)
#   10  the turn did NOT complete (client detached, killed, or timed out) —
#       the agent may still be running; do NOT prompt this session again and do
#       NOT touch the working copy until acpx-progress.sh says it is idle
#   2   usage error
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
need acpx; need python3
REPO=$(cd "$REPO" && pwd) || die "repo not a directory: $REPO"
[ -f "$PROMPT" ] || die "prompt file not found: $PROMPT"
mkdir -p "$OUTDIR" || die "cannot create out dir: $OUTDIR"

OUT=$OUTDIR/out.json ERR=$OUTDIR/out.err
START=$(date +%s)
# No --timeout, by design. Bound the turn by supervision (acpx-progress.sh),
# never by a client-side deadline that destroys in-flight work.
acpx --approve-all --format json --suppress-reads $(acpx_globals "$REPO") \
     "$AGENT" -s "$SESSION" --file "$PROMPT" >"$OUT" 2>"$ERR"
ACPX_RC=$?
ELAPSED=$(( $(date +%s) - START ))

python3 - "$OUT" "$OUTDIR" "$ELAPSED" "$ACPX_RC" "$SESSION" <<'PY'
import json, sys
out, outdir, elapsed, acpx_rc, session = sys.argv[1:6]
stop, usage, text, tools = None, None, [], []
for line in open(out, errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    r = d.get("result")
    if isinstance(r, dict) and "stopReason" in r:
        stop, usage = r["stopReason"], r.get("usage")
    u = ((d.get("params") or {}).get("update") or {}) if isinstance(d.get("params"), dict) else {}
    if u.get("sessionUpdate") == "agent_message_chunk":
        c = u.get("content") or {}
        if c.get("type") == "text":
            text.append(c["text"])
    if u.get("sessionUpdate") in ("tool_call", "tool_call_update"):
        t = u.get("title") or u.get("rawInput") or u.get("toolCallId")
        if t:
            tools.append(str(t)[:120])

body = "".join(text)
open(f"{outdir}/assistant.txt", "w").write(body)
print(f"session={session} elapsed={elapsed}s acpx_exit={acpx_rc}")
print(f"tool_calls={len(tools)} assistant_chars={len(body)}")
if usage:
    print("tokens: " + " ".join(f"{k}={v}" for k, v in usage.items()))
# Compaction IS announced inline as assistant text on codex-acp; the skill used
# to claim it was invisible. Cheap to detect, so detect it.
if "ontext compacted" in body:
    print("WARNING: the agent reported a context compaction during this turn")
if stop is None:
    print("TURN DID NOT COMPLETE: no terminal stopReason in the stream.", file=sys.stderr)
    print("The agent may still be running. Do not prompt this session again and", file=sys.stderr)
    print("do not touch the working copy until acpx-progress.sh reports idle.", file=sys.stderr)
    raise SystemExit(10)
print(f"stopReason={stop}")
PY
