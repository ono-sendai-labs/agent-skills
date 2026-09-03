# `awo-acpx` acpx wrappers

Every acpx invocation the skill makes goes through these. They exist because the raw
CLI's failure signals are unreliable in ways that destroyed roughly an hour of agent
work in each of two evaluation runs.

| Script | Purpose |
|---|---|
| `acpx-open.sh` | Create a session and pin model + reasoning effort, verified against the session record on disk |
| `acpx-prompt.sh` | Run one turn **detached**; exit `0` only if the turn finished, `10` if it did not, `11` if the *wrapper* was killed and the turn was not |
| `acpx-await.sh` | Reattach to a detached turn after supervision was lost, and wait for it |
| `acpx-progress.sh` | Ask whether a turn in flight is working (`0`), stalled (`1`), idle (`3`) or **dead** (`4`) |
| `acpx-evidence.sh` | Capture a lost turn's evidence in two tiers: small interpreted files, plus a `raw/` that stays gitignored |
| `acpx-close.sh` | Close one session, or `--sweep` every `awo-*` session for a repo |
| `jj-change-id.sh` | Print a **full** 32-character change id, or `--check` that ids resolve **and are change ids** |

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

**The turn is detached; the wrapper is only a waiter.** The orchestrating harness
kills backgrounded calls unpredictably — observed at 17 s, 19 s, 66 s and 141 s across
two runs, once taking an unrelated `sleep 900` with it in the same instant, and every
one destroyed an agent turn that had done nothing wrong. Kills are front-loaded: in
eleven observed turns every kill landed under 150 s and every survival ran past 360 s,
with no overlap. So `acpx-prompt.sh` launches acpx under `setsid`, in its own process
session, and records its pid in `{round}/turn.pid`. A kill aimed at the wrapper's
process group cannot reach the turn. If the wrapper dies, the turn keeps writing
`out.json` and `acpx-await.sh --out-dir {round}` picks it back up. Turn loss becomes
*supervision* loss, which is recoverable.

This is not the double-backgrounding the skill forbids: the wrapper blocks until the
turn is over, so a completion notification still means the turn finished. Only the kill
path changed.

The wrapper also traps `SIGTERM`/`SIGINT`/`SIGHUP` and appends the signal, the elapsed
time, whether the turn survived, and whether its own parent outlived it to
`{round}/wrapper-signals.log`. SIGKILL cannot be trapped — an empty signal log next to
a dead wrapper is itself evidence, and it narrows the vector.

**Death is decidable; `WORKING` was not the answer.** `acpx-progress.sh` gained a
fourth verdict, `4` (dead): the turn's process is gone and its stream carries no
`stopReason`. Without it the script reported `WORKING` for a turn with no process
behind it, then `STALLED` after fifteen minutes, and **never** `idle` — because idle
means "a `stopReason` arrived", which is precisely what a killed turn does not have.
The old instruction to poll until idle was unreachable on the one path it was written
for, at a cost of about four minutes of operator time per kill.

**Liveness is event growth.** `status -s` reported `running` with a live pid for five
minutes after a turn was already dead, and `sessions show` reports the supposed kill
signature (`disconnectReason: pipe_close` + `lastExitAt`) on a healthy session that has
merely been configured. `acpx-progress.sh` reads the ACP wire log instead.

**`--ttl 0` on every call.** The queue owner never reaps itself, so a session's pinned
configuration and its prompt-cache prefix survive between turns. An observed respawn cost
~348k input tokens re-sending history uncached for a single turn. The price is that
sessions must be explicitly closed — hence `acpx-close.sh --sweep`.

**Change ids are always full 32-character ids, and never commit ids.** `jj log`'s
default template prints a short prefix; an id *reconstructed* rather than read resolves
to nothing, and a reviewer handed an unresolvable `base_change` silently reviews the
wrong range rather than reporting an error. `--check` resolves every id and prints the
full form.

It also rejects a bare **commit** id. `jj log -r` accepts one as a revset, so an
earlier version resolved it and printed `ok` — positively confirming the one id class
the skill forbids. §4.6's `jj describe` rewrites the commit id of every earlier change
in the task, so a commit id resolves cleanly before finalisation and dangles after it:
a task record valid until §4.6 and silently wrong afterwards. It is the dangerous
malformation precisely because it *does* resolve.

## Requirements

acpx **≥ 0.13.2**, `jj`, `python3`, `bash`, `setsid` (util-linux). Earlier acpx does
not persist a session's model and reasoning effort across an adapter respawn.
