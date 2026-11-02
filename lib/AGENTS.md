# lib/ — Shared Library

## Purpose

Shared helpers sourced by every script in the repo root. Eliminates code duplication across the setup/fix scripts.

## Ownership

- `common.sh` — logging (`info`/`warn`/`error`/`detail`/`header`), package management (`check_package`/`install_package`), config guards (`create_backup`), `confirm()`, `strip_block()` (marker-block removal for v4 Lua configs)

## Local Contracts

- Must stay generic: no script-specific logic, no assumptions beyond `SCRIPT_DIR`
- Every public helper must have at least one caller script; unused helpers are deleted, not parked
- `strip_block <file> <begin_marker>` is the single marker-block removal implementation; setup scripts pass their own config path and marker string
- `common.sh` intentionally has NO `set -e` — guards rely on commands like `grep` returning 1; individual scripts add their own error handling
- Scripts load it via `source "$SCRIPT_DIR/lib/common.sh"` (`SCRIPT_DIR` resolved from `BASH_SOURCE`, so it works regardless of cwd)
- Never executed directly

## Work Guidance

- Adding a helper here adds a contract for every consumer script; extend an existing helper before adding a new one

## Verification

- No standalone framework; helpers are exercised by `test-idempotency.sh` at the repo root

## Child DOX Index

(none)
