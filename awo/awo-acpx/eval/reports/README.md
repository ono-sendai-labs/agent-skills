# awo-acpx run reports

Work logs from real `awo-acpx` runs, kept as the evidence behind the skill's design
decisions. The orchestrator writes its `work_log` to a gitignored scratchpad in the
target repository, so without checking a copy in here the reasoning behind a change
survives only in a commit message.

Each report is a verbatim copy, written incrementally during the run. They are
chronological rather than tidy: in-flight reasoning, corrections and dead ends are left
in, because *how* a defect was noticed is often more useful than the finished statement
of it.

Conventions:

- Name reports `{YYYY-MM-DD}-{repo}-{scope}-{plan-slug}.md`.
- Tag findings `[F-nn]` and keep the numbering stable within a report, so skill changes
  and commit messages can cite them.
- State the skill revision under test, and — once the report has produced changes — the
  revision that resulted. A report whose findings have been acted on should say so.
- Record judgement calls the orchestrator had to make where a deterministic tool would
  not have, and be explicit about which ones it was unsure of. Those are the candidates
  for future validation tooling, and they are the least recoverable information in a run.

| Report | Skill revision tested | Outcome |
|---|---|---|
| [2026-09-02 · arcc step 01](2026-09-02-arcc-step01-compositional-component-analysis.md) | `a949b850` (initial prototype) | 23 findings → `cfbee2a4`: reviewer scope narrowed step→task, per-step `implementation-review` added, plan progress moved to the orchestrator, per-prompt model re-assertion, killed-turn recovery |
