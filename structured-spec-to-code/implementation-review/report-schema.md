# Implementation Review — Report Schema (v1)

The `implementation-review` skill emits a single YAML file. The schema reuses the severity ladder, finding structure, and `ecosystem_reviews` block from `code-task-review/report-schema.md` (referenced where applicable) and adds blocks specific to whole-implementation analysis: `architecture`, `doc_code_alignment`, and `remediation_tasks`.

## Top-level structure

```yaml
review:           # required — metadata about the review itself
  ...
summary: |        # required — 3–5 sentence prose summary
  ...
architecture:     # required — design-element-to-code map
  - ...
doc_code_alignment:  # required — list of design/doc divergences
  - ...
findings:         # required — issues raised by this review (may be empty)
  - ...
remediation_tasks:  # required — manifest of generated task files (may be empty)
  - ...
ecosystem_reviews:  # required — record of ecosystem-specific reviewers run
  - ...
```

## `review` block

```yaml
review:
  project: template-feature
  plan_path: .agents/planning/template-feature/implementation/plan.md
  design_path: .agents/planning/template-feature/design/detailed-design.md
  reviewed_at: 2026-04-27T14:32:00Z
  schema_version: 1
  steps_in_scope: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
  commits_in_scope: 23
  remediation_step: .agents/tasks/template-feature/step13/   # null if verdict is `clean`
  verdict: remediation_recommended       # clean | remediation_recommended | remediation_required
```

| Field | Required | Notes |
|---|---|---|
| `project` | yes | Project name (last segment of `project_dir`) |
| `plan_path` | yes | Path to the plan that was reviewed |
| `design_path` | yes | Path to the design document used as the baseline |
| `reviewed_at` | yes | UTC ISO 8601 |
| `schema_version` | yes | Currently `1` |
| `steps_in_scope` | yes | List of plan step numbers reviewed (typically all of them) |
| `commits_in_scope` | yes | Total commit count across all in-scope tasks |
| `remediation_step` | yes | Path to the generated step folder, or `null` if verdict is `clean` |
| `verdict` | yes | See decision rule below |

## `summary`

A 3–5 sentence prose summary suitable for a human reader. Slightly longer than `code-task-review`'s summary because the scope is larger.

```yaml
summary: |
  Implementation matches the design at the major-element level: 7 of 9
  components are aligned. The TemplateRegistry diverged from a singleton
  to a per-request instance — likely the right call for step 4's
  requirements, but the design doc still describes the old shape.
  Cross-cutting cleanup is needed: empty-name validation is duplicated
  in three modules, and error types diverged between early and late
  steps. One important finding from a step 3 task review remains
  unresolved.
```

## `architecture`

One entry per major design element (component, module, interface, key data model, layering rule). The list is the architecture map produced in skill step 2.

```yaml
architecture:
  - element: TemplateRegistry
    expected: |
      Singleton owning template lookup; mutated only at startup.
    actual: |
      Per-request instance constructed in the request scope; supports
      mutation across the request lifecycle.
    status: drifted               # see status values below
    files:
      - src/templates/registry.py
    notes: |
      Plausibly intentional given step 4 added per-request mutability
      requirements. Design doc was not updated.

  - element: FieldFormatter
    expected: null                # not in the design
    actual: |
      Abstraction introduced in step 7 to centralise per-field rendering.
    status: undocumented_addition
    files:
      - src/fields/formatter.py
      - src/fields/__init__.py
    notes: |
      Reasonable separation; recommend adding to the design doc.
```

| Status | Meaning |
|---|---|
| `aligned` | Code matches the design's intent |
| `drifted` | Code exists but its shape differs from the design in a way that may not be intentional. The notes MUST capture both possibilities (drift vs. justified evolution) |
| `undocumented_addition` | The implementation added something the design did not describe. Not necessarily bad — the doc may need updating |
| `partial` | The element is partially implemented (e.g., interface exists but missing methods the design required) |
| `missing` | The design specified this element but it is absent from the code |

## `doc_code_alignment`

Decisions about each architecture element that is not `aligned`. This is the input for "should we update the doc or update the code?"

```yaml
doc_code_alignment:
  - artifact: design/detailed-design.md
    section: Template Registry
    issue: |
      Doc describes a singleton; code is per-request. Step 4's
      requirements made the per-request shape correct.
    suggested_action: update_doc       # update_doc | update_code | discuss
    related_finding: F4

  - artifact: design/detailed-design.md
    section: Field Pipeline
    issue: |
      FieldFormatter abstraction is not mentioned.
    suggested_action: update_doc
    related_finding: F5
```

| Field | Required | Notes |
|---|---|---|
| `artifact` | yes | Path to the doc relative to the project root, or doc identifier (e.g., `README.md`) |
| `section` | yes | Section heading or anchor where the issue lives |
| `issue` | yes | What's misaligned, in 1–3 sentences |
| `suggested_action` | yes | `update_doc` (code is right), `update_code` (doc captured the right intent), `discuss` (genuinely ambiguous) |
| `related_finding` | no | Finding ID in the `findings` list (if any) — links the alignment item to the corresponding finding |

## `findings`

Same shape and severity ladder as `code-task-review`'s `findings` list. See `../code-task-review/report-schema.md` for field definitions.

The category set is **expanded** for implementation review:

| Category | Use for |
|---|---|
| `architecture` | Drift, layering violations, cross-cutting structural issues |
| `duplication` | Same logic, validation, or data shape implemented in multiple places |
| `dependencies` | Import cycles, leaky abstractions, undesirable coupling |
| `doc_divergence` | Design or other docs no longer match the implementation |
| `consistency` | Patterns differ between tasks (error handling, logging, naming, test style) |
| `coverage` | Test coverage gaps that span tasks (typically at integration seams) |
| `dead_code` | Exports/functions/types added during implementation but unused at end of plan |
| `unresolved_review_findings` | A finding from a per-task `review.yaml` that was not addressed |
| `tests` | Test integrity issues at the implementation scope (rare — most belong to per-task review) |
| `style` | Cross-cutting style issues (e.g., one module diverges from coding_style.md) |
| `security` | Security issues visible only at the implementation scope (cross-component flows) |
| `other` | Anything that doesn't fit. Use sparingly |

Findings carry a stable ID (`F1`, `F2`, …) so other blocks can reference them. Each finding that warrants action MUST also appear in `remediation_tasks` via the `addresses_findings` field.

```yaml
findings:
  - id: F1
    severity: important
    category: duplication
    file: src/templates/validation.py
    line: 12
    title: Empty-name validation duplicated across three modules
    details: |
      The rule "name must be non-empty" is implemented at:
      - src/templates/validation.py:12
      - src/fields/validation.py:34
      - src/api/handlers.py:88
      Three subtly different error messages, all rejecting the same input.
    suggested_action: |
      Extract a shared validator into a common module and route all
      three call sites through it.
    source: built-in
    addressed_by: stepNN/task-01-consolidate-empty-name-validation.code-task.md
```

The `addressed_by` field is the inverse of `remediation_tasks[].addresses_findings`. Either or both may appear; orchestrators should accept either as the source of truth.

## `remediation_tasks`

Manifest of generated task files. May be empty.

```yaml
remediation_tasks:
  - path: .agents/tasks/template-feature/step13/task-01-consolidate-empty-name-validation.code-task.md
    title: Consolidate empty-name validation
    addresses_findings: [F1]
    sequence: 1

  - path: .agents/tasks/template-feature/step13/task-02-unify-error-types.code-task.md
    title: Unify validation error types
    addresses_findings: [F2, F6]
    sequence: 2
```

| Field | Required | Notes |
|---|---|---|
| `path` | yes | Path to the generated `.code-task.md` file |
| `title` | yes | Human-readable title (matches the task file's `# Task:` heading) |
| `addresses_findings` | yes | List of finding IDs addressed by this task |
| `sequence` | yes | Order within the remediation step (1-based). Tasks must be sequenced so that prerequisites come first |

## `ecosystem_reviews`

Same shape as `code-task-review`'s block. See `../code-task-review/report-schema.md`.

## Verdict decision rule

Mechanically derived from findings, architecture statuses, and doc/code alignment items:

| Condition | Verdict |
|---|---|
| Any `critical` finding present, OR any `architecture[].status: missing`, OR any `doc_code_alignment[].suggested_action: update_code` for a load-bearing element | `remediation_required` |
| Any `important` finding, OR any `architecture[].status` of `drifted` / `undocumented_addition` / `partial`, OR any `doc_code_alignment` items needing action — but no critical-tier issues | `remediation_recommended` |
| Otherwise (all aligned, only `suggestion`/`nit` findings, no doc divergences) | `clean` |

When the verdict is `clean`, no remediation tasks are generated and the plan is not modified.

## Minimal example (clean implementation)

```yaml
review:
  project: template-feature
  plan_path: .agents/planning/template-feature/implementation/plan.md
  design_path: .agents/planning/template-feature/design/detailed-design.md
  reviewed_at: 2026-04-27T14:32:00Z
  schema_version: 1
  steps_in_scope: [1, 2, 3]
  commits_in_scope: 7
  remediation_step: null
  verdict: clean

summary: |
  Implementation matches the design at every major element. No drift,
  no undocumented additions, no cross-cutting issues surfaced. All
  per-task reviews previously approved; no unresolved findings.

architecture:
  - element: TemplateModel
    expected: |
      Data model with name, description, and fields collection.
    actual: |
      As specified.
    status: aligned
    files:
      - src/models.py
    notes: ""

doc_code_alignment: []

findings: []

remediation_tasks: []

ecosystem_reviews: []
```
