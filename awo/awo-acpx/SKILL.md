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
   being told it had existed; another, after a 67-minute idle gap, opened its rework by
   citing a task requirement *by number* that appeared nowhere in the prompt.

   The speed-up is real but conditional. Observed rework rounds ran 1.1–5.2× faster than
   the initial round, and the spread is explained: **the saving is in re-orientation, not
   in execution.** A small fix is nearly all re-orientation, so it approaches 5×; a fix
   that moves a package between namespaces and re-runs a full build gate is nearly all
   execution, and measured 1.1×. Treat 3–5× as an upper bound on tasks whose rework is
   small, not as a property of the mechanism.
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
  A **soft limit**: it bounds grinding, not progress. See §4.4 — you may exceed it while the
  loop is still converging, and you MUST record each round taken beyond it.
- **turn_check_interval** (optional, default: `900` seconds): How long to wait before
  checking on a turn in flight, per §Supervising a running turn. Check-ins are an exception
  path — most turns finish inside this interval, so on a healthy run the check never fires
  and the per-turn token/wall lines are the record — but they pay for themselves on the long
  ones: on a 53-minute turn a check-in named the design decision the implementer had taken
  forty minutes before the result was readable.
- **turn_idle_warn** (optional, default: `900` seconds): How long a turn may go without a
  single ACP event before `acpx-progress.sh` calls it stalled.

**Constraints for parameter acquisition:**
- You MUST resolve `plan_file` and `repo` before starting; everything else has a derivable default.
- You MUST read `work_log` (or create it) before touching the repository, and locate the
  loop position per **§0 Resuming** before doing anything else. The plan may be partially
  complete — never assume you start at step 1, and never assume a step starts at §1: a run
  that stops at a task boundary mid-step is the normal way these runs end.
- You MUST verify `acpx` is on `PATH`, that `acpx --version` reports **0.13.2 or newer**
  (see §Sessions for why), and that both agents are configured (`acpx config show`) before
  the first step. A missing agent, or an older acpx, is a stop-and-ask condition.
- You MUST drive acpx exclusively through this skill's `scripts/` directory
  (`acpx-open.sh`, `acpx-prompt.sh`, `acpx-await.sh`, `acpx-progress.sh`,
  `acpx-evidence.sh`, `acpx-close.sh`) and resolve every
  change id through `scripts/jj-change-id.sh`. The raw CLI's exit codes and status output
  are not trustworthy on their own; the scripts encode what is. If a script is missing or
  not executable, stop and ask rather than hand-rolling the invocation.
- You MUST record a quota reading at preflight (`scripts/codex-quota.sh`, §Operating
  Constraints) alongside the resolved roles, **with its age**, and re-measure it at each task
  boundary. A run that does not know where it sits in the weekly window cannot tell whether
  its remaining steps fit, and the answer is a planning input: one observed step cost roughly
  **28 % of a weekly window** across 30 agent turns. At preflight the reading is normally
  inherited from the previous run and is **not** a launch gate — see §Operating Constraints:
  launch, then measure from the first turn's own rollout.
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
    model: gpt-5.6-luna
    effort: max
  step_reviewer:                        # §5.2 — implementation-review at step scope
    agent: codex
    model: gpt-5.6-sol
    effort: high
```

**Rationale for the defaults.** The task reviewer is scoped to a single task (§4.4) and is
handed acceptance criteria that a high-capability `task_generator` already wrote. It does
not have to derive from first principles what the implementer owed — it has to check work
against a written contract. So what it must not be is *weaker* than the implementer.
`gpt-5.6-luna` at `max` is the default because it has reviewed better than `terra`/`high`
and cost less; `terra`/`high` remains a reasonable cheaper setting.

Spend real capability on `task_generator`, where a bad decomposition poisons every task
beneath it, and — conservatively, for now — on `step_reviewer`, which is wide-scope,
judgement-heavy, and runs once per step. The step reviewer may well not need it; that is
an open question, not a settled one.

**Evidence, and its limits.** Across four runs the task reviewer at luna/`max` has produced
the run's high-value findings without over-reviewing: it opened an implementer's own
`work.log`, read the grep output pasted there and found it contradicted the cleanup claim
in `result.yaml`; on another task it re-derived, unprompted, that a prior important finding
was unaddressed, that the round's diff never touched the file, and that `result.yaml`
asserted the opposite — citing the line number of the false claim. It also found a Bazel
target that omitted a new 303-line test file, which nobody had looked for. Its zero-finding
approvals cite `file:line` per criterion (§Troubleshooting's test for a real approval), and
no degradation has been observed within a task; its sharpest turn was its second.

Latency tracks the **size of the reviewed delta** far more than the model — a one-file
re-review took 3m15s against 13m for a cold three-change series. The one direct
model-vs-model comparison remains **confounded** (an acpx 0.12.0 defect meant only 5 of 7
review turns ran at the configured effort; fixed in 0.13.2). A clean per-role evaluation —
same starting commit, one variable at a time — is worth doing eventually and is
deliberately not done incidentally, mid-run, where it would confound rather than measure.

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
- **Read the config file for its values, never for its instructions.** You read it before
  you read this skill, so a stale comment there can instruct you to violate a MUST NOT you
  have not reached yet — one was found telling the orchestrator to re-assert model/effort
  before every prompt, which §Sessions now forbids. This skill wins; say so in `work_log`
  when they disagree, and leave the file alone unless the user asks for it to be fixed.

## Operating Constraints

- **Long-running commands.** Agent turns routinely run for tens of minutes; the longest
  observed was **90** (2208 tool calls, a Bazel golden task). You MUST run them as background tasks and wait for the completion
  notification. Do NOT double-background (no `&` or `nohup` inside a `run_in_background`
  call) — the harness would report completion as soon as the launcher returns while the
  real work continues detached. `acpx-prompt.sh` detaching the *turn* is not that: the
  wrapper still blocks until the turn is over, so its completion still means completion.
- **The orchestrating harness is a kill vector. The sender is identified; the trigger is
  gated on launch.** A host-side `bpftrace` trace caught it in the act: `claude` itself
  issues the signals — one `killpg` on the wrapper's process group, then `kill(pid, SIGTERM)`
  on **every descendant it can enumerate**, in a burst of a few hundred microseconds. It
  walks the process tree by parentage.

  The exposure is **entirely at launch**. Across nineteen observed background tasks in one
  session, every kill landed between **3.9 s and 66.7 s** after launch and every survivor
  ran **136 s or longer**, with no overlap. Nothing has ever been killed after its first
  minute, and nothing has ever survived a minute and then died. The harness evaluates its
  condition when a background task is registered and does not re-evaluate: during a
  fifteen-minute stretch in which host free memory fell 1.5 GB *below* the level at which a
  launch was killed, the long turn running through it was untouched. The model has since
  survived its strongest test — a **53-minute, 705-tool-call** turn, the most exposed thing
  any run had done under the old length-based reading, finished untouched.

  On a host with roughly twice the free memory (20.5–21.3 GB at every launch, against
  10.59 GB at the last kill) a later stretch ran **0 kills in 14 launches**, against the
  7-in-19 baseline. That is consistent with the model and with host reclamation being
  sufficient, but the wrapper scripts and the host memory changed together so it attributes
  to neither, and fourteen launches against a 37 % rate is suggestive, not settled. Do not
  read it as the vector being closed.

  Four consequences, and you MUST hold all four:
  1. **You cannot prevent it, and turn *length* is not the risk.** Do not try to hold a
     turn open by raising a harness timeout, and do not read a kill as something the turn
     did wrong. Risk is proportional to how many turns you launch, not how long they run.
  2. **`setsid` does NOT protect the turn — this was believed and it is false.** An earlier
     revision of this skill told you the turn survives because it holds its own process
     session. It does hold its own session, and the `killpg` genuinely misses it — but the
     harness then kills it by explicit pid anyway. A trace of one kill shows nine signals
     taking the wrapper, the turn, the whole adapter chain (`bun` queue owner, `node`
     `codex-acp`, the agent's `app-server`) and the wrapper's own poll `sleep`. Treat exit
     `11` as *possibly* recoverable, never as certainly recoverable: run
     `acpx-progress.sh` first — it is the authority — and only reattach with
     `acpx-await.sh --out-dir` if it says the turn is alive. On `4` (dead), go to
     §Recovering. The one thing observed to survive is an adapter already reparented to
     pid 1 by a *previous* turn — i.e. a warm session's queue owner, which is luck, not
     design.
  3. **Reclaim host memory immediately before a launch, not during a turn.** Two of six kill
     events named a reason and both said the system was low on memory. The measured margin
     between a killed launch and a surviving one is only ~320 MB of `MemAvailable`, and the
     condition is read *at launch*. So anything you can free belongs at a task boundary
     right before the next launch; nothing done mid-turn matters. The other four events
     gave no reason at all, so do not assume memory explains every kill.

     Three specifics, because the margin is smaller than any of the terms:
     - **The project's build server is usually the largest process in the sandbox**, ahead
       of every adapter and ahead of `claude` itself — a Bazel JVM measured **1261 MB**,
       against a discriminating margin of ~320 MB. It belongs to no acpx session, survives
       every `acpx-close.sh --sweep` and every session restart, so nothing else in this
       skill reclaims it. Shut it down (`bazel shutdown`, or the project's equivalent) at
       the task boundary before a launch, and record whether it was a no-op — a run that
       claims a reclamation it did not perform is worse than one that reports the no-op.
     - **Adapter residency is the second term**, and it is one this skill creates: `--ttl 0`
       holds an implementer *and* a reviewer adapter open across a whole task
       (§Closing a session). Closing the other role's session before a launch is a live
       option when memory is tight.
     - **Your own verification work is a memory event.** Running the project's gate to check
       a producer's claim starts the same JVM you just reclaimed — observed three times in
       one run. Verify *before* the boundary reclamation, never between the reclamation and
       the launch.
  4. **§4.3's incremental-commit paragraph is the rest of the defence.** It is not
     decorative and it is not one anecdote's worth of caution: turn loss can be bounded,
     not prevented, and that paragraph is what bounds it. Because kills are launch-gated
     they usually cost seconds of agent work — the one turn that batched its work to a
     single commit at the end lost 65 minutes.
- **Usage quota is a launch gate, and exhausting it mid-turn presents as a stall.** acpx
  does not surface quota at all — no flag, no subcommand — but the codex harness records it
  on every `token_count` event in its rollout
  (`~/.codex/sessions/{YYYY}/{MM}/{DD}/rollout-*.jsonl`), as a `rate_limits` block carrying a
  **primary** (5-hour) and a **secondary** (weekly) window. `scripts/codex-quota.sh` reads
  the most recent block from the most recently written rollout. It costs nothing and touches
  no network, so there is no reason not to run it before every launch.

  **Run it before the launch, because after the launch it is too late to be useful.** A turn
  that exhausts the window mid-flight does not error and the adapter does not exit: it
  completes a tool call, then emits no further ACP event while `status` still reads
  `running`. `acpx-progress.sh` necessarily calls that STALLED, and there is no signal
  available to it that would say "quota" — one turn was lost this way and the cause was only
  established an hour later by asking the user. Checking beforehand converts an hour of
  waiting into one cheap command.

  Measured costs against the **weekly** window, per acpx session across all its rounds: an
  implementer round **3–5 %**, a reviewer round **1–2 %**, a whole two-round task **4–5 %**,
  and the largest single session observed **5 %** (a 67-minute, 2353-tool-call implementer
  turn). Reviewers are close to free in quota terms, so there is never a quota case for
  skipping a review. Size headroom against the maximum, not the average: **below 93 % launch
  freely; between 93 % and ~95 % only reviewer-sized turns; above that a large implementer
  turn can exhaust the window mid-flight.** 93 % is the launch floor the script encodes.

  **Weekly exhaustion is a stop-and-ask, not something to wait out.** The reset is days away,
  the user holds manual resets that replenish it, and there is no local API to trigger one.
  The 5-hour window is the opposite: it rolls, so holding an expensive turn until it resets
  is usually cheaper than losing the turn to it.

  **A reading is produced only by a turn, so a resumed run cannot measure quota until it
  launches one.** There is no poll, no endpoint, nothing to wait for: `rate_limits` appear
  only as a side effect of a turn running. The newest block on disk is therefore whatever the
  *previous* run left behind, and after a stop it can be arbitrarily old — `codex-quota.sh`
  prints the reading's age and says so loudly past 30 minutes. Two consequences, and the
  second is the one that bites:

  1. **A pre-break reading is a lower bound on usage, never an upper one.** Between the
     reading and now the windows can only have replenished — by rolling, or by a manual
     reset the user redeemed — and can never have worsened, because nothing ran. So a bad
     old figure is uninformative, not alarming.
  2. **Do not gate the first launch of a resumed run on it, and do not stop and ask on it.**
     That is a deadlock: the only action that can refute the figure is the launch the
     stop-and-ask is refusing. **Launch anyway** — the cheapest useful turn if the old
     reading looks bad, since task generation and reviewer turns cost 1–2 % — and take the
     real measurement from *that* turn's own rollout, then gate every subsequent launch on
     it. The weekly stop-and-ask above applies to a reading produced **in this run**; it
     does not apply to one inherited across a break. This is not hypothetical: one run's
     preflight read primary 99 % / secondary 93 %, the user reported having redeemed a
     manual reset, and the first turn's own rollout came back **18 % / 3 %**.

  Two further ways to misread the reading. A block whose `resets_at` has already passed is
  **stale, not current** — `rate_limits` refresh only when a turn runs, so the figure predates the
  reset and quota has almost certainly replenished; the script says so rather than making you
  infer it. And do **not** estimate burn by summing `last_token_usage.total_tokens`: with
  prompt caching every request re-reports several hundred thousand cached-read tokens and the
  sum overcounts by more than an order of magnitude (~370 M tokens for 23 % of a window).
  The percentage is the billed truth; tokens are a scale indicator. `scripts/quota-burn.py`
  attributes burn per session correctly, by bracketing each rollout's first and last snapshot
  — one acpx session is one rollout file.

  This is a **codex-only** reading. The opencode adapter publishes no equivalent, so for an
  opencode role record that no quota was evaluable, exactly as §Prompting a session requires
  for a context denominator that does not exist. That role's exhaustion will still arrive as
  a stall, and asking the user is then the only way to name it.
- **One turn at a time per session.** acpx queues concurrent prompts to the same session through
  its queue owner. Never issue a second prompt to a session with a turn in flight — including
  one you believe is lost but have not confirmed idle.
- **Never destroy completed work.** No `jj undo`, and no amending or squashing changes
  produced by a task loop, except the description-only `jj describe` that §4.6 requires.
  Every recovery must be additive. `jj abandon` is permitted **only** under the narrow
  predicate in §Recovering from a lost turn.
- **jj only.** Inspect and mutate the repository with jj.
- **Create bookmarks, never move them.** Always `jj bookmark create` — never `jj bookmark set`.
  `create` fails if the name exists, surfacing a collision or an unintended re-run. A `create`
  failure is a stop-and-investigate signal, not a reason to switch to `set`. It protects
  against a duplicate *name*, not against a correct name on the wrong revision, which raises
  nothing — so verify the target afterwards (§4.6).
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

The turn itself runs **detached**, under `setsid`, with its pid in `{round_dir}/turn.pid`;
the wrapper is only a waiter. That buys less than an earlier revision claimed. A kill aimed
at the wrapper's *process group* cannot reach the turn — verified — but the harness does not
stop there: it enumerates the wrapper's descendants and kills each by pid, crossing the
`setsid` boundary (§Operating Constraints). The turn therefore **sometimes** outlives the
wrapper and sometimes does not. `out.json` is streamed rather than buffered precisely so that
either way the partial transcript is on disk; that is the guarantee `setsid` failed to give.

**Constraints:**
- You MUST run this as a background task and wait for the completion notification. You
  MUST NOT double-background it (no `&` or `nohup` inside the backgrounded call) — the
  harness would report completion as soon as the launcher returned while the real work
  continued detached.
- **Check quota immediately before the launch**, with
  `scripts/codex-quota.sh [threshold]`, and record the reading alongside the round's token
  line. This belongs at the same task boundary as §Operating Constraints' memory
  reclamation, for the same reason: both conditions are read at launch and neither can be
  repaired mid-turn. Exit `1` means the primary window is at or above the threshold —
  hold an expensive turn until it rolls rather than launching into a near-certain mid-turn
  exhaustion, which is the one failure that cannot be waited out or distinguished from a
  hang. Take the weekly window's 93 % launch floor from the same output.
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
- **Context headroom.** After each turn, compare `totalTokens` against the context window
  the harness is actually enforcing. If a session exceeds **50%** of the window, say so in
  `work_log`. The window is a **per-harness** figure and one of them does not publish it:
  for the opencode implementer there is no such figure anywhere in its config, and this is
  the session the skill most cares about keeping uncompacted. Resolve each role's
  denominator during preflight and record it.

  **For codex, take the denominator from the harness's own `token_count` event, not from
  `~/.codex/config.toml`.** Every such event in the session's rollout
  (`~/.codex/sessions/{YYYY}/{MM}/{DD}/rollout-*.jsonl`) reports the
  `model_context_window` the harness is governing by, and it has been observed **disagreeing
  with the configured value**: `config.toml` said 850 000 while the events reported
  **807 500**. Percentages computed against the config figure were therefore all ~5 % low —
  enough that the 50 % flag failed to fire on a session that had actually crossed it, and
  a run recomputed three sessions' figures after catching it. Read the real denominator once
  per role, from the first turn's rollout, and record *where you read it from* — an earlier
  run reverted to the config value at its next session start, which is exactly how a
  corrected denominator gets silently un-corrected. Where none exists, record `totalTokens` per round and say
  explicitly that **no threshold was evaluable** — an orchestrator that silently skipped
  the check is indistinguishable from one that evaluated it and found nothing. The
  fallback signals still work there: `acpx-prompt.sh` warns on an announced compaction,
  and that warning is the thing you actually act on.

  **50 % is a flag, not a trigger, and do not project it linearly.** Context grows with the
  *size of the delta under review*, not with the round count: one observed session went
  +112k on a round that reviewed nine files and +41k on the next, which reviewed two — so a
  projection built on the previous round's increment over-predicts. Do not retire a session
  at 50 % on arithmetic alone.

- **Retiring a session is a judgement call, and you are expected to make it.** Above the
  50 % flag, weigh two signals and act on them without asking:

  1. **Context.** Around **60 %** of the window, a restart is more likely right than wrong.
     This is a signal, not a threshold to compute against — a session at 56 % whose next
     round will plainly cross 60 % is already a candidate.
  2. **Convergence.** A round that is **not converging** is a restart signal on its own, at
     any context level. What that looks like in practice, all of it observed: a turn that
     returns `end_turn` with **no repository change at all**; a turn far shallower than its
     predecessors (31 tool calls against 138–648); a rework that **regresses** an acceptance
     criterion that previously passed; a session that invents bespoke machinery rather than
     reuse what earlier steps shipped, and keeps defending it across rounds; a session
     asserting something false about **its own history** (one claimed its prior turns were
     fabricated when the diffs were on disk and correct). Findings that plateau rather than
     fall — 2 → 2 → 2 — count too.

  When you retire, say so in `work_log` **with the numbers behind it**: the token figure and
  percentage, the round's tool-call count, and the specific non-convergence signal. A
  restart recorded without its evidence cannot be evaluated later.

  Weigh the cost honestly in both directions. An accumulated reviewer session is what lets
  it say "still absent" about its own prior finding, which is the mechanism that catches a
  non-convergent rework, and a fresh one has to be re-fed the archived reviews to do the
  same — so a warm session that is converging keeps its round. But the replacement is
  **cheap and repeatedly productive**: the producers' on-disk state (the task file,
  `result.yaml`, `review.yaml`, the scratchpad) is designed to work from a cold session. In
  observed runs a fresh reviewer found a fail-closed hole four warm rounds had missed, and a
  fresh implementer — told explicitly to prefer the existing machinery its predecessor had
  bypassed — closed the task in one round. A long-lived session buys continuity and pays for
  it in independence.

  **"A restart costs one round of re-orientation" is too pessimistic at scale, and the
  measured cost has been close to zero.** On the largest task of one run, a replacement
  implementer handed its predecessor's scratchpad ran to 2265 tool calls against that
  predecessor's 2353 and closed a critical finding, six important findings and two injected
  items in a single round. That task took three restarts — no producer session survived more
  than one round — and still converged in three rounds. The result is about the *artifacts*,
  not the sessions: continuity is worth having, and it is evidently not what makes a large
  task tractable.

  **What decides it above the flag is the size of the remaining work, not the percentage.**
  The counter-case is recorded too: a task kept both sessions past 50 % because what was
  left was one test-matrix entry plus some assertions — the implementer's next round took
  **112 seconds** against round 0's 2258, and a restart would have cost more in
  re-orientation than the whole remainder of the task. Read the two together: a large
  pending rework on a session near the window is the case for retiring it, and a small one
  is the case against, at the same percentage.

- **A compaction is not a judgement call.** If a session compacts, or would plainly exceed
  the window on the next round, **close it and open a fresh one for the next round**, and
  record that you did. A session that compacted has silently lost the continuity this skill
  exists to test: you would be measuring a session that is no longer the one you think it is.

- When you reopen a role mid-task, the fresh session's prompt MUST name the produced series,
  the work log, the path to the reviews or results it needs to read, **and the predecessor's
  own scratchpad files** (`context.md`, `plan.md`, `progress.md`, `work.log`) so the task is
  re-read rather than re-derived — that naming is what makes the restarts above cost nearly
  nothing. It MUST also say plainly that the predecessor was retired for context and that its
  committed work is not in doubt on those grounds, and forbid amending the inherited changes.
  Where a restart was triggered by a specific non-convergence signal, it MUST name what its
  predecessor got wrong. Do not merely re-issue the round's prompt: the point of the restart is that the
  next turn approaches the round differently.
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
| `10` | The turn ended without a terminal `stopReason` | It really was lost. Do not prompt the session, do not touch the working copy. Go to §Recovering from a lost turn |
| `11` | **The wrapper was killed** | The turn *may* have survived — `setsid` does not reliably protect it (§Operating Constraints). Run `scripts/acpx-progress.sh` first: on `0`/`1` the turn is alive, so reattach with `scripts/acpx-await.sh --out-dir {round_dir}` as a background task, exactly as you launched the prompt. On `4` (dead) the turn went with the wrapper — go to §Recovering from a lost turn. Charge nothing until you know which |
| `2` | Usage error in the wrapper | Fix the invocation |

A harness kill may also leave **no exit status at all** — the wrapper is SIGKILLed, or the
harness reports the call as stopped rather than failed. That looks the same as `11` and is
handled the same way: check `acpx-progress.sh` first, and if the turn is still working,
reattach with `acpx-await.sh`. `{round_dir}/wrapper-signals.log` records which signal the
wrapper caught, if any; an absent log beside a dead wrapper means SIGKILL, which is itself
worth recording.

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

A real implementation turn runs for tens of minutes; the longest observed was **90**, at
2208 tool calls. There is no timeout, so you supervise instead. That turn was supervised by
seven check-ins, every one of them `WORKING` with a monotonically rising event count
(197 → 437 → 707 → 861 → 1065 → 1211 → 1637) — which is what a long healthy turn looks like,
and what distinguishes it from the stall it would otherwise be mistaken for.

**Check-ins are an exception path, not the routine record.** Most turns finish inside
`turn_check_interval` — observed completions span roughly 2.5 to 53 minutes, and the
majority sit under 15 — so on a healthy run the check never fires, and that is the normal
case rather than an oversight. The routine per-turn record is the wall-clock and token line
`acpx-prompt.sh` prints (§Prompting a session); that is what reconstructs a run's cost.
Check-ins exist for the long turn and for a turn you have reason to doubt. Run one when the
wait exceeds `turn_check_interval`, when a completion notification arrives without a
summary, and whenever you are about to conclude a turn is dead. Do not manufacture them,
and do not claim you performed one you did not.

**How to wake up mid-turn.** You are re-invoked on background-task *completion*, never at
an arbitrary elapsed time, and a foreground `sleep` is blocked — so a check-in needs a
mechanism, and there are two. In order of preference:

1. **Poll the turn's own task with a timeout.** `TaskOutput` takes a timeout and returns
   control to you when it expires *without* ending the turn. Polling it in slices of
   `turn_check_interval` gives you a wake-up per slice at **no extra process and no extra
   background-task launch**, which matters because launch is the harness's kill window
   (§Operating Constraints). This is the first-choice mechanism, verified over four
   check-ins on one 53-minute turn.
2. **A companion background task**, for a harness whose task-output call does not take a
   timeout: launch a second background task alongside the turn that sleeps
   `turn_check_interval` and then runs `acpx-progress.sh` for the same `--out-dir`; its
   completion is the wake-up. This is not double-backgrounding — it is a separate task with
   its own completion, and it blocks until its own work is done. It costs an extra launch,
   so do not schedule these speculatively on turns you have no reason to doubt.

Check-ins earn their cost on a long turn: on the 53-minute one, the second reported not
just that the turn was alive but the `sed -i` it was running, which named the design
decision it had taken forty minutes before the result was readable.

**Constraints:**
- The check is:

  ```sh
  scripts/acpx-progress.sh --repo "$REPO" --agent {agent} --session {session} \
                           --out-dir {round_dir}
  ```

  It reports the age of the last ACP event, the running tool-call and message counts, the
  title of the most recent tool call, and whether the detached turn's own pid is still
  alive. Its exit status is `0` working, `1` stalled, `3` idle (no turn in flight, or this
  turn's stream already carries a `stopReason`), `4` **dead** (the turn's process is gone
  and it produced no `stopReason` — it was killed).
- **Liveness is event growth, not `status: running`.** The script defines it that way and
  you MUST NOT substitute a status check. An agent that has been sitting in one tool call
  for twenty minutes is a different situation from one that is stepping through a build,
  and only the event stream distinguishes them.
- Record each check-in in `work_log` as one line: elapsed, tool-event count, last tool.
  Those lines are how a run's real cost is reconstructed afterwards.
- On `1` (stalled): check once more after another `turn_check_interval`. If it is still
  stalled with the same last tool, **stop and ask** — quote the last tool call and the
  elapsed time. Before you do, run `scripts/codex-quota.sh`: a STALLED verdict with a live
  adapter, a *completed* last tool call and no child process doing work is the exact
  signature of a mid-turn quota exhaustion, and the reading names it in one command. The
  script is the cheap half of the answer; the user is the other half, since a role whose
  harness publishes no quota leaves asking as the only way to tell. Do not wait longer in
  the hope of resolving it — a weekly window does not roll inside a turn. Do not cancel it yourself: `acpx cancel -s` exists but its cooperativeness
  is untested, and the one cancellation mechanism this skill has tested (`--timeout`)
  destroys work.
- On `4` (dead): the turn is over and it was lost. Go straight to §Recovering from a lost
  turn — do not wait, do not poll again, and do not escalate it as a stall. This verdict is
  the difference between a 60-second recovery and thirty minutes of waiting followed by a
  spurious stop-and-ask.
- You MUST NOT touch the repository while a turn is in flight or unconfirmed-dead. A
  turn believed lost has been observed still holding uncommitted work.

### Recovering from a lost turn

**First: is it actually lost?** Not necessarily — but do not assume it survived, either.
The turn runs detached under `setsid`, and that defeats the harness's `killpg` but not its
per-pid tree walk (§Operating Constraints). Establish which happened before you act.

- `acpx-prompt.sh` exited **`11`**, or the harness killed the call and reported no status:
  the *wrapper* died. **Run `scripts/acpx-progress.sh` to find out whether the turn died
  with it.** On `0` (working) or `1` (stalled) the turn is alive: reattach with
  `scripts/acpx-await.sh --out-dir {round_dir}`, backgrounded exactly as you launched the
  prompt, and wait for it — nothing is lost, nothing is charged, and the rest of this
  section does not apply. On `4` (dead) the turn was killed too: continue here. Record the
  interruption, the `acpx-progress.sh` verdict, and what you did in `work_log`.
- `acpx-prompt.sh` exited **`10`**, or `acpx-progress.sh` reports **`4` (dead)**: the turn
  is genuinely over without a `stopReason`. Continue here.

**Constraints:**
- You MUST first confirm the turn is actually over, with `acpx-progress.sh`. Never act on
  a turn that is still producing events. It is over when the script reports `3` (idle — a
  terminal `stopReason` arrived) or `4` (dead — the turn's process is gone and no
  `stopReason` ever arrived). **A killed turn never reports idle**: idle means a
  `stopReason` exists, which is exactly what a kill prevents. An earlier revision of this
  section said to poll until `3`, which on the one path it was written for could not
  happen — the script would report `WORKING` for `turn_idle_warn` seconds and `STALLED`
  forever after, costing about half an hour and a spurious stop-and-ask per kill. If the
  script reports `0` or `1`, the turn is still alive: reattach, do not recover.
- You MUST capture evidence before changing anything:

  ```sh
  scripts/acpx-evidence.sh --repo "$REPO" --agent {agent} --session {session} \
                           --out-dir {round_dir} --note "what you observed"
  ```

  It writes `{round_dir}/kill-evidence/` in two tiers: small interpreted files
  (`NOTES.md`, `sessions-show.txt`, `status.txt`, `wrapper-signals.log`, `resources.txt`,
  `jj-st.txt`, `jj-log.txt`, `jj-diff-stat.txt`) and a `raw/` holding `out.json`,
  `out.err` and the wire-log tail. **Only the first tier is copied into tracked history**
  (§4.7): a fifty-line ACP wire tail measured 243 KB, because wire lines embed whole file
  contents, and two kills on one task once committed more bytes than the distilled records
  of three tasks combined. The raw tier stays in the gitignored run dir, where it is
  actually used — during the incident.
- **Reading the evidence.** `sessions show`'s `disconnectReason: pipe_close` + a
  `lastExitAt` is not a kill signature on its own (§Deciding whether a turn finished) — it
  appears on a healthy just-configured session. It becomes informative when **ordered**: a
  `lastExitAt` *after* `lastPrompt`, with no live pid, is an exit mid-turn and cannot be
  produced by the healthy case. `resources.txt` records `/proc/meminfo`, memory pressure and
  the largest resident processes at the moment of the kill — the numbers that discriminate a
  killed launch from a surviving one (§Operating Constraints) are `MemAvailable` and the
  build server's RSS, and neither is visible in `free` alone, which is why an earlier
  revision's evidence tier produced four false negatives about the resource hypothesis.
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

  **Clause 3 fails closed.** It is only a guard while `task-record.json` is current, and
  §4.2's record has been found stale after a completed round — against an empty
  `produced_changes` the clause is vacuously true for *every* change and the predicate
  silently degrades into the "everything above the newest bookmark" test the paragraph
  above forbids. So: if `produced_changes` is empty while changes exist above the base,
  **abandon nothing**. Re-derive the series from the revset in §4.2, write it into the
  record, and re-evaluate — or, if you cannot, stop and ask. A guard that reads a file
  nothing keeps current reads as protection when it is not.
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
- **Loop guard, per role.** The guard exists to stop an orchestrator grinding against a
  flake it does not understand *while that grinding can damage state*. So it counts losses
  **per role within a round**, not per round:
  - **Implementer:** at most one automatic recovery per round from an undiagnosed cause. A
    lost implementer turn can leave partial, unvalidated work in the repository, which is
    the risk the guard is about. A second implementer loss on the same round is
    stop-and-ask.
  - **Reviewer:** a lost reviewer turn that provably changed nothing — the pre/post
    topology snapshots of §Validation Posture diff clean and `jj st` is clean — does not
    count against the guard. The reviewer does not write to the repository and re-running
    it is idempotent, so there is no state to damage. Recover it and say so. Two reviewer
    losses in a row on one round still warrant a look at the environment; three is a
    stop-and-ask.
  - A round is one implement/review cycle, and `rounds[]` in `task-record.json` holds both
    roles under one round number. Do not read "round" as "turn" when charging the guard;
    read it as "turn" only for the per-role counts above.

  You MAY override the guard when you have diagnosed the cause and can name the specific
  fix; declare the override in `work_log` and stop unconditionally if it recurs. Note that
  a **diagnosis without a fix is not an override** — the harness kill vector is diagnosed
  (§Operating Constraints) and has no fix on this side, which is exactly the case the guard
  covers. What removes the harness kill from the guard's scope is not diagnosis but
  detachment: a kill that `acpx-await.sh` reattaches to is not a loss at all.
- A lost turn MUST NOT consume a `max_rework_rounds` slot. No review happened, so no
  round elapsed; charging it would let flaky infrastructure fail a healthy task. Neither
  does a reattach — that is not even a loss.
- Note that the `jj abandon` predicate above has **not applied in any real kill so far**:
  in every one, the turn died inside its first minute with nothing committed and nothing
  in `@`. That is what "launch-gated" means in practice, and it is the reason the losses
  cost seconds rather than an hour. Keep the predicate — it guards the expensive case —
  but do not go looking for work to abandon.
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
- The wrappers run with `--ttl 0`, so the queue owner **never reaps itself**. That is what
  keeps a session's pinned configuration and prompt-cache prefix alive between turns, and
  it has eliminated compaction — zero compactions across two runs. The price is that
  **adapter residency is a kill-risk input, not tidiness**: resident adapters are the
  second-largest controllable term in the memory condition that gets launches killed
  (§Operating Constraints), and this design deliberately holds an implementer *and* a
  reviewer adapter open across a whole task. So closing is mandatory rather than hygiene,
  and closing the other role's session before a launch is a live option when memory is
  tight.
- You MUST close the implementer and reviewer sessions at the end of each task, and the
  step reviewer at the end of each step — including when the task or step ends in a block
  or an escalation.
- You MUST run `--sweep` at every **step boundary** and at **end of run**, and report the
  count it prints in `work_log`.
- **A mid-task stop-and-ask is not a sweep point.** Sweeping there destroys exactly what
  the user may be about to ask you to resume — a live implementer adapter holding a whole
  task's context, which is the thing this prototype exists to measure. At a mid-task stop:
  close what is **dead** (a session whose turn was killed and which §Recovering forbids
  resuming anyway), leave open what still **holds context**, and name every session you
  left open, prominently, in `work_log` so it cannot be silently orphaned. This is §E.2's
  rule ("leave both sessions open — the user may want you to resume") and it governs every
  mid-task stop, not only escalations. Sweep when the run actually ends.
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
- **A producer's prose about its own actions is not evidence — test it against the diff.**
  After every implementer turn, run `jj diff -r {produced change} --summary` and compare the
  file list against what the turn claims it did — on a rework round, the `file:` fields of
  the findings it was told to address; on round 0, `result.yaml`'s own account. Record any
  finding whose file was never touched. This is mechanical and costs one command:
  it does not require judging whether a fix is *correct*, only whether the file was opened at
  all. It is not hypothetical — an implementer reported "the Bazel `go_component` members now
  mirror `component.textproto` exactly" about a file its change never touched, and then, a
  round later, offered a confident root-cause story for that first claim ("the round-1 edits
  were dropped from the commit") which `jj evolog` flatly contradicts: no snapshot ever held
  the edit. The loop does catch this — §4.4's re-review caught it unprompted — but one round
  later and one review more expensive than the diff would have cost. Treat a producer's
  narrative about its own work as unverified, **including when it sounds like forensics.**
- **A produced change that touches the specification is an escalation, whatever the
  producer called it.** After every implementer turn, check whether the produced series
  touched any file under `.agents/tasks/` or `.agents/planning/` — one `--summary` you are
  already running for the check above. If it did, do not route on `result.status`: go to
  §Escalation Handling and apply §E.2's boundary test yourself. See §E.0 for why this
  is mechanical rather than a matter of judgement. (The check is on an *implementer*
  turn's produced series. Your own §E.3 spec-repair commit and §5.2's generated
  remediation task files are authored outside it and are not what this catches.)
- **A green gate is only evidence about what the gate executes.** Before accepting "CI is
  green" as confirmation of anything, check that the gate *covers the change*. In one round
  the implementer added 303 lines of new tests in a file that was not in the Bazel target's
  `srcs`; the gate passed, the orchestrator reported "81 tests pass" as confirmation, and
  none of the new tests had been compiled. The check is one query against the target's source
  closure (`bazel query 'kind(source, deps(<target>))'`, or the project's equivalent), and
  a cached "Executed 0 out of N" result is not a run — force the specific targets if the
  answer matters.

**You MAY be tolerant about:**
- Missing or malformed `spec-workflow-meta` blocks. Locate the canonical artifact at its
  conventional path under `.agents/scratchpad/{planning_slug}/step{NN}/{task_dir}/` instead.
- Schema imperfections in `result.yaml` / `review.yaml` — extra keys, missing optional fields,
  loose formatting. What you actually need from them is: the verdict/status, the change ID, the
  findings and their severities, the acceptance-criteria statuses, and any `escalation` block.
  This tolerance covers **form, not content**: a false factual assertion in a field you route
  on is not a schema imperfection, and the diff check above is what distinguishes them.
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

Loop over plan steps from the resolved position until every step in `plan_file` is checked
off, or you hit a block you cannot clear.

### 0. Resuming — locate the loop position before entering it

Do this before §1, on **every** run, including one you believe starts fresh.

`plan_file`'s checklist resolves only to a *step*, and a step is not a resume point. Both
previous runs of this skill ended mid-step, by design, and §2 has no idempotence guard: a
literal "the checklist says step 3 is unticked, so start step 3 at §1" would re-run task
generation over a step whose task files already exist and whose first tasks are already
implemented and approved — rewriting the very task files the completed work was reviewed
against. The `jj bookmark create`-never-`set` rule would eventually stop it, but only
*after* a full generator turn had run.

`work_log` usually names the resume point, but nothing in this skill *requires* it to, so
it is a convention, not a contract. **The bookmarks are the contract.** This skill creates
them at exactly the points where the loop can be re-entered, so they are a complete,
self-describing resume protocol that already exists as a side effect of §Artifacts' naming
scheme:

| Bookmark present | Means | Resume at |
|---|---|---|
| *(none for step N)* | step N not started | §1 |
| `pr/awo-generate-task-{slug}-step-{N}` | §2 done for step N — **skip §2** | §3, then §4 for the first task with no bookmark |
| `pr/{slug}/step{NN}/task-{MM}-….code-task` | task MM done through §4.6 | the next task's §4.1 |
| `pr/awo-record-{slug}-step{NN}-task-{MM}` | task MM's §4.7 bookkeeping done | the next task's §4.1 |
| `pr/awo-step-review-{slug}-step-{N}` | §5.2's first pass done | §5.3 if its verdict was `clean`; otherwise the step's remediation tasks, then §5.2 again |
| `pr/awo-step-review-{slug}-step-{N}-r{R}` | §5.2 re-review pass R done | §5.3 if `clean`; otherwise §5.2's loop guard |
| `pr/awo-step-complete-{slug}-step-{N}` | step N finished | step N+1, §1 |

**Constraints:**
- You MUST read the bookmarks (`jj log -r 'bookmarks()'`, or `jj bookmark list`) and derive
  the position to **task** granularity from the table above, before entering the loop.
- You MUST cross-check that position against `plan_file`'s checklist and `work_log`, and
  **stop and ask** if they disagree in any way you cannot explain. The bookmarks are
  authoritative about what was *done*; `work_log` is authoritative about *why* a run
  stopped, and only it can tell you a task was deliberately deferred rather than not
  reached.
- You MUST enumerate the step's existing task files before §2 and record what you found.
- You MUST record the resolved resume point in `work_log` as its own line, naming the step,
  the task, and the section you are entering at.
- Before ending a run at a task boundary, you MUST write a `RUN STOP` section to `work_log`
  stating the loop position in the terms above, the base change id for the next task, and
  any acpx session you deliberately left open (§Closing a session). This is what makes the
  next resume cheap; do not leave it to be reconstructed.

### 1. Verify jj Working State

**Constraints:**
- You MUST confirm you are in an empty jj working copy on top of the stack (`jj st`).
- If `@` contains stray files, you MUST investigate their origin. If they are leftovers from the
  previous step, `jj commit` them with a descriptive conventional-commit message; if their
  origin is unclear, stop and ask the user.

### 2. Generate Task Files for the Step

**Skip this section entirely if `pr/awo-generate-task-{planning_slug}-step-{step_number}`
already exists** (§0). Task generation is not idempotent: re-running it over a step that is
partly implemented rewrites the task files the completed tasks were reviewed against, and
the `jj bookmark create` collision that would eventually stop it fires only after the
generator turn has already run. If the bookmark exists but the task directory is empty or
inconsistent with it, **stop and ask** — do not regenerate.

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
- The base normally carries a bookmark, **unless an unbookmarked change has been interposed
  at the task boundary**: for the step's
  first task it is §2's task-generation change; for every later task it is the previous
  task's §4.7 bookkeeping commit, which §4.7 bookmarks
  `pr/awo-record-{planning_slug}-step{NN}-task-{MM}`. (§4.6 bookmarks the previous task's
  implementation tip, which sits one change below that.) If the base carries no bookmark,
  find out **why** before creating one, and expect one of two answers. The **benign** one:
  a commit this skill itself sanctions was interposed at the boundary — a `chore(awo):`
  side-edit of the kind §Operating Constraints permits with `@` empty — and it is now the
  base. That is self-explaining, harms nothing, and is **not** evidence a section was
  skipped. The other answer is that a section *was* skipped. Either way, inventing a name
  in the `pr/…` namespace that PR generation consumes is worse than a missing bookmark, so
  record what you found and create a bookmark only if it is one of the two names above and
  its absence is explained.
- **An interposed commit also moves §Recovering's `jj abandon` anchor.** That anchor is the
  newest bookmark on the current stack; with the base and the previous task's §4.7 record
  both unbookmarked it can sit two or more changes lower than intended, and the predicate's
  other clauses do not exclude the difference. If you find the base unbookmarked, you MUST
  NOT apply that predicate mechanically for the rest of this task: restrict abandonment to
  changes you saw this task's own turns create.

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
  "session_restarts": [],
  "outcome": null
}
```

`session_restarts` records every mid-task session replacement (§Prompting a session): one
entry per restart with the role, the round it happened on, the retired and replacement
session names, the trigger (`compaction`, `context`, `non_convergence`, `lost_turn`), and
the numbers behind it — `totalTokens` and window percentage, the round's tool-call count,
and the specific signal. It stays empty on most tasks; when it is not, it is the evidence
for the skill's central question, so it is not optional.

**Constraints:**
- `produced_changes` is **derived by you from `jj log` after each turn**, never taken from
  the producer:

  ```sh
  jj -R "$REPO" log --no-graph --reversed -r '{base}::@- ~ {base}' -T 'change_id ++ "\n"'
  ```

  Record it in oldest-to-newest order, and append a `rounds` entry per round with the role,
  prompt path, output path, verdict/status, and the token line.

  **`--reversed` is load-bearing.** `jj log` prints **newest-first**; an earlier revision of
  this command omitted the flag and annotated it `# oldest-to-newest`, which is exactly
  backwards. Following that comment reverses `produced_changes`, and the reversal is
  invisible on the one- and two-change tasks that are the common case — it surfaces on a
  long series, where §4.6 then describes the *newest* change as the merge-request commit
  instead of the oldest. Verify the order rather than trusting either the flag or this
  paragraph: the first id printed must be a child of `{base}`, and the last must be `@-`.
- **The write happens after every turn, in §4.3, §4.4 and §4.5 — not at §4.6.** This
  section says to "maintain" the record, and an earlier revision left it at that: no later
  section had a MUST that wrote to it, so the natural execution left the template values in
  place for a whole task and only §4.6's `outcome` was ever filled in. That is invisible
  while a run proceeds and load-bearing the moment one does not — §Recovering's `jj abandon`
  predicate is guarded by a clause that reads `produced_changes`, and against an empty list
  that clause licenses abandoning every change the task produced. Each of §4.3, §4.4 and
  §4.5 now carries the write; treat a stale record as a defect in its own right, not as
  bookkeeping you can catch up on later.
- **Do not trust the producer's own count of what it produced.** One implementer reported
  "four coherent jj changes were produced" when there were five: it had inherited the empty
  working copy `@`, described it, and committed on top, so its first "new" commit was the
  working copy it was handed. From its point of view it made four; the repository's series
  was five. Had the count been believed, the change carrying the schema the whole task
  rested on would have sat *outside* the reviewed range while `base_change` still pointed
  below it — and §4.4 warns that this does not error, it silently mis-scopes. The same
  implementer counted correctly on the next task under identical conditions, so the count
  is not biased, it is **unreliable**, and there is no way to tell from outside which kind
  you got. The revset is authoritative; the prose is not.
- An earlier revision said to append each change "as it is created". That describes an
  access pattern §Supervising a running turn forbids — you MUST NOT touch the repository
  while a turn is in flight — so the only time you can populate `produced_changes` is after
  the turn, from the log. It is now written that way.
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
  committed incrementally lost nothing. When a later turn died mid-round, three of its five
  fixes were already on disk as separate described changes. This paragraph is the only prompt
  padding this skill permits; §4.5 still forbids padding the rework prompt.
- **The paragraph is not reliably followed, and you cannot tell until the turn ends.** A
  90-minute round under this exact prompt held all of its work in `@` until the last minute;
  the very next task, same prompt, committed the cutover mid-turn. The variable appears to be
  whether the task has a natural early checkpoint, not the instruction. So keep sending it —
  it is free and it has demonstrably bounded a loss — but do not read it as a guarantee that
  a long turn's work is safe. Check-ins report tool-call counts, not commits, and
  §Supervising forbids inspecting the repository while a turn is in flight, so the exposure
  of a long turn is unknowable until it returns. Where that matters, the lever you actually
  have is task size at §2, not prompt wording.
- When it returns, you MUST perform the post-implementation checks in §Validation Posture, then
  read `result.yaml`.
- You MUST then write the round into `task-record.json` (§4.2): re-derive `produced_changes`
  from the revset and append this round's `rounds` entry. Do it now, not at §4.6 — the
  record is what §Recovering's abandon predicate reads if the next turn is killed.
- You MUST run the produced change's `jj diff --summary` and record the file list in
  `work_log` alongside the producer's own account of what it did (§Validation Posture).
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

If your remedy for a finding would be to amend the task's requirements or
acceptance criteria, that is a specification defect, not a change request:
return verdict `escalated` with reason `spec_defect`. Do not ask the
implementer to record a specification change.
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
- `produced_changes` MUST be the series you derived from `jj log` per §4.2, not the one
  the implementer said it made. A short series is the easy thing to eyeball and get wrong.
- Every change id in this prompt — `current_change`, `base_change`, and each entry of
  `produced_changes` — MUST be one you have verified with
  `scripts/jj-change-id.sh --repo "$REPO" --check <id>...`. Prefixes are fine as long as
  they resolve; ids you assembled by hand are not, and a **commit** id is not — `--check`
  reports that one as `COMMIT-ID` and fails, because a commit id resolves cleanly now and
  dangles the moment §4.6 rewrites it. An id that does not resolve produces a silently
  mis-scoped review, not an error.
- **`--check` validates tokens; it cannot validate that the list is a list.** Verify the
  `produced_changes` list by **splitting it on the delimiter you claim to have written**,
  then asserting each part is 32 characters and that the count matches the revset. Do not
  verify it by extracting id-shaped matches: a hand-assembled list whose ids ran together
  with no separators at all passed a `grep -oE '[a-z]{32}'` check, because the regex
  happily sliced the concatenated blob into five aligned windows that were each a real,
  resolvable change id — and `--check` then returned five `ok`s on a prompt containing no
  list. A verification that reconstructs its input from the same corruption it is meant to
  detect is worthless. The split check is what catches the third observed error too, and
  that one is worth naming because it looks correct: `paste -sd', '` does **not** join with
  `", "`. `paste`'s `-d` takes a *list* of delimiters and cycles through them, so it joined
  with a comma, then a space, then a comma — turning three ids into `[a,b c]`. Splitting on
  the delimiter you claim to have written and asserting three 32-character parts fails on it
  immediately; an id-shaped regex would have "found" three ids in it. (All three malformed
  prompts were caught at composition, but that is three hand-assembly errors in one run:
  prefer building the list from the revset's output **file**, directly, over retyping or
  reformatting it.)
- You MUST perform the post-review checks in §Validation Posture before reading the verdict.
- Route on `review.verdict`:

| `review.verdict` | Action |
|---|---|
| `approved` | Proceed to §4.6 |
| `changes_requested` | Go to §4.5; once `max_rework_rounds` is exhausted, apply the convergence test below |
| `escalated` | Go to §Escalation Handling |
| `blocked` | Deprecated verdict from older skill versions; treat as `escalated` |

- **The table above is not the whole routing decision: read the findings'
  `suggested_action` fields too.** A review that returns `changes_requested` while proposing
  that the task's requirements or acceptance criteria be amended has mis-routed a
  specification decision into the code loop; treat it as `escalated` with
  `reason: spec_defect` and go to §Escalation Handling. This has happened — see §E.0 — and
  the verdict alone does not show it.
- You MUST write the round's `rounds` entry, the verdict, and the token line into
  `task-record.json` (§4.2) before proceeding.
- **`max_rework_rounds` is a soft limit.** Its job is to stop an orchestrator grinding a loop
  that is going nowhere — not to fail a task that is one round from done. When it is
  exhausted without approval, do not stop on the count alone. Read the last `review.yaml`
  and the round history in `task-record.json` and ask whether the loop is **still
  converging**: severity and count of open findings falling round over round (6 → 2 → 1 → 0
  is converging; 2 → 2 → 2 is not), acceptance criteria trending toward pass, and each
  round's findings being *new or narrower* rather than the same finding restated. Then:

  - **Still converging** → take another round. Record in `work_log` that you exceeded the
    limit, the round number, and the per-round finding and AC counts that justify it. Keep
    doing this while the trend holds; each extra round is recorded the same way.
  - **Stalled** — findings flat or rising, the same finding surviving two rounds, or a round
    that regressed an AC — → the limit has done its job. Consider first whether this is a
    **session** problem rather than a task problem: a stalled loop is one of the
    non-convergence signals in §Prompting a session, and a fresh implementer or reviewer has
    repeatedly broken exactly this kind of plateau. A restart-and-retry is the cheaper move
    and does not itself need a dispensation. If the loop stalls again after a restart, stop
    grinding: if the outstanding findings are genuinely deferrable, record them in
    `work_log` and proceed to §4.6; otherwise treat as a block and stop and ask.

  The limit is also not a licence to run indefinitely. A task that has taken **twice**
  `max_rework_rounds` is a signal about the *task* — most likely mis-scoped, or resting on a
  specification defect that belongs in §Escalation Handling rather than the code loop —
  so at that point stop and ask even if the trend still looks positive, and say what the
  trend was.

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
- You MUST run the round's `jj diff -r {new change} --summary` and compare the file list
  against the `file:` fields of the findings this round was told to address
  (§Validation Posture). A finding whose file was never touched is unaddressed no matter
  what `result.yaml` claims — record it in `work_log` and let §4.4's re-review see the
  round unaltered; do not tell the reviewer what you found. Its catching or missing an
  unaddressed finding on its own is the measurement §4.4's continuity claim rests on, and
  steering it destroys the evidence. (On the one occasion this was run as an experiment,
  the warm reviewer re-derived the whole thing unprompted, down to the line number of the
  false claim.) **The withholding ends at the verdict:** if the re-review comes back
  `approved` while a finding you recorded as untouched is still open, you MUST NOT proceed
  to §4.6. Say so in `work_log` — that is a finding about §4.4, and a much more serious one
  — and stop and ask.
- You MUST re-derive `produced_changes` from the revset, append the new change and this
  round's `rounds` entry to `task-record.json` (§4.2), and then return to §4.4.

#### 4.6 Finalize the Task

Unlike `awo run`, nothing finalizes the stack for you. You do it.

**Constraints:**
- You MUST verify `@` is empty; commit stray files if present.
- You MUST describe the **oldest non-empty** produced change of this task with the **final**
  review's `merge_request.title` and `merge_request.body`, using `jj describe`. On the normal
  path the final review is the approved one. On §4.4's deferral branch — findings judged
  genuinely deferrable — the final verdict is `changes_requested` and **there is no approved
  review**; use that review's `merge_request` all the same.
- **"Oldest non-empty", not "oldest".** A produced series can begin with an empty change,
  and this is not a rare case: `jj` hands a session the empty working copy it inherits, and
  a producer that describes and commits *on top of* it leaves that empty change at the
  bottom of the range the §4.2 revset returns. Observed twice within a single task. Putting
  the merge-request body on it would attach the PR description to a commit containing
  nothing. So: skip leading changes whose `jj diff -r {change} --summary` is empty, and
  describe the first one with content. Do **not** abandon or squash the empty changes —
  they stay in the series (§Operating Constraints' no-rewriting rule), and you name them to
  the reviewer as in-scope-but-not-implementation. Record the skip in `work_log`; an empty
  change at the bottom of a series is also the signal that a producer miscounted what it
  made, which §4.2 already tells you not to trust.
- **You MUST check the merge request before using it, and rewrite title or body when they
  are written in the reviewer's voice rather than the change's.** The two observed failures
  are not equally likely, and the difference matters for how much effort each deserves:
  - **Body — unconditional.** Needed rewriting on **eight of eight** tasks, across warm and
    cold sessions, one-change and six-change series, `approved` and `changes_requested`.
    It is `code-task-review`'s default output, not an occasional wart: *"Reviews the
    complete ordered task series from the supplied base through the current change…"* —
    reviewer-voice prose addressed to an orchestrator, carrying raw change ids that mean
    nothing to a PR reader, about to be permanently attached to the commit as its PR
    description. Budget for rewriting it every time.
  - **Title — occasional, and it fails in three different shapes.** All three are
    observed, and the middle one is why this check must be mechanical rather than a glance:
    - A bracketed project tag the reviewer **invented**: `[Authority Lattice: Step 03/Task
      02]` where every other commit in the plan reads `[Compositional Analysis: Step NN/Task
      MM]`. Obviously wrong once you look.
    - A **near miss** of the same tag: `[Component Analysis: Step 08/Task 06]`. It reads
      correct, it is plausible for the project, and it is wrong — which is worse than the
      invented one, because a glance passes it.
    - **No conventional-commit type at all**, or a bogus one: a bare
      `complete surface-boundary cutover …`, and a `review: prune source inputs …` that
      describes the reviewer's activity rather than the change's, where every sibling commit
      in the plan uses `feat(scope):` / `fix(scope):`.

    The tag is what a human scans `jj log` for, so a one-off name — or a one-character
    difference — silently breaks the grouping for the whole plan. So do not verify it by
    reading it. **Take the tag from a sibling commit below you and compare the two strings
    for equality**, and separately assert the subject begins with a conventional-commit type.
    Both checks are one command and neither depends on noticing anything.

    Do **not** try to prevent any of this by adding a convention note to the §4.4 prompt: an
    un-steered reviewer produced the correct tag on the next task, so a single steered
    success was not evidence the note works, and this correction is reliable precisely
    because it does not depend on the reviewer at all.

  Rewrite in the change's own voice, preserving **every** substantive claim the reviewer
  made, including every finding left open **at any severity** — not only those phrased as
  suggestions. Record in `work_log` that you did and what you changed. Do not use this licence to soften or drop anything the reviewer
  said; it exists for voice and readability, not for content. This is the merge-request
  content the PR will carry. This is the one sanctioned exception to §Operating Constraints'
  no-amending rule: it is description-only, it preserves content and change ids, and jj will
  report `Rebased N descendant commits` as it rewrites this task's later commit ids. That is
  expected — and it is why every topology check in this skill compares **change** ids and
  never commit ids.
- **On the deferral path you MUST add a `DEFERRED` section to the `merge_request.body`.** A
  deferred task's permanent commit description is the only tracked record that it shipped
  with known defects — `run_dir_root` is gitignored, so the review artifacts under it are
  not. That section MUST state: that the task was deferred and who authorized it; every
  finding left open, at any severity, with its `file:line` and the inputs that reproduce it;
  and any contradiction between findings that the next reader would otherwise have to
  rediscover. A reviewer's `merge_request` has been observed omitting its own open
  `important` findings entirely, so you cannot rely on inheriting them — take them from the
  review body.
- When a task produced exactly one non-empty change, "oldest non-empty" and "newest" are the
  same change: describe it and bookmark it.
- **If the oldest non-empty produced change is a `wip(...)` recovery commit** written under
  §Recovering from a lost turn, its description is the only record of the recovery that
  lives in tracked history — `run_dir_root` is gitignored by default, so the evidence
  under it is not. The `wip` description's citation into `run_dir_root` is therefore
  deliberately a **run-local pointer**, not a tracked path; say so where you write it, so a
  later reader does not report the dangling reference as a defect. (A run that stops
  mid-task never reaches this section at all, so at such a stop the citation is the only
  record there is — leave the run directory in place.) In that case you MUST append the original `wip` description to the
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
- **Verify what the bookmark landed on, not just that `create` succeeded.** The
  create-never-`set` rule protects against a name collision; it does nothing about a correct
  name on the wrong revision, which raises no error at all. This has happened: a `jj commit`
  in the same shell block failed, the `jj bookmark create` chained after it with `;` rather
  than `&&` ran anyway, resolved its target from an unchanged `@-`, and put a record bookmark
  on the task tip. **Never chain a mutation after an unchecked command** — and after every
  `create`, print the change it points at and confirm it is the one you meant. (The recovery
  is `jj bookmark delete` and re-create; the deletion is retained in the op log.)
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
  - `kill-evidence/` for any round that lost a turn, **excluding its `raw/` subdirectory**
- **Copy the interpreted kill evidence, never `raw/`.** `acpx-evidence.sh` splits it for
  exactly this reason (§Recovering from a lost turn). The interpreted tier — `NOTES.md`,
  `sessions-show.txt`, `status.txt`, `wrapper-signals.log`, `resources.txt`, the `jj`
  snapshots — is under 2 KB and answers every question about a kill. `raw/` is `out.json`,
  `out.err` and the wire tail: a fifty-line wire tail measured **243 KB**, because ACP wire
  lines embed the whole contents of every file the agent read. One task with two kills that
  produced no code committed 600 KB, 560 KB of it raw evidence — more tracked bytes than
  the distilled records of three tasks combined, in a repository whose subject is
  architectural hygiene. `raw/` stays in the gitignored run dir, where it is used: during
  the incident.
- Commit it on its own as `chore(awo): record bookkeeping for step{NN} task {MM}`, with
  `@` otherwise empty so the commit contains nothing else. Verify that with
  `jj diff -r {the record change} --summary` — the file list must be the record files and
  nothing else. This is the cheapest place in the loop to notice that a commit did not
  happen or landed somewhere unexpected.
- You MUST bookmark it `pr/awo-record-{planning_slug}-step{NN}-task-{MM}`, with
  `jj bookmark create`. This commit is the **base of the next task**, so §4.1 needs it
  bookmarked, §Recovering's `jj abandon` predicate is anchored on "the newest bookmark on
  the current stack" and would otherwise silently widen by one change, and §0 uses it to
  resume. An earlier revision forbade bookmarking it, which made §4.1 unsatisfiable on
  every task after the first.
- If this task was completed under an earlier revision and has no record, you MAY run this
  section retroactively before starting the next task, provided you only **copy** artifacts
  that already exist in its run dir. Nothing may be synthesised. Say so in `work_log`.
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
- Two judgement calls are recorded here in full whenever they were made, because both are
  discretionary and neither leaves a trace anywhere else:
  - **Every session restart** — role, round, trigger and the numbers, mirroring
    `session_restarts` (§4.2) — and whether the replacement paid for itself: what the fresh
    session found, or failed to find, that the retired one had not.
  - **Every round taken beyond `max_rework_rounds`** (§4.4) — the round number and the
    per-round finding and AC counts that showed the loop was still converging.

  Record the negative case as well: a task where a session passed the 50 % flag and was
  **kept**, or where the round budget was not approached, is evidence about the thresholds
  too, and one line covers it.

### 5. Close Out the Step

#### 5.1 Verify the step's tasks

**Constraints:**
- You MUST verify every task in the step is approved (or explicitly recorded as deferred)
  before advancing.
- You MUST verify `@` is empty and every task carries its `pr/…` bookmark.
- You MUST run `scripts/acpx-close.sh --repo "$REPO" --sweep --slug {planning_slug}` and
  record the count it reports. With `--ttl 0` nothing reaps itself, so a session left open
  by an abandoned task holds an adapter process indefinitely. Do this at every step
  boundary and at end of run — **not** at a mid-task stop-and-ask, where §Closing a session
  says to keep a session that still holds context.
- The count is itself an audit: a sweep that finds *one* session after a step whose tasks
  all closed their own is the confirmation that §4.6's close discipline held. A larger
  count is a finding — say which task leaked and why.

#### 5.2 Step-scoped implementation review

Skip if `step_review` is false. Otherwise this is where cross-task drift is caught — the
job the reviewer no longer does.

**It earned its place the first time it had something to find, and the case is worth
knowing before you run it.** (An earlier step returned `clean` from this pass; what had
never run until then was its remediation branch.) On a six-task step it found that a
repeated proto field documented as an *ordered*
call path was being sorted during canonicalization, with a passing regression test
asserting that reordered paths are equivalent — a live semantic defect in the digest
contract the whole step existed to define, pinned by a test that would resist the fix. The
part that matters: that sorting had been written **in response to the task reviewer's own
finding**, which asked for the field to be order-insensitive, and the task reviewer then
approved it twice. Within the task's frame "canonicalization sorts repeated fields" is
exactly right, and nothing available to it said this particular field carries meaning in
its order. **A task-scoped reviewer working correctly and thoroughly can request a change
that introduces a defect, and then approve it.** That is the structural blind spot this
section covers, and it is not reachable by making the task reviewer better.

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
- **If any task in the step was deferred (§4.4's deferral branch), say so in the prompt** —
  name the task, its open findings, and where they are recorded. The deferral lives in the
  task's commit description and `task-record.json`, and this is the pass that is supposed to
  adjudicate it; a step review that never learns a task shipped with known defects cannot.
  Verified working: a flagged deferral came back as two findings routed into a remediation
  task, `category: unresolved_review_findings`.
- **Weigh a `clean` verdict against the step's shape before believing it.** A step whose
  last task is functionally independent of its siblings is the weakest possible test of
  cross-task drift, and a clean result on one says little. Record that judgement rather than
  letting an easy step look like supporting evidence.
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
- **A re-review's report gets its own bookmark, suffixed `-r{N}`.** The name above belongs
  to the first pass and `jj bookmark create` will — correctly — refuse to reuse it. Every
  §5.2 pass after the first commits its own report and bookmarks it
  `pr/awo-step-review-{planning_slug}-step-{step_number}-r{N}`, where `N` counts passes from
  2: the first re-review is `-r2`. Do **not** move the original bookmark and do not amend
  the first report into the second. The two reports are the evidence that remediation
  worked — the first names the findings, the second adjudicates each one — and a step that
  needed a remediation round should be visibly distinguishable in the bookmark list from one
  that came back `clean` on the first pass.
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

### E.0 The escalation nobody raised

**This section's boundary test is unenforceable while it can only be entered by a producer
volunteering an `escalated` verdict, and that has been observed failing** (F-66 in
[`eval/reports/`](eval/reports/README.md)). On one task the
reviewer twice found an acceptance criterion unmet; the implementer concluded the criterion
was unsatisfiable and, instead of escalating, **edited the task file** — a clean, separate,
well-described commit containing only the specification amendment — and the reviewer then
approved against the rewritten criteria. `result.yaml` contained no occurrence of
`escalat`, at any round, from either producer.

Every artifact looked textbook: green CI, 5/5 acceptance criteria, an approving review, a
tidy commit series. **An orchestrator routing on verdicts alone would have shipped it**,
and would then have built the rest of the step on an architectural change the user never
saw. Note also how it happened: the reviewer's own `suggested_action` said *"record that
specification change explicitly rather than silently redefining the acceptance test"* — it
had correctly detected a spec conflict, even named the failure mode, and then authorised
the fix at the wrong altitude. Two producers each behaving sensibly in isolation routed an
architectural decision around the contract built to send it here.

Three consequences, and they are cheap:

- **Enter this section on the mechanical signal, not the reported one.** A produced series
  that touches `.agents/tasks/` or `.agents/planning/` is an escalation regardless of
  `result.status` or `review.verdict` (§Validation Posture). One `jj diff --summary` per
  round, which you are already running.
- **A `changes_requested` whose remedy is to amend the specification is an escalation too**
  (§4.4). Read the `suggested_action` fields, not only the verdict.
- **Redefining which components may depend on which, or any comparable structural rule, is
  an architectural decision**, so §E.2's boundary test sends it to the user. If a producer
  has already made such a change, do **not** revert or re-scope it on your own authority —
  its technical argument may well be right. Record it where a reader will find it: a
  `SPECIFICATION AMENDMENT` heading in the permanent commit description (`run_dir_root` is
  gitignored, so nothing under it is tracked — the same reasoning §4.6 gives for `DEFERRED`),
  stating plainly that the amendment is producer-authored and carries no orchestrator
  boundary judgement and no user sign-off; a `spec_amendment` block in `task-record.json`;
  and a stop-and-ask with the change ids.

### E.1 Read the Escalation

**Constraints:**
- You MUST locate the escalation: the reviewer's `review.yaml` (`review.verdict: escalated`,
  top-level `escalation`) or the implementer's `result.yaml` (`result.status: escalated`,
  top-level `escalation`). Both carry `reason` and `details`.
- **When you arrived here from §E.0 there is no `escalation` block to read** — no producer
  wrote one. Derive `reason` and `details` yourself from the evidence that brought you here:
  the spec edit's diff and commit description, and the review finding it answers. Say in
  `work_log` that you classified it rather than read it, and continue at §E.2.
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
  both sessions open — the user may want you to resume — and name them in `work_log`. Do
  **not** sweep here; see §Closing a session.

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
  reviewer       codex/gpt-5.6-luna/max   step_reviewer codex/gpt-5.6-sol/high

§0: no bookmark for step 03 → step not started, enter at §1.

Step 03, 4 tasks generated → bookmark pr/awo-generate-task-{slug}-step-3

  task-01: impl + rev sessions opened via acpx-open.sh; model/effort verified from the
           session record at open
    round 0 → completed  (I1, stopReason=end_turn, 31m; one check-in at 15m)
              → review → approved
    produced_changes derived from `jj log --reversed -r 'base::@- ~ base'` — NOT from the
      implementer's own count of what it made
    describe I1 with merge_request (title's project tag corrected to the plan's);
      bookmark pr/{slug}/step03/task-01-….code-task on I1
    both sessions closed
    §4.7 record committed, bookmark pr/awo-record-{slug}-step03-task-01
  task-02:  (base = task-01's §4.7 commit)
    round 0 → completed  (I1) → review → changes_requested (2 important)
    round 1 → completed  (I2) → re-review → approved   (same reviewer: "resolves the
                                                        first half of my prior finding")
    describe I1 with merge_request; bookmark on I2
    both sessions closed; §4.7 record committed and bookmarked
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

### Example: the harness kills the backgrounded call

```
task-03 round 0: the backgrounded acpx-prompt.sh call is reported stopped, 19s
  after launch, with no summary. An unrelated background `sleep` died in the same
  second — the harness, not acpx (§Operating Constraints).
  acpx-progress.sh --out-dir round-0.implementer → turn pid 1045029 ALIVE,
    12 tool events, verdict WORKING. The WRAPPER died; the turn did not.
  wrapper-signals.log: "SIGTERM after 19s; turn pid 1045029 alive; parent gone".
  → acpx-await.sh --out-dir round-0.implementer, backgrounded, and wait.
  → 10m later: stopReason=end_turn, tokens as usual. Nothing lost.
  Not a loss: no evidence capture, no fresh session, no loop-guard charge.
  Recorded in work_log as one line: killed at 19s, reattached, turn completed.
```

### Example: the kill takes the turn too

```
task-05 round 0: the backgrounded acpx-prompt.sh call is reported stopped 24s after
  launch — "was stopped because the system is running low on memory".
  acpx-progress.sh → verdict 4 DEAD: turn pid gone, no stopReason, adapter pid "-".
  wrapper-signals.log: "SIGTERM after 24s; turn pid 177082 gone; parent alive".
  → setsid did NOT save it. Do not reattach; acpx-await.sh has nothing to wait for.
  → §Recovering from a lost turn: confirm the topology is unchanged pre/post (it was —
    the turn had committed nothing), capture evidence, close the session.
  Provably inert: no repository change, so the loop guard is NOT charged and
    max_rework_rounds is NOT charged. A fresh session retries the round.
  Before relaunching, reclaim host memory at this boundary — @ is empty and nothing
    is in flight, and launch is the only moment the harness checks.
```

### Example: a turn that really did not finish

```
task-02 round 0: acpx-prompt.sh exited 10 after 60m — no stopReason in out.json.
  acpx-progress.sh → WORKING, last tool "bazel test //...", 4 events in the last
    minute. The turn is ALIVE; the client detached. Do not prompt, do not touch @.
  Poll → verdict DEAD: turn pid gone, stream carries no stopReason.
  acpx-evidence.sh --out-dir round-0.implementer --note "…" → kill-evidence/
    (NOTES.md says: pid gone, no stopReason, lastExitAt after lastPrompt)
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

### Example: the escalation nobody raised (§E.0)

```
task-07 round 1 → changes_requested, 4 important. suggested_action on one of them:
  "If moving the taxonomy to schema is intended to replace the manifest
   requirement, record that specification change explicitly rather than
   silently redefining the acceptance test."
  → §4.4: a remedy that amends the spec is an escalation. Noted, but the round
    was already launched; the mechanical check below is what actually catches it.

task-07 round 2 → result.status: completed. review.verdict: approved, 5/5 criteria,
  just ci green. Every artifact says the task is finished.

§Validation Posture, one command:
  jj diff -r qwzruqot --summary  →  .agents/tasks/…/task-07-….code-task.md   (only)
  → the series touched a TASK FILE. Route to §Escalation Handling regardless of
    the reported status. grep result.yaml for "escalat" → zero hits, all rounds.

E.2 boundary: NOT contained — the amendment redefines which components may depend
     on which, which is an architectural decision. That is the user's call.
     → do NOT revert, rebase or re-scope: the producer's technical argument may be
       right and it is not mine to overturn.
     → record it where a reader will find it: a SPECIFICATION AMENDMENT heading in
       the permanent commit description stating the amendment is producer-authored,
       carries no orchestrator boundary judgement and no user sign-off; a
       spec_amendment block in task-record.json with escalation_emitted: false.
     → finish §4.6/§4.7 cleanly, then STOP and ask. Do not start the next task on
       top of an architectural change the user has not seen.
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
ACP event, the most recent tool call, and whether the detached turn's own process is still
alive — which is what actually distinguishes a working turn from a dead one. Exit `4` means
dead: stop waiting and go to §Recovering from a lost turn.

**A stall that is really a quota exhaustion looks identical from outside.** The turn does
not error, the adapter does not exit, and `status` still reads `running`; it simply completes
a tool call and stops emitting events. `acpx-progress.sh` has no signal that would name the
cause, so run `scripts/codex-quota.sh` (§Operating Constraints) as soon as a stall is
suspected — and check quota before launching, which is the only point at which the answer is
still actionable. On a role whose harness publishes no quota, asking the user is the cheapest
confirmation; waiting longer is not, because a weekly window's reset is days away.

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
   gpt-5.6 family). Having *set* it there, do not then use it as the denominator: verify
   what the harness reports back in its `token_count` events, which is the figure it
   enforces and has been observed lower than the configured one (§Prompting a session).
4. Track it and act on it (§Prompting a session): record compaction per round, flag a session
   above 50% of the window, retire one on judgement as it approaches ~60% or stops
   converging, and start a fresh session for the next round rather than let one compact.

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
code said. Follow §Recovering from a lost turn: confirm it is over with `acpx-progress.sh`
first (`3` idle or `4` dead — a killed turn never reports idle), capture evidence with
`acpx-evidence.sh`, and never prompt the session or touch the working copy until it is
confirmed over. The two known causes are a client-side `--timeout` (which the wrappers never
pass) and the orchestrating harness killing the call; both present identically in
`sessions show`.

### The backgrounded call was killed, or exited `11`
The **wrapper** was killed. Whether the *turn* went with it is not knowable from the exit
status: `acpx-prompt.sh` runs acpx detached under `setsid`, which defeats the harness's
`killpg` but not the per-pid tree walk it follows with (§Operating Constraints). Do not open
a fresh session and do not treat the round as lost until you have checked. Run
`scripts/acpx-progress.sh` first — on `4` (dead) go to §Recovering from a lost turn instead.
If it reports the turn alive, run

```sh
scripts/acpx-await.sh --out-dir {round_dir}
```

as a background task, exactly as you launched the prompt, and wait for it. It reattaches to
`turn.pid`, blocks until the turn ends, and prints the same summary and exit status
`acpx-prompt.sh` would have. `{round_dir}/wrapper-signals.log` names the signal the wrapper
caught, and an empty log beside a dead wrapper means SIGKILL — but the log's own
alive/gone verdict is **not** authoritative: its liveness check races the kill burst and has
recorded a turn as alive that was already dying. `acpx-progress.sh` decides. Record the
interruption and the reattach in `work_log` — the timings are the data behind
§Operating Constraints' launch-gating model.

### `jj-change-id.sh --check` reported `COMMIT-ID`
A producer emitted a **commit** id where a change id belongs — observed as
`result.change_id`. `jj log -r` accepts a commit id as a revset, so it resolves and looks
fine; §Validation Posture's tolerance for a "malformed but unambiguous" id anticipated the
variant that *fails* to resolve, and this is the dangerous one because it does not. Do not
copy it anywhere. Resolve the real change id (`jj-change-id.sh --repo "$REPO" @-`), write
that into `produced_changes` and any prompt, and record the substitution. Do not spend a
rework round on it. If §4.6 has already run, a commit id recorded earlier now points at
nothing — that is why this is loud.

### A producer amended the specification instead of escalating
Go to **§E.0**. The mechanical signal is a produced series that touches `.agents/tasks/` or
`.agents/planning/`; the softer one is a `changes_requested` whose `suggested_action`
proposes amending the requirements. Neither shows up in a verdict, and the resulting task
looks textbook — green gate, all criteria passing, an approving review. Do not revert it;
record it in the commit description and `task-record.json`, and stop and ask.

### Dozens of `dbus-daemon` / `gnome-keyring-daemon` processes
Seen accumulating in the sandbox, roughly one pair per invocation, never reaped: a process
in the agent's environment autospawns a session bus and a secret-service daemon because
`DBUS_SESSION_BUS_ADDRESS` is unset. They are a monotonic leak but individually tiny, and
the kill vector has since been measured — the terms that move the outcome are the build
server and the adapters (§Operating Constraints), not these. Not worth acting on unless
`resources.txt` shows them as a real share of memory. Restarting the sandbox clears them;
exporting `DBUS_SESSION_BUS_ADDRESS=disabled:` suppresses the autospawn but may break a
harness that genuinely reads credentials from a keyring, so try it deliberately rather
than as a default.

### The implementer rewrote its earlier change instead of adding one
Stop. The produced series is the audit trail and awo's whole topology contract depends on it.
Check `jj op log` to understand what happened, record it in `work_log`, and ask the user. Do not
attempt to reconstruct the series yourself.

### The reviewer modified the repository
Stop and investigate. Record what changed. The review is not trustworthy, and neither is the
change under review until you understand the mutation.

**Separate a semantic mutation from a dropped build artifact — they are different incidents
with opposite handling.** The paragraph above is written for the first: the reviewer edited
source, or committed, or rewrote a change. That invalidates the review.

The second is more common and mostly harmless: review tooling leaves a compiler or linker
temp in the working copy — an observed case was a 1 960-byte `stdin.o` `ar` archive in the
repo root — and because `jj` auto-tracks new files, the empty `@` becomes dirty and its
commit id changes. Neither §Stray files in `@` nor the paragraph above fits: the first would
have you **commit** it, which puts a binary temp permanently into the task series, and the
second implies the review is void, which it is not.

Handle it as its own case:
1. Confirm it is inert before deciding. The test is whether any *produced* change was
   touched: every change id and description in `produced_changes` still present and
   unchanged, every `pr/` bookmark still on the change it was created on, and the file
   itself not under any tracked source path. A commit-id change on the empty `@` alone is
   expected — `@` is not a produced change, and this skill's topology checks compare change
   ids, never commit ids (§4.6).
2. If it is inert, **delete the file** — do not commit it, do not `jj abandon` anything —
   and confirm `@` is empty and clean again.
3. If any of (1) fails, it is not this case. Treat it as a semantic mutation and stop.
4. Record it in `work_log` either way, with the file, its size, and which round's reviewer
   produced it. A build artifact appearing in the repo root is also evidence about the
   review's own environment, which is worth having when a later reviewer reports it could
   not run the build at all.

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

**A reviewer that asked for a change which turned out to be wrong is not degradation.** It
has happened — a request that was correct within the task's frame introduced a semantic
defect visible only across tasks — and that is §5.2's job, not a reason to replace the
session. Degradation is missing things inside its own scope; this is its scope ending.

### Stray files in `@` at loop boundaries
Commit them with a descriptive message if their origin is clear (usually an agent that finished
work without committing). If not, stop and ask — never abandon them.

**This is about work, not artifacts.** A build or tooling temp — an object file, an archive,
a coverage or profile output, anything the build system would have produced — is not stray
work and must not be committed here; see §The reviewer modified the repository, which covers
it. If you cannot tell which you are looking at, that is a stop-and-ask, not a commit: a
binary committed into a task series cannot be removed later without rewriting the series,
which §Operating Constraints forbids.

## Artifacts

```
{work_log}                                              — durable orchestration record (you maintain)
{run_dir_root}/{ts}-step{NN}-taskgen/                   — the step's task-generation turn (§2)
  prompt.md / out.json / out.err / assistant.txt
{run_dir_root}/{ts}-step{NN}-steprev/                   — the step-scoped review turn (§5.2)
  prompt.md / out.json / out.err / assistant.txt
{record_dir_root}/{slug}/step{NN}/task-{MM}-{slug}/      — distilled durable record (§4.7, TRACKED)
  task-record.json / round-{N}.result.yaml / round-{N}.review.yaml
  kill-evidence/                                        — interpreted tier ONLY; never raw/
{run_dir_root}/{ts}-step{NN}-task-{MM}-{slug}/          — per-task record (you maintain)
  task-record.json                                      — base, ordered produced changes, rounds, outcome
  round-{N}.implementer/                                — one --out-dir per turn (§Prompting a session)
    prompt.md                                           — exact prompt sent
    out.json                                            — streamed ACP messages (the black box)
    out.err                                             — acpx diagnostics
    assistant.txt                                       — assistant text, concatenated
    turn.pid / turn.meta / turn.launch.sh               — the detached turn (§Prompting a session)
    wrapper-signals.log                                 — which signal killed the wrapper, if any
    kill-evidence/                                      — present only after a lost turn
      NOTES.md / sessions-show.txt / status.txt         — interpreted tier: copied by §4.7
      resources.txt / jj-st.txt / jj-log.txt / jj-diff-stat.txt
      raw/out.json, raw/out.err, raw/wire-tail.ndjson   — NOT copied; ~250 KB per kill
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
pr/awo-record-{planning_slug}-step{NN}-task-{MM}        — the task's bookkeeping commit (§4.7); base of the next task
pr/{planning_slug}-spec-fix-step{NN}-task{MM}           — an interposed spec repair commit
pr/awo-step-review-{planning_slug}-step-{N}             — the step review report + remediation tasks (§5.2)
pr/awo-step-review-{planning_slug}-step-{N}-r{R}        — each §5.2 re-review's report (§5.2), R counting from 2
pr/awo-step-complete-{planning_slug}-step-{N}           — the checklist-only completion commit (§5.3)
```

Together these six shapes are a complete resume protocol — §0 reads the loop position off
them, to task granularity, without trusting any prose.

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
| Implementer context | fresh session per round | one session per task, replaced mid-task on judgement (§Prompting a session) |
| Reviewer context | fresh session per round | one session per task, replaced mid-task on judgement (§Prompting a session) |
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
`implementation-review`. That bet paid off the first time §5.2 actually ran: it found a
semantic defect that the task reviewer had *requested* and then approved twice, because
within one task's frame the request was correct (§5.2).

The fourth run's conclusion is about routing. Two of its three findings — F-65 and F-66 —
are cases where every reported signal said the task was fine and the repository said
otherwise: a producer's claim about a file its diff never touched, and a specification
amendment that no verdict recorded. **Routing on verdicts alone is not sufficient**, and
the checks that close the gap are mechanical `jj diff --summary` comparisons rather than
judgement (§Validation Posture, §E.0). Where this skill asks you to test a producer's
prose against the repository, that is why.

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
