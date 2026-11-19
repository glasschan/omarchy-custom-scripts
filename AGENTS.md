# DOX framework

- DOX is highly performant AGENTS.md hierarchy installed here
- Agent must follow DOX instructions across any edits

## Purpose

Personal Omarchy (Arch + Hyprland) macOS-style environment setup toolkit. Bash scripts that restore the user's desktop environment after a reinstall: fonts, input method (fcitx5-rime), keybindings, macOS-like input behavior, containers, and visual look & feel.

Branch mapping: `master` targets Omarchy v4 (Hyprland Lua configs, fcitx5 under systemd); the `v3` branch holds the last Omarchy v3-compatible versions (`setup-keyboard-swap.sh`, `setup-gaming.sh`, and the elephant/walker clipboard integration live only there).

## Ownership

Root owns: `setup-all.sh` (orchestrator + interactive menu), all `setup-*.sh` feature scripts, `fix-*.sh` one-off fixes, `test-idempotency.sh`, `lint.sh` + `.shellcheckrc` (the project lint entry point and its rules), `README.md`, `CLAUDE.md`. `lib/` is owned by its child doc below.

`docs/agents/` holds engineering-skill config, not code: `issue-tracker.md` (work lives in GitHub issues for `glasschan/omarchy-custom-scripts`), `triage-labels.md` (five canonical labels), `domain.md` (single-context: `GLOSSARY.md` + `docs/adr/`, created lazily). Edit these files directly; skills read them, nothing else does.

## Local Contracts

- Every setup/fix script must support `-i` install, `-u` uninstall/restore, `-s` status check, `-h` help; `setup-all.sh` detects `-s` support by probing the script's `-h` usage output for an `-s, --status` line — keep that line in `usage()` or the script is skipped in status
- Every script declares `# Category:` and `# Description:` metadata headers — `setup-all.sh` auto-discovers scripts from these, so a new script without them never appears in the menu; a `# Hidden: yes` header opts a script out of menu/status (e.g. the `setup-rime-scj.sh` legacy wrapper)
- Retired scripts move to `archive/`, not deleted (no backups outside the folder): discovery scans only `setup-*.sh` / `fix-*.sh` in the repo root, so archiving removes a script from the menu and from install/uninstall-all; also delete its line from `test-idempotency.sh` `SCRIPT_CONFIG_MAP`
- Idempotency is mandatory: running `-i` twice must leave config files byte-identical (no duplicate lines, no stacking)
- Scripts source `lib/common.sh` for logging/package helpers; never re-implement them locally. `error()` exits — nothing after an `error` call is reachable
- Package install chain: `paru` → `yay` → `sudo pacman` (via `install_package`)
- Hyprland v4 Lua configs (`input.lua`, `bindings.lua`) are modified by appending `-- BEGIN/END ... (setup-X.sh)` marker blocks — never rewrite the Omarchy template; `-u` removes only the BEGIN..END span via `lib/common.sh` `strip_block <file> <begin> <end>` (single implementation; scripts keep only their path + marker strings), so user content appended after the block survives; the END marker is optional and omitting it falls back to truncating from BEGIN to EOF
- State snapshots: scripts that rewrite existing user files snapshot originals to `~/.local/state/omarchy-custom-scripts/<script>/` at `-i` (a `<name>.absent` marker when the file didn't exist; an existing snapshot is never overwritten); `-u` restores from the snapshot and removes the snapshot dir. Single implementation in `lib/common.sh`: `snapshot_original`/`restore_original`/`cleanup_state_dir <state_dir> <file> <name>` (consumers: `setup-input.sh`, `setup-fonts.sh`). `setup-fonts.sh` also writes the three GTK font key values to `gtk-fonts` in the same state dir. The file holds `gsettings get` output, and `-u` feeds it back to `gsettings set` rather than resetting to the schema default. `-i`/`-u` are a strict pair: no snapshot means `-i` made no change, so `-u` must leave the file untouched — never a second, ad-hoc restore mechanism (`.bak.*` files, `ls -1t` picking)
- Never edit `/usr/share/omarchy/` or `~/.local/share/omarchy/` (Omarchy defaults); user configs live in `~/.config/...`; uninstall reverts only what the script changed
- No interactive prompts during install except optional-feature confirmations

## Work Guidance

- `CLAUDE.md` documents the hard-won bash pitfalls — read it before editing any script: escape `&` as `\&` in sed replacements, `\s` requires `grep -E`, use `--` separator when a grep pattern starts with `-` (Lua markers), restart fcitx5 via `systemctl --user restart omarchy-fcitx5.service`
- Lint rules are code, not conversation: when a review or a failed run teaches something a check can catch, add it to `.shellcheckrc` (shellcheck-level) or a rule in `lint.sh` (structural), and keep both docs and the rule in the same change
- New Hyprland config script: copy the marker-block pattern from `setup-macos-input.sh`, then validate with `hyprctl reload && hyprctl configerrors`
- Testing: run `-i` twice and compare checksums, then `-u` to verify clean removal

## Verification

- `./test-idempotency.sh` — runs a script's `-i` twice and asserts config files unchanged; accepts a script name to test just one. Script→config mapping lives in one place (`SCRIPT_CONFIG_MAP`); register a new script there with a single line and both usages pick it up; unregistered names exit non-zero
- `./lint.sh` — the single lint entry point: `bash -n` over `*.sh` and `lib/*.sh` (plus `archive/`), `shellcheck` with project rules from `.shellcheckrc` (errors/warnings plus `SC2162`/`SC2015`/`SC2086`/`SC2012` promoted to must-fix), then structural rules learned from real breakage: R1 every `strip_block` call passes an END marker, R2 no script uses `create_backup`, R3 every discoverable script is registered in `SCRIPT_CONFIG_MAP`, R4 every script's `usage()` exposes `-s, --status` and `-u, --uninstall`. `--strict` treats a missing `shellcheck` as failure (CI uses it); locally the tool may be absent and only warns
- `.github/workflows/ci.yml` (GitHub PR checks) — `lint`: `./lint.sh --strict` (installs shellcheck first); `idempotency`: the full suite in a sandboxed `HOME` with privileged binaries (`pacman`, `paru`, `yay`, `hyprctl`, `systemctl`, …) stubbed. Run both locally before pushing
- Manual: `./setup-all.sh -s` should correctly reflect installed state

## Core Contract

- AGENTS.md files are binding work contracts for their subtrees
- Work products, source materials, instructions, records, assets, and durable docs must stay understandable from the nearest applicable AGENTS.md plus every parent AGENTS.md above it

## Read Before Editing

1. Read the root AGENTS.md
2. Identify every file or folder you expect to touch
3. Walk from the repository root to each target path
4. Read every AGENTS.md found along each route
5. If a parent AGENTS.md lists a child AGENTS.md whose scope contains the path, read that child and continue from there
6. Use the nearest AGENTS.md as the local contract and parent docs for repo-wide rules
7. If docs conflict, the closer doc controls local work details, but no child doc may weaken DOX

Do not rely on memory. Re-read the applicable DOX chain in the current session before editing.

## Update After Editing

Every meaningful change requires a DOX pass before the task is done.

Update the closest owning AGENTS.md when a change affects:

- purpose, scope, ownership, or responsibilities
- durable structure, contracts, workflows, or operating rules
- required inputs, outputs, permissions, constraints, side effects, or artifacts
- user preferences about behavior, communication, process, organization, or quality
- AGENTS.md creation, deletion, move, rename, or index contents

Update parent docs when parent-level structure, ownership, workflow, or child index changes. Update child docs when parent changes alter local rules. Remove stale or contradictory text immediately. Small edits that do not change behavior or contracts may leave docs unchanged, but the DOX pass still must happen.

## Hierarchy

- Root AGENTS.md is the DOX rail: project-wide instructions, global preferences, durable workflow rules, and the top-level Child DOX Index
- Child AGENTS.md files own domain-specific instructions and their own Child DOX Index
- Each parent explains what its direct children cover and what stays owned by the parent
- The closer a doc is to the work, the more specific and practical it must be

## Child Doc Shape

- Create a child AGENTS.md when a folder becomes a durable boundary with its own purpose, rules, responsibilities, workflow, materials, or quality standards
- Work Guidance must reflect the current standards of the project or user instructions; if there are no specific standards or instructions yet, leave it empty
- Verification must reflect an existing check; if no verification framework exists yet, leave it empty and update it when one exists

Default section order:

- Purpose
- Ownership
- Local Contracts
- Work Guidance
- Verification
- Child DOX Index

## Style

- Keep docs concise, current, and operational
- Document stable contracts, not diary entries
- Put broad rules in parent docs and concrete details in child docs
- Prefer direct bullets with explicit names
- Do not duplicate rules across many files unless each scope needs a local version
- Delete stale notes instead of explaining history
- Trim obvious statements, repeated rules, misplaced detail, and warnings for risks that no longer exist

## Closeout

1. Re-check changed paths against the DOX chain
2. Update nearest owning docs and any affected parents or children
3. Refresh every affected Child DOX Index
4. Remove stale or contradictory text
5. Run existing verification when relevant
6. Report any docs intentionally left unchanged and why

## User Preferences

When the user requests a durable behavior change, record it here or in the relevant child AGENTS.md

## Child DOX Index

- `lib/AGENTS.md` — shared library: `common.sh` helpers. Read before editing anything in `lib/`.
