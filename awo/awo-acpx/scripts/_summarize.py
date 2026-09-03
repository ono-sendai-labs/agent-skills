# Summarise one turn's streamed ACP output. Shared by acpx-prompt.sh and
# acpx-await.sh so a reattached turn is reported exactly like a supervised one.
#
# argv: out.json out-dir elapsed-seconds session-name
# exit: 0 the turn completed (terminal stopReason present), 10 it did not.
import json, sys

out, outdir, elapsed, session = sys.argv[1:5]
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
print(f"session={session} elapsed={elapsed}s")
print(f"tool_calls={len(tools)} assistant_chars={len(body)}")
if usage:
    print("tokens: " + " ".join(f"{k}={v}" for k, v in usage.items()))
# Compaction IS announced inline as assistant text on codex-acp; the skill used
# to claim it was invisible. Cheap to detect, so detect it.
if "ontext compacted" in body:
    print("WARNING: the agent reported a context compaction during this turn")
if stop is None:
    print("TURN DID NOT COMPLETE: no terminal stopReason in the stream.", file=sys.stderr)
    print("The turn is detached, so it may still be running. Check with", file=sys.stderr)
    print("acpx-progress.sh; reattach with acpx-await.sh --out-dir. Do not prompt", file=sys.stderr)
    print("this session again and do not touch the working copy until it is idle", file=sys.stderr)
    print("or dead (acpx-progress.sh exit 4).", file=sys.stderr)
    raise SystemExit(10)
print(f"stopReason={stop}")
