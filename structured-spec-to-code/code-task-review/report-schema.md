# Code Task Review — Report Schema (v2)

The `code-task-review` skill emits a single YAML file conforming to the schema below. The format is structured enough for orchestrators to consume programmatically (e.g., to render PR comments, drive a remediation loop, or aggregate metrics) and human-readable enough that a developer can open the file directly.

## Top-level structure

```yaml
review:           # required — metadata about the review itself
  ...
merge_request:    # required — non-blank whole-change title and body
  ...
summary: |        # required — 2–4 sentence prose summary
  ...
acceptance_criteria:  # required — one entry per criterion in the task file
  - ...
findings:         # required — list of issues (may be empty)
  - ...
ecosystem_reviews:  # required — record of ecosystem-specific reviewers run
  - ...
```

## `review` block

```yaml
review:
  task_file: .agents/tasks/template-feature/step02/task-01-create-data-models.code-task.md
  change_id: qrstuvwxyz       # jj change ID, /^[k-z]+$/
  reviewed_at: 2026-04-27T14:32:00Z       # ISO 8601, UTC
  verdict: changes_requested              # approved | changes_requested | blocked
  schema_version: 2
  lsp_coverage: covered                   # covered | partial | unavailable
```

| Field | Required | Notes |
|---|---|---|
| `task_file` | yes | Path to the `.code-task.md` reviewed, relative to the repo root |
| `change_id` | yes | Reviewed jj change ID matching `^[k-z]+$` |
| `reviewed_at` | yes | UTC timestamp in ISO 8601 |
| `verdict` | yes | One of `approved`, `changes_requested`, `blocked`. See SKILL.md §7 for the decision rule |
| `schema_version` | yes | Must be `2` for this reviewer artifact |
| `lsp_coverage` | yes | `covered` if every touched file got LSP diagnostics; `partial` if some did; `unavailable` if no LSP tool was reachable |

## `merge_request`

Every successfully written v2 report MUST contain a non-blank merge-request title and body, regardless of `review.verdict`. They describe the complete ordered change series from the supplied base through the current change, including the initial implementation and every rework change.

```yaml
merge_request:
  title: "feat(awo): validate task state [Enhancement Step 02/Task 01]"
  body: |
    Reviews the initial implementation and each subsequent rework change in
    the complete task series, including their tests and validation evidence.
```

For a task under a plan, the title MUST end exactly with `[Enhancement Step NN/Task NN]`. For a standalone interactive task, it MUST end exactly with `[Enhancement Task NN]`. The suffix is contextual task identity, not a verdict or change ID.

## Inline completion metadata

The reviewer also emits the small YAML `spec-workflow-meta` locator with `schema_version: 1`. Its `status` describes successful report writing, so it MUST be `completed` for `approved`, `changes_requested`, and `blocked` reports; it does not mirror `review.verdict`. A complete fence may appear anywhere in the response, with prose before or after it; when multiple complete fences occur, the last complete fence is selected and an unterminated opening fence is ignored.

~~~text
Review report written.

```spec-workflow-meta
status: completed
result_path: .agents/scratchpad/feat-task/review.yaml
schema_version: 1
~~~

Additional prose is permitted after the closing fence.
~~~

## `summary`

A 2–4 sentence prose summary. Use a YAML block scalar (`|`) so newlines render. The summary is what a human reader sees first and what an orchestrator can paste into a PR comment header.

```yaml
summary: |
  Implementation covers AC1 and AC2 with corresponding tests and clean
  TDD evidence in work.log. AC3 lacks an error-path test, leaving the
  round-trip behavior under-verified. One unused-import warning in models.py.
```

## `acceptance_criteria`

One entry per criterion in the task file, in the same order. The `text` field preserves the criterion verbatim so the orchestrator can match it back.

```yaml
acceptance_criteria:
  - text: "Templates can be created with a name and description"
    status: pass                          # pass | fail | partial | not_verified
    evidence: |
      Covered by tests/models_test.py:14-28. Implementation in
      src/models.py:22 sets both fields on construction.
  - text: "Field validation rejects empty names"
    status: fail
    evidence: |
      No test asserts empty-name rejection. Implementation in
      src/models.py:91 silently accepts empty strings.
```

| Status | Meaning |
|---|---|
| `pass` | For a **behavioral** criterion: implementation present **and** at least one test exercises it. For a **non-behavioral** criterion (docs, config, structure, prose): the artifact demonstrably satisfies it, verified by inspection with cited evidence — no test required |
| `partial` | Implementation/artifact present but coverage is incomplete (e.g., a behavioral criterion tested happy-path only when it implies error handling). A non-behavioral criterion is not `partial` merely for lacking an automated test |
| `fail` | Implementation does not satisfy the criterion, or no implementation exists |
| `not_verified` | Cannot be evaluated from available artifacts. Use sparingly — prefer escalation if a criterion is genuinely unreviewable |

Any criterion not marked `pass` MUST have a corresponding entry in `findings`.

## `findings`

A list of issues. May be empty. Sort by severity (`critical` first), then by file path.

```yaml
findings:
  - severity: critical                    # critical | important | suggestion | nit
    category: tests                       # see categories below
    file: tests/models_test.py
    line: 142                             # may be null if not applicable
    title: Existing test removed without justification
    details: |
      Commit removes test_template_requires_name (was at line 142 pre-change).
      Test was passing on parent commit. progress.md does not document the
      removal. work.log has no RED entry for this requirement post-removal.
    suggested_action: |
      Restore the test, or document in progress.md why it was removed and
      add an equivalent assertion elsewhere.
    source: built-in                      # built-in | <ecosystem-skill-name>
```

| Field | Required | Notes |
|---|---|---|
| `severity` | yes | See severity ladder below |
| `category` | yes | One of: `acceptance_criteria`, `tests`, `style`, `security`, `architecture`, `other` |
| `file` | yes | Path relative to repo root. Use the file most directly affected; if the issue spans multiple files, pick the primary one and reference others in `details` |
| `line` | no | Integer line number, or `null` if the issue is file-scoped (e.g., missing test) |
| `title` | yes | One-line description, ≤ 80 chars. Used as a PR comment subject |
| `details` | yes | Multi-line explanation. Cite specific evidence — file:line, work.log entries, criterion text |
| `suggested_action` | yes | Concrete remediation. The implementer should be able to act on this without further interpretation |
| `source` | yes | `built-in` for findings produced by `code-task-review` itself; the skill name (e.g., `npm-supply-chain-review`) for findings merged in from an ecosystem reviewer |

### Severity ladder

| Severity | Meaning | Effect on verdict |
|---|---|---|
| `critical` | Blocks task completion. Examples: deleted tests without justification, security issue exploitable as written, an acceptance criterion entirely unmet, TDD evidence inconsistent with the commit | Forces `verdict: blocked` |
| `important` | Should be fixed before the task is considered done. Examples: missing test for a **behavioral** criterion (`partial`), LSP errors in touched files, latent security risk. (Do NOT raise an `important` finding for a non-behavioral criterion merely lacking an automated test — verify it by inspection instead.) | Forces at least `verdict: changes_requested` |
| `suggestion` | Improvement worth making but not blocking. Examples: refactoring opportunity, minor style drift | Does not change verdict |
| `nit` | Trivial preference, not a real issue. Examples: comment phrasing, whitespace | Does not change verdict |

### Categories

| Category | Use for |
|---|---|
| `acceptance_criteria` | A criterion is unmet, partially met, or not verifiable |
| `tests` | Test deletion, weakening, missing coverage, broken TDD evidence |
| `style` | Code conventions, naming, dead code, LSP diagnostics, comment quality |
| `security` | Issues from the security pass — input validation, auth, secrets, injection, etc. |
| `architecture` | Local architectural issues within the commit (e.g., a module gaining responsibilities outside its concern). Cross-task drift belongs to implementation-level review, not here |
| `other` | Anything that doesn't fit. Use sparingly |

## `ecosystem_reviews`

Records which ecosystem-specific review skills were run, so the report is traceable. Findings from these skills appear in the main `findings` list with `source` set to the skill's name; this block records the invocation itself.

```yaml
ecosystem_reviews:
  - skill: npm-supply-chain-review
    status: completed                     # completed | unavailable | failed
    findings_count: 2
    notes: |
      Audited package-lock.json changes; flagged one transitive dep with a
      reachable advisory.
  - skill: python-typing-review
    status: failed
    findings_count: 0
    notes: |
      Skill returned an error: mypy not installed in this environment.
```

If no ecosystem reviewers are applicable, set this to an empty list:

```yaml
ecosystem_reviews: []
```

## Verdict decision rule

The reviewer sets `verdict` mechanically from the findings and acceptance-criteria statuses:

| Condition | Verdict |
|---|---|
| Any `critical` finding present | `blocked` |
| Any `important` finding, or any AC with status `fail` / `partial` | `changes_requested` |
| Otherwise (only `suggestion`/`nit` findings; all ACs `pass` or `not_verified` with justification) | `approved` |

Orchestrators can rely on this rule to route reports without re-reading the findings.

## Minimal example (clean review)

```yaml
review:
  task_file: .agents/tasks/template-feature/step02/task-01-create-data-models.code-task.md
  change_id: qrstuvwxyz
  reviewed_at: 2026-04-27T14:32:00Z
  verdict: approved
  schema_version: 2
  lsp_coverage: covered

merge_request:
  title: "feat(models): add validated data models [Enhancement Task 01]"
  body: |
    Reviews the complete initial implementation and all subsequent rework
    changes, including tests and validation evidence.

summary: |
  All three acceptance criteria are met with corresponding tests. work.log
  shows clean RED→GREEN cycles for each. No style or security issues.

acceptance_criteria:
  - text: "Templates can be created with a name and description"
    status: pass
    evidence: tests/models_test.py:14-28 covers creation with both fields.
  - text: "Field validation rejects empty names"
    status: pass
    evidence: tests/models_test.py:42-55 asserts ValueError on empty name.
  - text: "Round-trip JSON serialization preserves all fields"
    status: pass
    evidence: tests/models_test.py:80-110 round-trips both valid and malformed input.

findings: []

ecosystem_reviews: []
```
