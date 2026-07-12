# Component Contracts (coco)

A suite of AI agent skills for **component-contract-oriented design**: software
built as components with contracts on their architecturally-visible interfaces.
The suite is a *discipline layer* that rides on top of
[`structured-spec-to-code`](../structured-spec-to-code/) (SSTC) — say "design the
software architecture according to the coco skills" (per-feature, or as a
standing instruction in a project's `AGENTS.md`) to apply it.

## Skills

| Skill | Purpose | SSTC phase it hooks |
|---|---|---|
| **coco-component-design** | Design a system/feature as components + two-tier contracts + declared deps/authority; **evolve** an existing contract codebase via a single-orchestrator ripple. | interactive-design / design-to-plan |
| **coco-contract-testing** | Turn contract clauses into test evidence; build **verified fakes** for stateful wrappers (fake + real pass one shared contract suite). | task-to-code |
| **coco-contract-review** | Check a contract (or proposed changeset) for **adherence** (impl satisfies its own contract) and **compositional soundness** (dependencies' contracts are strong enough — the rely-set is met). | code-task-review / implementation-review |

All three share one vocabulary: **[`coco-references/concepts.md`](coco-references/concepts.md)** —
read it first in any coco workflow. It defines the component model, the two
contract tiers (Tier 1 = caller's need-to-know in doc comments; Tier 2 = the full
contract in the manifest-named contract file, e.g. `component-contract.md`), the
contract algebra (Liskov–Wing: weaker-pre / stronger-post = *stronger*; the
reverse = *breaking*), rely/guarantee compositional reasoning, and DAG-prefer-tree
dependency shape.

## Design principles

- **Not prescriptive about format.** Interface files and contract files are
  *designated by a project-wide manifest schema* (e.g. a textproto in the ARC
  tool). The skills read whatever schema is given; they do not invent one, and
  they work whether or not the ARC conformance tool is present.
- **Contracts are the unit of reasoning.** Small public contracts let a reader
  (human or agent) reason about many components at once without reading
  implementations.
- **Architectural change surfaces first.** Contract changes are emitted as a
  reviewable declarative changeset *before* the code changes.
- **Rigor is a spectrum.** Contracts are prose today; parts may become a formal
  DSL later. The workflows do not depend on formality — only on prose precise
  enough to test against.

## Grounding

Design by Contract (Meyer); behavioral subtyping (Liskov & Wing, TOPLAS 1994);
rely/guarantee compositional reasoning (Jones); contract tests & verified fakes
(Fowler; *Software Engineering at Google* ch. 13); ADRs, the C4 model, and
fitness functions (*Building Evolutionary Architectures*). Project rationale:
`architectural-contracts/docs/rationale-and-concepts.md`.
