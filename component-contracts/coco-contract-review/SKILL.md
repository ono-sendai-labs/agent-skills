---
name: coco-contract-review
description: Review a component's contract — or a proposed contract change — for consistency in a coco component-contract codebase. Checks two things: (1) that the implementation actually satisfies its own contract, and (2) compositional soundness — that the contracts of the components it depends on are strong enough to justify its own guarantees (its rely-set is met). Also reviews a contract changeset from an evolution ripple for correct strengthening/breaking classification and completeness. Use when reviewing a contract, a proposed contract, or a commit that touches contracts; plugs into the structured-spec-to-code review phase (code-task-review, implementation-review). Reach for this whenever component contracts need to be checked for internal or compositional consistency.
---

# coco-contract-review

## Overview

A contract is a claim; this skill checks the claim holds. It reviews for two
kinds of consistency:

1. **Adherence** — does the component's **implementation satisfy its own
   contract**?
2. **Compositional soundness** — are the **dependencies' contracts strong enough**
   to justify this component's guarantees, i.e. is every entry in its rely-set
   actually promised by the depended-on contract?

It also reviews a **proposed** contract or a **contract changeset** (from a
`coco-component-design` Mode-B ripple) *before* implementation — the cheapest
place to catch an inconsistency.

**Before doing anything, read `../coco-references/concepts.md`** for the component
model, the two contract tiers, the contract algebra, and rely/guarantee
reasoning. This skill is the compositional check of §5 run **backward** (given
the code/contract as written, is every rely met?), where `coco-component-design`
runs it forward.

## Relationship to structured-spec-to-code (SSTC) and the ARC tool

This is the review-phase hook of the coco discipline. It composes with SSTC's
`code-task-review` (per-commit) and `implementation-review` (whole-plan): those
skills check task/plan conformance and code quality; this one adds the
contract-specific judgements below. When run inside an SSTC review, fold these
findings into that review's report using its existing severity vocabulary rather
than inventing a parallel report.

This skill does **not** assume the ARC conformance tool is present. Where the
tool exists, it mechanically enforces the *structural* facts (no calls into
private implementation, declared-dependencies-only, interface = designated
files); trust those results and spend review effort on the *behavioral*
judgements below, which the tool cannot make. Where the tool is absent, do a
best-effort structural read from the manifest, but focus on the parts that need
human/agent judgement regardless.

## Parameters

- **component** (required): the component (or proposed contract/changeset) under
  review — interface files, contract file(s), implementation, and (if present)
  its manifest. Resolve these via the project's manifest schema if one exists.
- **agents_dir** (optional, default: `.agents`): SSTC artifact base, if composing
  with SSTC.

---

## Review dimension 1 — Adherence (does the impl satisfy its own contract?)

Reason about the implementation against **its own contract only** — you may
assume dependencies honor *their* contracts (that is modular reasoning; dimension
2 checks that assumption is warranted).

- **Test evidence.** Is each testable clause backed by a test in the clause→test
  map (`coco-contract-testing`)? An un-evidenced postcondition/invariant is a
  finding — the claim is unverified. An **orphan test** asserting behavior the
  contract does not promise is also a finding: either the contract is incomplete,
  or the test over-specifies.
- **Reasoning gaps for un-tested clauses.** For clauses not (yet) covered by
  tests, reason directly: does the implementation plausibly establish the
  postcondition on every path, including error paths? Flag any path that can
  return while violating a postcondition or invariant.
- **Tier coherence.** Do Tier 1 (doc comments) and Tier 2 (contract file) agree?
  Tier 1 must be a faithful *summary* of Tier 2 for callers — never promise in
  Tier 1 something Tier 2 contradicts, and never let implementation detail leak
  up into Tier 1.
- **Responsibility split.** Is each clause on the right side of the caller/
  component line? A "postcondition" that is really a demand on the caller is
  mislabeled and misleads reasoning.
- **Testability.** Flag clauses too vague to test; a contract that cannot be
  tested cannot be trusted (concepts §7). Recommend making them precise.
- **Declared authority.** Does the implementation reach only the ambient
  authority the contract declares? Undeclared authority is a
  soundness-*and*-security finding.

## Review dimension 2 — Compositional soundness (are dependencies strong enough?)

This is the crux. Walk the component's **rely-set** (Tier 2): for each guarantee
it assumes from a dependency D, confirm **D's current contract actually promises
it.**

- **Unmet rely.** The component leans on behavior D does not guarantee (D's
  contract is silent on it, or weaker than assumed). This is a **critical**
  finding: the component's own contract is *not justified*, even if the code
  works against D's current implementation — because D is free to change anything
  its contract does not promise. The fix is to strengthen D's contract (which
  ripples — hand back to `coco-component-design` Mode B) or to weaken the
  component's reliance.
- **Implicit rely.** The implementation depends on some behavior of D that is
  *not recorded* in the rely-set at all. Surface it: add it to the rely-set, then
  check it like any other (it may turn out unmet).
- **Strength, not just presence.** A rely can be *present but too weak*: D
  promises "returns a value" where the component assumed "returns a *sorted*
  value." Check the strength of each promised guarantee, not merely that D
  mentions the operation.
- **Fake fidelity.** If the component's tests use a dependency's fake, confirm the
  fake is a **verified fake** (passes the same shared suite as the real impl,
  per `coco-contract-testing`). Tests built on an unverified fake are evidence
  about the fake, not about the real dependency.

## Reviewing a proposed contract or changeset (before code)

When the input is a proposed contract or a Mode-B **contract changeset**, add:

- **Correct classification.** Is each edit correctly labeled *strengthening*
  (weaker pre / stronger post / preserved invariants) vs **breaking**
  (strengthened pre / weakened post)? A breaking change mislabeled as safe is a
  critical finding. Confirm breaking changes name their affected callers.
- **Ripple completeness.** Is the changeset **closed**? Every new demand the
  ripple places on a dependency must appear as a corresponding strengthening of
  *that dependency's* contract in the same changeset. A demand with no matching
  dependency edit means the ripple was cut short — the design is not yet sound.
- **Termination and shape.** Did the ripple terminate (no unmet demand left
  dangling), and did it introduce any new cycle or diamond worth flagging
  (concepts §6)?

---

## Output

Produce findings, each with: a **severity** (reuse the host review's vocabulary
when embedded in an SSTC report; otherwise `critical` / `important` /
`suggestion`), the **dimension** (adherence / soundness / changeset), a
**contract clause or rely-set entry reference**, and a concrete description of
the inconsistency and the smallest fix. Lead with the unmet-rely and
mislabeled-breaking-change findings — those are the ones that make the whole
modular-reasoning story unsound if missed.

Do not block on findings — record them. Route contract-strengthening fixes back
to `coco-component-design` (they ripple); route missing-test findings to
`coco-contract-testing`.
