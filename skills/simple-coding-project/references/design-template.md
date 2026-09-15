# <project>: Design

Status: draft, <YYYY-MM-DD>. Requirement numbers (Rn, Qn, Fn) refer to
[requirements.md](requirements.md).

## 1. Overview

```
ASCII diagram of the main flow: who calls what, where it runs, where state lives.
```

### 1.1 Artifacts

| Binary / package / file | Role |
|---|---|

## 2. <Hardest problem> (R…)

Why it is hard. List what you verified empirically, and say how.

### 2.1 Options considered

| # | Approach | Pros | Cons / risk | Cost |
|---|---|---|---|---|
| A | … | | | |
| **B** | **Chosen** | | | |

**Decision:** B, because …

### 2.2 How it works

Concrete contracts: command lines, JSON examples, invariants, and what fails
closed.

## 3. <Policy / data model / core logic>

Tables and examples of the configuration or rule format.

## 4. <State: stores, file formats, locking>

## 5. Guards / validation

## 6. Logging / audit

Record examples and `jq` queries.

## 7. Execution details

Error messages, exit codes, signals, and edge cases.

## 8. Later milestones (sketch)

How the design accommodates the future requirements.

## 9. Testing

- Unit tests (what is covered where).
- Integration and end-to-end tests: how external dependencies are faked or
  intercepted.
- Security regression cases, as a bulleted list of concrete attacks.

## 10. Repository layout

```
cmd/…            entry points
internal/…       packages, one line each
docs/            requirements, design, status
scripts/         build helpers
examples/        example configs and integration snippets
justfile
```

Also give a config file example here.

## 11. Security findings during implementation

Add an entry whenever implementation reveals a new risk, together with its
mitigation.

## 12. Milestones

| Milestone | Scope |
|---|---|
| **M0** | Skeleton, build, the riskiest core piece with tests |
| **M1** | Main feature set end to end |
| **M2** | Integration with the target environment, verification |
| **Later** | F1…Fn |
