# <project>: Requirements

Status: draft, <YYYY-MM-DD>

## 1. Context

What exists today, what the project builds on, and the gap it fills. Link to
the dependencies and neighboring repos it relies on.

## 2. Goals

- **G1: <short name>.** One or two sentences.
- **G2: …**

## 3. Non-goals (v1)

- Things deliberately out of scope, including the threat-model limits.

## 4. Actors

| Actor | Where | Trust |
|---|---|---|
| … | … | trusted / untrusted |

## 5. Functional requirements

Group by area and number requirements sequentially across the whole document
(R1, R2, …). Use sub-letters (R11a) for requirements inserted later, so
existing references stay valid.

### 5.1 <Area>

- **R1.** Precise, testable statement.
- **R2.** …

### 5.x Security / guards

- **Rn.** Each guard as a requirement (what is rejected, and why).

### 5.y Logging / audit

- **Rn.** Format, location, rotation, and fail-closed behavior.

## 6. Non-functional requirements

- **N1.** Language and deployment.
- **N2.** Performance budget.
- **N3.** Concurrency and platform assumptions.

## 7. Decisions (<YYYY-MM-DD>)

| # | Question | Decision |
|---|---|---|
| Q1 | … | … |

## 8. Open questions

- **Qn.** The question, with a proposed answer.

## 9. Future enhancements

- **F1. <name>.** What it is, how it would work, and what it depends on.
