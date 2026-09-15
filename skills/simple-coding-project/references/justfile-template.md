# justfile templates

These are conventions, not a script. Keep recipe comments to one line each,
because `just --list` shows only the comment line directly above a recipe.
Stamp versions with `git describe`, which works for plain git and colocated jj
checkouts alike.

## Go

```just
# <project> developer recipes. Run `just --list` to see all recipes.

# The Go toolchain may live outside PATH on dev machines.
export PATH := env_var('HOME') + "/.local/go/bin:" + env_var('PATH')

install_dir := env_var('HOME') + "/.local/bin"
config_file := env_var_or_default('XDG_CONFIG_HOME', env_var('HOME') + "/.config") + "/<project>/config.yaml"

# Build stamp from git (works for plain git and colocated jj checkouts).
version := `git describe --always --dirty --abbrev=12 2>/dev/null || echo dev`

# Build binaries into bin/
build:
    go build -ldflags "-X main.version={{version}}" -o bin/ ./cmd/...

# Format Go sources
fmt:
    gofmt -w .

# Check formatting and run go vet
lint:
    test -z "$(gofmt -l .)" || (gofmt -l . && exit 1)
    go vet ./...

# Run unit tests
test:
    go test ./...

# Run integration tests
test-integration: build
    go test -tags integration -count=1 ./test/integration/...

# Lint, unit tests and integration tests
test-all: lint test test-integration

# Install binaries to ~/.local/bin and create the config from the example if missing
install: build
    install -d {{install_dir}}
    install -m 0755 bin/* {{install_dir}}/
    @just install-config

# Create the config file from examples/config.yaml unless it already exists
install-config:
    #!/usr/bin/env bash
    set -euo pipefail
    cfg="{{config_file}}"
    if [[ -e "$cfg" ]]; then echo "config exists, leaving it unchanged: $cfg"; exit 0; fi
    install -d -m 0700 "$(dirname "$cfg")"
    install -m 0600 examples/config.yaml "$cfg"
    echo "created $cfg from examples/config.yaml; edit it before use"

# Remove build output
clean:
    rm -rf bin/
```

## Python (uv)

```just
# <project> developer recipes. Run `just --list` to see all recipes.

# Sync the virtualenv with the lockfile
sync:
    uv sync

# Format sources
fmt:
    uv run ruff format .

# Lint and type-check
lint:
    uv run ruff check .
    uv run ruff format --check .
    uv run mypy src

# Run unit tests
test:
    uv run pytest -q

# Run integration tests
test-integration:
    uv run pytest -q -m integration

# Lint, unit tests and integration tests
test-all: lint test test-integration

# Install the CLI as a uv tool from this checkout
install:
    uv tool install --force .

# Remove build output and caches
clean:
    rm -rf dist .pytest_cache .mypy_cache .ruff_cache
```

## Notes

- **Add project-specific recipes next to the defaults,** for example
  `build-<dependency>`, `lint-policy`, or `build-<dependency>-worktree` for
  development against a local fork.
- **Integration tests depend on their prerequisites** (`test-integration:
  build-deps`), so `just test-integration` works on a fresh checkout.
- **Verify the file parses** with `just --list` after every edit.
