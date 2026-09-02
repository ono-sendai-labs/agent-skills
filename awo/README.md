# awo

Skills for driving the [agent-workflow-orchestrator](https://github.com/ono-sendai-labs/agent-workflow-orchestrator) (`awo`) binary.

## Skills

| Skill | Purpose | Interactive? |
|---|---|---|
| **awo-orchestrator** | Drive an implementation plan to completion: per step generate tasks, per task run the awo inner loop, bookmark and log; repair escalated specs in an auditable commit and resume in rework mode | No (stops and asks at the auto-fix boundary) |

## Layering

```
awo-orchestrator skill        outer loop: plan → steps → tasks, bookmarks, work log,
        │                                 escalation handling (spec repair + resume)
        ▼
awo binary (run / rework)     inner loop: implementer ⇄ reviewer, up to max-rework-rounds
        │
        ▼
structured-spec-to-code       producer skills: task-to-code, code-task-review
```

The inner loop's producer skills live in `../structured-spec-to-code/`. Their escalation
contract — the `escalated` verdict/status and the shared reason taxonomy (`spec_defect`,
`spec_ambiguity`, `unrecoverable_state`, `blocked_dependency`) — is what this skill routes
on; see `code-task-review/report-schema.md` and `task-to-code/result-schema.md`.

## Design principle

An escalated task is repaired at the **specification**, never in the code. The orchestrator
authors a spec+task-only commit, interposes it below the implementation, and restarts awo
with an injected review so the implementer reconciles its own work. Spec and code stay in
sync, and both the correction and the reconciliation are separately reviewable commits.
