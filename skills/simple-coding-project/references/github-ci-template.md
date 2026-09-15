# GitHub Actions CI template

Add CI only after the user agrees. It should run the same `just` recipes
developers run locally. Before adding the file, check the current major
versions of the actions used, and pin them.

## Go

`.github/workflows/ci.yml`:

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - uses: extractions/setup-just@v2
      - run: just lint
      - run: just test

  # Optional: integration tests that need no credentials or special host features.
  integration:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - uses: extractions/setup-just@v2
      - run: just test-integration
```

## Python (uv)

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v6
      - uses: extractions/setup-just@v2
      - run: uv sync --locked
      - run: just lint
      - run: just test
```

## Considerations to raise with the user

- **Dependencies outside the repo.** Sibling checkouts or private forks need an
  extra `actions/checkout` step with `repository:` and `path:`, and possibly a
  token. Otherwise, leave those jobs out of CI.
- **Credentials.** Tests that need real credentials belong in a separate job
  with `workflow_dispatch` or environment secrets, never on pull requests from
  forks.
- **Host features.** Sandboxing or user namespaces may not be available on
  hosted runners. Skip those tests in CI and document the gap in
  `docs/status.md`.
- **Matrix builds** (OS or toolchain versions) only if the project promises
  that support.
