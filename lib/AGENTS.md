# lib/ — Shared Library

## Purpose

Shared helpers sourced by every script in the repo root. Eliminates code duplication across the setup/fix scripts.

## Ownership

- `common.sh` — logging (`info`/`warn`/`error`/`detail`/`header`), package management (`check_package`/`install_package`), config guards (`create_backup`), `confirm()`, state snapshots (`snapshot_original`/`restore_original`/`cleanup_state_dir`, all `<state_dir> <file> <name>` except cleanup which takes `<state_dir>`), `strip_block()` (marker-block removal for v4 Lua configs)

## Local Contracts

- Must stay generic: no script-specific logic, no assumptions beyond `SCRIPT_DIR`
- Every public helper must have at least one caller script; unused helpers are deleted, not parked
- `strip_block <file> <begin_marker>` is the single marker-block removal implementation; setup scripts pass their own config path and marker string
- `snapshot_original <state_dir> <file> <name>` is the single pre-install snapshot implementation (`state_dir` = `~/.local/state/omarchy-custom-scripts/<script>`, defined per-script): never overwrites an existing snapshot, `<name>.absent` marks a file that didn't exist; `restore_original` skips when no snapshot exists ("`-i` didn't change it"), `cleanup_state_dir` removes the dir plus its empty parent. Callers: `setup-input.sh`, `fix-spotify-scale.sh`
- `common.sh` intentionally has NO `set -e` — guards rely on commands like `grep` returning 1; individual scripts add their own error handling
- Scripts load it via `source "$SCRIPT_DIR/lib/common.sh"` (`SCRIPT_DIR` resolved from `BASH_SOURCE`, so it works regardless of cwd)
- Never executed directly

## Work Guidance

- Adding a helper here adds a contract for every consumer script; extend an existing helper before adding a new one

## Verification

- No standalone framework; helpers are exercised by `test-idempotency.sh` at the repo root

## Child DOX Index

(none)
