# DOX framework

- DOX is highly performant AGENTS.md hierarchy installed here
- Agent must follow DOX instructions across any edits

## Purpose

Personal Omarchy (Arch + Hyprland) macOS-style environment setup toolkit. Bash scripts that restore the user's desktop environment after a reinstall: fonts, input method (fcitx5-rime), keybindings, macOS-like input behavior, containers, and visual look & feel.

Branch mapping: `master` targets Omarchy v4 (Hyprland Lua configs, fcitx5 under systemd); the `v3` branch holds the last Omarchy v3-compatible versions (`setup-keyboard-swap.sh`, `setup-gaming.sh`, and the elephant/walker clipboard integration live only there).

## Ownership

Root owns: `install-wizard.sh` (interactive checkbox installer for Chinese users), `setup-all.sh` (orchestrator + interactive menu), all `setup-*.sh` feature scripts, `fix-*.sh` one-off fixes, `test-idempotency.sh`, `README.md`, `CLAUDE.md`. `lib/` is owned by its child doc below.

## Local Contracts

- Every setup/fix script must support `-i` install, `-u` uninstall/restore, `-s` status check, `-h` help; scripts that write config blocks also support `-f/--force` (skip the installed-check, rewrite the block — needed after block content changes)
- Every script declares `# Category:`, `# Description:` and `# Device: laptop|desktop|both` metadata headers — `setup-all.sh`/`install-wizard.sh` auto-discover from these; a new script without them never appears in the menu. Device filtering: the wizard asks the user; `setup-all.sh` auto-detects via `lib/discovery.sh` (`current_device`) and skips non-applicable scripts on install (uninstall/status stay unfiltered)
- Idempotency is mandatory: running `-i` twice must leave config files byte-identical (no duplicate lines, no stacking)
- Scripts source `lib/common.sh` for logging/package helpers and `lib/discovery.sh` for script discovery; never re-implement them locally
- Package install chain: `paru` → `yay` → `sudo pacman` (via `install_package`)
- Hyprland v4 Lua configs (`input.lua`, `bindings.lua`) are modified by appending `-- BEGIN/END ... (setup-X.sh)` marker blocks — never rewrite the Omarchy template; `-u` deletes only that marker block (multiple blocks may coexist in the same file, so strip must target the exact block, not truncate to EOF)
- Never edit `/usr/share/omarchy/` or `~/.local/share/omarchy/` (Omarchy defaults); user configs live in `~/.config/...`; uninstall reverts only what the script changed
- No interactive prompts during install except optional-feature confirmations

## Work Guidance

- `CLAUDE.md` documents the hard-won bash pitfalls — read it before editing any script: escape `&` as `\&` in sed replacements, `\s` requires `grep -E`, use `--` separator when a grep pattern starts with `-` (Lua markers), restart fcitx5 via `systemctl --user restart omarchy-fcitx5.service`
- New Hyprland config script: copy the marker-block pattern from `setup-keyboard.sh`, then validate with `hyprctl reload && hyprctl configerrors`
- New RIME schemas: repo map lives in `setup-input.sh` (`SCHEMA_REPOS`); `-u` removes only schemas recorded in `$RIME_DIR/.omarchy-schemas`

## Verification

- `./test-idempotency.sh` — runs a script's `-i` twice and asserts config files unchanged; accepts a script name to test just one
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
