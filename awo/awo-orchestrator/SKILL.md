---
name: awo-orchestrator
description: Drive an implementation plan to completion with the awo workflow orchestrator. Loops over plan steps, generating code tasks per step and running the awo implementer/reviewer loop on each task, bookmarking every produced change for PR generation and keeping a work log. Handles an escalated task by repairing the specification and task file in a separate, auditable commit interposed below the implementation, then resuming awo in rework mode — never by silently patching the divergence in code.
---

# awo Orchestrator

## Overview

This is the **meta-loop** above the awo binary. awo itself drives the inner loop for a single task (implementer ⇄ reviewer, up to `--max-rework-rounds`); this skill drives the outer loop across a whole implementation plan: per step, generate task files; per task, run awo; bookmark, log, repeat.

Its substantive job beyond bookkeeping is **escalation handling**. When the inner loop terminates `ESCALATED` because the task cannot be satisfied as written, the correct repair is to the *specification and task file*, not the code. This skill authors that repair as a separate commit interposed **below** the task's implementation, then restarts awo seeded with an injected review so the implementer reconciles its own work against the corrected task. The result is an auditable spec commit and a separate reconciliation commit — instead of code that quietly diverges from its spec.

Repository interaction is **jj-only**. Never use Git commands.

## Parameters

- **plan_file** (required): Path to the implementation plan, e.g. `.agents/planning/{project_name}/implementation/plan.md`. The **planning slug** is the `{project_name}` path component; it names the task directories and bookmarks.
- **work_log** (optional, default: `.agents/scratchpad/orchestration-report.{planning_slug}.md`): Your durable orchestration record. Read it first; create it if absent; keep it updated after every step and task.
- **generate_tasks_cmd** (optional, default: `.agents/scratchpad/awo-generate-tasks.sh`): Invoked as `{generate_tasks_cmd} {plan_file} {step_number}`. Drives an agent that runs `plan-to-tasks` and commits the resulting task files.
- **run_task_cmd** (optional, default: `.agents/scratchpad/awo-run-task.sh`): Invoked as `{run_task_cmd} {task_file}`. Wraps `awo run` with the harness/model/effort flags for this project.
- **rework_task_cmd** (optional, default: `.agents/scratchpad/awo-rework-task.sh`): Invoked to resume a task in rework mode. Wraps `awo rework` with the same harness/model/effort flags as `run_task_cmd`, and passes through the resume arguments (seed review, base, produced changes). See §Escalation Handling for its inputs.

**Constraints for parameter acquisition:**
- You MUST resolve `plan_file` before starting; everything else has a derivable default.
- You MUST read `work_log` (or create it) before touching the repository, and derive the **next step number** from `plan_file`'s progress checklist and `work_log` together. The plan may be partially complete — never assume you start at step 1.
- You MUST verify `generate_tasks_cmd` and `run_task_cmd` exist and are executable before the first step; a missing wrapper is a stop-and-ask condition, not something to improvise.

## Operating Constraints

- **Long-running commands.** The wrapper scripts drive agent harnesses and can run for hours, producing little output. You MUST run them as background tasks and wait for completion notification. If the inner agent exhausts its quota it will block and appear to hang — you MUST NOT cancel it.
- **Never destroy completed work.** No `jj abandon`, no `jj undo`, no amending or squashing changes produced by a task loop. Every recovery must be additive.
- **jj only.** Inspect and mutate the repository with jj.
- **Create bookmarks, never move them.** Always use `jj bookmark create` — never `jj bookmark set`. `create` fails if the name already exists, surfacing a name collision or a re-run you did not intend; `set` would silently move an existing bookmark off the change it was protecting. A `create` failure is a stop-and-investigate signal, not something to switch to `set` for.
- **When in doubt, stop and ask the user.** The user is often away from keyboard; a clean stop with a clear question in the `work_log` beats a guess.
- **If you get lost**, re-read `work_log` and the plan to reorient before acting.

## Steps

Loop over plan steps from the resolved next step number until every step in `plan_file` is checked off, or you hit a block you cannot clear.

### 1. Verify jj Working State

**Constraints:**
- You MUST confirm you are in an empty jj working copy on top of the stack (`jj st`).
- If `@` contains stray files, you MUST investigate their origin. If they are leftovers from the previous step, `jj commit` them with a descriptive conventional-commit message; if their origin is unclear, stop and ask the user.

### 2. Generate Task Files for the Step

**Constraints:**
- You MUST run `{generate_tasks_cmd} {plan_file} {step_number}` as a background task and wait for it.
- After it returns, you MUST verify you are again in an empty working copy with `@-` holding the task files. If the agent left the files uncommitted in `@`, you MUST commit them yourself.
- You MUST create a bookmark on that change named `pr/awo-generate-task-{planning_slug}-step-{step_number}` (with `jj bookmark create`). The `{planning_slug}` guarantees the name is unique across concurrently-open plans.
- You MUST enumerate the step's task files (`jj log -s` on the change). They live in `.agents/tasks/{planning_slug}/step{NN}/` and are named `task-{MM}-{task_slug}.code-task.md`.
- You MUST record the generated task files in `work_log` before implementing any of them.

### 3. Implement Each Task

For each task file in order:

#### 3.1 Ensure a Clean Starting State

**Constraints:**
- You MUST verify `@` is empty; commit stray files if present.
- You MUST note the change ID of `@-` — the tip left by the previous task or by task generation. This is the task's **base**.
- You MUST verify `@-` carries a bookmark. If not, create one (with `jj bookmark create`) named `awo-loop-checkpoint-step{NN}-task{MM}-{task_slug}` so the base is recoverable. The step/task/slug components MUST make the name unique — a bare `awo-loop-checkpoint` reused across tasks would collide, and `create` would (correctly) reject it.

#### 3.2 Run the awo Task Loop

**Constraints:**
- You MUST run `{run_task_cmd} {task_file}` as a background task and wait for it.
- awo writes a run directory at `.agents/runs/{timestamp}-task-{MM}-{task_slug}/`. Note that these directory names carry no step number, so identify the current run by timestamp. It contains `orchestrator.log` (terse JSONL progress) plus `implementer/` and `reviewer/` subdirectories holding each round's `result.yaml` / `review.yaml`.
- You MUST read the printed terminal status and route on it:

| Status | Meaning | Action |
|---|---|---|
| `APPROVED` | Reviewer approved the change series | Proceed to §3.3 |
| `ESCALATED` | Implementer or reviewer stopped the loop deliberately | Go to §Escalation Handling |
| `REWORK_CAP` | Rounds exhausted without approval | Read the last `review.yaml`. If the outstanding findings are genuinely deferrable, record them in `work_log` and proceed; otherwise treat as a block and stop |
| `BLOCKED` | Deprecated reviewer verdict, from an older build | Read the report and treat it as `ESCALATED` |
| `FAILED` / other | Transient or harness failure | Investigate; a quick, non-destructive fix and re-run is fine. Otherwise stop and ask |

- You MUST NOT edit the produced code yourself to make a task pass. Route it back through awo, or escalate.

#### 3.3 Bookmark the Produced Changes

The loop leaves one change per round — the initial implementation plus one per rework round.

**Constraints:**
- You MUST verify `@` is empty; commit stray files if present.
- You MUST note the change ID of `@-`, the last change the loop produced.
- You MUST bookmark `@-` as `pr/{planning_slug}/step{NN}/task-{MM}-{task_slug}.code-task`, with `jj bookmark create`. These bookmarks are what PR generation consumes, so the name must match exactly.

#### 3.4 Update the Work Log

**Constraints:**
- You MUST append a summary of the task execution to `work_log`: task file, terminal status, round count, produced change IDs, and the bookmark you created. Record any escalation and its resolution here too — `work_log` is the human-readable audit trail.

### 4. Close Out the Step

**Constraints:**
- You MUST verify every task in the step is `APPROVED` (or explicitly recorded as deferred) before advancing.
- You MUST confirm the step's checklist item in `plan_file` is marked complete. `task-to-code` normally does this after the step's last task; if it did not, mark it yourself and commit that edit.
- Then continue the loop at §1 with the next step number.

## Escalation Handling

An `ESCALATED` terminal status means a producer decided that another rework round would be wasted. Read the escalation before doing anything else.

### E.1 Read the Escalation

**Constraints:**
- You MUST locate the escalation in the run directory: the reviewer's `review.yaml` (`review.verdict: escalated`, top-level `escalation`) or the implementer's `result.yaml` (`result.status: escalated`, top-level `escalation`). Both carry `reason` and `details`.
- You MUST read `details` in full and read the task file it names. Route on `reason`:

| `reason` | Meaning | Handling |
|---|---|---|
| `spec_defect` | The task cannot be satisfied as written | Candidate for repair — apply the §E.2 boundary test |
| `spec_ambiguity` | The task admits materially different implementations | Candidate for repair — apply the §E.2 boundary test |
| `unrecoverable_state` | The produced change cannot be trusted as a base (e.g. tests deleted wholesale to force green) | **Not** a spec repair. Stop and surface to the user with the evidence; the produced changes need human judgement before anything builds on them |
| `blocked_dependency` | A prerequisite outside this task's scope is missing | Usually a plan-ordering problem — stop and surface to the user |

### E.2 Decide: Repair Inline, or Escalate to the User

You may repair a specification inline **only** when the correction is contained to this task's requirements plus the shared spec/plan document.

**Constraints:**
- You MUST stop and escalate to the user, without editing anything, when the correction would:
  - change sibling or downstream task files in this or any other step,
  - alter the plan's step structure (adding, removing, splitting, or reordering steps),
  - constitute an architectural or design decision rather than a correction of a clear defect, or
  - leave you genuinely unsure which of several readings the user intended.
- You MAY repair inline when the defect is a self-contained inconsistency in this task's requirements or its shared spec doc, and the correct reading is unambiguous from the surrounding design documents.
- When you stop, you MUST write the escalation, your boundary reasoning, and the change IDs involved into `work_log`, and leave the repository in a clean, non-destructive state.

### E.3 Author the Spec Repair as a Separate Commit

The repair commit `S` contains **only** the specification-document edit and its trickle-down into the task file. No code. No tests.

**Constraints:**
- You MUST edit only spec/design/plan documents and the affected `.code-task.md` file. If you find yourself wanting to touch code, you are past the §E.2 boundary — stop.
- You MUST make the task file and the spec document consistent with each other; a task edit that leaves the design doc stating the defective requirement just relocates the divergence.
- You MUST commit with a conventional-commit message that names the defect and cites the escalation, e.g. `fix(spec): resolve contradictory quota criteria in task-03`.

Then place `S` correctly, in one of two shapes:

**Shape A — produced changes exist** (the usual case: the loop got at least one implementation change out before escalating). Interpose `S` below the first produced change, so the implementation series never appears as commits authored against a spec that was already known to be wrong:

```sh
jj rebase -r <S> --insert-before <I1>     # I1 = first produced change of this task
jj bookmark create pr/<planning_slug>-spec-fix-step<NN>-task<MM> -r <S>
```

Resulting topology — `B` is the task base, `I1…In` the produced series:

```
B ─ S (spec+task fix, bookmarked) ─ I1′ ─ [I2′ …] ─ @ (empty)
```

**Shape B — no produced changes yet** (round-0: the implementer escalated before committing anything). Author `S` directly on the base `B`; it simply becomes the new base. Bookmark it the same way, then re-run the task from scratch with `{run_task_cmd}` per §3.2 — there is nothing to reconcile, so no seeded review is needed.

**Constraints:**
- The rebase MUST leave `I1`'s content untouched — it reparents, it does not merge. Change IDs stay stable; commit IDs are rewritten, which awo tolerates.
- You MUST verify the resulting topology with `jj log` before proceeding, and confirm `@` is still empty.
- You MUST NOT squash `S` into any produced change. Its separateness *is* the audit trail.

### E.4 Write the Injected Review

For Shape A, awo resumes via an injected `review.yaml` that tells the implementer what changed and what to reconcile. Write it to the task's scratchpad (e.g. `{scratchpad}/injected-review.yaml`) conforming to `code-task-review/report-schema.md`.

**Constraints:**
- `review.verdict` MUST be `changes_requested` — this is the verdict that drives another implementer round.
- `review.change_id` MUST be the current tip of the produced series; `review.task_file` MUST point at the corrected task file.
- `acceptance_criteria` MUST reflect the **corrected** task, not the defective one.
- You MUST include at least one `critical` finding, category `acceptance_criteria`, that states the spec was corrected, cites the repair commit, and gives specific reconciliation steps in `suggested_action`.
- You MUST NOT include an `escalation` block — the verdict is not `escalated`.

```yaml
review:
  task_file: .agents/tasks/<planning_slug>/step<NN>/task-<MM>-<slug>.code-task.md
  change_id: <current tip of the produced series>
  reviewed_at: <now, ISO 8601 UTC>
  verdict: changes_requested
  schema_version: 2
  lsp_coverage: unavailable
merge_request:
  title: "fix(<scope>): reconcile implementation with corrected task [<Topic>: Step NN/Task MM]"
  body: |
    Reconciles the implementation series with the task specification corrected
    in the interposed spec commit.
summary: |
  Specification corrected (see bookmark pr/<planning_slug>-spec-fix-step<NN>-task<MM>).
  Re-implement against the updated task file.
acceptance_criteria:
  - text: "<criterion, per the corrected task>"
    status: fail
    evidence: |
      Implemented against the previous, defective wording of this criterion.
findings:
  - severity: critical
    category: acceptance_criteria
    file: <primary implementation file>
    line: null
    title: Spec corrected; reconcile the implementation
    details: |
      The task's requirement <X> was logically inconsistent (<the defect>), and
      has been corrected in the interposed change <S>. The existing
      implementation reflects the old wording.
    suggested_action: |
      <specific reconciliation steps against the corrected requirement>
    source: built-in
ecosystem_reviews: []
```

### E.5 Resume with `awo rework`

`awo rework` identifies the task from the seed review's `review.task_file`; it takes no positional task-file argument. It needs the seed review plus the change series to resume from, in one of two equivalent forms:

```sh
# Explicit form: base + produced changes, oldest-to-newest
{rework_task_cmd} --seed-review <path to injected review> \
    --base <S> --produced-change <I1′> [--produced-change <I2′> …]

# Prior-run form: reuse the earlier run's task-state.json
{rework_task_cmd} --seed-review <path to injected review> \
    --task-state .agents/runs/<timestamp>-task-<MM>-<slug>/task-state.json
```

**Constraints:**
- You MUST resume with `{rework_task_cmd}`, passing `--seed-review <path to the injected review>` plus either `--base <S>` with the ordered `--produced-change` list (oldest-to-newest), or `--task-state <path>`. The wrapper supplies the project's harness/model/effort flags; you supply the resume arguments.
- The `--base` MUST be the interposed spec commit `S` from §E.3, so the reworked round descends from the corrected spec. Pass the produced changes `I1′ … In′` in oldest-to-newest order.
- awo pre-flights the resume: `@` must be empty and childless, `@-` must be described/bookmarked, and the produced changes must descend from the given base. A pre-flight error means your topology from §E.3 is wrong — re-inspect with `jj log`; do not force it.
- The seeded round is a **rework** round: the implementer reads the injected review and produces a fresh child change. Subsequent rounds are the normal loop under `--max-rework-rounds`.
- When it returns, you MUST route on its terminal status exactly as in §3.2. A second escalation on the same task after a repair is a stop-and-ask condition — do not repair twice in a row.
- On approval, continue at §3.3. The task's bookmark goes on the final tip; the spec commit keeps its own bookmark, and both appear in the log as separate, reviewable changes.
- You MUST record the whole sequence in `work_log`: the escalation reason, your boundary judgement, the spec commit and its bookmark, and the rework outcome.

## Examples

### Example: normal step

```
Step 03, 4 tasks generated → bookmark pr/awo-generate-task-2026-07-18-escalation-step-3
  task-01 → APPROVED, 1 round  → pr/2026-07-18-escalation/step03/task-01-….code-task
  task-02 → APPROVED, 3 rounds → pr/2026-07-18-escalation/step03/task-02-….code-task
  …
Step 03 checklist item marked complete → continue at step 04.
```

### Example: spec-defect escalation, repaired

```
task-03 → ESCALATED, reviewer, reason: spec_defect
  details: AC2 mandates rejection above quota; AC4 forbids rejecting trial
           tenants, whose quota is 0. No implementation satisfies both.

E.2 boundary: contained — the contradiction is between two criteria of this
     task, and design/detailed-design.md §4 states trial tenants are exempt
     from quota accounting. No sibling task or step structure is affected.
     → repair inline.

E.3 Author S: correct AC4's wording in the task file and the corresponding
     sentence in detailed-design.md §4. Commit; then
       jj rebase -r S --insert-before I1
       jj bookmark create pr/2026-07-18-escalation-spec-fix-step03-task03 -r S
     Topology: B ─ S ─ I1′ ─ I2′ ─ @(empty)   ✓

E.4 Injected review: changes_requested, one critical finding pointing at
     src/quota.py, suggested_action = exempt trial tenants from the quota
     check rather than granting them a zero quota.

E.5 awo rework --seed-review … → APPROVED after 1 seeded round.
     Bookmark the tip; log both the spec commit and the reconciliation.
```

### Example: escalation that must go to the user

```
task-02 → ESCALATED, implementer, reason: blocked_dependency
  details: The task imports lib/validators, which does not exist. The design
           references it as a prerequisite from an earlier step.

E.2 boundary: NOT contained — supplying the prerequisite means adding a task
     to an earlier step, i.e. changing the plan's step structure.
     → do not repair. Stop, write the finding to work_log, surface to user.
```

## Troubleshooting

### Stray files in `@` at loop boundaries
Commit them with a descriptive message if their origin is clear (usually an agent that finished work without committing). If not, stop and ask — never abandon them.

### The run directory for this task is ambiguous
Run directories carry no step number. Identify the current one by timestamp, and cross-check `orchestrator.log`'s task file against the one you launched.

### `awo rework` pre-flight fails
The resume contract requires an empty `@` and a produced series descending from the given base. Re-inspect with `jj log` and fix the topology (§E.3); do not work around the pre-flight. A base mismatch usually means the interpose targeted the wrong change.

### A task escalates again after a spec repair
Stop. Either the repair was wrong or the defect is deeper than §E.2's boundary allows. Surface both escalations and your repair to the user.

## Artifacts

```
{work_log}                                              — durable orchestration record (you maintain this)
.agents/runs/{timestamp}-task-{MM}-{slug}/              — per-task awo run directory (awo writes this)
{scratchpad}/injected-review.yaml                       — seed review for a rework resume (you write this)
```

Bookmarks created:

```
pr/awo-generate-task-{planning_slug}-step-{N}           — the step's task-generation change
awo-loop-checkpoint-step{NN}-task{MM}-{slug}            — recovery checkpoint on an unbookmarked base
pr/{planning_slug}/step{NN}/task-{MM}-{slug}.code-task  — the task's final tip (consumed by PR generation)
pr/{planning_slug}-spec-fix-step{NN}-task{MM}           — an interposed spec repair commit
```
