---
name: simple-coding-project
description: Start or bootstrap a small coding project end to end. Interview the user on requirements and design, write docs/requirements.md and docs/design.md, scaffold the repo (README, AGENTS.md with a CLAUDE.md symlink, LICENSE/NOTICE, .gitignore, justfile, source layout, docs/status.md), optionally set up GitHub CI, then implement milestone by milestone while keeping status notes current. Use when the user wants to start a new project or tool, turn an idea into a requirements/design doc and a working repo, or says things like "set up the repo", "write a requirements doc and sketch a design", or "create a justfile / AGENTS.md / README".
---

# Simple coding project

Takes a small project from idea to a working, documented repository. The user
stays in charge of requirements and key design decisions. You do the research,
drafting, scaffolding and implementation, and you leave a trail that future
agents can pick up (`docs/status.md`, `AGENTS.md`).

The phases below run in order. Each phase ends with something the user can
review. Don't skip ahead to scaffolding or code before the requirements and
design have been reviewed, unless the user explicitly asks you to.

## Phase 0: Reconnaissance (before asking anything)

Gather what you can yourself, so the interview asks only what you cannot
infer:

- **The repo.** Read what exists: README, LICENSE, `.gitignore`, any code.
  Establish:
  - **VCS.** `.jj` means jj; use jj for every write operation, even when it is
    colocated with git. A plain `.git` means git. Neither means offer to
    initialize.
  - **Remotes.** `jj git remote list` or `git remote -v`. Note whether the repo
    is on GitHub; this matters for CI in Phase 4.
- **Referenced material.** When the user points at neighboring repos, docs or
  tools, read the relevant parts: the CLI surface, config formats, security
  model and extension points. Designs go wrong when they are based on guesses
  about a dependency.
- **Verification.** Where possible, check key assumptions empirically: build
  the dependency, run its CLI, probe edge cases. Record what you verified and
  how, and label the assumptions you could not verify as such.
- **User context.** Check memory, CLAUDE.md or AGENTS.md for the user's
  preferences, such as language, VCS, license, commit style and tooling.

## Phase 1: Requirements interview → `docs/requirements.md`

Interview the user in short rounds of 1–4 related questions. Use the
structured question tool if one is available. Give each question a
recommended default, and prefer concrete options to open-ended prompts. See
[references/interview-guide.md](references/interview-guide.md) for the
question bank.

Cover, as relevant:

- the problem and context;
- actors and trust levels;
- goals and non-goals;
- functional requirements;
- security and threat model;
- constraints: language, deployment, dependencies, platforms;
- observability, such as logging and audit;
- future directions to keep in mind without building them now.

When the user has already written a rich brief, don't re-ask what it answers.
Draft the document directly and put the gaps in **Open questions**, each with
a proposed answer.

Write `docs/requirements.md` from
[references/requirements-template.md](references/requirements-template.md):

- **Numbered IDs:** R1, R2… for requirements; Q1… for open questions; F1… for
  future enhancements. Later docs and code comments refer to them.
- **Resolved questions** move into a **Decisions** table (question → decision)
  rather than disappearing.
- **Deferred ideas** go under **Future enhancements** with enough detail to
  implement later.

## Phase 2: Design → `docs/design.md`

Sketch the design from
[references/design-template.md](references/design-template.md):

- **Overview diagram.** An ASCII data or control flow is fine.
- **Hardest problems first.** For each, weigh 2–5 options in a small table and
  make a **clear recommendation**; don't just survey. Mark the choice as a
  decision once the user agrees.
- **Contracts and formats.** Give concrete examples: config files, file
  formats, CLI usage, JSON records, error messages.
- **A security or failure-mode section** when the project touches
  credentials, sandboxes, or external side effects.
- **Testing strategy, repository layout and milestones** (M0, M1…), each
  milestone small enough to finish and verify in one sitting.

Show the user both documents, then iterate:

- Take their answers into the Decisions table.
- Update the requirements and design docs consistently. Grep both for stale
  references after every change.
- When a decision reverses an earlier approach, rewrite the affected sections
  instead of appending contradictions. A short note on why the alternative
  was rejected is still worth keeping.

Commit the docs when the user is happy, or when they ask.

## Phase 3: Scaffold the repository

Ask once, as one grouped question with defaults taken from Phase 0, about
whatever is still unknown:

- language and toolchain;
- license and copyright holder;
- package or module name;
- whether to use a justfile (default yes).

Then create:

| File | Notes |
|---|---|
| `README.md` | What it is, how it works (short diagram), install, configure, use, develop. Only describe what is implemented. Update it as milestones land. |
| `AGENTS.md` | From [references/agents-md-template.md](references/agents-md-template.md): project summary, layout, VCS notes (jj commands if jj), language conventions, **security invariants**, and a pointer to `docs/status.md`. |
| `CLAUDE.md` | A symlink to `AGENTS.md` (`ln -s AGENTS.md CLAUDE.md`), so every agent reads the same file. |
| `LICENSE`, `NOTICE` | Only if missing. Use the license the user chooses. Match the user's existing NOTICE format if other repos have one. |
| `.gitignore` | Language defaults plus `/bin/` or other build output. |
| `justfile` | From [references/justfile-template.md](references/justfile-template.md): `build`, `fmt`, `lint`, `test`, `test-integration`, `test-all`, `install`, `install-config` (if the tool has a config file), `clean`. Stamp versions via `git describe`, which works in both plain git and colocated jj checkouts. |
| `docs/status.md` | From [references/status-template.md](references/status-template.md): milestone table, what exists, decisions made during implementation, known gaps and next steps, how to verify. |
| `examples/` | Example config files and integration snippets, when the project has them. |
| Source skeleton | Idiomatic layout for the language, for example Go `cmd/` + `internal/`, or Python `src/<pkg>/` + `tests/` with uv. |

Run `just --list` and `just lint test` to confirm the scaffold works before
committing.

## Phase 4: CI (ask; don't assume)

If the repo has a GitHub remote, or the user plans one, **ask whether they
want GitHub Actions CI**. If yes, add `.github/workflows/ci.yml` from
[references/github-ci-template.md](references/github-ci-template.md). It
should:

- run the same entry points as local development (`just lint test`);
- install `just` and the toolchain;
- leave out integration tests that need credentials or unusual host features,
  or put them in a separate, manually triggered job;
- pin action versions.

For non-GitHub remotes, mention that CI can be set up later and move on.

## Phase 5: Implement by milestone

For each milestone:

1. **Plan the interfaces first.** Types and function signatures for each
   package, so work can be split without conflicts.
2. **Write the core yourself,** meaning the parts where subtle mistakes are
   costly: the security-relevant flow and cross-cutting orchestration.
3. **Fan out self-contained pieces to subagents** on cheaper models when
   subagents are available and the user is fine with it. Good candidates are
   leaf packages with a pinned API, test suites and docs. Give each subagent:
   - the exact API spec and the docs to read;
   - a list of the only files it may touch, since other agents run
     concurrently;
   - instructions not to commit;
   - the verification commands to run;
   - a request to report deviations and bugs prominently.
4. **Review every subagent's result.** Read the code, rerun its tests, and
   check its claims against the source. Don't relay reports unverified.
   Subagent reviews and tests regularly find real bugs in *your* code, so ask
   them to look adversarially.
5. **Run the full gate** (`just test-all` or equivalent) before committing.
6. **Commit in logical changes** using the repo's VCS and commit style, for
   example Conventional Commits. With jj, `jj commit <paths> -m …` commits a
   subset while other work is in progress.
7. **Update `docs/status.md`** in the same change, plus the README,
   requirements and design wherever behavior or decisions changed.

When the user steps away and asks you to continue autonomously:

- Make reasonable decisions and record each one, with its rationale, in
  `docs/status.md` and the design doc.
- Stop before anything outward-facing: pushing, publishing, or sending
  anything to external services.

## Conventions that apply throughout

- **Research before asking.** Check the repo and referenced material before
  asking the user anything.
- **Recommend.** When presenting options, pick one and say why.
- **Verify empirically.** When a claim can be tested cheaply, test it and say
  it was verified.
- **Keep docs, code and status consistent.** After edits, grep for stale
  terms such as renamed binaries, old flags and superseded decisions.
- **Never push, publish, or change remote state without explicit approval.**
- **End-of-session summary.** Say what was built, what was verified and how,
  which decisions were made on the user's behalf, which bugs were found, and
  what remains open.
