---
name: implementation-review
description: Review the full implementation of a plan once all its steps are complete. Looks across every commit, the current state of the codebase, the design, and the task-level review residue to surface architectural drift, duplication, undesirable dependencies, doc/code divergence, and cross-cutting issues that no single task review could catch. Produces a structured YAML report and a set of follow-on remediation `.code-task.md` files that re-enter the existing pipeline. Designed to run with clean context after the last task in the plan is committed.
---

# Implementation Review

## Overview

Review a finished implementation as a whole — not commit by commit. The reviewer reads the design, the plan, every task file, the scratchpad evidence (including any per-task `review.yaml` reports), and selectively reads the current state of the codebase. It produces:

1. A structured YAML report at `{project_dir}/implementation/review.yaml` (schema in `report-schema.md`).
2. A set of follow-on remediation `.code-task.md` files in a new step folder, addressing findings that warrant code changes.
3. An appended remediation step in the implementation plan, so the existing `task-to-code` flow can pick the new tasks up.

The skill is single-pass: read inputs, analyse, emit artifacts, exit. It does not iterate, does not modify the existing code, and does not run task-to-code itself. It is intended to run with a highly capable model (Opus-class), since the analysis is wide-scope and judgement-heavy.

## Parameters

- **agents_dir** (optional, default: `.agents`): Base directory for structured-spec-to-code artifacts
- **project_dir** (required): Project directory containing the design and plan (e.g., `{agents_dir}/planning/{project_name}`)
- **plan_path** (optional, default: `{project_dir}/implementation/plan.md`): Path to the implementation plan
- **report_path** (optional, default: `{project_dir}/implementation/review.yaml`): Where to write the YAML report
- **remediation_step_dir** (optional): Where to put generated remediation tasks. Defaults to `{agents_dir}/tasks/{project_name}/step{NN}/`, where `NN` is the next available step number after the highest existing step folder

**Constraints for parameter acquisition:**
- You MUST ask for all parameters upfront in a single prompt
- You MUST validate that the plan and design files exist
- You MUST verify that all checklist items in the plan are marked complete; if not, you MUST escalate — running implementation review on a partial implementation is out of scope

## Escalation Policy

This skill does not block on findings — findings go in the report. Escalate to the user ONLY when:
- The plan still has unchecked items (review of a partial implementation is not supported)
- The design document is missing or unparseable
- No commits can be located for the implementation (no `progress.md` files, no commit log entries)

Do NOT escalate because findings are severe — record them in the report and generate remediation tasks for the orchestrator to act on.

## Steps

### 1. Load Inputs

Build a complete picture of the implementation before forming any judgement.

**Constraints:**
- You MUST read the plan in full and confirm all checklist items are complete
- You MUST read the design document referenced by the plan (typically `{project_dir}/design/detailed-design.md`)
- You MUST enumerate every task file under `{agents_dir}/tasks/{project_name}/step*/` and read each one
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
- A task with `verdict: blocked` but no subsequent fix commit is by itself a `critical` finding

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
- You MUST determine the next available step number (`NN`) by inspecting `{agents_dir}/tasks/{project_name}/` and choosing the smallest integer not already used as `step{NN}`
- You MUST create the directory `{remediation_step_dir}` (defaulting to `step{NN}/`)
- You MUST follow the Code Task Format documented in `../plan-to-tasks/SKILL.md` (sections: Description, Background, Reference Documentation, Technical Requirements, Dependencies, Implementation Approach, Acceptance Criteria, Metadata)
- Each remediation task MUST:
  - Reference the implementation review report in its Reference Documentation section: `Implementation Review: {report_path}`
  - Cite in Background which finding IDs it addresses (e.g., "Addresses findings F3, F7 from implementation review")
  - Have acceptance criteria that make the fix verifiable — typically "the original issue is no longer present, demonstrated by [specific check]"
  - Be atomic (single concern, single commit)
- You MUST NOT exceed 5–6 remediation tasks per step. If more are needed, generate the highest-priority 5–6 and note in the report that further remediation rounds will be needed
- You MUST record each generated task in the report's `remediation_tasks` block (path + addressed finding IDs)

### 9. Update the Implementation Plan

Append a new step to `plan.md` for the remediation work.

**Constraints:**
- You MUST append a new numbered step to the plan's checklist, using a title like "Remediation from implementation review {date}"
- You MUST add the corresponding step section in the body of the plan, following the same structure as existing steps (Objective, Implementation guidance, Test requirements, Demo criteria), summarised from the remediation tasks
- You MUST leave the new step's checklist item *unchecked* — `task-to-code` will tick it once all remediation tasks are committed
- If no remediation tasks were generated (verdict: `clean`), you MUST NOT modify the plan

### 10. Emit the Report

Write the YAML report to `{report_path}`.

**Constraints:**
- You MUST follow the schema in `report-schema.md` exactly
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
If any plan checklist item is incomplete:
- You MUST escalate. Implementation review assumes the plan is finished. A partial implementation has different remediation dynamics (in-progress work shouldn't be flagged as drift) and is out of scope

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

```
{project_dir}/implementation/
├── plan.md          — Updated with appended remediation step (if any)
└── review.yaml      — Implementation review report (schema in report-schema.md)

{agents_dir}/tasks/{project_name}/step{NN}/
├── task-01-*.code-task.md
├── task-02-*.code-task.md
└── ...              — Generated remediation tasks (if any)
```

The skill writes the report unconditionally, the plan and remediation tasks only when the verdict is not `clean`. It does not modify any other artifact.
