# Interview guide

Use these questions as a menu, not a script. Ask only what the brief and your
own reconnaissance leave open, in rounds of 1–4 related questions. Give each
question a recommended default ("Recommended: …"), and prefer multiple choice
where the answer space is small.

## Requirements

**Problem and context**
- What problem does this solve, and for whom? What happens today without it?
- What existing tools, repos or services does it wrap, extend or integrate
  with? Which versions?

**Actors and trust**
- Who or what invokes it: a human, an agent, CI, another service?
- Which of those actors are trusted? What is the threat model? For example:
  "agent is untrusted, host user and config author are trusted".

**Goals and non-goals**
- What must the first version do? What is explicitly out of scope for now?
- What is planned for later that the design should accommodate but not build?

**Functional details**
- What is the primary workflow, end to end? Ask for a concrete example session.
- Inputs and outputs: CLI surface, config file, file formats, APIs.
- Which operations are dangerous or irreversible, and how should they be
  gated?
- What should the defaults be (TTLs, scopes, paths)?

**Operational**
- Logging and auditing: what must be recorded, in what format, with what
  retention or rotation?
- How is it deployed or installed? Single binary, `uvx`, container?
- Credentials: where do they come from? Any custom auth helpers?

**Constraints**
- Language and toolchain preferences, and why? For example: easy deployment
  favors Go; quick scripting favors Python with uv.
- Supported platforms, performance budgets, dependency restrictions.

## Design

- Which part is hardest or riskiest? Present options with a recommendation.
- Where might behavior drift from a dependency (parsers, schemas, versions)?
  How do we keep them consistent? Examples: code generation, a runtime schema,
  asking the dependency itself, or forking it.
- Is carrying a fork of a dependency acceptable if upstream doesn't take a
  patch? Should we track a released tag or main?
- What must fail closed? What is acceptable to fail open?

## Repository and process

- VCS: jj or git? Commit style, for example Conventional Commits? Who pushes?
- License and copyright holder, if not already present.
- justfile targets beyond the defaults? An install location?
- If the repo is on GitHub: set up GitHub Actions CI? Which checks? Should
  integration tests run in CI?
- May subagents on cheaper models do parts of the implementation?
- Where should status notes live? Default: `docs/status.md`.

## Recording answers

- Resolved questions go into the requirements doc's **Decisions** table as
  question → decision.
- Deferred ideas go under **Future enhancements** (F1, F2…) with enough detail
  to implement later.
- Anything the user leaves open stays in **Open questions** with a proposed
  answer.
