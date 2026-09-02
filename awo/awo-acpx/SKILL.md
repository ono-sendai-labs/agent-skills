---
name: awo-acpx
description: Drive an implementation plan to completion using long-lived acpx agent sessions instead of the awo binary. Loops over plan steps, generating code tasks per step and running an implementer/reviewer loop on each task, where the implementer session spans a whole task (reused across rework rounds) and the reviewer session spans a whole step. Bookmarks every produced change for PR generation, keeps a work log, and handles an escalated task by repairing the specification in a separate auditable commit interposed below the implementation, then reconciling in the same implementer session.
---

# awo-acpx Orchestrator (prototype)

## Overview

This is a **prototype variant of `awo-orchestrator`** that replaces the `awo` binary with
[`acpx`](https://github.com/openclaw/acpx) sessions driven directly by you. Same outer loop —
plan → steps → tasks, bookmarks, work log, escalation handling — but the inner
implementer ⇄ reviewer loop is yours to run, over **long-lived agent sessions**.

Two things change, and they are what the prototype exists to evaluate:

1. **The implementer session spans a whole task.** Rework rounds reuse it, so the implementer
   never re-reads the task, re-explores the codebase, or re-derives why it wrote what it wrote.
2. **The reviewer session spans a whole step.** One reviewer sees every task and every round in
   the step, which should catch cross-task drift a per-task reviewer cannot — at the cost of
   a reviewer that is no longer context-independent per task.

Because the sessions are stateful, **you** are the loop: you route on verdicts, you check the
repository shape, and you decide when the YAML is good enough. Validation that the `awo` binary
did deterministically is done here by judgement. That is deliberate for the prototype — you are
a capable model reading real artifacts, and the point is to find out which of those checks
actually needed to be deterministic.

Repository interaction is **jj-only**. Never use Git commands.

## Parameters

- **plan_file** (required): Path to the implementation plan, e.g.
  `.agents/planning/{project_name}/implementation/plan.md`. The **planning slug** is the
  `{project_name}` path component; it names the task directories, sessions, and bookmarks.
- **repo** (optional, default: the repository root containing `plan_file`): Absolute path.
  Every `acpx` invocation MUST pass this as `--cwd`, because acpx keys sessions on the absolute
  cwd — an inconsistent `--cwd` silently starts a different conversation.
- **work_log** (optional, default: `.agents/scratchpad/awo-acpx-report.{planning_slug}.md`):
  Your durable orchestration record. Read it first; create it if absent; keep it updated after
  every step and task.
- **run_dir_root** (optional, default: `.agents/runs-acpx/`): Where you write per-task records.
- **generate_tasks_cmd** (optional): Invoked as `{generate_tasks_cmd} {plan_file} {step_number}`.
  If unset, run task generation yourself per §2.
- **implementer_agent** (optional, default: `opencode`) / **implementer_model** (optional,
  default: `opencode-go/glm-5.3-flash`) / **implementer_effort** (optional, unset).
- **reviewer_agent** (optional, default: `codex`) / **reviewer_model** (optional, default:
  `gpt-5.6-sol`) / **reviewer_effort** (optional, default: `medium`).
- **check_cmd** (optional, unset): A CLI providing deterministic validation of report YAML and
  jj topology, e.g. `awo check`. When set, prefer it over your own inspection for the checks it
  covers, and record its verdicts in `work_log`. When unset — the prototype default — do those
  checks by inspection per §Validation Posture.
- **max_rework_rounds** (optional, default: `4`): Rounds *after* the initial implementation.

**Constraints for parameter acquisition:**
- You MUST resolve `plan_file` and `repo` before starting; everything else has a derivable default.
- You MUST read `work_log` (or create it) before touching the repository, and derive the **next
  step number** from `plan_file`'s progress checklist and `work_log` together. The plan may be
  partially complete — never assume you start at step 1.
- You MUST verify `acpx` is on `PATH` and that both agents are configured (`acpx config show`)
  before the first step. A missing agent is a stop-and-ask condition.
- You MUST verify the producer skills are reachable by both harnesses before the first task —
  normally as symlinks in `{repo}/.agents/skills/` (`task-to-code`, `code-task-review`,
  `plan-to-tasks`). See §Troubleshooting if an agent cannot find a skill.

## Operating Constraints

- **Long-running commands.** Agent turns can run for many minutes. You MUST run them as
  background tasks and wait for completion notification. Do NOT double-background (no `&` or
  `nohup` inside a `run_in_background` call) — the harness would report completion as soon as
  the launcher returns while the real work continues detached.
- **One turn at a time per session.** acpx queues concurrent prompts to the same session through
  its queue owner. Never issue a second prompt to a session with a turn in flight; wait.
- **Never destroy completed work.** No `jj abandon`, no `jj undo`, no amending or squashing
  changes produced by a task loop. Every recovery must be additive.
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

### Naming

| Role | Session name | Lifetime |
|---|---|---|
| Implementer | `awo-impl-{planning_slug}-step{NN}-task{MM}` | one task, all its rounds |
| Reviewer | `awo-rev-{planning_slug}-step{NN}` | one step, all its tasks and rounds |

The names must be unique per scope; the slug guarantees that across concurrently-open plans.

### Opening a session

```sh
acpx --cwd "$REPO" {agent} sessions new --name {session}
acpx --cwd "$REPO" {agent} -s {session} set model {model}
acpx --cwd "$REPO" {agent} -s {session} set reasoning_effort {effort}   # if effort is set
```

**Constraints:**
- Use `sessions new`, not `sessions ensure`. `new` soft-closes any existing session of that name
  and starts fresh, which is what you want at a task or step boundary. `ensure` would silently
  resume a stale conversation from an aborted earlier attempt.
- You MUST set the model *before* the first prompt, and confirm the command printed
  `model set: {model}`. A silently defaulted model invalidates the experiment.
- `set reasoning_effort` is a `session/set_config_option` call and is adapter-defined. If the
  adapter rejects it, record that in `work_log` and proceed on the adapter default — do not
  substitute a different model.

### Prompting a session

Write each prompt to a file and pass it with `--file`; do not embed multi-line prompts in shell
arguments.

```sh
acpx --approve-all --format quiet --timeout 3600 --cwd "$REPO" \
     {agent} -s {session} --file {prompt_path} \
     >{output_path} 2>{stderr_path}
```

**Constraints:**
- `--approve-all` is REQUIRED. acpx's non-interactive permission default is deny, and a denied
  implementer produces nothing while still consuming a round.
- `--format quiet` puts only the final assistant text on stdout; token/cost accounting and
  diagnostics go to stderr. You MUST capture both.
- You MUST record the stderr token line for every round in `work_log`. It is the primary
  instrumentation for this prototype: it shows whether long sessions actually save context
  reacquisition, and whether the step-scoped reviewer's context grows unsustainably.
- Route on the exit code:

| Exit | Meaning | Action |
|---|---|---|
| `0` | Turn completed | Read the output and route on the artifact |
| `1` | Agent / protocol / runtime error | Read stderr. One retry of the same prompt is fine; twice means stop and ask |
| `3` | `--timeout` exceeded | The turn was cancelled cooperatively. Inspect the repository — partial work may exist. Treat as a block; stop and ask |
| `4` | No session found | You did not open the session, or `--cwd` differs from the one you opened it with. Fix and retry |
| `5` | Every permission request denied | You omitted `--approve-all`. Fix and retry |
| `130` | Interrupted | Stop and ask |

### Closing a session

```sh
acpx --cwd "$REPO" {agent} sessions close {session}
```

**Constraints:**
- You MUST close the implementer session at the end of its task, and the reviewer session at the
  end of its step — including when the task or step ends in a block. Sessions hold a live
  adapter process for an idle TTL; leaving them open leaks processes across a long run.
- `close` is a soft close. The record and history stay on disk for later inspection.

## Validation Posture

Where the `awo` binary validated deterministically, you validate by inspection. Do it, but do it
with judgement rather than schema pedantry.

**You MUST check, every round:**
- After an implementer turn: `@` is empty and childless; `@-` is non-empty, described, and
  carries no bookmark; `@-`'s change ID matches the `result.change_id` the implementer reported.
- After a reviewer turn: the repository is unchanged — same `@-` change ID, commit ID,
  description, and bookmarks as before the review. A reviewer that mutated the repository is a
  stop-and-investigate condition, not something to accept.
- The task's base identity is still what you recorded at §3.1. A base that moved under you means
  something rewrote history; stop.

**You MAY be tolerant about:**
- Missing or malformed `spec-workflow-meta` blocks. Locate the canonical artifact at its
  conventional path under `.agents/scratchpad/{planning_slug}/step{NN}/{task_dir}/` instead.
- Schema imperfections in `result.yaml` / `review.yaml` — extra keys, missing optional fields,
  loose formatting. What you actually need from them is: the verdict/status, the change ID, the
  findings and their severities, the acceptance-criteria statuses, and any `escalation` block.
- A missing artifact entirely, when the final assistant text states the outcome unambiguously.
  Record in `work_log` that you routed on prose rather than an artifact.

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
  session named `awo-gen-{planning_slug}-step{NN}`, using the reviewer agent and model (task
  generation benefits from the more capable model), with a prompt of the form:

  ```
  Skill: plan-to-tasks
  Parameters:
    agents_dir: .agents
    plan: {plan_file}
    step: {step_number}

  Run the `plan-to-tasks` skill on this step. Then `jj commit` the resulting task
  files with a conventional-commit message. Do not create a bookmark.
  ```

  Close that session when it returns.
- After it returns, you MUST verify you are again in an empty working copy with `@-` holding the
  task files. If the agent left the files uncommitted in `@`, you MUST commit them yourself.
- You MUST create a bookmark on that change named
  `pr/awo-generate-task-{planning_slug}-step-{step_number}` (with `jj bookmark create`).
- You MUST enumerate the step's task files (`jj log -s` on the change). They live in
  `.agents/tasks/{planning_slug}/step{NN}/` and are named `task-{MM}-{task_slug}.code-task.md`.
- You MUST record the generated task files in `work_log` before implementing any of them.

### 3. Open the Step's Reviewer Session

**Constraints:**
- You MUST open the reviewer session once per step, per §Sessions, before the first task.
- Its first prompt is the first task's review kickoff (§3.4); there is no separate priming turn.
- You MUST NOT reopen or recreate it between tasks in the step. Its continuity across tasks is
  the property under test.

### 4. Implement Each Task

For each task file in order:

#### 4.1 Ensure a Clean Starting State

**Constraints:**
- You MUST verify `@` is empty; commit stray files if present.
- You MUST note the change ID of `@-` — the tip left by the previous task or by task generation.
  This is the task's **base**. Record it in the run record (§4.2).
- You MUST verify `@-` carries a bookmark. If not, create one (with `jj bookmark create`) named
  `awo-loop-checkpoint-step{NN}-task{MM}-{task_slug}` so the base is recoverable.

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
  "reviewer_session": "awo-rev-{slug}-step{NN}",
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
```

**Constraints:**
- You MUST run this as a background task and wait for it.
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

Prompt the step's reviewer session. On its **first** task in the step, prefix the non-interactive
preamble from §4.3.

```
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

For a re-review (round ≥ 1) in the same session, the reviewer already holds its prior review;
say so rather than restating it:

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
- You MUST run this as a background task and wait for it.
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
  `merge_request.title` and `merge_request.body`, using `jj describe`. This is the merge-request
  content the PR will carry.
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
- You MUST close the implementer session (§Sessions) and write `outcome` into `task-record.json`.

#### 4.7 Update the Work Log

**Constraints:**
- You MUST append a summary to `work_log`: task file, terminal outcome, round count, produced
  change IDs, the bookmark you created, and the per-round token lines. Record any escalation and
  its resolution here too — `work_log` is the human-readable audit trail.
- You MUST also record, for the prototype evaluation: wall-clock duration per round, and any
  observation about whether the implementer retained context across rework or the reviewer
  degraded across the step.

### 5. Close Out the Step

**Constraints:**
- You MUST verify every task in the step is approved (or explicitly recorded as deferred) before
  advancing.
- You MUST close the step's reviewer session.
- You MUST confirm the step's checklist item in `plan_file` is marked complete. `task-to-code`
  normally does this after the step's last task; if it did not, mark it yourself and commit
  that edit.
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
- Then tell the step's **reviewer** — the same session, which has already seen the escalation:

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
Step 03, 4 tasks generated → bookmark pr/awo-generate-task-{slug}-step-3
  Reviewer session awo-rev-{slug}-step03 opened (codex, gpt-5.6-sol, medium)

  task-01: impl session opened (opencode, opencode-go/glm-5.3-flash)
    round 0 → completed  (I1) → review → approved
    describe I1 with merge_request; bookmark pr/{slug}/step03/task-01-….code-task on I1
    impl session closed
  task-02:
    round 0 → completed  (I1) → review → changes_requested (2 important)
    round 1 → completed  (I2) → re-review → approved
    describe I1 with merge_request; bookmark on I2
    impl session closed
  …
  Reviewer session closed. Step 03 checklist item marked complete → continue at step 04.
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
absolute `--cwd` you opened the session with.

### The agent cannot find the skill
The producer skills must be discoverable by each harness. The repo convention is symlinks in
`{repo}/.agents/skills/` — codex resolves those; opencode also reads `~/.claude/skills/` and
`.opencode/skills/`. If a harness reports it cannot find `task-to-code` or `code-task-review`,
do not paraphrase the skill into the prompt. Point the agent at the absolute `SKILL.md` path and
tell it to read and follow that file, and record the discovery failure in `work_log`.

### `set model` printed nothing, or the wrong model
Do not proceed. A round run on the wrong model invalidates the comparison this prototype exists
to make. Re-open the session and set the model again; if it still fails, `acpx --cwd "$REPO"
{agent} sessions show {session}` and stop and ask.

### A turn appears to hang
Check `acpx --cwd "$REPO" {agent} status` — `running` with a live pid means it is working. Do NOT
cancel a working turn; agent turns on a large task legitimately take many minutes. If you must
stop one, use `acpx --cwd "$REPO" {agent} cancel -s {session}`, which cancels cooperatively.

### The implementer rewrote its earlier change instead of adding one
Stop. The produced series is the audit trail and awo's whole topology contract depends on it.
Check `jj op log` to understand what happened, record it in `work_log`, and ask the user. Do not
attempt to reconstruct the series yourself.

### The reviewer modified the repository
Stop and investigate. Record what changed. The review is not trustworthy, and neither is the
change under review until you understand the mutation.

### The reviewer's answers are degrading across the step
This is the prototype's main risk, so record it carefully rather than working around it: which
task, which round, what the reviewer missed or waved through, and the token line at that point.
If it is bad enough to compromise the step, close the reviewer session and open a fresh one for
the remaining tasks — and say so prominently in `work_log`, because it is the experiment's
result.

### Stray files in `@` at loop boundaries
Commit them with a descriptive message if their origin is clear (usually an agent that finished
work without committing). If not, stop and ask — never abandon them.

## Artifacts

```
{work_log}                                              — durable orchestration record (you maintain)
{run_dir_root}/{ts}-step{NN}-task-{MM}-{slug}/          — per-task record (you maintain)
  task-record.json                                      — base, ordered produced changes, rounds, outcome
  round-{N}.implementer.prompt.md                       — exact prompt sent
  round-{N}.implementer.out.txt                         — final assistant text
  round-{N}.implementer.err.txt                         — token line and diagnostics
  round-{N}.reviewer.prompt.md / .out.txt / .err.txt
  round-{N}.result.yaml / round-{N}.review.yaml         — archived copies of the canonical artifacts
```

Bookmarks:

```
pr/awo-generate-task-{planning_slug}-step-{N}           — the step's task-generation change
awo-loop-checkpoint-step{NN}-task{MM}-{slug}            — recovery checkpoint on an unbookmarked base
pr/{planning_slug}/step{NN}/task-{MM}-{slug}.code-task  — the task's final tip, consumed by PR generation
pr/{planning_slug}-spec-fix-step{NN}-task{MM}           — an interposed spec repair commit
```

## Relationship to `awo-orchestrator`

Use `awo-orchestrator` for production runs on the `awo` binary. Use this skill to evaluate
whether long-lived sessions are worth adopting. The differences to watch:

| | `awo-orchestrator` | `awo-acpx` |
|---|---|---|
| Inner loop | `awo run` / `awo rework` | you, over acpx sessions |
| Implementer context | fresh session per round | one session per task |
| Reviewer context | fresh session per round | one session per step |
| Topology validation | deterministic, in-binary | by inspection (or `check_cmd`) |
| Artifact validation | schema-enforced, with repair prompts | tolerant; verdict must still be unambiguous |
| Finalization | `awo run` describes and bookmarks | §4.6, by you |
| Escalation resume | injected `review.yaml` + `awo rework --seed-review …` | one prompt to the live implementer session (§E.4) |
