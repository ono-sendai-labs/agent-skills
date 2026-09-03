---
name: implementation-review
description: Review an implementation as a whole — either a single completed step or a finished plan. Looks across every commit in scope, the current state of the codebase, the design, and the task-level review residue to surface architectural drift, duplication, undesirable dependencies, doc/code divergence, and cross-cutting issues that no single task review could catch. Produces a structured YAML report and a set of follow-on remediation `.code-task.md` files that re-enter the existing pipeline. Designed to run with clean context after the last task in scope is committed.
---

# Implementation Review

## Overview

Review a completed implementation as a whole — not commit by commit. The reviewer reads the design, the plan, every task file in scope, the scratchpad evidence (including any per-task `review.yaml` reports), and selectively reads the current state of the codebase.

The review runs at one of two **scopes**, selected by the `scope` parameter:

| `scope` | Covers | Runs when | Purpose |
|---|---|---|---|
| `step` | One step's tasks and commits | After the last task of a step is approved, before advancing | Catch cross-task drift *within* a step while it is still cheap to fix |
| `plan` (default) | Every step in the plan | After the last task of the last step | Catch drift that spans steps, and residue the per-step passes missed |

The two are complementary, not alternatives. Running per-step reviews does not remove the value of a final plan-scoped pass, but it should make it quieter: a plan-scoped review MUST treat existing per-step reports as input (see step 5) rather than re-deriving findings already remediated.

It produces:

1. A structured YAML report (`{report_path}`; schema in `report-schema.md`).
2. A set of follow-on remediation `.code-task.md` files addressing findings that warrant code changes — placed so the existing `task-to-code` flow picks them up (placement differs by scope; see step 8).
3. At `plan` scope only, an appended remediation step in the implementation plan.

The skill is single-pass: read inputs, analyse, emit artifacts, exit. It does not iterate, does not modify the existing code, and does not run task-to-code itself. It is intended to run with a highly capable model (Opus-class), since the analysis is wide-scope and judgement-heavy — and, when driven by an orchestrator, in a **fresh session**, since context independence is the whole point of a review that is meant to catch what the per-task reviewer could not.

## Parameters

- **agents_dir** (optional, default: `.agents`): Base directory for structured-spec-to-code artifacts
- **project_dir** (required): Project directory containing the design and plan (e.g., `{agents_dir}/planning/{project_name}`)
- **scope** (optional, default: `plan`): `plan` to review every step, or `step` to review a single completed step
- **step** (required iff `scope: step`): The step number to review, e.g. `1`. Zero-padded `step{NN}` directory naming is used on disk regardless of how it is passed
- **plan_path** (optional, default: `{project_dir}/implementation/plan.md`): Path to the implementation plan
- **report_path** (optional): Where to write the YAML report. Defaults to `{project_dir}/implementation/review.yaml` at `plan` scope, and `{project_dir}/implementation/review-step{NN}.yaml` at `step` scope — a step-scoped review MUST NOT overwrite the plan-scoped report or another step's
- **remediation_step_dir** (optional): Where to put generated remediation tasks. Defaults differ by scope:
  - `plan`: `{agents_dir}/tasks/{project_name}/step{NN}/`, where `NN` is the next available step number after the highest existing step folder
  - `step`: the **reviewed step's own** directory, `{agents_dir}/tasks/{project_name}/step{NN}/` — remediation tasks are appended to that step as additional tasks, continuing its `task-{MM}-` numbering
- **prior_step_reports** (optional, `plan` scope only): Paths to step-scoped reports already produced for this plan. Defaults to any `{project_dir}/implementation/review-step*.yaml` found

**Constraints for parameter acquisition:**
- You MUST ask for all parameters upfront in a single prompt
- You MUST validate that the plan and design files exist
- You MUST resolve `scope` explicitly and state it in the report; never infer it from whether `step` happens to be set
- Checklist validation depends on scope:
  - At `plan` scope, you MUST verify that all checklist items in the plan are marked complete; if not, you MUST escalate — reviewing a partial implementation is out of scope
  - At `step` scope, you MUST NOT require the step's checklist item to be ticked. Under the current contract the orchestrator ticks it *after* this review passes, so an unticked item is the expected state. You MUST instead verify that every task file in the step has a recorded commit (see step 1); a step with uncommitted tasks is out of scope and you MUST escalate
- At `step` scope you MUST verify the step directory `{agents_dir}/tasks/{project_name}/step{NN}/` exists and contains at least one task file

## Escalation Policy

This skill does not block on findings — findings go in the report. Escalate to the user ONLY when:
- At `plan` scope: the plan still has unchecked items (review of a partial implementation is not supported)
- At `step` scope: one or more of the step's tasks has no recorded commit (the step is not finished)
- The design document is missing or unparseable
- No commits can be located for the implementation in scope (no `progress.md` files, no commit log entries)

Do NOT escalate because findings are severe — record them in the report and generate remediation tasks for the orchestrator to act on.

## Steps

### 1. Load Inputs

Build a complete picture of the implementation before forming any judgement.

**Constraints:**
- You MUST read the plan in full. At `plan` scope, confirm all checklist items are complete; at `step` scope, read the reviewed step's section in full and treat the surrounding steps as context for sequencing only
- You MUST read the design document referenced by the plan (typically `{project_dir}/design/detailed-design.md`)
- You MUST enumerate task files according to scope and read each one:
  - `plan`: every task file under `{agents_dir}/tasks/{project_name}/step*/`
  - `step`: only `{agents_dir}/tasks/{project_name}/step{NN}/`
- At `step` scope you MUST NOT flag work belonging to later, not-yet-implemented steps as `missing` or as drift. The plan is the authority on what this step was responsible for; a design element the plan defers to a later step is out of scope, and saying otherwise produces findings the orchestrator cannot act on. You SHOULD, however, flag a design element this step *was* responsible for and did not deliver
- At `plan` scope you MUST read any `prior_step_reports` before analysing, and treat their findings as already-known: a finding that a step-scoped report raised and whose remediation is present in the current code MUST NOT be re-reported. One that was raised and is still unaddressed MUST be re-reported, escalated one severity level, citing the earlier report
- You MUST locate each task's scratchpad and read its `progress.md` (for the commit revision) and `review.yaml` if present
- You MUST collect the list of commits from progress.md entries; if any task lacks a recorded commit you SHOULD note it and continue
- You SHOULD consult `{agents_dir}/summary/` if available — both `codebase-summary.md` and `coding_style.md` — to understand pre-existing architecture and conventions
- You MUST NOT read the entire codebase up front; instead, identify the major code surfaces from the design and read those files selectively as the review proceeds
- You MUST NOT re-read prior commits' diffs unless investigating a specific finding; the reviewer's primary frame is the *current* state of the code, not commit-by-commit history

### 2. Build the Architecture Map

Map each major design element to where it lives in the code now, and judge whether it aligns with intent.

**Constraints:**
- You MUST extract the major architectural elements from the design document — components, modules, interfaces, data models, key invariants, layering rules
- For each element, you MUST locate the corresponding code (files, classes, functions, modules) by reading the codebase
- For each element, you MUST assign an alignment status (see schema for allowed values: `aligned` / `drifted` / `undocumented_addition` / `missing` / `partial`)
- `drifted` means the code exists but its shape differs from the design in a way that may not be intentional — flag both possibilities (drift vs. justified evolution) in the notes
- `undocumented_addition` means the code added something not described in the design — this is not automatically bad, but the design should either be updated or the addition justified
- You MUST capture the architecture map in the report's `architecture` block

### 3. Check Doc/Code Alignment

Identify every place where the design or other docs no longer match the implementation.

**Constraints:**
- For each `drifted`, `undocumented_addition`, or `partial` element from step 2, you MUST decide whether the appropriate remediation is `update_doc` (code is correct, doc is stale), `update_code` (doc captured the right intent, code drifted), or `discuss` (genuinely ambiguous — needs human judgement)
- You MUST capture these in the `doc_code_alignment` block of the report
- You SHOULD also check obvious external docs touched by the implementation: README sections, API references, comments at module headers — but do not exhaustively crawl all docs

### 4. Cross-Cutting Analysis

Look for issues that no individual task review could have caught.

**Constraints:**
- You MUST evaluate the following cross-cutting concerns:
  - **Duplication** — the same logic, validation, or data shape implemented in multiple places across tasks
  - **Dependencies** — module/package import cycles, layering violations, leaky abstractions, unnecessary coupling between concerns
  - **Pattern consistency** — error handling, logging, naming, test style differ between tasks; flag opportunities to consolidate
  - **Coverage gaps** — flows that span multiple tasks and end up only partially tested at the seams between them
  - **Dead code** — exports/functions/types added during implementation but unused at end of plan
- You MUST record each issue as a finding in the report
- You MUST NOT include tech-stack-specific cross-cutting checks here — those come from ecosystem reviewers in step 6

### 5. Aggregate Task-Level Review Residue

Account for findings raised by `code-task-review` that may not have been addressed.

**Constraints:**
- For each task that has a `review.yaml`, you MUST inspect its `findings` and `verdict`
- You MUST identify any `important` or `critical` findings whose `suggested_action` does not appear to have been carried out (cross-check against the current code)
- You MUST surface unresolved findings as new findings in the implementation review report, category `unresolved_review_findings`, citing the original task and finding
- A task whose final `review.yaml` has `verdict: escalated` (or the deprecated `verdict: blocked`, in archived reports) but no subsequent fix commit is by itself a `critical` finding

### 6. Discover and Invoke Ecosystem Reviewers

Detect installed skills that perform tech-stack-specific review at the implementation scope, and invoke them.

**Constraints:**
- You MUST scan available skills for ones whose purpose is reviewing or auditing within a specific ecosystem (supply-chain audits, framework-specific architecture reviewers, infrastructure-config reviewers, etc.)
- You MUST select only those whose ecosystem matches the project (inferred from the codebase summary or the dominant languages/manifests in the touched files)
- You MUST invoke each selected skill with appropriate context for an implementation-scope review (full codebase, not a single commit)
- You MUST merge their findings into the main `findings` list with `source` set to the skill's name
- You MUST record the invocation in the `ecosystem_reviews` block
- If no matching skill is installed, set `ecosystem_reviews: []` and proceed

### 7. Score Findings and Plan Remediation

Decide which findings warrant a remediation task.

**Constraints:**
- You MUST assign each finding a severity (`critical`, `important`, `suggestion`, `nit`) using the same ladder as `code-task-review` (see report-schema.md)
- Every `critical` finding MUST be matched to a remediation task
- Every `important` finding SHOULD be matched to a remediation task; if it is not, you MUST justify in the finding's `details`
- `suggestion` findings MAY have remediation tasks; they typically do not
- `nit` findings MUST NOT generate remediation tasks
- You SHOULD group multiple related findings under a single remediation task when they share a fix (e.g., "extract duplicated validation" addresses three duplication findings at once)
- You MUST sequence remediation tasks so that prerequisites come first, mirroring the rule used by `plan-to-tasks`

### 8. Generate Remediation Task Files

Write the remediation tasks following the same code task format used by `plan-to-tasks`.

**Constraints:**
- Placement depends on scope:
  - At `plan` scope, you MUST determine the next available step number (`NN`) by inspecting `{agents_dir}/tasks/{project_name}/` and choosing the smallest integer not already used as `step{NN}`, then create the directory `{remediation_step_dir}` (defaulting to `step{NN}/`)
  - At `step` scope, you MUST write remediation tasks into the **reviewed step's own** directory, continuing its `task-{MM}-` numbering from the highest existing task number. You MUST NOT create a new step, and MUST NOT renumber or modify the step's existing task files. Name them so their origin is obvious, e.g. `task-04-remediate-duplicated-path-canonicalisation.code-task.md`
- At `step` scope you MUST cap remediation at **3 tasks**. Cross-task issues found within a single step are by construction narrow; if more than 3 are warranted, the step's decomposition is likely wrong and that is itself the finding — generate the top 3, and record in the report's summary that the step needs re-planning rather than more remediation
- You MUST follow the Code Task Format documented in `../plan-to-tasks/SKILL.md` (sections: Description, Background, Reference Documentation, Technical Requirements, Dependencies, Implementation Approach, Acceptance Criteria, Metadata)
- Each remediation task MUST:
  - Reference the implementation review report in its Reference Documentation section: `Implementation Review: {report_path}`
  - Cite in Background which finding IDs it addresses (e.g., "Addresses findings F3, F7 from implementation review")
  - Have acceptance criteria that make the fix verifiable — typically "the original issue is no longer present, demonstrated by [specific check]"
  - Be atomic (single concern, single commit)
- You MUST NOT exceed 5–6 remediation tasks per step. If more are needed, generate the highest-priority 5–6 and note in the report that further remediation rounds will be needed
- You MUST record each generated task in the report's `remediation_tasks` block (path + addressed finding IDs)

### 9. Update the Implementation Plan

**This step applies at `plan` scope only. At `step` scope you MUST NOT modify `plan.md` at all** — not the checklist, not the step body. The remediation tasks live inside the step that is already in progress, and the orchestrator ticks that step's checklist item once they are done. Skip to step 10.

At `plan` scope, append a new step to `plan.md` for the remediation work.

**Constraints:**
- You MUST append a new numbered step to the plan's checklist, using a title like "Remediation from implementation review {date}"
- You MUST add the corresponding step section in the body of the plan, following the same structure as existing steps (Objective, Implementation guidance, Test requirements, Demo criteria), summarised from the remediation tasks
- You MUST leave the new step's checklist item *unchecked* — the orchestrator ticks it once all remediation tasks are committed
- If no remediation tasks were generated (verdict: `clean`), you MUST NOT modify the plan

### 10. Emit the Report

Write the YAML report to `{report_path}`.

**Constraints:**
- You MUST follow the schema in `report-schema.md` exactly
- You MUST record the `scope` you ran at, and at `step` scope the `step` number, in the report header. A consumer that cannot tell a step report from a plan report will mis-file its findings
- You MUST set `verdict`:
  - `clean` if no `important` or `critical` findings, no `drifted`/`missing` architecture elements, and no `update_code` doc/code alignment items — and therefore no remediation tasks generated
  - `remediation_recommended` if `important` findings or notable doc/code drift exist, but no `critical` blockers
  - `remediation_required` if any `critical` findings exist
- You MUST sort `findings` by severity (`critical` first), then by category, then by file
- You MUST emit valid YAML; use block scalars (`|`) for multi-line content
- After writing, you MUST report to the user (or calling orchestrator) the report path, the verdict, the count of remediation tasks generated, and the new step's path; do not paste the entire report into the response

## Examples

### Example Input
```
project_dir: ".agents/planning/template-feature"
```

### Example Process
```
1. Load: 12-step plan, all complete. 23 task files across 12 steps. 23 commits.
   Read design (8KB), plan (4KB), all review.yaml files (3 had unresolved
   important findings).
2. Architecture map: 9 elements total.
   - 7 aligned
   - 1 drifted: TemplateRegistry was specified as a singleton; implementation
     has it as a per-request instance. Plausibly intentional, not documented.
   - 1 undocumented_addition: A FieldFormatter abstraction added in step 7
     that the design didn't mention.
3. Doc/code alignment:
   - design/detailed-design.md §"Template Registry" — update_doc (per-request
     pattern is the right call given step 4 reqs)
   - design/detailed-design.md §"Field Pipeline" — update_doc (mention
     FieldFormatter)
4. Cross-cutting:
   - Duplication: validation rule "name must be non-empty" appears in 3 modules
   - Pattern consistency: errors raised as ValueError in steps 1-6, custom
     ValidationError in step 7+. One should win.
5. Task-level review residue:
   - step03/task-02 had an unresolved 'important' finding about missing
     error-path test. Still missing.
6. Ecosystem reviewers: Python project, no python-specific reviewer installed.
   ecosystem_reviews: [].
7. Findings scored: 0 critical, 4 important, 3 suggestions.
8. Remediation tasks generated under step13/:
   - task-01-consolidate-empty-name-validation
   - task-02-unify-error-types
   - task-03-add-error-path-test-from-step03
   - task-04-update-design-doc-for-registry-and-formatter
9. plan.md: appended Step 13 "Remediation from implementation review 2026-04-27"
10. Emit: review.yaml, verdict = remediation_recommended.
```

## Troubleshooting

### Plan Has Unchecked Items
At `plan` scope, if any plan checklist item is incomplete:
- You MUST escalate. A plan-scoped review assumes the plan is finished. A partial implementation has different remediation dynamics (in-progress work shouldn't be flagged as drift) and is out of scope

At `step` scope this is **not** an error condition: the reviewed step's item is expected to be unticked, because the orchestrator ticks it after this review passes. Escalate only if one of the step's own tasks has no recorded commit.

### A Step-Scoped Review Keeps Finding Problems
The orchestrator may re-run a step-scoped review after its remediation tasks are implemented. Guard against an unbounded loop:
- A step SHOULD receive at most **two** step-scoped reviews: the initial one, and one confirmation pass after remediation
- If the confirmation pass still yields `critical` findings, you MUST say so plainly in the summary and recommend the orchestrator stop and surface to the user rather than generating a third round. Repeated remediation on one step means the step was mis-planned, which is a planning decision, not a review one

### Design Document Missing or Unparseable
If the design referenced by the plan cannot be read or has no architectural content:
- You MUST escalate. Without a design, there is no baseline for "drift" or "undocumented addition"
- You MAY still produce a partial review focused on cross-cutting issues (duplication, dependencies, pattern consistency) if the user explicitly asks

### No Remediation Tasks Needed
If the verdict is `clean`:
- You MUST NOT create a remediation step folder
- You MUST NOT modify the plan
- You MUST still write the YAML report — it documents that the implementation was reviewed and found clean

### Too Many Findings to Address in One Round
If the review surfaces enough issues that more than 5–6 remediation tasks would be needed:
- You MUST generate the highest-priority 5–6 (all `critical`, then `important` by impact)
- You MUST note in the report's summary that a follow-up implementation review is recommended after this round of remediation, to address the remaining findings

## Artifacts

At `plan` scope:

```
{project_dir}/implementation/
├── plan.md          — Updated with appended remediation step (if any)
└── review.yaml      — Implementation review report (schema in report-schema.md)

{agents_dir}/tasks/{project_name}/step{NN}/     — NEW step folder
├── task-01-*.code-task.md
└── ...              — Generated remediation tasks (if any)
```

At `step` scope:

```
{project_dir}/implementation/
└── review-step{NN}.yaml   — Step review report; plan.md is NOT modified

{agents_dir}/tasks/{project_name}/step{NN}/     — the EXISTING step folder
├── task-01-*.code-task.md                      — untouched
├── task-02-*.code-task.md                      — untouched
└── task-03-remediate-*.code-task.md            — appended remediation tasks (if any)
```

The skill writes the report unconditionally, and remediation tasks only when the verdict is not `clean`. It modifies `plan.md` only at `plan` scope. It does not modify any other artifact.
