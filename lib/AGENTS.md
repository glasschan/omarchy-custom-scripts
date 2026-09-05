# lib/ — Shared Library

## Purpose

Shared helpers sourced by every script in the repo root. Eliminates code duplication across the setup/fix scripts.

## Ownership

- `common.sh` — logging (`info`/`warn`/`error`/`detail`/`header`), package management (`check_package`/`install_package`), config guards (`config_contains`/`ensure_dir`/`create_backup`), `confirm()`, `usage_template()`
- `discovery.sh` — script discovery for front-ends: `get_script_metadata`, `get_script_category`, `get_script_description`, `get_script_device`, `discover_scripts`, `group_scripts_by_category`, `get_scripts_in_category` (extracted from `setup-all.sh`); device applicability: `current_device` (hostnamectl-based laptop/desktop detection, fails open to laptop), `script_applies_here` (Device: both or matches this machine)

## Local Contracts

- Must stay generic: no script-specific logic, no assumptions beyond `SCRIPT_DIR`
- `common.sh` intentionally has NO `set -e` — guards rely on commands like `grep` returning 1; individual scripts add their own error handling
- Scripts load them via `source "$SCRIPT_DIR/lib/common.sh"` and `source "$SCRIPT_DIR/lib/discovery.sh"` (`SCRIPT_DIR` resolved from `BASH_SOURCE`, so it works regardless of cwd)
- `discovery.sh` requires `$SCRIPT_DIR` to be set by the sourcing script; never executed directly

## Work Guidance

- Adding a helper here adds a contract for every consumer script; extend an existing helper before adding a new one

## Verification

- No standalone framework; helpers are exercised by `test-idempotency.sh` at the repo root

## Child DOX Index

(none)
