---
name: code-task-review
description: Review jj changes produced by `task-to-code`. Supports initial reviews and re-reviews — a re-review is a fresh invocation that reads the prior review from disk and validates that its findings were addressed in the new change. Verifies acceptance-criteria coverage, test integrity (incl. detection of deleted/weakened tests), code style and LSP cleanliness on touched files, and security. Produces a structured YAML report that an orchestrator can use to route remediation back to the implementer.
---

# Code Task Review

## Overview

Review the complete ordered jj task-change series from the supplied base through the current produced change. The reviewer reads the task file, scratchpad evidence (especially `work.log`), the jj diff and history for that whole range, and every touched file, then produces a structured YAML report at a known path. Repository inspection is jj-only.

The skill supports **two modes of invocation** with the same Steps below:
- **Initial review** — first review of a fresh produced jj change. No prior report exists at `{report_path}`.
- **Re-review** — review of a fresh rework change produced in response to a prior review. The kickoff prompt indicates this is a re-review; a prior report exists at `{report_path}` and is read from disk before forming new judgements. A re-review focuses on validating that prior `critical`/`important` findings and prior non-`pass` acceptance criteria have been addressed, surfaces regressions, and produces a fresh self-contained report on the current change series.

Each invocation runs in its own session; prior context is reloaded from the on-disk `review.yaml` rather than carried in conversation history. This keeps state management simple, makes recovery from crashes straightforward (just restart the re-review), and avoids prompt-cache expiry costs that would accrue across the implementer's intervening rework round.

The report format is defined in `report-schema.md` (sibling file). Findings carry a severity (`critical` / `important` / `suggestion` / `nit`), a category, and a file/line reference, so the same report can drive an interactive fix loop, PR-comment generation, or human-readable summary without further parsing. An external orchestrator decides what to do with findings.

**Note: human-driven invocations.** A single ad-hoc invocation (human running the skill once on a jj change) is fully supported and produces a valid `review.yaml` and a complete `spec-workflow-meta` block. Re-review behavior is triggered only when both a prior report exists at `{report_path}` and the prompt directs a re-review. The re-review capability MUST remain non-disruptive for standalone human invocations across future edits to this skill.

## Parameters

- **agents_dir** (optional, default: `.agents`): Base directory for structured-spec-to-code artifacts
- **task** (required): Path to the `.code-task.md` file that was implemented
- **current_change** (optional): Current produced jj `change_id` under review. If omitted, you MUST read it from the task's `progress.md` (recorded by `task-to-code` after committing)
- **base_change** (optional): jj `change_id` of the task base. When supplied by an orchestrator, review the complete base-to-current range.
- **produced_changes** (optional): Ordered jj `change_id` list for the implementation and rework changes. When supplied, review every listed change in order and describe the complete series in the merge request.
- **task_state** (optional): Orchestrator task-state path supplying current/base/ordered produced-change context. Use it when available; standalone human invocations remain valid with only the task and current change.
- **scratchpad_dir** (optional): Base directory for scratchpads. Defaults to `{agents_dir}/scratchpad/`. The task's scratchpad is derived by mirroring the task file's path under `tasks/`, identical to the rule used by `task-to-code`
- **report_path** (optional): Where to write the YAML report. Defaults to `{scratchpad}/review.yaml`. On a re-review round, the prior report at this path MUST be read before forming new judgements.

**Constraints for parameter acquisition:**
- You MUST ask for all parameters upfront in a single prompt
- You MUST validate that the task file and scratchpad exist
- You MUST resolve the current jj `change_id` before proceeding (from parameters or `progress.md`); if neither is available, escalate

## Escalation Policy

This skill does not block on findings — findings go in the report. This holds for both initial and re-review rounds. Escalate to the user ONLY when:
- The current jj change ID cannot be resolved
- The task file or scratchpad is missing or malformed in a way that prevents review
- The current change cannot be inspected (jj errors, missing parent, etc.)

Do NOT escalate because findings are severe — record them in the report and let the orchestrator decide.

## Steps

### 1. Load Inputs

Read everything needed for review before forming any judgement.

**Constraints:**
- You MUST read the task file in full and extract:
  - Acceptance Criteria (verbatim, with their numbering/names preserved)
  - Technical Requirements
  - Reference Documentation paths
- You MUST read the scratchpad files: `context.md`, `plan.md`, `progress.md`, and `work.log`
- You MUST resolve the current jj `change_id` and any supplied base/ordered produced changes.
- You MUST obtain the complete jj diff and ordered history from the supplied base through the current change (use jj range commands such as `jj diff -r {base}..{current}`; never use Git).
- You MUST list every file touched by the complete jj change series and read each one in its current state.
- You MUST NOT create or move bookmarks, mutate commits or descriptions, amend/squash/rewrite changes, or otherwise change repository state. Review inspection is read-only, except for writing the report file.
- You SHOULD read referenced design documents only when an acceptance criterion or finding genuinely requires them — not by default
- You MUST NOT read prior changes or unrelated parts of the codebase unless a specific finding demands it
- **On a re-review round:** you SHOULD read the prior report at `{report_path}` before forming new judgements. The prior report is the canonical schema-shaped record of the previous cycle's findings and AC statuses; use it to focus the re-review on verifying resolution of prior `critical`/`important` findings and non-`pass` acceptance criteria.

### Re-review Round Behavior

When the kickoff prompt indicates a re-review and a prior report exists at `{report_path}`, the following constraints apply in addition to the standard steps.

**Constraints:**
- You MUST read the prior `{report_path}` before forming judgements (per Step 1). The file is the canonical schema-shaped record of the previous round; it is the only carrier of prior-round context across the session boundary.
- You MUST focus the review on validating that every `critical`/`important` finding from the prior report has been addressed in the new change. For each prior finding, cite the specific code or test change (file:line) that resolves it.
- You MUST focus on validating that every prior acceptance criterion whose status was `fail`, `partial`, or `not_verified` is now `pass` (or explain why it remains non-passing).
- You MUST surface any regressions introduced by the rework — for example, newly deleted tests, new style or security issues introduced while fixing prior ones. Regressions are findings in their own right and are not excused by the prior round.
- You MUST overwrite `{report_path}` with a fresh, self-contained report on the **current** change series, conforming in full to `report-schema.md`. The report is not a delta — it covers the complete series, with prior-finding resolution reflected in the `summary` and `evidence` fields.
- You SHOULD reflect prior-finding resolution in the prose `summary` field (e.g., "All three prior findings resolved in the new change; one new style suggestion in models.py introduced during the rework.").
- You SHOULD NOT redo a full from-scratch review if the rework was narrow in scope. Focus effort where the rework touched the code; resurface prior-round concerns only if they remain unaddressed.

### 2. Discover Ecosystem-Specific Reviewers

Detect any installed skills that perform tech-stack-specific review and that fit the project's language/ecosystem.

**Constraints:**
- You MUST scan the available skills for ones whose purpose is reviewing or auditing within a specific ecosystem (examples: supply-chain audit for npm/pip/cargo, framework-specific lint reviewers, infrastructure-config reviewers)
- You MUST select only those whose ecosystem matches the project (inferred from the touched files' languages, lockfiles in the diff, or the codebase summary if available at `{agents_dir}/summary/`)
- You MUST NOT invent ecosystem-specific checks yourself — if no matching skill is installed, simply record `ecosystem_reviews: []` and proceed
- You MUST invoke each selected skill, passing the same task/commit context, and collect its findings
- You MUST merge their findings into the main report's `findings` list, setting each finding's `source` field to the skill's name (built-in checks use `source: built-in`)

### 3. Review Tests First

Before assessing production code, evaluate the test changes. This ordering avoids being anchored by the implementation.

**Constraints:**
- You MUST identify every test file touched by the complete change series and review its jj diff
- You MUST check for deleted or weakened tests using these signals:
  - Tests removed in the diff (any `- def test_…` / `- it(…)` / equivalent)
  - Assertions removed without equivalent assertions added elsewhere
  - Newly added skip/pending markers (`.skip`, `.todo`, `xit`, `pending`, `@pytest.mark.skip`, etc.)
  - Coverage of an acceptance criterion narrowed (e.g., a parametrized case dropped)
- For each suspicious change, you MUST consult `progress.md` and `work.log` for justification:
  - `work.log` should contain a RED entry (failing test) followed by a GREEN entry (passing test) for each requirement; gaps are evidence the TDD cycle was skipped
  - If a test removal is not explained in `progress.md`, it is a `critical` finding by default
- You MUST verify that each **behavioral** acceptance criterion — one verifiable by executing code and asserting on observable output, state, or errors — has at least one test scenario that exercises it; missing test coverage for a behavioral criterion is at minimum an `important` finding
- Some acceptance criteria are **non-behavioral** — documentation content or currency, presence/shape of configuration, file/directory structure, or prose quality — and have no runtime behavior to exercise. For these you MUST NOT require an automated test. Verify them by artifact inspection, and treat the implementer's cited inspection evidence (in `result.yaml`/`work.log`) or your own inspection as sufficient. **Requesting a mechanical test for a non-behavioral criterion is itself a review defect — do not do it.**
- You MUST NOT request brittle tests, and you MUST NOT credit them as coverage. A brittle test pins incidental details (exact wording, formatting, ordering) rather than a contract or an observable behavior; the canonical anti-pattern is a **change-detector** that asserts a file contains literal strings copied from that same file. If the implementer added such a test, raise a `suggestion` to remove or narrow it. (Narrow exceptions that ARE legitimate and should not be flagged: asserting the absence of a specific deprecated/stale token, or the presence of a genuine contract string an external consumer copies verbatim — a public env-var name, CLI flag, or API identifier.)
- You SHOULD evaluate test quality: meaningful assertions, edge cases, error paths — but lower-severity unless tied to an unmet criterion
- **On a re-review round:** pay particular attention to whether prior test-related findings have been addressed; surface any regressions in test coverage introduced by the rework as new findings

### 4. Verify Acceptance Criteria

For every acceptance criterion in the task file, determine whether the produced change series satisfies it.

**Constraints:**
- You MUST produce one entry in `acceptance_criteria` per criterion in the task file, preserving the original criterion text
- For each criterion, you MUST assign one of: `pass`, `fail`, `partial`, `not_verified`
- You MUST cite specific evidence (file:line references to test cases or implementation) in the `evidence` field
- A **behavioral** criterion is `pass` only if both the implementation and a test cover it; implementation without a test is at most `partial`
- A **non-behavioral** criterion (docs, config, structure, prose) is `pass` when the artifact demonstrably satisfies it and you can cite concrete inspection evidence (a file:line or quoted excerpt); it does NOT require an automated test, and the absence of a test is not grounds for `partial`
- A criterion that cannot be evaluated from the available artifacts is `not_verified` — do not guess
- Each non-`pass` criterion MUST have a corresponding finding in the `findings` list, severity `critical` or `important` depending on whether it blocks task completion
- **On a re-review round:** for each criterion that was non-`pass` in the prior report, you MUST explicitly state in `evidence` whether and how it has been addressed in the new commit, citing the specific change

### 5. Style and LSP Cleanliness

Inspect the touched files for style issues and language-server diagnostics.

**Constraints:**
- You MUST consult `{agents_dir}/summary/coding_style.md` if it exists and treat it as the authoritative reference for naming, structure, error handling, and imports
- You MUST inspect every file touched by the change series for:
  - Convention violations relative to coding_style.md or surrounding code
  - Dead code, leftover debugging output, commented-out blocks
  - Comments that explain *what* the code does (those are noise) versus *why* (those may be appropriate)
- You MUST attempt to obtain LSP diagnostics for each touched file; if an LSP tool is available in the harness, use it; otherwise note in the report that LSP coverage was not possible
- LSP errors in touched files are `important` findings; LSP warnings are `suggestion` unless they indicate a real defect
- You MUST NOT report style findings on lines the commit did not modify, unless the issue was caused by the commit (e.g., a now-unused import elsewhere)

### 6. Security Pass

Assess the produced change series for security issues at the scope of the change.

**Constraints:**
- You MUST consider, at minimum: input validation at trust boundaries, authentication/authorization changes, handling of secrets and credentials, injection risks (SQL, command, template), unsafe deserialization, broken access control, sensitive data exposure in logs/errors, unsafe file/path operations
- You MUST scope the security pass to the changed code and its immediate callers/callees — this is not a full audit
- You MUST NOT include tech-stack-specific checks (e.g., npm supply chain) here — those come from ecosystem reviewers in step 2
- Security findings are `critical` if exploitable as written, `important` if they create a latent risk, `suggestion` for hardening opportunities

### 7. Emit the Report

Write a single YAML file at `{report_path}` conforming to the schema in `report-schema.md`, then emit a complete fenced completion-metadata block.

**Constraints:**
- You MUST follow the schema in `report-schema.md` exactly — field names, allowed values, required fields
- You MUST set `verdict`:
  - `approved` if no `critical` or `important` findings, and all acceptance criteria are `pass`
  - `changes_requested` if there are `important` findings or `partial`/`fail` acceptance criteria but the task is salvageable with edits
  - `blocked` if `critical` findings indicate the task should not be considered complete (e.g., test deletion without justification, security issue, criterion entirely unmet)
- You MUST include a `summary` field with a 2–4 sentence prose summary suitable for a human reader. On a re-review, the `summary` SHOULD reflect prior-finding resolution (e.g., "All three prior findings resolved in the new jj change; one new style suggestion in models.py introduced during the rework.").
- You MUST sort `findings` by severity (`critical` first), then by file path
- You MUST emit valid YAML — quote strings containing special characters, use block scalars (`|`) for multi-line content
- You MUST overwrite any existing report at `{report_path}`. The report is always a fresh, self-contained report on the **current** commit — not a delta or patch. (The orchestrator preserves prior cycles' copies in the run directory before allowing the next cycle to start.)
- Every successfully written report, including `approved`, `changes_requested`, and `blocked`, MUST include non-blank `merge_request.title` and `merge_request.body`. The title MUST describe the complete change series and end with a task reference of the form `[<Topic>: Step NN/Task NN]` for a planned task or `[<Topic>: Task NN]` for a standalone interactive task; where `<Topic>` is a short (2-3 word) reference to the epic, feature/enhancement, etc which the step/task is part of. The body MUST summarize the initial implementation and every subsequent rework change.
- After writing the report, you MUST report to the user (or calling orchestrator) the report path and the verdict; do not paste the entire report into the response.
- After writing the report, you MUST emit a complete fenced block whose info string is exactly `spec-workflow-meta` (not bare `yaml`) carrying `status: completed`, `result_path`, and `schema_version: 1`. This locator means the report was written successfully, regardless of verdict. The complete fence may appear anywhere in the response, with prose before or after it; if multiple complete fences appear, the parser selects the last complete one. Use `status: failed` only if the skill could not produce a valid report. The format and parser rules are defined in `../task-to-code/result-schema.md`.

**Example closing block:**

```spec-workflow-meta
status: completed
result_path: .agents/scratchpad/feat-templates-task-01/review.yaml
schema_version: 1
```

## Examples

### Example Input
```
task: ".agents/tasks/template-feature/step02/task-01-create-data-models.code-task.md"
```

### Example Process
```
1. Load: read task file (3 acceptance criteria), scratchpad (progress.md cites the
   current change), work.log (3 RED→GREEN cycles recorded), and the complete jj
   base-to-current diff.
2. Ecosystem scan: project is Python; no matching ecosystem-review skill installed →
   ecosystem_reviews: [].
3. Tests first: 4 test cases added, none removed, no skip markers. work.log shows
   each AC's RED entry preceded its GREEN entry. AC3's test only covers happy path.
4. AC verification:
   - AC1 (Templates created with name + description): pass — tested at
     tests/models_test.py:14
   - AC2 (Field validation rejects empty names): pass — tests/models_test.py:42
   - AC3 (Round-trip serialization): partial — tested for valid input only,
     no error-path test
5. Style/LSP: 1 unused import in src/models.py (LSP warning).
6. Security: no externally-influenced inputs touched, nothing to flag.
7. Emit: review.yaml verdict = changes_requested (1 partial AC + 1 LSP warning).
   Close turn with spec-workflow-meta block.
```

### Example Report Excerpt
```yaml
review:
  task_file: .agents/tasks/template-feature/step02/task-01-create-data-models.code-task.md
  change_id: qrstuvwxyz
  schema_version: 2
  reviewed_at: 2026-04-27T14:32:00Z
  verdict: changes_requested

merge_request:
  title: "feat(models): add validated data models [REST API: Step 02/Task 01]"
  body: |
    Adds validated data models for all domain entities:
      - models defined in ThingDSL
      - validation rules for each model
      - comprehensive fuzz test suite

summary: |
  Implementation covers AC1 and AC2 with corresponding tests and clean
  TDD evidence in work.log. AC3 lacks an error-path test, leaving the
  round-trip behavior under-verified. One unused-import warning in models.py.

acceptance_criteria:
  - text: "Templates can be created with a name and description"
    status: pass
    evidence: tests/models_test.py:14-28 covers creation with both fields.
  ...

findings:
  - severity: important
    category: acceptance_criteria
    file: tests/models_test.py
    line: null
    title: AC3 missing error-path coverage
    details: |
      Round-trip serialization is tested for valid input only. The criterion
      requires that malformed input be rejected; no test exercises that path.
    suggested_action: |
      Add a test asserting that deserializing malformed JSON raises the
      project's standard validation error.
    source: built-in
  ...
```

## Troubleshooting

### Current Change Cannot Be Resolved
If neither the `current_change` parameter nor `progress.md` provides a jj change ID:
- You MUST escalate to the user. Do not guess at the latest change — you may review the wrong series

### Scratchpad Is Missing or Empty
If the scratchpad does not exist or `work.log` is absent:
- You SHOULD record this as a `critical` finding under category `tests` titled "TDD evidence missing" — without `work.log` the test-deletion check cannot rely on RED→GREEN evidence
- You SHOULD still complete the rest of the review using only the diff and task file

### LSP Tool Unavailable
If no LSP-diagnostic tool is available in the harness:
- You MUST set `lsp_coverage: unavailable` in the report's `review` block
- You MAY still report style issues identifiable from static reading of the file

### Conflicting Evidence Between work.log and Diff
If `work.log` claims a test exists but the diff shows it removed (or vice versa):
- You MUST treat this as a `critical` finding under category `tests`, titled "TDD evidence inconsistent with change"
- The orchestrator should re-open the task

## Artifacts

```
{scratchpad}/
└── review.yaml      — Structured review report (schema in report-schema.md); overwritten on every invocation (initial or re-review)
```

The skill writes one report file. It does not modify the task file, any jj change or description, repository state, or any other scratchpad artifact. On each invocation, `{report_path}` is overwritten with a fresh, self-contained report on the current change series; the orchestrator archives the prior round's copy before launching the next round.
