# Task-to-Code — Result Schema (v2)

The `task-to-code` skill emits two artifacts during every turn: a `result.yaml` file written to the scratchpad, and a `spec-workflow-meta` fenced locator. The artifact schema is v2; the tiny inline locator remains YAML schema v1. A complete locator fence may be surrounded by prose. Both are documented here for orchestrators and developers.

## `result.yaml` — Top-level structure

```yaml
result:               # required — metadata about the implementation run
  ...
acceptance_criteria:  # required — one entry per criterion in the task file
  - ...
artifacts:            # required — scratchpad location and file list
  ...
escalation:           # present only when status == escalated
  ...
failure:              # present only when status == failed
  ...
notes: |              # required — prose summary of the iteration
  ...
```

## `result` block

```yaml
result:
  task_file: .agents/tasks/template-feature/step02/task-01-create-data-models.code-task.md
  change_id: qrstuvwxyz         # jj change ID, /^[k-z]+$/; null if status != completed
  status: completed             # completed | escalated | failed
  schema_version: 2
  produced_at: 2026-04-28T15:01:23Z   # ISO 8601, UTC
```

| Field | Required | Notes |
|---|---|---|
| `task_file` | yes | Path to the `.code-task.md` implemented, relative to the repo root |
| `change_id` | yes | Stable jj change ID matching `^[k-z]+$` when `status: completed`; it is the produced task change at `@-` after commit, never the empty working-copy `@`; `null` otherwise |
| `status` | yes | One of `completed`, `escalated`, `failed`. See status semantics below |
| `schema_version` | yes | Must be `2` for this producer artifact |
| `produced_at` | yes | UTC timestamp in ISO 8601 |

### Status semantics

| Status | Meaning | `change_id` field | Conditional blocks |
|---|---|---|---|
| `completed` | Implementation done, tests pass, and a fresh jj change with an empty `@` was produced; `change_id` identifies that produced change at `@-` | valid jj change ID | none |
| `escalated` | Agent escalated to the user; could not proceed autonomously | `null` permitted | `escalation` block required |
| `failed` | Agent attempted but cannot produce a working change | `null` permitted | `failure` block required |

## `acceptance_criteria`

One entry per criterion in the task file, in the same order. The `text` field preserves the criterion verbatim so an orchestrator can match it back to the task file.

```yaml
acceptance_criteria:
  - text: "Templates can be created with a name and description"
    addressed: yes              # yes | partial | no
    evidence: |
      tests/models_test.py:14-28 covers creation with both fields; test runs green.
  - text: "Field validation rejects empty names"
    addressed: partial
    evidence: |
      Implementation in src/models.py:91 raises ValueError on empty name.
      Happy-path test exists but no test for the rejection case was added.
```

| Field | Required | Notes |
|---|---|---|
| `text` | yes | Verbatim criterion text from the task file |
| `addressed` | yes | For a **behavioral** criterion: `yes` — implementation and at least one test cover it; `partial` — implementation present but test coverage is incomplete; `no` — criterion not met. For a **non-behavioral** criterion (docs, config, structure, prose): `yes` — the artifact demonstrably satisfies it, verified by inspection and no test is required; `partial` — partially satisfied; `no` — not satisfied |
| `evidence` | yes | For behavioral criteria, file:line references to implementation and test code. For non-behavioral criteria, artifact-inspection evidence (a file:line or quoted excerpt) that supports the `addressed` value |

## `artifacts`

Records the scratchpad location and the files produced during the task.

```yaml
artifacts:
  scratchpad_dir: .agents/scratchpad/template-feature/step02/task-01-create-data-models/
  files:
    - context.md
    - plan.md
    - progress.md
    - work.log
    - result.yaml
```

| Field | Required | Notes |
|---|---|---|
| `scratchpad_dir` | yes | Path to the task scratchpad directory, relative to the repo root |
| `files` | yes | List of files present in the scratchpad at the time `result.yaml` is written |

## `escalation` block

Present only when `status == escalated`.

```yaml
escalation:
  reason: ambiguous_requirement     # short tag, e.g. ambiguous_requirement | blocked_dependency | design_conflict
  details: |
    Multi-line prose explanation aimed at the user: what the blocker is,
    what was tried, and what decision is needed to proceed.
```

## `failure` block

Present only when `status == failed`.

```yaml
failure:
  category: test                    # build | test | other
  details: |
    What broke, what was tried, and why recovery was not possible.
```

## `notes`

Always present. A 2–4 sentence prose summary of the iteration.

```yaml
notes: |
  Implemented the Template and Field models with full validation. All
  acceptance criteria are covered by passing tests; work.log shows clean
  RED→GREEN cycles for each. Commit abc123def.
```

## `spec-workflow-meta` inline block

After writing `result.yaml`, the skill emits a complete fenced block whose info string is exactly `spec-workflow-meta`. This block is a lightweight schema-v1 completion signal that lets an orchestrator locate the result file and detect the end of the turn without a separate round-trip.

```
spec-workflow-meta
status: completed
result_path: .agents/scratchpad/feat-templates-task-01/result.yaml
schema_version: 1
```

| Field | Required | Notes |
|---|---|---|
| `status` | yes | Same value as `result.status` in the written file |
| `result_path` | yes | Path to `result.yaml`, relative to the repo working directory |
| `schema_version` | yes | Must remain `1`; this inline locator is not the v2 artifact schema |

### Parser rules

- Find the **last complete** fenced block in the turn whose info string is exactly `spec-workflow-meta` (not bare `yaml` or any other string). The custom info string distinguishes this block from the illustrative YAML the skill quotes earlier in the turn. An unterminated opening fence is ignored.
- The complete block may appear anywhere in the response; prose or tool output may appear before or after its closing fence. If multiple complete blocks appear, select the last one.
- The body is parsed as YAML. The three fields above are required; unknown keys are ignored (forward-compatible).
- `result_path` is resolved relative to the working directory; the file MUST exist and parse against this schema.
- A successful inline-block parse is necessary but not sufficient: the canonical artifact is `result.yaml`. If the inline block parses but `result.yaml` does not, the turn is treated as malformed.

These same rules apply to `spec-workflow-meta` blocks emitted by other skills in the structured-spec-to-code workflow (e.g., `code-task-review`), with `result_path` pointing at the respective output file.

## Minimal example (completed)

```yaml
result:
  task_file: .agents/tasks/template-feature/step02/task-01-create-data-models.code-task.md
  change_id: qrstuvwxyz
  status: completed
  schema_version: 2
  produced_at: 2026-04-28T15:01:23Z

acceptance_criteria:
  - text: "Templates can be created with a name and description"
    addressed: yes
    evidence: tests/models_test.py:14-28 covers creation with both fields.
  - text: "Field validation rejects empty names"
    addressed: yes
    evidence: tests/models_test.py:42-55 asserts ValueError on empty name.

artifacts:
  scratchpad_dir: .agents/scratchpad/template-feature/step02/task-01-create-data-models/
  files:
    - context.md
    - plan.md
    - progress.md
    - work.log
    - result.yaml

notes: |
  Both acceptance criteria met with passing tests and clean TDD evidence
  in work.log. The implementation follows existing ORM patterns. The fresh
  jj change has an empty working copy and no bookmark.
```

## Minimal example (escalated)

```yaml
result:
  task_file: .agents/tasks/template-feature/step02/task-02-add-validation.code-task.md
  change_id: null
  status: escalated
  schema_version: 2
  produced_at: 2026-04-28T16:14:07Z

acceptance_criteria:
  - text: "Validation rejects inputs over 255 characters"
    addressed: no
    evidence: |
      The task references a shared validation library that does not exist in
      the codebase; cannot implement without a prerequisite.

artifacts:
  scratchpad_dir: .agents/scratchpad/template-feature/step02/task-02-add-validation/
  files:
    - context.md
    - plan.md
    - progress.md
    - work.log
    - result.yaml

escalation:
  reason: blocked_dependency
  details: |
    The task requires importing from `lib/validators`, which does not exist.
    The design doc references it as a prerequisite that should have been
    created in an earlier task. Please confirm whether task-01 was skipped
    or whether the path has changed.

notes: |
  Implementation blocked by a missing prerequisite library. No commit was
  produced. The escalation block describes the dependency and what is needed
  to unblock.
```
