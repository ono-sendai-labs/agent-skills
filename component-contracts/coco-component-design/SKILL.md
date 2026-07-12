---
name: coco-component-design
description: Design and evolve software as components with contracts on their architecturally-visible interfaces (the "coco" component-contract discipline). Use this whenever the user asks to design a system or feature "according to the coco skills" / "using component contracts", when shaping an architecture into components with declared interfaces, dependencies, and authority, or when adding a feature to an existing contract-based codebase (which requires strengthening a contract and rippling the change to dependencies). Plugs into the structured-spec-to-code design phase. Make sure to reach for this skill for any component-boundary, interface-contract, or architecture-shaping design work under this discipline, even if the user doesn't say "coco".
---

# coco-component-design

## Overview

Produce and evolve a **component-and-contract architecture**: a system
decomposed into components, each with a designated interface, a two-tier
contract, declared dependencies, and declared ambient authority. The output is a
design that a reviewer can understand and trust by reading the *contracts*, not
the implementations.

This skill has two modes:

- **Mode A — Design** a new system or a new feature's components from scratch.
- **Mode B — Evolve** an existing contract-based codebase (add a feature by
  strengthening a contract and rippling the required strengthenings down to
  dependencies).

**Before doing anything, read `../coco-references/concepts.md`.** It defines the
component model, the two contract tiers, the contract algebra, and compositional
reasoning. This skill assumes that vocabulary and does not repeat it.

## Relationship to structured-spec-to-code (SSTC)

This is the design-phase hook of the coco discipline. It composes with SSTC:

- When invoked from `interactive-design` (or when the user says "design the
  architecture according to the coco skills"), shape the **detailed design** so
  its components, interfaces, contracts, dependencies, and authority are
  first-class — not an afterthought.
- Hand off to `design-to-plan` / `plan-to-tasks` as usual; the plan should
  sequence components so a component is built after the dependencies whose
  contracts it relies on.
- During implementation, `coco-contract-testing` turns contract clauses into
  tests and builds verified fakes; `coco-contract-review` checks consistency and
  compositional soundness. This skill produces the artifacts those two consume.

If a project's `AGENTS.md` says to design according to the coco skills, treat
that as a standing instruction to apply this discipline to every feature.

## Parameters

- **agents_dir** (optional, default: `.agents`): base directory for SSTC
  artifacts.
- **project_dir** (optional): the design's home, e.g.
  `{agents_dir}/planning/{project_name}`. When composing with SSTC, use the
  directory `interactive-design` created.
- **mode** (optional): `design` or `evolve`. If not given, infer it: a
  greenfield idea or a brand-new feature ⇒ `design`; a request to change or
  extend components that already carry contracts ⇒ `evolve`.

Confirm the mode and the location of any existing interface designation before
proceeding.

---

## Mode A — Design

Work top-down, but let the contracts push back on the decomposition.

### A1. Decompose into components

Identify the components and their responsibilities. For each, decide **what its
interface is** and **designate the interface files** (§1 of concepts). If the
project already uses a component-manifest schema, read that schema and author
manifests in it — **do not invent a manifest format** (§1). If there is no
designation convention yet, establish the lightest thing that works (a simple
manifest, or an "Interface files:" list in each `component-contract.md`) and note
that a project-wide schema should be chosen. Prefer a **tree-shaped** dependency
structure; call out any diamonds or cycles (§6).

Keep each component's public surface **small**. If a component's interface wants
to be large, that is a signal to split it or to move detail into the private
implementation.

### A2. Write the contract, in two tiers

For each component, write the contract to the two homes from §3:

- **Tier 1 — doc comments** on the interface types/methods: the caller's
  need-to-know pre/postconditions, the error outcomes that change caller
  behavior, key invariants, thread-safety.
- **Tier 2 — the contract file(s) the manifest names** (conventionally a
  `component-contract.md` beside the component; may be split, or partly in a
  formal DSL as rigor grows): exhaustive failure/edge behavior, the **rely-set**,
  the clause→test map (left as obligations for the testing skill), fake-fidelity
  notes if applicable, and the declared dependencies + authority with rationale.

Write prose **precise enough to test against** (§7). For each postcondition, ask
"what test would show this?" — if you cannot imagine one, the clause is too
vague.

### A3. Declare dependencies and authority

For each component, list the *other components* it depends on and the *ambient
authority* it exercises. Default to **zero** ambient authority; a component that
needs the filesystem, network, clock, or randomness must declare it, with a
one-line rationale in Tier 2. Treat every declared power as something a reviewer
will scrutinize, so justify it.

### A4. Check compositional soundness (forward)

For each component A, walk its rely-set: for every guarantee A assumes from a
dependency D, confirm D's contract **actually promises** it (§5). Where it does
not, either strengthen D's contract now (D is yours to design) or adjust A's
contract so it no longer over-relies. Do not leave an unmet rely — that is an
unsound design, even if code would happen to work.

### A5. Record and hand off

Produce, in the design:
- the component list with responsibilities and the dependency graph (a small
  diagram or table; C4-component altitude);
- per-component: interface designation (manifest, per the project schema),
  Tier-1 contract sketch, Tier-2 contract-file outline, declared deps +
  authority;
- a short **architecture-decisions** note (ADR-style) for the non-obvious
  boundary and dependency choices, so the *why* is recorded next to the *what*.

Then hand to `design-to-plan`, and flag the per-component testing/fake
obligations for `coco-contract-testing`.

---

## Mode B — Evolve (the ripple)

Use this when a feature requires an existing component to promise *more*. The
mechanism is a **single-orchestrator tree-walk**: one agent holds the whole
picture (contracts are small enough for this) and ripples the change downward.
Do **not** spin up a sub-agent per component by default — that is heavier and
more brittle than it is worth. Reserve sub-agents for the escalation case in B5.

### B1. State the target guarantee

At the component where the feature lands (the **root** of the ripple), write the
**new or strengthened guarantee** the feature needs — as a concrete change to
that component's contract. Classify it with the algebra (§4): is it a
*strengthening* (safe for existing callers) or a *breaking* change (strengthened
precondition / weakened postcondition)? A breaking change must be surfaced
loudly and its callers reviewed.

### B2. Can the root meet it from current dependencies?

Ask: can the root satisfy its new guarantee using only its dependencies'
**current** contracts (its existing rely-set)? 
- **Yes** ⇒ the ripple stops here; only the root's contract (and implementation)
  changes.
- **No** ⇒ determine, for each dependency, the **stronger guarantee** the root
  now needs from it. This is the root's new demand on that dependency.

### B3. Recurse down each affected dependency

For each dependency D that must promise more, treat D as a new root and repeat
B1–B2: express the required strengthening as an edit to D's contract (algebra-
legal), then ask whether D can meet it from *its* dependencies' current
contracts. The recursion terminates at components that can absorb the new
guarantee locally (often leaf components, or wrappers whose backing service
already supports it). Because the structure is tree-leaning, the ripple flows one
way and terminates.

### B4. Emit the contract changeset *before* touching code

Collect every contract edit the ripple produced — across all affected components,
both tiers — into a single **contract changeset**: a reviewable diff of contracts
and rely-sets, with each edit labeled *strengthening* or *breaking*. Present this
for review first. The point (per the rationale doc) is that architectural change
shows up as a small declarative diff *before* implementation, where focused
review belongs. Only after the changeset is agreed do the implementations and
tests follow (via SSTC + `coco-contract-testing`).

### B5. When to escalate to sub-agents

The single-orchestrator walk is the default. Escalate to per-component
sub-agents only when the graph is genuinely too large to hold at once, or when
components are independently owned and the "can you support this?" question needs
a real negotiation with each owner. Even then, keep this skill as the
**orchestrator** that issues each demand, collects each answer, and assembles the
one changeset in B4 — the sub-agents answer local feasibility, they do not each
edit contracts independently.

---

## Anti-patterns to avoid

- **Fat Tier 1.** Implementation detail or exhaustive failure lists leaking into
  interface doc comments. Move it to Tier 2.
- **Unstated rely.** A component's correctness silently depending on a
  dependency's behavior that the dependency does not actually promise. Record
  every rely; check every rely (A4 / B2).
- **Silent breaking change.** Strengthening a precondition or weakening a
  postcondition without labeling it and reviewing callers.
- **Undeclared authority.** Reaching for the filesystem/network/clock without
  declaring it — it defeats the blast-radius guarantee and must surface as an
  architectural change.
- **Editing code before the contract changeset (Mode B).** The declarative diff
  is supposed to come first.
