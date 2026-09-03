# awo

Skills for driving an autonomous implementer ⇄ reviewer loop over a
`structured-spec-to-code` implementation plan — either through the
[agent-workflow-orchestrator](https://github.com/ono-sendai-labs/agent-workflow-orchestrator)
(`awo`) binary, or directly over [`acpx`](https://github.com/openclaw/acpx) sessions.

## Skills

| Skill | Purpose | Interactive? |
|---|---|---|
| **awo-orchestrator** | Drive an implementation plan to completion: per step generate tasks, per task run the awo inner loop, bookmark and log; repair escalated specs in an auditable commit and resume in rework mode | No (stops and asks at the auto-fix boundary) |
| **awo-acpx** | *Prototype.* Same outer loop, but the inner loop runs over long-lived `acpx` sessions driven by the orchestrating agent: the implementer session spans a task, the reviewer session spans a step | No (stops and asks at the auto-fix boundary) |

## Layering

```
awo-orchestrator skill        outer loop: plan → steps → tasks, bookmarks, work log,
        │                                 escalation handling (spec repair + resume)
        ▼
awo binary (run / rework)     inner loop: implementer ⇄ reviewer, fresh session per round
        │
        ▼
structured-spec-to-code       producer skills: task-to-code, code-task-review
```

```
awo-acpx skill                outer loop AND inner loop, driven by the orchestrating agent
        │                     deterministic validation replaced by judgement
        ▼
awo-acpx/scripts/             the acpx surface: session open/prompt/progress/close,
        │                     change-id resolution. Encodes what the raw CLI gets wrong.
        ▼
acpx sessions                 long-lived: implementer per task, reviewer per task
        │
        ▼
structured-spec-to-code       the same producer skills
```

The `scripts/` layer exists because two evaluation runs found acpx's exit codes and status
output reporting the opposite of the truth — a `--timeout` that returns success while the
turn keeps running, a `status` that says `running` for a dead turn. Those assertions belong
somewhere executable and re-testable against a new acpx release, not in prose. See
[`awo-acpx/scripts/README.md`](awo-acpx/scripts/README.md).

The producer skills live in `../structured-spec-to-code/`. Their escalation contract — the
`escalated` verdict/status and the shared reason taxonomy (`spec_defect`, `spec_ambiguity`,
`unrecoverable_state`, `blocked_dependency`) — is what both skills route on; see
`code-task-review/report-schema.md` and `task-to-code/result-schema.md`.

## Design principle

An escalated task is repaired at the **specification**, never in the code. The orchestrator
authors a spec+task-only commit and interposes it below the implementation, then has the
implementer reconcile its own work against the corrected task. Spec and code stay in sync, and
both the correction and the reconciliation are separately reviewable commits.

The two skills differ only in how the reconciliation is delivered. `awo-orchestrator` must
author a synthetic `changes_requested` review and resume the binary with `awo rework
--seed-review …`, because its implementer is a fresh session that knows nothing. `awo-acpx`
sends one prompt to the implementer session that is still holding the work.

## What `awo-acpx` is testing

1. **Does session longevity pay?** A cold implementer re-reads the task, re-explores the
   codebase, and re-derives its own reasoning on every rework round. A warm one does not.
2. **Is a step-scoped reviewer better or worse?** It sees cross-task drift no per-task reviewer
   can — but it is no longer context-independent per task, and its context grows all step.
3. **Which of awo's deterministic checks actually needed to be deterministic?** `awo-acpx`
   replaces them with the orchestrating agent's judgement and records where that goes wrong.

Its `work_log` is the experiment's output, not just an audit trail.
