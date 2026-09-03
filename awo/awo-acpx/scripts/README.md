# `awo-acpx` acpx wrappers

Every acpx invocation the skill makes goes through these. They exist because the raw
CLI's failure signals are unreliable in ways that destroyed roughly an hour of agent
work in each of two evaluation runs.

| Script | Purpose |
|---|---|
| `acpx-open.sh` | Create a session and pin model + reasoning effort, verified against the session record on disk |
| `acpx-prompt.sh` | Run one turn; exit `0` only if the turn actually finished, `10` if it did not |
| `acpx-progress.sh` | Ask whether a turn in flight is still making progress, without disturbing it |
| `acpx-close.sh` | Close one session, or `--sweep` every `awo-*` session for a repo |
| `jj-change-id.sh` | Print a **full** 32-character change id, or `--check` that ids resolve |

## What they encode

**Never pass `--timeout`.** acpx's `--timeout` does not cancel a turn cooperatively. When
it fires it pipe-closes the client and returns **exit 0 with empty output** while the agent
keeps running (`src/runtime/engine/prompt-turn.ts`: a `TimeoutError` is swallowed and
reported as `stopReason: end_turn` whenever any assistant message has already arrived).
Verified still present in acpx 0.13.2. Turns are bounded by supervision, not by a
client-side deadline that destroys in-flight work.

**Completion is `stopReason`, not the exit code.** A finished turn ends with a terminal
JSON-RPC `result` carrying `stopReason` and `usage`. A killed one does not. That is the
only sound signal: acpx's exit code, `status -s`, and `sessions show`'s
`disconnectReason` have each been observed reporting the opposite of the truth.

**`--format json`, never `quiet`.** `quiet` buffers every chunk and flushes only on the
stop reason, so a killed turn leaves zero bytes and a completed one leaves messages
concatenated without delimiters. `json` streams each ACP message as it arrives — a live
progress feed, a delimited transcript, and a partial record that survives a kill, all in
one file.

**Liveness is event growth.** `status -s` reported `running` with a live pid for five
minutes after a turn was already dead, and `sessions show` reports the supposed kill
signature (`disconnectReason: pipe_close` + `lastExitAt`) on a healthy session that has
merely been configured. `acpx-progress.sh` reads the ACP wire log instead.

**`--ttl 0` on every call.** The queue owner never reaps itself, so a session's pinned
configuration and its prompt-cache prefix survive between turns. An observed respawn cost
~348k input tokens re-sending history uncached for a single turn. The price is that
sessions must be explicitly closed — hence `acpx-close.sh --sweep`.

**Change ids are always full 32-character ids.** `jj log`'s default template prints a
12-character prefix; a prefix passed to a reviewer as `base_change` resolves to nothing,
and the reviewer silently reviews the wrong range rather than reporting an error.

## Requirements

acpx **≥ 0.13.2**, `jj`, `python3`, `bash`. Earlier acpx does not persist a session's
model and reasoning effort across an adapter respawn.
