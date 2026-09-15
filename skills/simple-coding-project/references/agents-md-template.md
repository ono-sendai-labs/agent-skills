# <project>: agent guidelines

`CLAUDE.md` is a symlink to this file. Edit `AGENTS.md`.

## What this is

Two to five sentences: what the project does, for whom, and its key
properties.

Start with [docs/requirements.md](docs/requirements.md) and
[docs/design.md](docs/design.md). They are the source of truth for behavior;
update them when behavior changes.

**[docs/status.md](docs/status.md)** tracks implementation progress and next
steps. Read it first, and update it with every change that moves a milestone.

## Layout

- `cmd/<binary>/`: …
- `internal/<pkg>`: …
- `docs/`: requirements, design, status.
- `scripts/`: …
- `test/integration/`: end-to-end tests (`just test-integration`).
- `justfile`: build, lint and test entry points (`just --list`).

## Relationship to <dependency>

Include this section when the project wraps or forks another project: where it
lives, how it is pinned, and the rules for changing it.

## Version control

<!-- For jj repos: -->
This repo uses [jj](https://jj-vcs.github.io/jj/) (colocated git). Use `jj`,
not `git`, for anything that writes.

- `jj st` and `jj log` to inspect.
- `jj commit -m "…"` to commit the working copy. `jj commit <paths> -m "…"`
  commits only those paths.
- `jj describe -m "…"` to set a message; `jj new` to start the next change.
- `jj bookmark set <name> -r @-` to move a bookmark.
- `jj git push -b <name>` to push, and only when asked.
- Never run `git commit`, `git checkout` or `git rebase` here.

<!-- For git repos: say which branch to work on, and that commits and pushes
happen only when asked. -->

Commit messages follow Conventional Commits, for example `feat(scope): …`,
`fix: …`, `docs: …`.

## <Language>

- **Toolchain.** Version, and where it is installed if not on PATH.
- **Checks.** Formatting, vet or lint, and tests before committing
  (`just lint test`).
- **Style.** Idioms that matter in this codebase, for example: stdout stays
  machine-parseable, diagnostics go to stderr, errors fail closed.

## Security invariants (do not regress)

- One bullet per invariant, with the requirement ID where one exists.
