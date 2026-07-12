# Component-Contract Concepts

*Shared reference for the `coco-*` skills. Read this once at the start of any
coco workflow; the individual skills assume the vocabulary defined here.*

This file defines **what** a component and a contract are and **where** each part
is recorded. The individual skills define the **workflows** (design, testing,
review) that operate on them.

## Table of contents

1. [The component model](#1-the-component-model)
2. [What a contract is](#2-what-a-contract-is)
3. [Where each part of the contract lives](#3-where-each-part-of-the-contract-lives)
4. [The contract algebra — what "stronger" means](#4-the-contract-algebra)
5. [Compositional reasoning — rely and guarantee](#5-compositional-reasoning)
6. [Dependency shape — DAG, prefer tree](#6-dependency-shape)
7. [Rigor is a spectrum](#7-rigor-is-a-spectrum)
8. [Glossary and sources](#8-glossary-and-sources)

---

## 1. The component model

The unit is the **component** (the C4 "component", enriched). A component is:

- **A collection of code units exposing a well-defined interface.** The specific
  files holding that interface are **designated** somehow. Do **not** assume any
  particular tool or format: the designation might be a manifest/textproto, a
  Bazel rule, or simply a heading in the component's docs ("Interface files:
  ..."). The coco skills read *whatever* designation exists; if none exists, the
  first job is to establish one (even a prose list in `CONTRACT.md`).
- **The owner of a private implementation** that nothing outside may call into.
- **A declarer of its dependencies** — the *other components* it uses, named at
  component granularity, not file or symbol granularity.
- **A declarer of its ambient authority** — the system powers (filesystem,
  network, clock, randomness…) it exercises. A component that declares *none* is
  self-sandboxed; treat that as the desirable default and flag any new authority
  as an architectural change.

**Component manifests and their schema.** Most projects adopt a single manifest
format/schema, applied project-wide, that declares each component: which source
files make up its interface, which additional file(s) hold its contract, its
dependencies, and its authority. (In the ARC tool, for example, the manifest is
a textproto that lists the interface source files and one or more further files
that carry the contract.) **Assume the schema is given to you as a reference —
do not invent one on the fly.** If the project has a manifest schema, read it and
follow it; if it does not yet, establish the lightest designation that works and
flag that a schema should be chosen, rather than improvising a format that later
work would have to unpick.

The **architecturally-visible interface** is exactly what the designated
interface files expose. The contract attaches to *that* surface — never to
private implementation details.

> This model, and the rationale for it, is developed in
> `architectural-contracts/docs/rationale-and-concepts.md` if available. The
> coco skills work whether or not the ARC conformance tool is present; the tool
> mechanically enforces the structure, but the design discipline stands on its
> own.

## 2. What a contract is

A **contract** is the design-by-contract specification attached to a component's
interface: **preconditions** (what a caller must guarantee before calling),
**postconditions** (what the component guarantees on return, for both success
and failure), and **invariants** (what stays true across calls). Together with
the signatures, the contract is meant to be *the entire thing a reader needs* to
use the component or to reason about code that depends on it — without reading
the implementation.

The responsibility split (Meyer): the **caller** is responsible for meeting
preconditions; the **component** guarantees postconditions *provided* its
preconditions were met. A precondition violation is the caller's bug; a
postcondition violation is the component's bug. Every contract clause should be
assignable to one side of this line.

**Design pressure: keep contracts small.** A small interface + contract is what
lets a reader (human or agent) hold *many* components' contracts at once without
dragging in implementation. When a contract grows large, treat it as a smell —
usually the component is doing too much, or implementation detail has leaked into
the contract.

## 3. Where each part of the contract lives

Not everything belongs in the same place. Split the contract into two tiers:

**Tier 1 — the public contract, in doc comments on the interface.** The
caller's need-to-know: the preconditions they must satisfy, the postconditions
they can rely on (success *and* the error outcomes that change what a caller
does), the key invariants, and concurrency/thread-safety guarantees. Keep this
tight — it is read every time someone uses the component, and it competes for
context-window space.

**Tier 2 — the full contract, in the contract file(s) the manifest names.**
Everything a *reviewer or maintainer* needs but a caller does not. The physical
home is whatever the project's manifest designates — conventionally a single
`component-contract.md` beside the component, but it may be **split across several
files**, and parts may be written in a **more formal DSL** rather than Markdown
(e.g. a precondition/postcondition specification language) as the project's rigor
grows. Follow the project's convention; the tiers below are about *what content*
goes where, not about mandating a specific filename. Tier 2 holds:

- exhaustive failure and edge-case behavior (every error path, ordering,
  idempotency, resource limits);
- the **rely-set** — which guarantees of which dependencies this component leans
  on (see §5);
- the **clause → test map** — which tests provide evidence for which contract
  clause (see the testing skill);
- **fake-fidelity notes** — if the component has a fake, the shared contract
  suite that both fake and real pass (see the testing skill);
- **authority/capability rationale** — why each declared power is needed.

| Content | Tier 1 (doc comment) | Tier 2 (contract file) |
|---|---|---|
| Preconditions a caller must meet | ✅ | ✅ (may elaborate) |
| Success postconditions | ✅ | ✅ |
| Error outcomes that change caller behavior | ✅ | ✅ |
| Exhaustive failure / edge behavior | — | ✅ |
| Key invariants, thread-safety | ✅ | ✅ |
| Rely-set (depended-on guarantees) | — | ✅ |
| Clause → test evidence map | — | ✅ |
| Fake-fidelity notes | — | ✅ |
| Declared dependencies & authority + rationale | — | ✅ |

Rule of thumb: **if a caller needs it to call correctly, it is Tier 1. If only a
maintainer or reviewer needs it, it is Tier 2.** When in doubt, prefer Tier 2 —
keeping Tier 1 lean is the whole point.

## 4. The contract algebra

"Evolving a contract" is not free-form editing. Contracts form a lattice, and
the legal moves come from **behavioral subtyping** (Liskov & Wing). A new
contract is **stronger** than (a valid replacement for) an old one iff it:

- **weakens (or keeps) preconditions** — demands no more of callers than before;
- **strengthens (or keeps) postconditions** — promises callers at least as much;
- **preserves invariants and history properties.**

A **stronger** contract is a *safe* change for existing callers: anything that
worked against the old contract still works. A change that strengthens a
precondition or weakens a postcondition is **breaking** — it can invalidate
existing callers and must be surfaced and reviewed as such.

This algebra is the backbone of two skills:
- **Fakes** (testing) must be behavioral subtypes of the real component — same
  contract, so either can stand in.
- **Evolution** strengthens a component's contract and computes what *stronger*
  guarantees it therefore needs *from* its dependencies.

## 5. Compositional reasoning

To establish that component **A** satisfies its contract, use **A**'s own
implementation plus the **contracts** — never the implementations — of the
components A depends on. This is **rely-guarantee** reasoning (Jones): A's
guarantee (its postconditions) rests on a **rely-set** — the specific guarantees
it assumes from its dependencies.

**Soundness condition:** for every dependency D that A relies on, the guarantee A
assumes from D must be *actually promised* by D's current contract. If A leans on
something D does not guarantee, the composition is **unsound** — A's contract is
not justified, regardless of whether the code happens to work today.

Two skills run this same check in opposite directions:
- **Review** runs it *backward*: given the code as written, is every rely
  actually met by the depended-on contract?
- **Evolution** runs it *forward*: to make A promise more, what must its
  dependencies be asked to promise?

Record each component's rely-set explicitly in Tier 2. It is the seam that makes
whole-system reasoning tractable: check one component at a time, against
contracts, never unfolding the whole call graph.

## 6. Dependency shape

Dependencies form a **directed acyclic graph** in general, but **prefer a
tree**. A tree keeps the ripples of a contract change flowing in one direction
(downward, from dependent to dependency) and avoids negotiation cycles. Where
cycles are unavoidable, push them to the **highest** level of the module
structure, where the abstraction is small enough to hold in mind at once. When
designing or evolving, treat a new cycle — or a new edge that turns a tree into a
diamond — as a structural change worth calling out.

## 7. Rigor is a spectrum

Contracts are **incremental, partial, and of mixed rigor.** Today they are
written in **prose**. Later, parts may become formal predicates (runtime-checked
assertions, then static/formal verification). A single contract may mix formal
and informal clauses. None of the coco workflows depend on formality: the
contract is the *unit of reasoning* whether prose or predicate, and it can be
strengthened in place over time. Write prose that is *precise enough to test
against* (§ the testing skill) — that is the practical bar, not formal syntax.

## 8. Glossary and sources

| Term | Meaning |
|---|---|
| **Component** | Code units with a designated interface, private implementation, declared dependencies and authority. |
| **Public contract (Tier 1)** | The caller's-eye pre/post/invariants, in interface doc comments. |
| **Full contract (Tier 2)** | The maintainer's-eye contract in the manifest-named contract file(s) (conventionally `component-contract.md`, possibly split or in a formal DSL): exhaustive behavior, rely-set, test map, fake notes, authority rationale. |
| **Rely-set** | The specific dependency guarantees a component assumes in order to meet its own. |
| **Stronger contract** | Weaker preconditions, stronger postconditions, preserved invariants (Liskov–Wing). A safe replacement. |
| **Breaking change** | A contract edit that strengthens a precondition or weakens a postcondition. |
| **Verified/faithful fake** | An in-memory stand-in that passes the same contract test suite as the real component. |

Sources: Meyer, *Design by Contract* (Eiffel); Liskov & Wing, *A Behavioral
Notion of Subtyping* (TOPLAS 1994); Jones, *rely/guarantee* compositional
reasoning; Fowler, *ContractTest* & *Consumer-Driven Contracts*; *Software
Engineering at Google*, ch. 13 (test doubles / fakes); Ford et al., *Building
Evolutionary Architectures* (fitness functions); the C4 model; and the project's
own `rationale-and-concepts.md`.
