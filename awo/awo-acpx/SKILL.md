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

**Constraints for parameter acquisition:**
- You MUST resolve `plan_file` and `repo` before starting; everything else has a derivable default.
- You MUST read `work_log` (or create it) before touching the repository, and derive the **next
  step number** from `plan_file`'s progress checklist and `work_log` together. The plan may be
  partially complete — never assume you start at step 1.
- You MUST verify `acpx` is on `PATH` and that both agents are configured (`acpx config show`)
  before the first step. A missing agent is a stop-and-ask condition.
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

**Rationale for the defaults.** The task reviewer is scoped to a single task (§4.4), so
it no longer carries cross-task reasoning and does not need the most capable model —
cross-task drift is the `step_reviewer`'s job. Spend capability on `task_generator`
(a bad decomposition poisons every task under it) and on `step_reviewer` (wide-scope,
judgement-heavy, runs once per step), not on every task-review round.

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

- **Long-running commands.** Agent turns can run for many minutes. You MUST run them as
  background tasks and wait for completion notification. Do NOT double-background (no `&` or
  `nohup` inside a `run_in_background` call) — the harness would report completion as soon as
  the launcher returns while the real work continues detached.
- **One turn at a time per session.** acpx queues concurrent prompts to the same session through
  its queue owner. Never issue a second prompt to a session with a turn in flight; wait.
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

### Naming

| Role | Session name | Lifetime |
|---|---|---|
| Task generator | `awo-gen-{planning_slug}-step{NN}` | one step's task generation |
| Implementer | `awo-impl-{planning_slug}-step{NN}-task{MM}` | one task, all its rework rounds |
| Reviewer | `awo-rev-{planning_slug}-step{NN}-task{MM}` | one task, all its rework rounds |
| Step reviewer | `awo-steprev-{planning_slug}-step{NN}` | one step-scoped review pass |

The names must be unique per scope; the slug guarantees that across concurrently-open plans.

**Why the reviewer is task-scoped.** An earlier revision of this skill scoped the
reviewer to a whole step. In practice the only continuity benefit that materialised was
*intra*-task — the reviewer awarding partial credit against its own prior findings
across rework rounds ("addressing the first half of the prior finding"). No finding was
observed that depended on having reviewed an *earlier task*. Meanwhile the step-scoped
session grew ~35k tokens per turn and **auto-compacted mid-turn** on a three-task step,
silently discarding most of its history — invisibly to the orchestrator, since nothing
in acpx's output reports compaction. Cross-task drift is now covered explicitly by the
step-scoped `implementation-review` pass (§5.2), with clean context, which is a better
tool for it than a session that happens to still remember.

Keep the reviewer session across a task's **rework rounds** — that is where its value
was demonstrated. Do not narrow it further to per-round.

### Opening a session

```sh
acpx --cwd "$REPO" {agent} sessions new --name {session}
```

**Constraints:**
- Use `sessions new`, not `sessions ensure`. `new` soft-closes any existing session of that name
  and starts fresh, which is what you want at a task or step boundary. `ensure` would silently
  resume a stale conversation from an aborted earlier attempt.
- Then apply the role's model and effort per §Asserting the model, below — **before** the
  first prompt, and again before every subsequent prompt.

### Asserting the model and effort — before EVERY prompt

Do not set the model once and assume it holds. It does not.

```sh
acpx --cwd "$REPO" {agent} -s {session} set model {model}
acpx --cwd "$REPO" {agent} -s {session} set reasoning_effort {effort}   # only if effort is non-null
acpx --cwd "$REPO" {agent} status -s {session}                          # VERIFY
```

**Constraints:**
- You MUST re-assert model (and effort, when the role sets one) **before every prompt to
  every session**, not once per session.
- You MUST verify with `status -s {session}` and read the `model:` line it reports. That
  line is the *resolved* model as the adapter sees it. The `model set: {model}` echo from
  the `set` command is **not** verification — it only reports the value acpx forwarded, so
  a rejected or reverted setting looks identical to a successful one.
- Note that `set reasoning_effort` succeeds with a differently-shaped message
  (`config set: reasoning_effort=medium (4 options)`), not `model set: …`. Do not
  pattern-match on the `model set:` shape for it.
- If the reported model is not the one the role asked for, stop and ask. Do not run the
  turn — a round on the wrong model is worse than a missing round, because it silently
  corrupts both the cost model and any model comparison.

**Why this is mandatory.** acpx reaps an adapter process after its idle TTL (default
300s) and respawns it on the next prompt. The respawned process re-reads the harness's
*global* config, discarding session-scoped settings. This was observed in practice: a
reviewer session explicitly set to `reasoning_effort: medium` ran three turns at medium,
idled ~34 minutes while the implementer worked, and then silently ran its remaining
three turns at `high` — the value in `~/.codex/config.toml`. Nothing in acpx's stdout,
stderr, or exit code reported the change.

The exposure is not hypothetical for a task-scoped reviewer either: the gap between
review turns is one implementer rework round, observed at 2m50s–4m07s against a 300s
TTL. And under a mixed-model configuration (§Role Configuration), a revert silently
promotes a cheap reviewer to whatever the global default is — inverting the economics
the configuration exists to achieve.

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
- `--format quiet` sends assistant text to stdout and token/cost accounting and diagnostics
  to stderr. You MUST capture both. Note that "quiet" does **not** mean only the *final*
  message: a turn's intermediate assistant messages arrive concatenated with no delimiter,
  so there is no mechanical way to isolate the last one. If you need message boundaries —
  e.g. to route on prose because an artifact is missing (§Validation Posture) — use
  `--format json`, which is message-delimited.
- You MUST record the stderr token line for every round in `work_log`. Read it correctly:
  `input`/`output` are **per model call**, not per turn, so `total` is not a turn cost.
  `cache_read` grows monotonically within a session and is the usable proxy for that
  session's accumulated context. It is **not** comparable across agents (different
  harness preambles), so never compare an opencode figure to a codex one.
- The token line cannot see auto-compaction. If a session's `cache_read` *drops*, its
  history was very likely compacted — treat that as a finding and record it, per
  §Troubleshooting.
- acpx writes a full JSON-RPC wire log per session to
  `~/.acpx/sessions/{acp_session_id}.stream.ndjson`, always on, and a session record to
  `~/.acpx/sessions/{acpx_record_id}.json`. That wire log is the black box: it survives a
  killed client, which the captured stdout/stderr do not. Cite it when diagnosing.
- Route on the exit code:

| Exit | Meaning | Action |
|---|---|---|
| `0` | Turn completed | Read the output and route on the artifact |
| `1` | Agent / protocol / runtime error | Read stderr. One retry of the same prompt is fine; twice means stop and ask |
| `3` | `--timeout` exceeded | The turn was cancelled cooperatively. Inspect the repository — partial work may exist. Treat as a block; stop and ask |
| `4` | No session found | You did not open the session, or `--cwd` differs from the one you opened it with. Fix and retry |
| `5` | Every permission request denied | You omitted `--approve-all`. Fix and retry |
| `130` | Interrupted | Stop and ask |
| *(none)* | The client was **killed** — no exit code at all, empty stdout and stderr | See §Recovering from a killed turn |

**Detecting a killed turn.** `status -s` is not sufficient: after a kill it reports
`idle`, identical to a healthy session that has never been prompted. Use
`acpx --cwd "$REPO" {agent} sessions show {session}` and look for `closed: false`
together with a **non-null `disconnectReason`** (e.g. `pipe_close`) and a `lastExitAt`.
On a clean close those exit fields are null.

Do **not** use an empty `agentSessionId` as a kill signal. Some adapters (opencode among
them) never return an agent-side session id at all, so that field is empty on every
session, successful or not; acpx resumes on its own `acp_session_id` regardless.

### Recovering from a killed turn

A turn can die without producing an exit code — a supervisor SIGTERM, an OOM kill, a
lost terminal. The session record survives, partial work may be committed or sitting in
`@`, and the conversation may or may not be resumable. You are expected to recover from
this yourself rather than stopping, because every alternative route out is otherwise
forbidden to you.

**Constraints:**
- You MUST first confirm the turn is actually dead, per §Detecting a killed turn. Never
  act on a turn that is still running.
- You MUST capture evidence before changing anything: copy the session's
  `.stream.ndjson` tail and `sessions show` output into the run dir, and record
  `jj diff -r <C>` for any change you are about to abandon. The audit trail must show
  what was discarded, not merely that something was.
- You MAY `jj abandon` a change only when **all** of these hold:
  1. it is a strict descendant of the newest bookmark on the current stack;
  2. it carries no bookmark itself; and
  3. its change id does **not** appear in `produced_changes` of the active
     `task-record.json`.

  Evaluate descendants-first and re-check after each abandon. Anything above the newest
  bookmark and absent from `produced_changes` is by construction the output of a turn
  that never reported completion. Anything *in* `produced_changes` completed a round and
  is off limits.
- You MUST NOT rely on "everything above the newest bookmark" alone. Within a task the
  produced series `I1…In` is unbookmarked until §4.6, so that test would license
  discarding completed, reviewed rework rounds.
- Then restart the round: open a **fresh** session (suffix the name, e.g. `…-task02b`),
  re-assert model and effort, and re-issue the same prompt. Do not resume the killed
  session — even when it is resumable, you cannot tell from the outside how much of the
  turn it believes it completed, and the repository has since moved.
- **Loop guard:** at most **one** automatic recovery per round. A second kill on the same
  round is stop-and-ask.
- A killed turn MUST NOT consume a `max_rework_rounds` slot. No review happened, so no
  round elapsed; charging it would let flaky infrastructure fail a healthy task.
- You MUST record the kill, the evidence, what you abandoned, and the restart in
  `work_log`.

Note that `jj abandon` is recoverable in jj — the operation log retains the change and
`jj op restore` brings it back. That is why this narrow exception is safe; it is not a
git-style destructive reset.

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
  "Matches" means **prefix containment**: `result.change_id` is the full 32-character change
  id while `jj log` shows a 12-character prefix. Compare change ids, never commit ids —
  §4.6's `jj describe` rewrites commit ids for every earlier task in the step.
- After a reviewer turn: the repository is unchanged — same `@-` change ID, commit ID,
  description, and bookmarks as before the review. A reviewer that mutated the repository is a
  stop-and-investigate condition, not something to accept. To do this check properly you
  MUST snapshot the topology *before* the review turn (e.g.
  `jj log -r 'ancestors(@,N)' -T '…' > {run_dir}/round-{N}.pre-review.topology`) and diff
  it afterwards. Keep both snapshots in the run dir.
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
- A **malformed but unambiguous** `result.change_id`. Producers have been observed emitting
  a change-id prefix concatenated with a commit-id prefix (e.g. `sxqzlwnn65d9000d`), which
  resolves to nothing. Accept it if — and only if — you can identify the intended change
  with certainty from `jj log` and no other change shares either prefix; record that you
  did. Do **not** copy the malformed string into `produced_changes`; write the real change
  id, or you corrupt the series §E.3 depends on. Do not spend a rework round fixing a
  string in a YAML file.
- A `schema_version` in the artifact that disagrees with the one in the
  ```spec-workflow-meta``` block. Prefer the artifact's.
- A missing artifact entirely, when the final assistant text states the outcome unambiguously.
  Record in `work_log` that you routed on prose rather than an artifact. Note that
  `--format quiet` concatenates a turn's assistant messages without delimiters, so
  "the final assistant text" is not mechanically identifiable — re-run with
  `--format json` if the outcome is not plain from the concatenation.

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

  Close that session when it returns.
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
  content the PR will carry. This is the one sanctioned exception to §Operating Constraints'
  no-amending rule: it is description-only, it preserves content and change ids, and jj will
  report `Rebased N descendant commits` as it rewrites this task's later commit ids. That is
  expected — and it is why every topology check in this skill compares **change** ids and
  never commit ids.
- When a task produced exactly one change, "oldest" and "newest" are the same change:
  describe it and bookmark it.
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
- You MUST close **both** the implementer and this task's reviewer session (§Sessions), and
  write `outcome` into `task-record.json`.

#### 4.7 Update the Work Log

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
- You MUST verify every per-task implementer and reviewer session is closed.
- You MUST verify `@` is empty and every task carries its `pr/…` bookmark.

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
- You MUST commit the review report and any generated task files before implementing them,
  with a conventional-commit message, and bookmark that change
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

  task-01: impl + rev sessions opened; model re-asserted and verified before each prompt
    round 0 → completed  (I1) → review → approved
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
       bookmark pr/awo-step-complete-{slug}-step-3 → continue at step 04.
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
Check `acpx --cwd "$REPO" {agent} status -s {session}` — `running` with a live pid means it is
working. **The `-s` is required.** Without it, `status` reports on the cwd-default session, not
your named one, and prints `status: no-session` even while your turn is running — which reads
as "the turn is dead" and invites you to cancel live work.

Do NOT cancel a working turn; agent turns on a large task legitimately take many minutes
(15+ observed for a first implementation). If you must stop one, use
`acpx --cwd "$REPO" {agent} cancel -s {session}`, which cancels cooperatively.

### A session's `cache_read` dropped instead of growing
Its history was almost certainly auto-compacted. Nothing in acpx's stdout, stderr token line,
or exit code reports compaction — only the harness's own session log does (for codex,
`~/.codex/sessions/{YYYY}/{MM}/{DD}/rollout-*.jsonl`, searchable for `"type":"compacted"` and
`context_compacted`; note it nests by **local** date, and the id in the filename is the
`acp_session_id` from the acpx record, not the acpx record id).

Record it in `work_log` with the round it happened on. Compaction is not necessarily fatal —
an observed instance preserved enough for the turn to complete correctly — but a session that
compacted is no longer the session you think you are measuring, and any claim about its
continuity after that point is unsupported.

Mitigations: keep sessions task-scoped (already the default here), and raise the harness's
context window if it is set below the model's real capability. For codex this is
`model_context_window` / `model_auto_compact_token_limit` in `~/.codex/config.toml`; check the
model's `max_context_window` in `~/.codex/models_cache.json` and stay inside it.

### The model or effort changed without you setting it
Expected, if you only set it once. See §Asserting the model and effort — re-assert and verify
before **every** prompt. Do not fix this by editing the harness's global config to match what
you wanted: that changes behaviour for interactive use of the same harness, and it only moves
which silent default you are relying on.

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
| Model/effort | set once by the binary | re-asserted and verified before every prompt |
| Plan checklist | ticked by `task-to-code` | ticked by the orchestrator, own commit (§5.3) |
| Topology validation | deterministic, in-binary | by inspection (or `check_cmd`) |
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
