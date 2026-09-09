# Shared helpers for the awo-acpx acpx wrappers. Source, do not execute.
#
# Every acpx invocation in this skill goes through these scripts so that the
# global flags are applied consistently. acpx keys sessions on (agent, absolute
# cwd, name); an inconsistent --cwd silently addresses a different conversation.

set -uo pipefail

die() { printf '%s: %s\n' "${0##*/}" "$*" >&2; exit 2; }

need() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

# Globals that MUST precede the agent token on every acpx call.
#   --ttl 0   never reap the queue owner; the session's model/effort and its
#             prompt-cache prefix survive between turns. Requires that sessions
#             are explicitly closed (see acpx-close.sh).
#   NO --timeout. acpx's --timeout does not cancel a turn cooperatively: it
#             pipe-closes the client and returns exit 0 with no output while the
#             turn keeps running. Verified still present in acpx 0.13.2.
acpx_globals() { printf -- '--ttl 0 --cwd %s' "$1"; }

# Sandbox mode for codex-acp sessions.
#
# codex-acp reads INITIAL_AGENT_MODE at ADAPTER SPAWN and has no CLI flag for
# it (it takes no options at all). Its default mode, `agent`, is a codex
# `workspaceWrite` sandbox with `writableRoots: []` — only the session cwd is
# writable. That breaks Bazel on this project, because the output base lives at
# ~/.cache/bazel, outside the workspace:
#
#   FATAL: Output base directory '/home/…/.cache/bazel/_bazel_…' must be
#          readable and writable.
#   touch: cannot touch '/home/…/.cache/bazel/…': Read-only file system
#
# Verified by running one identical probe under each mode: `agent` failed all
# three of `bazel info`, `bazel build` and a direct write; `agent-full-access`
# passed all three. This is the cause of the "reviewer could not run the gate"
# reports — the reviewer was not misconfigured and its disclosure was accurate.
#
# `acpx … set mode agent-full-access` does NOT work: the adapter answers
# `Internal error` and the session record still reads `agent`. The environment
# variable is the only working channel, so it is set here, where every wrapper
# in this skill picks it up.
#
# Scope and posture. This is deliberately set inside the skill rather than in
# ~/.acpx/config.json, so it applies ONLY to awo-acpx sessions and leaves
# interactive acpx use of codex on its default sandbox. These sessions already
# run --approve-all with write access to the repository, so the mode is not the
# thing standing between the agent and the working copy; what it additionally
# grants is write access outside the workspace and network access. Override with
# AWO_ACPX_AGENT_MODE=agent (or read-only) if a run does not need Bazel.
#
# It must be exported before the QUEUE OWNER spawns. With --ttl 0 the owner
# outlives the turn, so a session whose owner started without this keeps the old
# mode until it is closed; the value is recorded per session as the `mode`
# config option and acpx-open.sh verifies it.
export INITIAL_AGENT_MODE="${AWO_ACPX_AGENT_MODE:-agent-full-access}"

# Absolute path of a session's ACP wire log, or empty if unknown.
wire_log_for() { # agent session repo
  local rec
  rec=$(acpx --cwd "$3" "$1" sessions show "$2" 2>/dev/null | awk '/^id:/{print $2}')
  [ -n "$rec" ] || return 0
  python3 - "$HOME/.acpx/sessions/$rec.json" <<'PY' 2>/dev/null
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: raise SystemExit(0)
print((d.get("event_log") or {}).get("active_path") or "")
PY
}

mtime_age() { # path -> seconds since last modification, or -1
  [ -e "$1" ] || { echo -1; return; }
  echo $(( $(date +%s) - $(stat -c %Y "$1") ))
}

# Is a pid still alive? (kill -0 succeeds for a live process we may not own.)
proc_alive() { [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }

# The pid of a detached turn launched by acpx-prompt.sh, or empty.
turn_pid_in() { # out-dir
  [ -s "$1/turn.pid" ] || return 0
  tr -dc '0-9' < "$1/turn.pid"
}

# Does this turn's stream already carry a terminal stopReason?
turn_finished_in() { # out-dir
  [ -e "$1/out.json" ] && grep -q '"stopReason"' "$1/out.json" 2>/dev/null
}
