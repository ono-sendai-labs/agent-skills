---
name: awo-acpx
description: Drive an implementation plan to completion using long-lived acpx agent sessions instead of the awo binary. Loops over plan steps, generating code tasks per step and running an implementer/reviewer loop on each task, where both the implementer and reviewer sessions span a whole task and are reused across its rework rounds. Catches cross-task drift with a step-scoped implementation-review in a fresh session, marks plan progress itself in a separate commit, bookmarks every produced change for PR generation, keeps a work log, and handles an escalated task by repairing the specification in a separate auditable commit interposed below the implementation, then reconciling in the same implementer session.
---

# awo-acpx Orchestrator (prototype)

## Overview

This is a **prototype variant of `awo-orchestrator`** that replaces the `awo` binary with
[`acpx`](https://github.com/openclaw/acpx) sessions driven directly by you. Same outer loop —
plan → steps → tasks, bookmarks, work log, escalation handling — but the inner
implementer ⇄ reviewer loop is yours to run, over **long-lived agent sessions**.

Two things change:

1. **The implementer session spans a whole task.** Rework rounds reuse it, so the implementer
   never re-reads the task, re-explores the codebase, or re-derives why it wrote what it wrote.
   This is well supported in practice: an implementer asked only to "address the findings"
   reconstructed measurement tooling it had built and deleted two rounds earlier, without
   being told it had existed, and rework rounds ran 3–5× faster than the initial round.
2. **The reviewer session spans a whole task too**, reused across that task's rework rounds so
   it can award partial credit against its own earlier findings. Cross-task drift is *not* its
   job — that is covered explicitly by a step-scoped `implementation-review` in a fresh
   session (§5.2). An earlier revision scoped the reviewer to a whole step; see
   §Relationship to `awo-orchestrator` for why that was narrowed.

Because the sessions are stateful, **you** are the loop: you route on verdicts, you check the
repository shape, and you decide when the YAML is good enough. The acpx surface itself is
*not* yours to improvise — it lives in this skill's `scripts/` directory, because two
evaluation runs showed the CLI's exit codes and status output reporting the opposite of the
truth in both directions. Read `scripts/README.md` before working around any of it. Validation that the `awo` binary
did deterministically is done here by judgement. That is deliberate for the prototype — you are
a capable model reading real artifacts, and the point is to find out which of those checks
actually needed to be deterministic.

Repository interaction is **jj-only**. Never use Git commands.

## Parameters

- **plan_file** (required): Path to the implementation plan, e.g.
  `.agents/planning/{project_name}/implementation/plan.md`. The **planning slug** is the
  `{project_name}` path component; it names the task directories, sessions, and bookmarks.
- **repo** (optional, default: the repository root containing `plan_file`): Absolute path.
  Pass it as `--repo` to every wrapper in `scripts/`; they forward it as acpx's `--cwd`,
  which is load-bearing because acpx keys sessions on the absolute cwd — an inconsistent
  one silently starts a different conversation.
- **work_log** (optional, default: `.agents/scratchpad/awo-acpx-report.{planning_slug}.md`):
  Your durable orchestration record. Read it first; create it if absent; keep it updated after
  every step and task.
- **run_dir_root** (optional, default: `.agents/runs-acpx/`): Where you write per-task
  records and turn transcripts. This path is **gitignored** and must stay that way (§Artifacts).
- **record_dir_root** (optional, default: `.agents/awo/runs/`): Where the *distilled*,
  durable record of each task is committed (§4.7). This path must **not** be gitignored.
  Verify that before the first task — `.agents/runs/` is already ignored in at least one
  project this runs against, and a record directory that is silently ignored preserves
  nothing while looking like it does.
- **generate_tasks_cmd** (optional): Invoked as `{generate_tasks_cmd} {plan_file} {step_number}`.
  If unset, run task generation yourself per §2.
- **roles_config** (optional, default: `{repo}/.agents/awo/acpx-config.yaml`): Per-role
  agent/model/effort selection. See §Role Configuration.
- **step_review** (optional, default: `true`): Whether to run a step-scoped
  `implementation-review` at the end of each step.
- **max_step_remediation_rounds** (optional, default: `1`): How many times a step may be
  remediated and re-reviewed before you stop and ask.
- **check_cmd** (optional, unset): A CLI providing deterministic validation of report YAML and
  jj topology, e.g. `awo check`. When set, prefer it over your own inspection for the checks it
  covers, and record its verdicts in `work_log`. When unset — the prototype default — do those
  checks by inspection per §Validation Posture.
- **max_rework_rounds** (optional, default: `4`): Rounds *after* the initial implementation.
- **turn_check_interval** (optional, default: `900` seconds): How often to check on a turn
  in flight, per §Supervising a running turn.
- **turn_idle_warn** (optional, default: `900` seconds): How long a turn may go without a
  single ACP event before `acpx-progress.sh` calls it stalled.

**Constraints for parameter acquisition:**
- You MUST resolve `plan_file` and `repo` before starting; everything else has a derivable default.
- You MUST read `work_log` (or create it) before touching the repository, and derive the **next
  step number** from `plan_file`'s progress checklist and `work_log` together. The plan may be
  partially complete — never assume you start at step 1.
- You MUST verify `acpx` is on `PATH`, that `acpx --version` reports **0.13.2 or newer**
  (see §Sessions for why), and that both agents are configured (`acpx config show`) before
  the first step. A missing agent, or an older acpx, is a stop-and-ask condition.
- You MUST drive acpx exclusively through this skill's `scripts/` directory
  (`acpx-open.sh`, `acpx-prompt.sh`, `acpx-progress.sh`, `acpx-close.sh`) and resolve every
  change id through `scripts/jj-change-id.sh`. The raw CLI's exit codes and status output
  are not trustworthy on their own; the scripts encode what is. If a script is missing or
  not executable, stop and ask rather than hand-rolling the invocation.
- You MUST verify the producer skills are reachable by both harnesses before the first task —
  normally as symlinks in `{repo}/.agents/skills/` (`task-to-code`, `code-task-review`,
  `plan-to-tasks`, `implementation-review`). See §Troubleshooting if an agent cannot find a skill.

## Role Configuration

Four roles run in this workflow, and they want different capability/cost trade-offs.
Read them from `roles_config` if it exists; otherwise use the defaults below.

```yaml
# .agents/awo/acpx-config.yaml
roles:
  task_generator:                       # §2 — decomposes a plan step into tasks
    agent: codex
    model: gpt-5.6-sol
    effort: high
  implementer:                          # §4.3/§4.5 — writes the code
    agent: opencode
    model: opencode-go/glm-5.3-flash
    effort: null                        # null / omitted = leave adapter default
  reviewer:                             # §4.4 — reviews ONE task and its rework rounds
    agent: codex
    model: gpt-5.6-terra
    effort: high
  step_reviewer:                        # §5.2 — implementation-review at step scope
    agent: codex
    model: gpt-5.6-sol
    effort: high
```

**Rationale for the defaults.** The task reviewer is scoped to a single task (§4.4) and
is handed acceptance criteria that a high-capability `task_generator` already wrote. It
does not have to derive from first principles what the implementer owed — it has to check
work against a written contract. So it wants **roughly the implementer's capability or a
step above**, not the most capable model available: `gpt-5.6-terra` at `high`, or
`gpt-5.6-luna` at `max` (observed to review better than terra/high, and cheaper). What it
must not be is *weaker* than the implementer.

Spend real capability on `task_generator`, where a bad decomposition poisons every task
beneath it, and — conservatively, for now — on `step_reviewer`, which is wide-scope,
judgement-heavy, and runs once per step. The step reviewer may well not need it; that is
an open question, not a settled one.

**Evidence, and its limits.** A run with the task reviewer at luna/`max` produced every
high-value finding of that run — including one that opened the implementer's own
`work.log`, read the grep output pasted there, and found it contradicted the cleanup claim
in the implementer's `result.yaml`. It did not over-review: fewer rework rounds per task
than the cheaper configuration, discriminated severities, and two zero-finding approvals.
It cost ~5× the per-turn latency, though that tracked the *size of the reviewed delta*
far more than the model — a one-file re-review took 3m15s.

The comparison is **confounded**: an acpx defect meant only 5 of 7 review turns actually
ran at the configured effort, so model and effort cannot be separated. Treat it as
suggestive, not settled. A clean per-role model evaluation — same starting commit, one
variable at a time — is worth doing eventually and is deliberately not being done
incidentally, mid-run, where it would confound rather than measure.

**Constraints:**
- Precedence is: explicit invocation parameter > `roles_config` > the defaults above.
- You MUST record the resolved agent/model/effort for all four roles in `work_log`
  before the first turn. A run whose model selection is not written down cannot be
  compared against another run.
- A role's `effort: null` (or omitted) means do not issue `set reasoning_effort` at all;
  it does NOT mean "set it to the adapter default".
- If `roles_config` exists but is unparseable, or names a role you do not recognise,
  stop and ask. Do not silently fall back to defaults — a config that is being ignored
  is worse than no config.

## Operating Constraints

- **Long-running commands.** Agent turns routinely run for tens of minutes; the longest
  observed was 65. You MUST run them as background tasks and wait for the completion
  notification. Do NOT double-background (no `&` or `nohup` inside a `run_in_background`
  call) — the harness would report completion as soon as the launcher returns while the
  real work continues detached.
- **The orchestrating harness is itself a kill vector.** A foreground call cannot hold a
  turn that outlives the harness's own limit, and an out-of-range timeout value has been
  observed being neither clamped nor rejected — the call was simply killed at 141 seconds,
  which pipe-closed acpx and took the agent turn with it. Never try to hold a turn open by
  raising a harness timeout. Run it in the background and supervise it per §Supervising a
  running turn.
- **One turn at a time per session.** acpx queues concurrent prompts to the same session through
  its queue owner. Never issue a second prompt to a session with a turn in flight — including
  one you believe is lost but have not confirmed idle.
- **Never destroy completed work.** No `jj undo`, and no amending or squashing changes
  produced by a task loop, except the description-only `jj describe` that §4.6 requires.
  Every recovery must be additive. `jj abandon` is permitted **only** under the narrow
  predicate in §Recovering from a killed turn.
- **jj only.** Inspect and mutate the repository with jj.
- **Create bookmarks, never move them.** Always `jj bookmark create` — never `jj bookmark set`.
  `create` fails if the name exists, surfacing a collision or an unintended re-run. A `create`
  failure is a stop-and-investigate signal, not a reason to switch to `set`.
- **You MUST NOT edit the produced code yourself** to make a task pass. Route it back through
  the implementer session, or escalate.
- **When in doubt, stop and ask the user.** The user is often away from keyboard; a clean stop
  with a clear question in the `work_log` beats a guess.
- **If you get lost**, re-read `work_log` and the plan to reorient before acting.

## Sessions

All acpx invocations go through the wrapper scripts in this skill's `scripts/`
directory. They exist because the raw CLI's failure signals are unreliable in ways
that cost two evaluation runs an hour of destroyed work each: read
`scripts/_common.sh` for the specifics before working around them.

**Prerequisite: acpx ≥ 0.13.2.** Earlier versions do not persist a session's model
and reasoning effort, so a respawned adapter silently reverts to the harness global
(observed: a reviewer pinned to `medium` running three turns at `high` after an idle
gap). 0.13.2 stores both in the session record and replays them on reconnect —
verified by killing an adapter and prompting with no `set` commands at all. Check
with `acpx --version` before the first turn; an older acpx is a stop-and-ask.

### Naming

| Role | Session name | Lifetime |
|---|---|---|
| Task generator | `awo-gen-{planning_slug}-step{NN}` | one step's task generation |
| Implementer | `awo-impl-{planning_slug}-step{NN}-task{MM}` | one task, all its rework rounds |
| Reviewer | `awo-rev-{planning_slug}-step{NN}-task{MM}` | one task, all its rework rounds |
| Step reviewer | `awo-steprev-{planning_slug}-step{NN}` | one step-scoped review pass |

The names must be unique per scope; the slug guarantees that across concurrently-open plans.
Every session this skill opens MUST be named `awo-*` so `acpx-close.sh --sweep` can find it.

**Why the reviewer is task-scoped.** An earlier revision of this skill scoped the
reviewer to a whole step. In practice the only continuity benefit that materialised was
*intra*-task — the reviewer awarding partial credit against its own prior findings
across rework rounds ("addressing the first half of the prior finding"). No finding was
observed that depended on having reviewed an *earlier task*. Meanwhile the step-scoped
session grew ~35k tokens per turn and auto-compacted mid-turn on a three-task step.
Cross-task drift is now covered explicitly by the step-scoped `implementation-review`
pass (§5.2), with clean context, which is a better tool for it than a session that
happens to still remember.

Keep the reviewer session across a task's **rework rounds** — that is where its value
was demonstrated. Do not narrow it further to per-round.

### Opening a session

```sh
scripts/acpx-open.sh --repo "$REPO" --agent {agent} --session {session} \
                     --model {model} [--effort {effort}]
```

This creates the session with `sessions new`, pins the role's model and reasoning
effort, and then **verifies both against the session record on disk** —
`~/.acpx/sessions/{record}.json`, whose `acpx.config_options[].currentValue` is the
adapter's own acknowledgement. It exits non-zero if either value did not take, so a
turn never runs on the wrong model.

**Constraints:**
- You MUST open every session through this script. Do not call `acpx sessions new`
  directly, and do not use `sessions ensure` — `ensure` silently resumes a stale
  conversation from an aborted earlier attempt.
- Pin the model **once, at open**. Do not re-assert it before every prompt; acpx ≥ 0.13.2
  replays the pinned values itself on reconnect, and re-asserting achieves nothing
  except when the adapter is already alive, which is exactly when it was not needed.
- Do **not** verify the model with `acpx status -s`. Verify against the record, which
  is what the script does. (`status` in 0.13.2 does report the session's real model, but
  it is an adapter-liveness view, not the configuration authority, and in 0.12.0 it
  reported the harness global with no marker distinguishing it from a resolved value —
  a failure that fires *toward halting a healthy run*.)
- A role's `effort: null` (or omitted) means pass no `--effort` at all; it does NOT mean
  "set it to the adapter default".
- An effort level the model does not support is **rejected loudly** by the adapter
  (`ACP -32602 Invalid params`), not silently dropped, and the script surfaces it. There
  is no need to pre-check `models_cache.json`.
- Ignore the `(N options)` in `config set: reasoning_effort=high (4 options)`. `N` counts
  the session's *config options* (mode, model, reasoning_effort, fast-mode), not the
  effort levels available. It has never meant what it looks like it means.
- After `set` and before the first prompt, `sessions show` reports
  `disconnectReason: pipe_close` and a `lastExitAt` on a **perfectly healthy** session.
  That is normal. It is not a kill signature — see §Deciding whether a turn finished.

### Prompting a session

Write each prompt to a file and run it through the wrapper:

```sh
scripts/acpx-prompt.sh --repo "$REPO" --agent {agent} --session {session} \
                       --prompt-file {prompt_path} --out-dir {round_dir}
```

It writes `{round_dir}/out.json` (the streamed ACP messages), `{round_dir}/out.err`,
and `{round_dir}/assistant.txt` (the assistant text, concatenated), and prints the turn's
`stopReason` and token usage.

**Constraints:**
- You MUST run this as a background task and wait for the completion notification. You
  MUST NOT double-background it (no `&` or `nohup` inside the backgrounded call) — the
  harness would report completion as soon as the launcher returned while the real work
  continued detached.
- **No `--timeout`, ever.** acpx's `--timeout` does not cancel a turn cooperatively: it
  pipe-closes the client and returns **exit 0 with empty output** while the agent keeps
  running. Verified still present in 0.13.2. A turn is bounded by supervision
  (§Supervising a running turn), never by a client-side deadline that destroys in-flight
  work. The script does not accept a timeout flag.
- The output format is `json`, not `quiet`, and this is load-bearing. `quiet` buffers
  every chunk and flushes only when the stop reason arrives, so a turn that dies leaves
  **zero bytes** — and its concatenated messages carry no delimiters. `json` streams each
  ACP message as it arrives, so the file is simultaneously a live progress feed, a
  message-delimited transcript, and a partial record that survives a kill.
- You MUST record the token line the script prints (`totalTokens`, `inputTokens`,
  `cachedReadTokens`, `outputTokens`) in `work_log` for every round, **and note explicitly
  whether the turn compacted** — `acpx-prompt.sh` prints a warning when the agent announces
  one. "No compaction" is a result worth recording, not an absence worth omitting; the
  point of tracking it is to find out whether the current configuration has eliminated it.
- **Context headroom.** After each turn, compare `totalTokens` against the harness's
  configured context window. If a session exceeds **50%** of the window, say so in
  `work_log`. If a session compacts, or would plainly exceed the window on the next round,
  **close it and open a fresh one for the next round**, and record that you did. The
  producers' on-disk state — the task file, `result.yaml`, `review.yaml`, the scratchpad —
  is designed to work from a cold session, so a restart costs one round of re-orientation
  and nothing else. A session that compacted has silently lost the continuity this skill
  exists to test, which is worse: you would be measuring a session that is no longer the
  one you think it is.
- Compaction should now be **rare**. It was previously driven by a combination of a
  conservatively low harness context window and adapter respawns that re-sent the whole
  history uncached; `--ttl 0` removes the respawns, and the window should be set near the
  model's real `max_context_window` (872000 for the gpt-5.6 family; see
  `~/.codex/models_cache.json`). If it still happens under those conditions, that is a
  finding — record the task's size (changes, files) alongside it, because a task big enough
  to compact a task-scoped reviewer at a near-maximal window is probably a task that should
  have been split. `cachedReadTokens`
  grows monotonically within a session and is the usable proxy for accumulated context.
  It is **not** comparable across agents (different harness preambles), so never compare
  an opencode figure to a codex one.
- **One turn at a time per session.** Never issue a second prompt to a session with a
  turn in flight, including a turn you believe is lost but have not confirmed idle.

### Deciding whether a turn finished

Route on the script's exit status, which describes the **turn**, not the acpx client:

| Exit | Meaning | Action |
|---|---|---|
| `0` | The turn completed — a terminal `result` carrying a `stopReason` arrived | Read `assistant.txt` and the artifact; route on the verdict |
| `10` | The turn did **not** complete | The agent may still be running. Do not prompt the session, do not touch the working copy. Go to §Supervising a running turn |
| `2` | Usage error in the wrapper | Fix the invocation |

**Do not route on acpx's own exit code, `status -s`, or `sessions show`.** All three have
been observed lying in both directions:

- `--timeout` firing mid-turn returns **exit 0** with no output and no token line, while
  the turn runs on for another five minutes.
- `status -s` reported `running` with a live pid for five minutes *after* a turn was
  already dead — and reports `running` for an idle adapter that has simply not been
  reaped.
- `sessions show`'s `closed: false` + `disconnectReason: pipe_close` + non-null
  `lastExitAt` — the signature an earlier revision of this skill called the kill
  signature — appears on a healthy session that has merely been configured with `set`
  and not yet prompted. It detects "the pipe closed", not "the turn died".

The presence of a terminal `stopReason` in the streamed output is the only sound signal,
and `acpx-prompt.sh` is what checks it.

### Supervising a running turn

A real implementation turn runs for tens of minutes; the longest observed was 65. There
is no timeout, so you supervise instead.

**Constraints:**
- While a turn is in flight, check on it about every **15 minutes**:

  ```sh
  scripts/acpx-progress.sh --repo "$REPO" --agent {agent} --session {session} \
                           --out-dir {round_dir}
  ```

  It reports the age of the last ACP event, the running tool-call and message counts, and
  the title of the most recent tool call. Its exit status is `0` working, `1` stalled,
  `3` idle (no turn in flight, or this turn's stream already carries a `stopReason`).
- **Liveness is event growth, not `status: running`.** The script defines it that way and
  you MUST NOT substitute a status check. An agent that has been sitting in one tool call
  for twenty minutes is a different situation from one that is stepping through a build,
  and only the event stream distinguishes them.
- Record each check-in in `work_log` as one line: elapsed, tool-event count, last tool.
  Those lines are how a run's real cost is reconstructed afterwards.
- On `1` (stalled): check once more after another 15 minutes. If it is still stalled with
  the same last tool, **stop and ask** — quote the last tool call and the elapsed time.
  Do not cancel it yourself: `acpx cancel -s` exists but its cooperativeness is untested,
  and the one cancellation mechanism this skill has tested (`--timeout`) destroys work.
- You MUST NOT touch the repository while a turn is in flight or unconfirmed-dead. A
  turn believed lost has been observed still holding uncommitted work.

### Recovering from a lost turn

`acpx-prompt.sh` exited `10`, or the orchestrating harness killed the call. Note that the
harness is an independent kill vector: a background call with an out-of-range timeout was
killed at 141 seconds without an error, pipe-closing acpx and taking the agent turn with
it. Both vectors present identically.

**Constraints:**
- You MUST first confirm the turn is actually over, with `acpx-progress.sh`. Never act on
  a turn that is still producing events. Poll until it reports `3` (idle).
- You MUST capture evidence before changing anything: copy `out.json`, `out.err`, the
  `sessions show` output and the wire-log tail into `{round_dir}/kill-evidence/`, and
  record `jj diff` / `jj st` for anything you are about to touch.
- **A lost turn is never resumed.** Open a *fresh* session (suffix the name, e.g.
  `…-task02b`) and re-issue the prompt. Do not reconnect to the killed session: its last
  event is typically a pending tool call, so it does not know what it completed, and
  reconnecting re-sends the whole history uncached — one observed respawn cost ~348k
  input tokens for a single junk turn. A clean context is cheaper and is what the task
  files and report YAMLs are designed for.
- **If the lost turn left committed changes**, you MAY `jj abandon` a change only when
  **all** of these hold:
  1. it is a strict descendant of the newest bookmark on the current stack;
  2. it carries no bookmark itself; and
  3. its change id does **not** appear in `produced_changes` of the active
     `task-record.json`.

  Evaluate descendants-first and re-check after each abandon. You MUST NOT rely on
  "everything above the newest bookmark" alone: within a task the produced series is
  unbookmarked until §4.6, so that test would license discarding completed, reviewed
  rework rounds.
- **If the lost turn left uncommitted work in `@`** — the common case, and the one an
  earlier revision of this skill had no rule for — then:
  1. `jj commit` it yourself as `wip({scope}): interrupted <what it was doing>`, with a
     description that states what the change does and does **not** contain and cites the
     kill evidence path. Append it to `produced_changes` like any other produced change.
  2. In the fresh session's prompt, name that change, summarise what its predecessor
     *claimed* to have done, and instruct the session to **verify rather than trust** it,
     because an interrupted turn's work is not merely incomplete — it is **unvalidated**.
     This is not a formality: in the one real occurrence, the resuming session found two
     regressions the killed session had introduced and never checked.
  3. Do not revert it and do not fold it into a later change. It is part of the audit
     trail, and §4.6 must not be allowed to erase the fact of the recovery — see §4.6.

  If the uncommitted work is too incoherent to describe honestly, stop and ask. Never
  `jj abandon` uncommitted work.
- **Loop guard:** at most one automatic recovery per round *from an undiagnosed cause*.
  A second loss on the same round is stop-and-ask **unless** you have diagnosed the cause
  and can name the specific fix; if so, apply it, declare the override in `work_log`, and
  stop unconditionally if it recurs. The guard exists to stop an orchestrator grinding
  against a flake it does not understand, not to forbid a known repair.
- A lost turn MUST NOT consume a `max_rework_rounds` slot. No review happened, so no
  round elapsed; charging it would let flaky infrastructure fail a healthy task.
- You MUST record the loss, the evidence, what you kept or abandoned, and the restart in
  `work_log`.

Note that `jj abandon` is recoverable in jj — the operation log retains the change and
`jj op restore` brings it back. That is why the narrow exception above is safe; it is not
a git-style destructive reset.

### Closing a session

```sh
scripts/acpx-close.sh --repo "$REPO" --agent {agent} --session {session}
scripts/acpx-close.sh --repo "$REPO" --sweep --slug {planning_slug}   # step boundaries
```

**Constraints:**
- The wrappers run with `--ttl 0`, so the queue owner **never reaps itself**. Closing is
  therefore mandatory rather than hygiene: an unclosed session holds a live adapter
  process indefinitely. This is the price of keeping a session's pinned configuration and
  prompt-cache prefix alive between turns, and it is worth paying — but only if you pay
  the other half.
- You MUST close the implementer and reviewer sessions at the end of each task, and the
  step reviewer at the end of each step — including when the task or step ends in a block
  or an escalation.
- You MUST run `--sweep` at every step boundary and on **every** abort path, including
  stop-and-ask. Report the count it prints in `work_log`.
- `close` is a soft close. The record and history stay on disk for later inspection.

## Validation Posture

Where the `awo` binary validated deterministically, you validate by inspection. Do it, but do it
with judgement rather than schema pedantry.

**You MUST check, every round:**
- After an implementer turn: `@` is empty and childless; `@-` is non-empty, described, and
  carries no bookmark; `@-`'s change ID matches the `result.change_id` the implementer reported.
  "Matches" means **prefix containment**, in either direction: producers emit sometimes a
  full 32-character change id and sometimes a prefix, while `jj log` shows 8 by default.
  Compare change ids, never commit ids —
  §4.6's `jj describe` rewrites commit ids for every earlier task in the step.
- After a reviewer turn: the repository is unchanged — same `@-` change ID, commit ID,
  description, and bookmarks as before the review. A reviewer that mutated the repository is a
  stop-and-investigate condition, not something to accept. To do this check properly you
  MUST snapshot the topology *before* the review turn (e.g.
  `jj log -r 'ancestors(@,N)' -T '…' > {run_dir}/round-{N}.pre-review.topology`) and diff
  it afterwards. Keep both snapshots in the run dir.
- Every change id you are about to write into a prompt or a task record **resolves to
  exactly one change**: `scripts/jj-change-id.sh --repo "$REPO" --check <id>...`, which
  also prints the full form of anything you gave it as a prefix. Cheap, mechanical, and it
  catches the one error class that silently mis-scopes a review.
- The task's base recorded at §4.1 is still an **ancestor of `@`**, with an unchanged
  change id. Test ancestry, not identity: a base that is no longer `@-` because someone
  appended a commit below you is benign and normal in a shared repo, and stopping on it
  halts a healthy run. A base that has *vanished* or whose change id no longer resolves
  means history was rewritten — that is the stop condition.

**You MAY be tolerant about:**
- Missing or malformed `spec-workflow-meta` blocks. Locate the canonical artifact at its
  conventional path under `.agents/scratchpad/{planning_slug}/step{NN}/{task_dir}/` instead.
- Schema imperfections in `result.yaml` / `review.yaml` — extra keys, missing optional fields,
  loose formatting. What you actually need from them is: the verdict/status, the change ID, the
  findings and their severities, the acceptance-criteria statuses, and any `escalation` block.
- A **malformed but unambiguous** `result.change_id`. A bare 8-character prefix is
  normal and fine — run it through `jj-change-id.sh --check`, which resolves it and prints
  the full form. What needs judgement is a genuinely malformed id: producers have been
  observed emitting a change-id prefix concatenated with a commit-id prefix
  (e.g. `sxqzlwnn65d9000d`), which resolves to nothing. Accept it if — and only if — you can identify the intended change
  with certainty from `jj log` and no other change shares either prefix; record that you
  did. Do **not** copy the malformed string into `produced_changes`; write the real change
  id, or you corrupt the series §E.3 depends on. Do not spend a rework round fixing a
  string in a YAML file.
- A `schema_version` in the artifact that disagrees with the one in the
  ```spec-workflow-meta``` block. Prefer the artifact's.
- A missing artifact entirely, when the final assistant text states the outcome unambiguously.
  Record in `work_log` that you routed on prose rather than an artifact. `acpx-prompt.sh`
  captures the streamed messages in `{round_dir}/out.json`, so individual assistant messages
  *are* separable — read the last `agent_message_chunk` sequence there rather than the
  flattened `assistant.txt` when message boundaries matter.

**You MUST NOT be tolerant about:** the verdict itself. If you cannot determine from either the
artifact or the final text whether the reviewer approved, requested changes, or escalated, ask
the session one clarifying question rather than guessing.

When `check_cmd` is set, run it for report parsing and jj topology and prefer its verdict over
your own reading; note any disagreement between the two in `work_log` — that disagreement is
itself a finding worth reporting.

## Steps

Loop over plan steps from the resolved next step number until every step in `plan_file` is
checked off, or you hit a block you cannot clear.

### 1. Verify jj Working State

**Constraints:**
- You MUST confirm you are in an empty jj working copy on top of the stack (`jj st`).
- If `@` contains stray files, you MUST investigate their origin. If they are leftovers from the
  previous step, `jj commit` them with a descriptive conventional-commit message; if their
  origin is unclear, stop and ask the user.

### 2. Generate Task Files for the Step

**Constraints:**
- If `generate_tasks_cmd` is set, run `{generate_tasks_cmd} {plan_file} {step_number}` as a
  background task and wait for it. Otherwise run task generation yourself in a disposable acpx
  session named `awo-gen-{planning_slug}-step{NN}`, using the **`task_generator`** role
  from §Role Configuration (a bad decomposition poisons every task beneath it, so this is
  worth a capable model), with a prompt of the form:

  ```
  This session runs in non-interactive mode as part of an automated orchestrator.
  There is no human to answer questions. Do not ask for clarification and do not
  emit progress narration. If genuinely blocked, say so explicitly rather than
  asking.

  Skill: plan-to-tasks
  Parameters:
    agents_dir: .agents
    plan: {plan_file}
    step: {step_number}

  Run the `plan-to-tasks` skill on this step. Then `jj commit` the resulting task
  files with a conventional-commit message. Do not create a bookmark.
  ```

  Open it with `scripts/acpx-open.sh`, prompt it with `scripts/acpx-prompt.sh` into
  `{run_dir_root}/{ts}-step{NN}-taskgen/`, supervise it per §Supervising a running turn,
  and close it with `scripts/acpx-close.sh` when it returns.
- After it returns, you MUST verify you are again in an empty working copy with `@-` holding the
  task files. If the agent left the files uncommitted in `@`, you MUST commit them yourself.
- You MUST create a bookmark on that change named
  `pr/awo-generate-task-{planning_slug}-step-{step_number}` (with `jj bookmark create`).
- You MUST enumerate the step's task files (`jj log -s` on the change). They live in
  `.agents/tasks/{planning_slug}/step{NN}/` and are named `task-{MM}-{task_slug}.code-task.md`.
- You MUST record the generated task files in `work_log` before implementing any of them.

### 3. Record the Step's Task Inventory

**Constraints:**
- You MUST record in `work_log`, before the first task, the ordered list of task files for
  this step and the resolved role configuration (§Role Configuration) you will run them
  with.
- There is no step-scoped reviewer session to open. Both the implementer and the reviewer
  are opened per task, in §4.

### 4. Implement Each Task

For each task file in order:

#### 4.1 Ensure a Clean Starting State

**Constraints:**
- You MUST verify `@` is empty; commit stray files if present.
- You MUST record the task's **base** — the tip left by the previous task or by task
  generation — obtained with:

  ```sh
  scripts/jj-change-id.sh --repo "$REPO" @-
  ```

  which prints the full 32-character id. Record that in the run record (§4.2).

  A short prefix is *not* the problem: `jj log` prints 8 characters by default and
  guarantees they are unique, producers legitimately emit them, and rejecting them fails
  healthy runs. The problem is an id that was **reconstructed rather than read** — a real
  prefix padded out with invented characters, which resolves to nothing. A reviewer handed
  an unresolvable `base_change` does not error; it quietly reviews the wrong range. So
  never retype or complete an id by hand; take it from the script.
- The base already carries a bookmark in every case this loop produces: §2 bookmarks the
  task-generation change, and §4.6 bookmarks the previous task's tip. If it somehow does
  not, create one with `jj bookmark create` before proceeding.

#### 4.2 Create the Run Record

Create `{run_dir_root}/{timestamp}-step{NN}-task-{MM}-{task_slug}/` and, inside it, a
`task-record.json` you maintain as the task proceeds:

```json
{
  "task_file": ".agents/tasks/{slug}/step{NN}/task-{MM}-{task_slug}.code-task.md",
  "planning_slug": "{slug}",
  "step": {NN},
  "task": {MM},
  "implementer_session": "awo-impl-{slug}-step{NN}-task{MM}",
  "reviewer_session": "awo-rev-{slug}-step{NN}-task{MM}",
  "base": {"change_id": "...", "bookmark": "..."},
  "produced_changes": [],
  "rounds": [],
  "outcome": null
}
```

**Constraints:**
- You MUST append each produced change ID to `produced_changes` in **oldest-to-newest** order as
  it is created, and append a `rounds` entry per round recording the role, prompt path, output
  path, verdict/status, and the token line from stderr.
- This record replaces awo's `task-state.json`. Escalation handling (§E.3) needs the base and the
  ordered produced series; without it you cannot place a spec repair correctly.
- You MUST keep every round's prompt file and captured output in this directory. They are the
  forensic record for the prototype evaluation.

#### 4.3 Round 0 — Implementation

Open the implementer session per §Sessions, then prompt it:

```
This session runs in non-interactive mode as part of an automated orchestrator.
There is no human to answer questions. Do not ask for clarification and do not
emit progress narration. If genuinely blocked, use the skill's escalation
contract rather than asking.

Skill: task-to-code  (.agents/skills/task-to-code/SKILL.md)
Parameters:
  agents_dir: .agents
  task: {task_file}

Run the `task-to-code` skill on this task. Follow the skill's instructions
exactly, including all of its turn-completion contracts: write the canonical
result.yaml and include the complete ```spec-workflow-meta block.

Commit your work incrementally with `jj commit` as coherent pieces become
complete, rather than holding everything for a single commit at the end.
Several small described changes are expected and are preferred here. This
session can be interrupted by infrastructure outside your control, and
uncommitted work is lost when that happens.
```

**Constraints:**
- You MUST run this as a background task per §Prompting a session, supervise it per
  §Supervising a running turn, and wait for it.
- The incremental-commit paragraph is **required**, not decorative. `task-to-code`'s natural
  shape is explore → plan → implement → one commit at the end, which is maximally fragile to
  an interruption: the one task that ran that way lost 65 minutes of work, and the one that
  committed incrementally lost nothing. This paragraph is the only prompt padding this skill
  permits; §4.5 still forbids padding the rework prompt.
- When it returns, you MUST perform the post-implementation checks in §Validation Posture, then
  read `result.yaml`.
- Route on `result.status`:

| `result.status` | Action |
|---|---|
| `completed` | Record the produced change; proceed to §4.4 |
| `escalated` | Go to §Escalation Handling |
| anything else / unreadable | Read the final text. If it states an outcome unambiguously, route on that and note it in `work_log`. Otherwise send one clarifying prompt to the same session |

- If the repository shape is wrong (`@` not empty or has children, `@-` bookmarked or
  undescribed, change ID mismatch), you MUST send a repair prompt to the **same** session rather
  than fixing it yourself:

  ```
  Your previous completion was parsed, but the jj repository shape is not valid
  for review: {what you observed}.

  Repair the repository and completion in this same session, per the task-to-code
  contract: leave one empty child `@` with no descendants; use `jj commit -m` to
  create the described implementation change; create no bookmark; re-emit a
  corrected result.yaml whose result.change_id identifies the produced `@-`, with
  the complete ```spec-workflow-meta block.
  ```

  One repair attempt per round. A second failure is a block — stop and ask.

#### 4.4 Review

Open **this task's** reviewer session per §Sessions (`awo-rev-{slug}-step{NN}-task{MM}`,
using the `reviewer` role), then prompt it. Because the session is new for each task, its
first prompt always carries the non-interactive preamble from §4.3.

```
This session runs in non-interactive mode as part of an automated orchestrator.
There is no human to answer questions. Do not ask for clarification and do not
emit progress narration. If genuinely blocked, use the skill's escalation
contract rather than asking.

Skill: code-task-review  (.agents/skills/code-task-review/SKILL.md)
Parameters:
  agents_dir: .agents
  task: {task_file}
  current_change: {newest produced change ID}
  base_change: {base change ID}
  produced_changes: [{oldest}, ..., {newest}]
  task_record: {run_dir}/task-record.json

Run the `code-task-review` skill on this change against this task. Inspect the
whole base-to-current range in implementation order. Do not modify the
repository. Emit review.yaml plus the complete ```spec-workflow-meta block.
```

If the task's produced series contains a change that is not implementation — there
should be none under the current contract, but verify rather than assume — say what it
is and that it is in scope, rather than leaving the reviewer to infer why
`current_change` is not what it expects.

For a re-review (round ≥ 1) in the **same task's** session, the reviewer already holds its
prior review; say so rather than restating it. This continuity across rework rounds is the
reviewer session's whole purpose — awarding partial credit against its own earlier
findings is something a per-round reviewer cannot do without being re-fed the old review:

```
Re-review round {N} for {task_file}.

The implementer produced a fresh change addressing your last review:
  current_change: {new tip}
  produced_changes: [{oldest}, ..., {newest}]

Validate that your prior critical/important findings and every non-pass
acceptance criterion have been addressed, and surface any regressions across the
whole base-to-current range. Emit a fresh, self-contained review.yaml plus the
```spec-workflow-meta block.
```

**Constraints:**
- You MUST run this as a background task per §Prompting a session, supervise it per
  §Supervising a running turn, and wait for it.
- Every change id in this prompt — `current_change`, `base_change`, and each entry of
  `produced_changes` — MUST be one you have verified resolves, with
  `scripts/jj-change-id.sh --repo "$REPO" --check <id>...`. Prefixes are fine as long as
  they resolve; ids you assembled by hand are not. An id that does not resolve produces a
  silently mis-scoped review, not an error.
- You MUST perform the post-review checks in §Validation Posture before reading the verdict.
- Route on `review.verdict`:

| `review.verdict` | Action |
|---|---|
| `approved` | Proceed to §4.6 |
| `changes_requested` | Go to §4.5, unless `max_rework_rounds` is exhausted |
| `escalated` | Go to §Escalation Handling |
| `blocked` | Deprecated verdict from older skill versions; treat as `escalated` |

- When `max_rework_rounds` is exhausted without approval, read the last `review.yaml`. If the
  outstanding findings are genuinely deferrable, record them in `work_log` and proceed to §4.6;
  otherwise treat as a block and stop.

#### 4.5 Rework Round — Same Implementer Session

This is the point of the prototype. The implementer already holds the task, its exploration, its
plan, and its own prior reasoning. Do not re-brief it.

```
Review round {N}. The reviewer's findings are at:
  {path to review.yaml}

Address every critical and important finding, and every acceptance criterion not
marked "pass". Produce a FRESH commit with `jj commit` — do not amend, squash, or
rewrite your earlier change. Then re-emit result.yaml plus the complete
```spec-workflow-meta block.
```

**Constraints:**
- You MUST NOT restate the task, the skill, or the prior work in this prompt. If the implementer
  behaves as though it has lost that context, record it in `work_log` — that is a finding about
  the prototype's core hypothesis, not a reason to silently pad the prompt.
- You MUST verify the round produced a **fresh child change**, not a rewrite of the previous one:
  the previous produced change ID must still be present in `jj log` and must still be `@-`'s
  ancestor. A rewritten change is a stop-and-investigate condition.
- Append the new change to `produced_changes` and return to §4.4.

#### 4.6 Finalize the Task

Unlike `awo run`, nothing finalizes the stack for you. You do it.

**Constraints:**
- You MUST verify `@` is empty; commit stray files if present.
- You MUST describe the **oldest** produced change of this task with the approved review's
  `merge_request.title` and `merge_request.body`, using `jj describe`.
- **You MAY rewrite that body when it narrates the review instead of describing the
  change.** Reviewers have been observed opening with *"Reviews the complete base-to-current
  range for the single produced change pyopkyun…"* — reviewer-voice prose, carrying a raw
  change id that means nothing to a PR reader, permanently attached to the commit. Rewrite
  it in the change's own voice, preserving every substantive claim the reviewer made, and
  record in `work_log` that you did and why. Do not use this licence to soften or drop
  anything the reviewer said; it exists for voice and readability, not for content. This is the merge-request
  content the PR will carry. This is the one sanctioned exception to §Operating Constraints'
  no-amending rule: it is description-only, it preserves content and change ids, and jj will
  report `Rebased N descendant commits` as it rewrites this task's later commit ids. That is
  expected — and it is why every topology check in this skill compares **change** ids and
  never commit ids.
- When a task produced exactly one change, "oldest" and "newest" are the same change:
  describe it and bookmark it.
- **If the oldest produced change is a `wip(...)` recovery commit** written under
  §Recovering from a lost turn, its description is the only record of the recovery that
  lives in tracked history — `run_dir_root` is gitignored by default, so the evidence
  under it is not. In that case you MUST append the original `wip` description to the
  `merge_request.body` you write, under a `Recovery note:` heading, rather than replacing
  it. Losing the description would leave no tracked trace that a turn was interrupted and
  its partial work carried forward.
- You MUST create the task bookmark on the **newest** produced change, with `jj bookmark create`,
  named exactly:

  ```
  pr/{planning_slug}/step{NN}/task-{MM}-{task_slug}.code-task
  ```

  This name — the task file's path under `.agents/tasks/`, prefixed with `pr/` and stripped of
  `.md` — is what PR generation consumes, so it must match exactly.
- If `create` fails because the name is taken, do not switch to `jj bookmark set`. Find the
  holder (`jj log -r 'bookmarks(<name>)'`) and stop and ask, unless it is a superseded tip of
  *this same task's* series — in which case say so explicitly in `work_log` before moving it.
- You MUST close **both** the implementer and this task's reviewer session with
  `scripts/acpx-close.sh` (§Closing a session) — with `--ttl 0` these hold live adapter
  processes until you do — and write `outcome` into `task-record.json`.

#### 4.7 Preserve the Task's Bookkeeping

`{run_dir_root}` is gitignored (§Artifacts), so nothing under it reaches tracked history on
its own. The raw transcripts should stay that way — they are large and only matter while
debugging a run. The *distilled* record should not: it is the part that will still be worth
reading in six months.

**Constraints:**
- After §4.6, with `@` empty, copy this task's distilled record into the tracked path
  `{record_dir_root}/{planning_slug}/step{NN}/task-{MM}-{task_slug}/`
  (default `.agents/awo/runs/…`, alongside `.agents/awo/acpx-config.yaml`):
  - `task-record.json` — base, ordered produced changes, rounds, outcome
  - `round-{N}.result.yaml` and `round-{N}.review.yaml` for every round
  - `kill-evidence/` for any round that lost a turn
- Commit it on its own as `chore(awo): record bookkeeping for step{NN} task {MM}`, with
  `@` otherwise empty so the commit contains nothing else. Do not bookmark it.
- Copy into a tracked path; do **not** `jj file track --include-ignored` a file inside
  `{run_dir_root}`. That command works, but tracking is **sticky**: a tracked-but-ignored
  file reappears in `jj st` on every later edit, and `jj file untrack` records a deletion
  rather than restoring the previous state. Since `task-record.json` is updated throughout
  the task, tracking it in place would contaminate exactly the working copies this skill
  needs to keep clean. A copy made once, when the content is final, has none of that.
- If a produced YAML is missing because a producer never wrote one, copy what exists and
  say so in `work_log`. Do not synthesise an artifact.
- You MUST confirm `{record_dir_root}` is not gitignored before the first task of a run —
  `jj file track --dry-run` is not available, so check the repo's `.gitignore` directly, or
  write a probe file and confirm it appears in `jj st`. A silently-ignored record directory
  is worse than no record directory: the commit will simply be empty and the loss is
  invisible until someone goes looking for the record months later.

#### 4.8 Update the Work Log

**Constraints:**
- You MUST append a summary to `work_log`: task file, terminal outcome, round count, produced
  change IDs, the bookmark you created, and the per-round token lines. Record any escalation and
  its resolution here too — `work_log` is the human-readable audit trail.
- You MUST also record, for the prototype evaluation: wall-clock duration per round, and any
  observation about whether the implementer retained context across rework or the reviewer
  degraded across the step.

### 5. Close Out the Step

#### 5.1 Verify the step's tasks

**Constraints:**
- You MUST verify every task in the step is approved (or explicitly recorded as deferred)
  before advancing.
- You MUST verify `@` is empty and every task carries its `pr/…` bookmark.
- You MUST run `scripts/acpx-close.sh --repo "$REPO" --sweep --slug {planning_slug}` and
  record the count it reports. With `--ttl 0` nothing reaps itself, so a session left open
  by an abandoned task holds an adapter process indefinitely. Do this at every step
  boundary and on every abort path, including stop-and-ask.

#### 5.2 Step-scoped implementation review

Skip if `step_review` is false. Otherwise this is where cross-task drift is caught — the
job the reviewer no longer does.

**Constraints:**
- You MUST run it in a **fresh** session `awo-steprev-{planning_slug}-step{NN}`, using the
  `step_reviewer` role. Context independence is the point; do not reuse any session that
  has seen this step's tasks.
- Prompt:

  ```
  This session runs in non-interactive mode as part of an automated orchestrator.
  There is no human to answer questions. Do not ask for clarification and do not
  emit progress narration.

  Skill: implementation-review  (.agents/skills/implementation-review/SKILL.md)
  Parameters:
    agents_dir: .agents
    project_dir: {project_dir}
    scope: step
    step: {step_number}

  Run the `implementation-review` skill at step scope. Do not modify the
  repository beyond writing your report and any remediation task files.
  ```

  Open, prompt and close it with the `scripts/` wrappers, writing into
  `{run_dir_root}/{ts}-step{NN}-steprev/`.

- The step's checklist item is expected to be **unticked** at this point; that is normal
  and the skill knows it. Do not tick it first to make the review "valid".
- When it returns, read the report at
  `{project_dir}/implementation/review-step{NN}.yaml` and route on `verdict`:

  | `verdict` | Action |
  |---|---|
  | `clean` | Proceed to §5.3 |
  | `remediation_recommended` | Judge: if the findings are genuinely deferrable, record them in `work_log` and proceed to §5.3; otherwise treat as `remediation_required` |
  | `remediation_required` | Run the generated remediation tasks through §4 as additional tasks of this step, then re-run §5.2 once |

- Remediation tasks land in **this step's** task directory and are implemented exactly like
  any other task in §4 — own implementer session, own reviewer session, own bookmark.
- You MUST commit the review report, and any generated task files, before proceeding —
  including when the verdict is `clean` and there are no task files. §5.3 requires the
  checklist commit to contain only the checklist edit, and §1/§4.1 require an empty `@`,
  so leaving the report uncommitted is not an option the rest of this skill permits.
  Use a conventional-commit message, and bookmark that change
  `pr/awo-step-review-{planning_slug}-step-{step_number}`.
- **Loop guard:** at most `max_step_remediation_rounds` (default 1) remediation rounds per
  step. If a re-review still returns `remediation_required`, stop and ask — repeated
  remediation on one step means the step was mis-planned, which is the user's call.

#### 5.3 Mark the step complete

The orchestrator owns plan progress; `task-to-code` does not touch it.

**Constraints:**
- You MUST mark the step's checklist item complete in `plan_file` (`- [ ]` → `- [x]`)
  **yourself**, and commit that edit as its own change with a message like
  `docs(plan): mark {planning_slug} step {N} complete`.
- That commit MUST contain only the checklist edit. Keeping it separate is what makes
  `@- == result.change_id` hold unconditionally for every task, and it is what will let
  plan progress move to an external tracker later without touching any producer skill.
- You MUST bookmark it `pr/awo-step-complete-{planning_slug}-step-{step_number}`.
- If the item is already ticked, stop and investigate — under the current contract nothing
  else should be ticking it, so something is out of date or another actor is writing to
  the plan.
- Then continue the loop at §1 with the next step number.

## Escalation Handling

An `escalated` verdict or status means a producer decided that another rework round would be
wasted. Read the escalation before doing anything else.

### E.1 Read the Escalation

**Constraints:**
- You MUST locate the escalation: the reviewer's `review.yaml` (`review.verdict: escalated`,
  top-level `escalation`) or the implementer's `result.yaml` (`result.status: escalated`,
  top-level `escalation`). Both carry `reason` and `details`.
- You MUST read `details` in full and read the task file it names. Route on `reason`:

| `reason` | Meaning | Handling |
|---|---|---|
| `spec_defect` | The task cannot be satisfied as written | Candidate for repair — apply the §E.2 boundary test |
| `spec_ambiguity` | The task admits materially different implementations | Candidate for repair — apply the §E.2 boundary test |
| `unrecoverable_state` | The produced change cannot be trusted as a base (e.g. tests deleted wholesale to force green) | **Not** a spec repair. Stop and surface to the user with the evidence |
| `blocked_dependency` | A prerequisite outside this task's scope is missing | Usually a plan-ordering problem — stop and surface to the user |

### E.2 Decide: Repair Inline, or Escalate to the User

You may repair a specification inline **only** when the correction is contained to this task's
requirements plus the shared spec/plan document.

**Constraints:**
- You MUST stop and escalate to the user, without editing anything, when the correction would:
  - change sibling or downstream task files in this or any other step,
  - alter the plan's step structure (adding, removing, splitting, or reordering steps),
  - constitute an architectural or design decision rather than a correction of a clear defect, or
  - leave you genuinely unsure which of several readings the user intended.
- You MAY repair inline when the defect is a self-contained inconsistency in this task's
  requirements or its shared spec doc, and the correct reading is unambiguous from the
  surrounding design documents.
- When you stop, you MUST write the escalation, your boundary reasoning, and the change IDs
  involved into `work_log`, and leave the repository in a clean, non-destructive state. Leave
  both sessions open — the user may want you to resume.

### E.3 Author the Spec Repair as a Separate Commit

The repair commit `S` contains **only** the specification-document edit and its trickle-down into
the task file. No code. No tests.

**Constraints:**
- You MUST edit only spec/design/plan documents and the affected `.code-task.md` file. If you
  find yourself wanting to touch code, you are past the §E.2 boundary — stop.
- You MUST make the task file and the spec document consistent with each other; a task edit that
  leaves the design doc stating the defective requirement just relocates the divergence.
- You MUST commit with a conventional-commit message that names the defect and cites the
  escalation, e.g. `fix(spec): resolve contradictory quota criteria in task-03`.

Then place `S` correctly, in one of two shapes:

**Shape A — produced changes exist** (the usual case). Interpose `S` below the first produced
change, so the implementation series never appears as commits authored against a spec that was
already known to be wrong:

```sh
jj rebase -r <S> --insert-before <I1>     # I1 = first produced change of this task
jj bookmark create pr/<planning_slug>-spec-fix-step<NN>-task<MM> -r <S>
```

Resulting topology — `B` is the task base, `I1…In` the produced series:

```
B ─ S (spec+task fix, bookmarked) ─ I1′ ─ [I2′ …] ─ @ (empty)
```

**Shape B — no produced changes yet** (round-0: the implementer escalated before committing
anything). Author `S` directly on the base `B`; it becomes the new base. Bookmark it the same
way, then restart the task at §4.3 — with a **fresh implementer session**, since the old one's
context is built on the defective task.

**Constraints:**
- The rebase MUST leave `I1`'s content untouched — it reparents, it does not merge. Change IDs
  stay stable; commit IDs are rewritten.
- You MUST verify the resulting topology with `jj log` before proceeding, and confirm `@` is
  still empty.
- You MUST NOT squash `S` into any produced change. Its separateness *is* the audit trail.
- You MUST update `task-record.json`: the base becomes `S`, and `produced_changes` keeps its
  order.

### E.4 Reconcile — Same Implementer Session

Here the long session pays off directly. `awo-orchestrator` had to author a synthetic
`changes_requested` review and resume the binary with `--seed-review`, `--base`, and an ordered
`--produced-change` list, because its implementer was cold. Yours is not. Tell it what changed.

```
The specification you were implementing against was defective and has been
corrected.

The defect: {the contradiction or ambiguity, in one or two sentences}
The correction: {what changed in the task file and the design document}
It was committed separately as {S}, interposed below your implementation, and is
bookmarked pr/{planning_slug}-spec-fix-step{NN}-task{MM}.

Re-read the corrected task file at {task_file}. Your existing implementation
reflects the previous wording. Reconcile it: {specific reconciliation steps}.

Produce a FRESH commit — do not amend or rewrite your earlier changes. Then
re-emit result.yaml plus the complete ```spec-workflow-meta block.
```

**Constraints:**
- You MUST name the defect and the correction concretely. "The spec was fixed, redo it" wastes
  the session's context advantage.
- You MUST give specific reconciliation steps, the way the injected review's `suggested_action`
  would have.
- Then tell this task's **reviewer** — the same session, which has already seen the escalation:

  ```
  The task you escalated has been repaired at the specification, not in the code.

  The defect: {…}
  The correction: {…}, committed as {S} and interposed below the implementation.

  The implementer has reconciled its work against the corrected task. Re-review
  {task_file} against the CORRECTED acceptance criteria:
    current_change: {new tip}
    base_change: {S}
    produced_changes: [{oldest}, …, {newest}]
  ```

- Keep the reviewer session. It saw the defect and raised it; it is the best-placed judge of
  whether the repair actually resolved it.
- When the reviewer returns, route on its verdict exactly as in §4.4. **A second escalation on
  the same task after a repair is a stop-and-ask condition** — do not repair twice in a row.
- On approval, continue at §4.6. The task's bookmark goes on the final tip; the spec commit keeps
  its own bookmark, and both appear in the log as separate, reviewable changes.
- You MUST record the whole sequence in `work_log`: the escalation reason, your boundary
  judgement, the spec commit and its bookmark, and the reconciliation outcome.

## Examples

### Example: normal step

```
Roles resolved from .agents/awo/acpx-config.yaml and recorded in work_log:
  task_generator codex/gpt-5.6-sol/high   implementer opencode/glm-5.3-flash/-
  reviewer       codex/gpt-5.6-terra/high step_reviewer codex/gpt-5.6-sol/high

Step 03, 4 tasks generated → bookmark pr/awo-generate-task-{slug}-step-3

  task-01: impl + rev sessions opened via acpx-open.sh; model/effort verified from the
           session record at open
    round 0 → completed  (I1, stopReason=end_turn, 31m; 2 progress check-ins logged)
              → review → approved
    describe I1 with merge_request; bookmark pr/{slug}/step03/task-01-….code-task on I1
    both sessions closed
  task-02:
    round 0 → completed  (I1) → review → changes_requested (2 important)
    round 1 → completed  (I2) → re-review → approved   (same reviewer: "resolves the
                                                        first half of my prior finding")
    describe I1 with merge_request; bookmark on I2
    both sessions closed
  …

  §5.2 step review: awo-steprev-{slug}-step03 (fresh session, sol/high)
    → verdict remediation_recommended, 1 important: validation duplicated across
      task-02 and task-04. Not deferrable → 1 remediation task written into step03/
      as task-05-….  Commit report+task, bookmark pr/awo-step-review-{slug}-step-3.
    task-05 runs through §4 like any other task → approved.
    Re-run §5.2 once → clean.

  §5.3 tick Step 03 in plan.md, own commit,
       bookmark pr/awo-step-complete-{slug}-step-3.
  acpx-close.sh --sweep --slug {slug} → "swept 0 session(s)" → continue at step 04.
```

### Example: a turn that did not finish

```
task-02 round 0: acpx-prompt.sh exited 10 after 60m — no stopReason in out.json.
  acpx-progress.sh → WORKING, last tool "bazel test //...", 4 events in the last
    minute. The turn is ALIVE; the client detached. Do not prompt, do not touch @.
  Poll every 15m → after 5m more: verdict IDLE.
  Capture out.json/out.err/sessions show/wire tail → round-0.implementer/kill-evidence/
  jj st: 47 files modified, nothing committed.
  → commit as wip(absorbed): interrupted partial removal of absorbed_dependencies
    (description states what it does and does not contain, cites kill-evidence path);
    append to produced_changes.
  → open fresh session …-task02b, prompt it to RESUME: names the wip change, lists
    what its predecessor claimed, instructs it to verify rather than trust.
  → the fresh session finds two regressions the interrupted one never validated.
  Round 0 is not charged against max_rework_rounds.
  §4.6 later: merge_request.body gets the wip description appended as a Recovery note.
```

### Example: spec-defect escalation, repaired

```
task-03 → reviewer escalated, reason: spec_defect
  details: AC2 mandates rejection above quota; AC4 forbids rejecting trial
           tenants, whose quota is 0. No implementation satisfies both.

E.2 boundary: contained — the contradiction is between two criteria of this
     task, and design/detailed-design.md §4 states trial tenants are exempt
     from quota accounting. No sibling task or step structure is affected.
     → repair inline.

E.3 Author S: correct AC4's wording in the task file and the corresponding
     sentence in detailed-design.md §4. Commit; then
       jj rebase -r S --insert-before I1
       jj bookmark create pr/{slug}-spec-fix-step03-task03 -r S
     Topology: B ─ S ─ I1′ ─ I2′ ─ @(empty)   ✓

E.4 Same implementer session: "AC4 was contradictory with AC2; corrected in S to
     exempt trial tenants from the quota check rather than granting them a zero
     quota. Reconcile src/quota.py accordingly." → fresh change I3.
     Same reviewer session: told about the repair → approved.

Bookmark the tip; log both the spec commit and the reconciliation.
```

### Example: escalation that must go to the user

```
task-02 → implementer escalated, reason: blocked_dependency
  details: The task imports lib/validators, which does not exist. The design
           references it as a prerequisite from an earlier step.

E.2 boundary: NOT contained — supplying the prerequisite means adding a task
     to an earlier step, i.e. changing the plan's step structure.
     → do not repair. Stop, write the finding to work_log, surface to user.
     Sessions left open pending the user's decision.
```

## Troubleshooting

### `acpx` exits `4` (no session found)
Almost always a `--cwd` mismatch: acpx keys sessions on `(agentCommand, absoluteCwd, name)`.
Confirm with `acpx --cwd "$REPO" {agent} sessions list --local` and re-issue with the same
absolute `--cwd` you opened the session with. The wrapper scripts all take `--repo` and
canonicalise it, so this should not arise unless a `--repo` was passed inconsistently.

### The agent cannot find the skill
The producer skills must be discoverable by each harness. The repo convention is symlinks in
`{repo}/.agents/skills/` — codex resolves those; opencode also reads `~/.claude/skills/` and
`.opencode/skills/`. If a harness reports it cannot find `task-to-code` or `code-task-review`,
do not paraphrase the skill into the prompt. Point the agent at the absolute `SKILL.md` path and
tell it to read and follow that file, and record the discovery failure in `work_log`.

### `acpx-open.sh` refused to open the session
It verified the pinned model or effort against the session record and they did not match, or
the adapter rejected the effort level outright (`ACP -32602 Invalid params` — that level does
not exist for that model). Do not proceed and do not work around it by calling acpx directly:
a round run on the wrong model invalidates the comparison this prototype exists to make. Fix
the role config or the level name and re-open.

### A turn appears to hang
Run `scripts/acpx-progress.sh` (§Supervising a running turn). It reports the age of the last
ACP event and the most recent tool call, which is what actually distinguishes a working turn
from a dead one.

Do **not** decide this from `acpx status -s`. It has reported `running` with a live pid for
five minutes after a turn was already dead, and it reports `running` for a merely-idle
adapter. Do not cancel a working turn: turns on a large task legitimately take tens of
minutes. `acpx cancel -s {session}` exists and is documented as cooperative, but this skill
has never exercised it, and the one cancellation path it *has* exercised (`--timeout`)
destroys in-flight work while reporting success. Stop and ask instead.

### A session's `cachedReadTokens` dropped instead of growing
Two different causes, and they are distinguishable — an earlier revision of this skill assumed
only the first:

- **Compaction.** Both `cachedReadTokens` and `inputTokens` shrink together.
- **Adapter respawn.** `cachedReadTokens` collapses while `inputTokens` becomes *enormous*
  (one observed case: `cachedReadTokens` 354048 → 8960 with `inputTokens=347915`). The prompt
  cache prefix was thrown away and the whole history re-sent as fresh input. That is a cost
  event, not a history-loss event, and reporting it as compaction is a false finding.

Compaction **is** visible without reading a rollout: codex-acp emits `*Context compacted to fit
the model's context window.*` as assistant text mid-stream, and `acpx-prompt.sh` warns when it
sees it. The rollout remains the authority if you need certainty
(`~/.codex/sessions/{YYYY}/{MM}/{DD}/rollout-*.jsonl`, searchable for `"type":"compacted"`;
it nests by **local** date, and the id in the filename is the `acp_session_id` from the acpx
record, not the acpx record id).

Record either event in `work_log` with the round it happened on. A session that compacted is
no longer the session you think you are measuring, and any claim about its continuity after
that point is unsupported — though an observed instance preserved enough for the reviewer to
score a rework against its own earlier finding correctly.

Mitigations, in the order they were adopted:

1. Keep sessions task-scoped — already the default here.
2. Avoid respawns: the wrappers always pass `--ttl 0`, so a session's prompt-cache prefix is
   never thrown away and its history is never re-sent as fresh input.
3. Raise the harness's context window to near the model's real capability. For codex this is
   `model_context_window` / `model_auto_compact_token_limit` in `~/.codex/config.toml`;
   `max_context_window` in `~/.codex/models_cache.json` is the ceiling (872000 for the
   gpt-5.6 family).
4. Track it and act on it (§Prompting a session): record compaction per round, flag a session
   above 50% of the window, and start a fresh session for the next round rather than let one
   compact.

Note that (3) alone was tried twice and was not sufficient: raising 258400 → 500000 moved the
threshold, and a task-scoped reviewer on a 5-change, 49-file task compacted anyway — it had
reached 354048 tokens on its *first* review turn. With (2) and (4) in place, a session that
still compacts is evidence the **task** is too large, not the window too small. Record its
size in `work_log` when it happens.

### The model or effort changed without you setting it
This was a real defect in acpx 0.12.0 and is **fixed in 0.13.2**, which persists the pinned
model and effort in the session record and replays them on reconnect. If you observe it on
0.13.2 or newer, that is a genuine regression: capture the session record's `acpx` block and
the rollout's `turn_context` entries, record it in `work_log`, and stop and ask. Do not fix it
by editing the harness's global config to match what you wanted — that changes behaviour for
interactive use of the same harness, and only moves which silent default you are relying on.

### `acpx-prompt.sh` exited `10`
The turn produced no terminal `stopReason`, so it did not finish — whatever acpx's own exit
code said. The agent may still be running. Follow §Recovering from a lost turn: confirm it is
actually idle with `acpx-progress.sh` first, capture evidence, and never prompt the session or
touch the working copy until it is confirmed over. The two known causes are a client-side
`--timeout` (which the wrappers never pass) and the orchestrating harness killing the
background call; both present identically in `sessions show`.

### The implementer rewrote its earlier change instead of adding one
Stop. The produced series is the audit trail and awo's whole topology contract depends on it.
Check `jj op log` to understand what happened, record it in `work_log`, and ask the user. Do not
attempt to reconstruct the series yourself.

### The reviewer modified the repository
Stop and investigate. Record what changed. The review is not trustworthy, and neither is the
change under review until you understand the mutation.

### The reviewer's answers are degrading within a task
Record it: which task, which round, what the reviewer missed or waved through, its
`cache_read` at that point, and whether a compaction event preceded it. Watch particularly for
a zero-finding approval arriving right after a run of `changes_requested` verdicts — check
whether the approval cites specific `file:line` evidence per acceptance criterion, or merely
asserts that the criteria pass. The former is a real approval on a small task; the latter is
degradation.

If a task's reviewer is compromised, close it and open a fresh session for the remaining
rounds of that task — and say so in `work_log`, noting that the fresh reviewer will not hold
the prior rounds' findings, so you must pass the previous `review.yaml` path explicitly.

### Stray files in `@` at loop boundaries
Commit them with a descriptive message if their origin is clear (usually an agent that finished
work without committing). If not, stop and ask — never abandon them.

## Artifacts

```
{work_log}                                              — durable orchestration record (you maintain)
{run_dir_root}/{ts}-step{NN}-taskgen/                   — the step's task-generation turn (§2)
  prompt.md / out.json / out.err / assistant.txt
{run_dir_root}/{ts}-step{NN}-steprev/                   — the step-scoped review turn (§5.2)
  prompt.md / out.json / out.err / assistant.txt
{record_dir_root}/{slug}/step{NN}/task-{MM}-{slug}/      — distilled durable record (§4.7, TRACKED)
  task-record.json / round-{N}.result.yaml / round-{N}.review.yaml / kill-evidence/
{run_dir_root}/{ts}-step{NN}-task-{MM}-{slug}/          — per-task record (you maintain)
  task-record.json                                      — base, ordered produced changes, rounds, outcome
  round-{N}.implementer/                                — one --out-dir per turn (§Prompting a session)
    prompt.md                                           — exact prompt sent
    out.json                                            — streamed ACP messages (the black box)
    out.err                                             — acpx diagnostics
    assistant.txt                                       — assistant text, concatenated
    kill-evidence/                                      — present only after a lost turn
  round-{N}.reviewer/                                   — same shape
  round-{N}.result.yaml / round-{N}.review.yaml         — archived copies of the canonical artifacts
  round-{N}.pre-review.topology                         — §Validation Posture snapshot
```

Every turn this skill runs gets an `--out-dir`, including the task-generation and step-review
turns, which are not part of any task.

**`{run_dir_root}` is `.gitignore`d, and must stay that way.** jj auto-tracks new files in
the working copy, so an un-ignored run directory would put a growing pile of agent
transcripts into `jj st` during every implementer turn and invite them into the
implementer's own commits. Keeping it ignored is what makes the run directory invisible to
the agents working in the repo.

The distilled subset is preserved instead, by §4.7, in its own commit under
`{record_dir_root}/{planning_slug}/step{NN}/task-{MM}-{task_slug}/`.

Bookmarks:

```
pr/awo-generate-task-{planning_slug}-step-{N}           — the step's task-generation change
pr/{planning_slug}/step{NN}/task-{MM}-{slug}.code-task  — the task's final tip, consumed by PR generation
pr/{planning_slug}-spec-fix-step{NN}-task{MM}           — an interposed spec repair commit
pr/awo-step-review-{planning_slug}-step-{N}             — the step review report + remediation tasks (§5.2)
pr/awo-step-complete-{planning_slug}-step-{N}           — the checklist-only completion commit (§5.3)
```

Note the step numbers are **not** consistently padded: session names and the task bookmark
use `step{NN}` (`step01`), while the generation, step-review and step-complete bookmarks use
`step-{N}` (`step-1`). Follow each name exactly as written — the task bookmark in particular
is consumed by PR generation and must match to the character.

## Relationship to `awo-orchestrator`

Use `awo-orchestrator` for production runs on the `awo` binary. Use this skill to evaluate
whether long-lived sessions are worth adopting. The differences to watch:

| | `awo-orchestrator` | `awo-acpx` |
|---|---|---|
| Inner loop | `awo run` / `awo rework` | you, over acpx sessions |
| Implementer context | fresh session per round | one session per task |
| Reviewer context | fresh session per round | one session per task |
| Cross-task drift | plan-scoped `implementation-review` at the end | step-scoped `implementation-review` per step (§5.2) |
| Role selection | CLI flags per run | `.agents/awo/acpx-config.yaml` (§Role Configuration) |
| Model/effort | set once by the binary | pinned at session open, verified against the session record (§Sessions) |
| Plan checklist | ticked by `task-to-code` | ticked by the orchestrator, own commit (§5.3) |
| Topology validation | deterministic, in-binary | by inspection (or `check_cmd`), with change-id resolution checked by script |
| Turn liveness | the binary owns the subprocess | `scripts/` wrappers: `stopReason` for completion, ACP event growth for progress |
| Artifact validation | schema-enforced, with repair prompts | tolerant; verdict must still be unambiguous |
| Finalization | `awo run` describes and bookmarks | §4.6, by you |
| Escalation resume | injected `review.yaml` + `awo rework --seed-review …` | one prompt to the live implementer session (§E.4) |

**Findings that drove the current design.** The prototype's original hypotheses were a
task-scoped implementer and a *step*-scoped reviewer. A run over a three-task step
supported the first and only partly supported the second: reviewer continuity paid off
across a task's rework rounds, but no observed finding depended on having reviewed an
earlier task, and the step-scoped session auto-compacted mid-turn. Hence the current
shape — reviewer scoped to a task, cross-task coverage moved to an explicit per-step
`implementation-review`.

The full evidence is in [`eval/reports/`](eval/reports/README.md) — the orchestrator's
own work log from that run, with each finding tagged and traceable to the rule it
produced. Read it before relaxing any constraint in this skill that looks
over-cautious: several of them (never passing `--timeout`, routing on `stopReason` rather
than the exit code, comparing change ids rather than commit ids, testing base *ancestry*
rather than identity, checking that every change id in a prompt resolves) exist because the
obvious-looking version was tried and silently failed.

The second run's conclusion was that the orchestration logic held up while the skill's
*model of its own tooling* did not — every serious finding was the skill confidently
asserting something false about acpx. That is why the acpx surface now lives in
`scripts/`, where the assertions are executable and can be re-tested against a new acpx
release, rather than in prose that cannot.

**If you run this skill and hit something it does not cover, add a report.** A run that
surfaces a defect and leaves no record is a run that will be repeated.
