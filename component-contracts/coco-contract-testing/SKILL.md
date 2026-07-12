---
name: coco-contract-testing
description: Turn a component's contract into a test suite that provides evidence the implementation satisfies it, and build verified fakes for components that wrap stateful services (storage, RPCs). Use this during implementation of a coco component-contract codebase — when writing tests for a component whose behavior is specified by a contract, when a contract clause needs test evidence, or when a component needs an in-memory fake that must stay faithful to the real implementation. Plugs into the structured-spec-to-code implementation phase (task-to-code). Reach for this whenever contract clauses need to become tests or a fake must be shown to match the real thing.
---

# coco-contract-testing

## Overview

A contract is only trustworthy if there is **evidence** the implementation obeys
it. This skill produces two kinds of evidence:

1. **Contract tests** — tests that exercise each testable contract clause, so the
   informal (prose) contract is backed by executable checks.
2. **Verified fakes** — for components that wrap stateful services, an in-memory
   stand-in demonstrated faithful by passing the *same* contract test suite as
   the real implementation. (Tests are evidence, not proof — see the note on
   what "verified" can and cannot mean in Part 2.)

**Before doing anything, read `../coco-references/concepts.md`** for the component
model, the two contract tiers, and the contract algebra. This skill assumes that
vocabulary.

## Relationship to structured-spec-to-code (SSTC)

This is the implementation-phase hook of the coco discipline. It runs while a
component is being built (inside or alongside `task-to-code`): the design skill
left a Tier-2 **clause→test map** as an obligation; this skill discharges it. The
evidence it produces is what `coco-contract-review` later checks.

## Parameters

- **component** (required): the component under test — its interface files, its
  contract file(s), and its implementation. Locate these via the project's
  manifest if one exists.
- **agents_dir** (optional, default: `.agents`): SSTC artifact base, if composing
  with SSTC.

---

## Part 1 — Contract tests as evidence

### 1. Enumerate the testable clauses

Read the contract (both tiers). List every clause that makes a checkable claim:
each **postcondition** (success and error), each **invariant**, each stated
**edge/failure behavior**, and the **boundary** of each **precondition** (what
happens right at the edge of what the caller must guarantee). Prose that is too
vague to test is a finding — feed it back: the contract should be made *precise
enough to test against* (concepts §7), not tested around.

### 2. Write a test per clause, and map them

Write tests that exercise each clause. Maintain the **clause→test map** in the
Tier-2 contract file: each contract clause names the test(s) that evidence it,
and each contract test names the clause it covers. This map is what lets a
reviewer confirm coverage without re-deriving it, and what surfaces an
un-evidenced clause (a claim with no test) or an orphan test (a test asserting
behavior the contract never promised — often a sign the contract is incomplete).

Test the contract, **not the implementation's internals**. A contract test
should assert only what the *contract* promises, so it survives any
implementation change that still honors the contract. If a test has to reach into
private state or mirror the algorithm, it is testing the wrong layer.

### 3. Respect the responsibility split

Postconditions and invariants are the component's obligation — test that they
hold whenever the preconditions were met. Preconditions are the *caller's*
obligation — so do **not** write tests demanding well-defined behavior when a
precondition is violated, unless the contract explicitly promises a defined
response (e.g. "returns InvalidArgument"). Testing beyond the contract quietly
strengthens it; if that behavior is actually wanted, add it to the contract
first.

### 4. Cover the rely-set boundary

The component's own tests may assume its dependencies honor their contracts (that
is the point of modular reasoning). Use test doubles for dependencies that stand
in for their *contracts*. If a dependency has a **verified fake** (Part 2), use
that fake — it is the faithful stand-in.

---

## Part 2 — Verified fakes for stateful wrappers

When a component wraps a **stateful service** — local storage, a database, an RPC
backend — depending components need a fast, deterministic **in-memory fake** for
their own unit tests. But a fake is only safe if it behaves like the real thing;
a fake that has drifted from the real implementation makes every test that uses
it lie.

The discipline (Fowler's contract tests; *SWE at Google* ch. 13):

### 5. Author the fake as a behavioral subtype

The fake and the real implementation must satisfy the **same contract** — the
fake is a Liskov–Wing behavioral subtype of the component (concepts §4). For any
input, the fake must produce the same observable outcome and state change the
contract promises. It may take shortcuts *invisible through the contract* (in-
memory maps instead of SQL), but it must not weaken any postcondition or add
preconditions.

### 6. Run one shared contract suite against both

Write the contract tests from Part 1 as a **single suite parameterized over the
implementation under test**, and run it against **both** the fake and the real
implementation:
- against the **fake** — fast, runs in every unit-test cycle;
- against the **real** implementation — as an integration test (it may need the
  actual service, so it can run less often, on the service's change rhythm).

If both pass the same suite, the fake is a **verified fake**: depending
components can use it with confidence. When the suite passes on the fake but fails
on the real implementation (or vice versa), that gap *is* the drift the pattern
exists to catch — resolve it before shipping.

**What "verified" can and cannot mean.** A shared suite passing on both is strong
evidence they agree, but tests are necessarily incomplete — passing is necessary,
not sufficient. Where a contract clause resists exhaustive testing (a subtle
ordering guarantee, a concurrency invariant), confirm by *review* that the fake
matches the real behavior there too; do not treat a green suite as proof the fake
is faithful in every respect the contract promises.

### 7. Record the fake in the contract

Note in the Tier-2 contract file that the component has a verified fake, where it
lives, and which shared suite verifies both. That tells depending components the
fake exists and is trustworthy, and tells a reviewer where the fidelity evidence
is.

**Is the fake part of the interface?** It sits on the boundary: the contract
*names* it (so in that sense it belongs to the component's public surface), yet
it is test code that production callers must never instantiate. If the project's
build system can mark it test-only (e.g. Bazel `testonly = 1`), that
mechanically keeps production code from depending on it, and it is safe to list
the fake among the component's designated interface files. Absent such a
mechanism, do **not** add the fake to the production interface designation —
keep it in test-only sources — but still record its existence and location in
the Tier-2 contract so depending components can find it. Follow whatever the
project's manifest convention says about test-only interface files; if it says
nothing, treat the fake as test code and reference it from the contract rather
than promoting it into the production interface.

---

## What "done" looks like

- Every testable contract clause has at least one test, recorded in the
  clause→test map; no un-evidenced clauses and no orphan tests.
- Tests assert the contract, not implementation internals.
- Any stateful-wrapper component has a verified fake that passes the same shared
  contract suite as the real implementation, and the contract records it.
- Vague, untestable clauses were sent back to `coco-component-design` to be made
  precise, not silently worked around.
