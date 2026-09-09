#!/usr/bin/env bash
# Open a fresh acpx session and pin its model and reasoning effort.
#
# Usage: acpx-open.sh --repo DIR --agent NAME --session NAME --model ID [--effort LEVEL]
#
# Verifies the pinned values against the session record on disk — the adapter's
# own acknowledgement — rather than against the `set` echo (which only reports
# what acpx forwarded) or `status -s` (which cannot see an adapter that has not
# spawned yet). Exits non-zero if a value did not take, so the caller never runs
# a turn on the wrong model.
#
# Note: `set` alone leaves `sessions show` reporting disconnectReason: pipe_close
# and a lastExitAt on a perfectly healthy session. That is expected here and is
# NOT a kill signature.

. "$(dirname "$0")/_common.sh"

REPO= AGENT= SESSION= MODEL= EFFORT=
while [ $# -gt 0 ]; do
  case $1 in
    --repo) REPO=$2; shift 2;;
    --agent) AGENT=$2; shift 2;;
    --session) SESSION=$2; shift 2;;
    --model) MODEL=$2; shift 2;;
    --effort) EFFORT=$2; shift 2;;
    *) die "unknown argument: $1";;
  esac
done
[ -n "$REPO" ] && [ -n "$AGENT" ] && [ -n "$SESSION" ] && [ -n "$MODEL" ] \
  || die "usage: $0 --repo DIR --agent NAME --session NAME --model ID [--effort LEVEL]"
need acpx; need python3
REPO=$(cd "$REPO" && pwd) || die "repo not a directory: $REPO"

# `new` (not `ensure`): soft-close any stale session of this name and start
# clean. `ensure` would silently resume an aborted earlier attempt.
acpx $(acpx_globals "$REPO") "$AGENT" sessions new --name "$SESSION" >/dev/null \
  || die "sessions new failed for $SESSION"

acpx $(acpx_globals "$REPO") "$AGENT" -s "$SESSION" set model "$MODEL" >/dev/null \
  || die "set model $MODEL failed"
if [ -n "$EFFORT" ] && [ "$EFFORT" != null ]; then
  acpx $(acpx_globals "$REPO") "$AGENT" -s "$SESSION" set reasoning_effort "$EFFORT" >/dev/null \
    || die "set reasoning_effort $EFFORT failed"
fi

REC=$(acpx --cwd "$REPO" "$AGENT" sessions show "$SESSION" | awk '/^id:/{print $2}')
[ -n "$REC" ] || die "could not resolve session record id for $SESSION"

python3 - "$HOME/.acpx/sessions/$REC.json" "$MODEL" "$EFFORT" "${INITIAL_AGENT_MODE:-}" <<'PY'
import json, sys
path, want_model, want_effort, want_mode = (
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
d = json.load(open(path))
a = d.get("acpx") or {}
opts = {o.get("id"): o.get("currentValue") for o in (a.get("config_options") or [])}
model  = opts.get("model")  or a.get("current_model_id")
effort = opts.get("reasoning_effort") or (a.get("desired_config_options") or {}).get("reasoning_effort")
bad = []
if model != want_model:
    bad.append(f"model: wanted {want_model}, record says {model!r}")
if want_effort and want_effort != "null" and effort != want_effort:
    bad.append(f"reasoning_effort: wanted {want_effort}, record says {effort!r}")
    levels = [o.get("value") for o in (opts and next(
        (x.get("options") or [] for x in (a.get("config_options") or [])
         if x.get("id") == "reasoning_effort"), []))]
    if levels:
        bad.append(f"  levels this model accepts: {', '.join(str(l) for l in levels)}")
# Sandbox mode, when the adapter exposes one (codex does; opencode does not).
# It is set through INITIAL_AGENT_MODE at adapter spawn, never with `set` —
# see _common.sh. A session that silently kept the default `agent` mode cannot
# run Bazel on this project, and that failure surfaces much later and much
# more confusingly than here.
mode = opts.get("mode")
if want_mode and mode is not None and mode != want_mode:
    bad.append(f"mode: wanted {want_mode}, record says {mode!r}"
               "\n    INITIAL_AGENT_MODE is read when the QUEUE OWNER spawns."
               "\n    A live owner started without it keeps the old mode:"
               "\n    close the session (acpx-close.sh) and re-open.")

print(f"session record: {path}")
print(f"model={model} reasoning_effort="
      f"{effort if effort is not None else '(unset)'}"
      f"{'' if mode is None else ' mode=' + str(mode)}")
if bad:
    print("MISMATCH:", *bad, sep="\n  ", file=sys.stderr)
    raise SystemExit(1)
PY
rc=$?
[ $rc -eq 0 ] || die "pinned configuration did not take for $SESSION — do not run the turn"
echo "opened $SESSION ($AGENT) in $REPO"
