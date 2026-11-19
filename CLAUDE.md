# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Glass Omarchy Custom Scripts** - A collection of bash scripts for personalizing an Omarchy Linux (Arch-based) Hyprland environment: fonts, input method, and comfortable keyboard/trackpad defaults.

**Target: Omarchy v4** (`master` branch). Omarchy v3 machines use the `v3` branch. v4 switched Hyprland config to Lua (`~/.config/hypr/*.lua`) and supervises fcitx5 via systemd (`omarchy-fcitx5.service`).

**Design Philosophy:**

- Personal use only - not generic installation scripts
- Fully automated - no GUI tools or interactive wizards
- Idempotent - safe to re-run; can restore/reinstall without polluting system
- Don't rewrite Omarchy templates - v4 Lua configs get marker-delimited blocks appended, preserving template comments and Omarchy defaults

## Code Architecture

### Entry Point

- **`setup-all.sh`** - Main interactive menu that orchestrates all other scripts. Provides:
  - Interactive menu mode (default)
  - One-click install all (`-i`)
  - Status check (`-s`)
  - Uninstall all (`-u`)
  - `install_all` / `uninstall_all` keep going past a failing script, then print `N 個腳本失敗：<names>` and exit 1; the success header is printed only when every script succeeded. The interactive menu passes `keep-running` so a failure returns to the menu instead of exiting.

### Script Modules

All scripts follow this pattern:

```bash
./script.sh -i  # install/apply
./script.sh -u  # uninstall/restore
./script.sh -h  # help
```

| Script | Purpose | Key Files Modified |
| -------- | --------- | ------------------- |
| `setup-fonts.sh` | Fonts (default MiSans VF 10) + GTK/fontconfig | `~/.config/fontconfig/fonts.conf`, gsettings, `~/.local/share/fonts/` |
| `setup-chromium-scale.sh` | Chromium/Electron scale factor 1 | `~/.config/chromium-flags.conf` |
| `setup-input.sh` | fcitx5-rime + Quick Cangjie input method | `~/.local/share/fcitx5/rime/*`, `~/.config/fcitx5/{config,profile}` |
| `setup-macos-input.sh` | Keyboard/trackpad tuning | `~/.config/hypr/input.lua` (marker block) |
| `setup-keybindings.sh` | Custom screenshot/recording/clipboard bindings | `~/.config/hypr/bindings.lua` (marker block) |

Retired scripts live in `archive/` (not discovered by `setup-all.sh`, no longer registered in `test-idempotency.sh`): `setup-rime-scj.sh`, `setup-looknfeel.sh`, `setup-foot.sh`, `setup-distrobox.sh`, `fix-spotify-scale.sh`, `fix-chrome-keyring.sh`. `archive/lib` is a symlink to `../lib`, so archived scripts still source `common.sh` and can be run by hand.

Removed in v4 (kept on `v3` branch): `setup-keyboard-swap.sh`, `setup-gaming.sh`, `lib/elephant-clipboard-activate.sh`.

### Common Patterns Across All Scripts

 1. **Helpers from `lib/common.sh`**: `info()`, `warn()`, `error()`, `detail()`, `header()` - all use ANSI colors; `error()` exits immediately (no code after it runs); state snapshots via `snapshot_original`/`restore_original`/`cleanup_state_dir`
 2. **Idempotent checks**: Always check if already installed/configured before making changes
 3. **Package detection**: Uses `pacman -Q pkgname` to check for existing packages
 4. **AUR helper fallback**: `paru` → `yay` → `sudo pacman`
 5. **No interactive prompts during install** (except confirmations for optional features) — the one exception is `setup-fonts.sh`, which asks for family/size on a TTY only; non-interactive runs (`install_all`, CI, pipes) use the defaults without prompting

### ⚠️ Critical Shell Scripting Pitfalls (Hard Learned)

Lint rules live in `.shellcheckrc` + `lint.sh`; the structural ones (R1–R6) are listed under Testing. The bash-specific ones:

**THESE WILL BREAK YOUR SCRIPTS IF YOU IGNORE THEM.**

#### **sed Special Character - `&`**

In `sed` replacement strings, `&` means **"insert the entire matched text here"**, NOT a literal ampersand. Always escape it:

```bash
# ❌ BROKEN - & expands to the whole match!
sed -i 's/old=.*/new=foo && bar/' file

# ✅ CORRECT - escape & as \&
sed -i 's/old=.*/new=foo \&\& bar/' file
```

This was the root cause of the clipboard manager corruption bug. Each run doubled the content because `&&` expanded to the entire matched line.

#### **Wayland Input Tools - Use `hyprctl` over `wtype`**

`wtype` sends keystrokes via the Wayland protocol, which requires a focused window and fails during focus transitions (e.g. right after a launcher closes). Use `hyprctl dispatch` instead — it works at the compositor level:

```bash
# ❌ UNRELIABLE - fails during focus transitions
wtype -M shift -k Insert -m shift

# ✅ CORRECT - compositor-level, no focus dependency (Hyprland 0.55+ requires the 3rd field)
hyprctl dispatch sendshortcut "SHIFT, Insert, activewindow"
```

#### **grep Whitespace Regex - Use `-E` for `\s`**

`\s` (whitespace) only works in extended regex mode. Always use `grep -E` when you need `\s`:

```bash
# ❌ UNRELIABLE - may match literal "\s" on some systems
grep -q '^command\s*=' file

# ✅ CORRECT - extended regex mode
grep -Eq '^command\s*=' file
```

#### **grep Pattern Starting with `-` (e.g. Lua markers)**

A pattern that starts with `--` is parsed as a grep **option**, not a pattern — grep exits 2 and the guard check always fails, so append-style installs stack duplicates on every run (this broke all three v4 marker-block scripts until caught by `test-idempotency.sh`):

```bash
# ❌ BROKEN - "-- BEGIN ..." is treated as an (invalid) long option; exit 2
grep -qF "-- BEGIN custom keybindings" file

# ✅ CORRECT - `--` ends option parsing
grep -qF -- "-- BEGIN custom keybindings" file
```

Applies to any grep where the pattern is a variable that may start with `-` (Lua comments, CLI flags in logs, etc.).

#### **Idempotency is Mandatory - Test It**

**Always run your script twice in a row** and verify the config file is identical both times:

```bash
./script.sh -i && md5sum ~/.config/target.lua  # Run 1
./script.sh -i && md5sum ~/.config/target.lua  # Run 2 - MUST match!
```

If the checksums differ, you have a stacking bug.

## Common Development Commands

### Run Scripts

```bash
# Interactive menu (default; -m is the same)
./setup-all.sh

# Install all
./setup-all.sh -i

# Check status
./setup-all.sh -s

# Run individual script
./setup-fonts.sh -i
./setup-fonts.sh -u
./setup-chromium-scale.sh -i
```

### Testing

Test by:

1. Running the script with `-i` on a fresh Omarchy system
2. Running with `-u` to verify clean removal
3. Running the same command twice to verify idempotency
4. Using the idempotency test script:

```bash
# Lint — project rules live in .shellcheckrc + lint.sh (same as CI)
./lint.sh              # warns when shellcheck is absent
./lint.sh --strict     # shellcheck missing = failure (CI uses this)

# Test all scripts
./test-idempotency.sh

# Test a single script
./test-idempotency.sh setup-keybindings.sh
```

`test-idempotency.sh` runs each script's `-i` twice and asserts config files unchanged, then runs `-u` and asserts every config returns byte-for-byte to its pre-run state (absent must stay absent). It also checks the script's real exit status and restores each pre-existing config from `<config>.bak.idempotency_test` afterwards, pass or fail.

Structural rules lint.sh enforces, each from a real breakage:

| Rule | What it prevents |
| ------ | ----------------- |
| R1 every `strip_block` passes an END marker | `-u` truncating from BEGIN to EOF and eating user config appended after the block; a 2-arg call fails even when the script defines no `END_MARKER` |
| R2 no `create_backup` | `.bak.<timestamp>` litter that `-u` never reads; snapshots in `~/.local/state/` are the only backup |
| R3 every discoverable script is in `SCRIPT_CONFIG_MAP` | a new script silently skipping the idempotency suite; `# Hidden: yes\|true\|1` opts out with the same test as `setup-all.sh` |
| R4 every `usage()` lists `-i, --install`, `-u, --uninstall`, `-s, --status`, `-h, --help` | `setup-all.sh` silently skipping the script in status; missing install/uninstall path |
| R5 no script writes a `keyboard-*` input method | English as a separate IM just adds a switching slot; it belongs on rime's `ascii_mode` |
| R6 every script in `SCRIPT_CONFIG_MAP` exists in the repo root | stale registrations left behind after archiving a script |

## Key Implementation Details

### Hyprland Config Files (v4 Lua)

- User configs go in `~/.config/hypr/*.lua` — auto-loaded after Omarchy defaults: `monitors.lua`, `input.lua`, `bindings.lua`, `looknfeel.lua`, `autostart.lua` (plus `hyprland.lua` itself for anything else)
- Lua API: `hl.config({...})` for variables, `o.bind("KEYS", "desc", "cmd")` for bindings, `hl.unbind`, `o.window(class, rules)` for window rules, `hl.env`, `hl.curve`/`hl.animation` for animations
- Our scripts append `-- BEGIN/END ... (setup-X.sh)` marker blocks; uninstall removes only the BEGIN..END span, so user content appended after the block survives (marker removal is `strip_block <file> <begin> <end>` in `lib/common.sh`)
- `-f, --force` (`setup-macos-input.sh`, `setup-keybindings.sh`) skips the already-installed check and rewrites the block from scratch
- Both scripts report `hyprctl configerrors` after `-i` and `-f`; `setup-keybindings.sh` also does after `-u`. `setup-macos-input.sh -i` prints the effective `hyprctl getoption` values rather than assuming them
- Validate after any Lua change: `hyprctl reload && hyprctl configerrors` (empty output = clean); check bindings with `omarchy menu keybindings --print`
- Never edit `/usr/share/omarchy/` or `~/.local/share/omarchy/` (Omarchy defaults; reading is fine)

### Fonts (setup-fonts.sh) and Chromium Scale

- Defaults are `FONT_NAME="MiSans VF"` / `FONT_SIZE=10`; both are the `fc-list` family names (OPPO Sans is `OPPO Sans 4.0`, MiSans is `MiSans VF`)
- Resolution order: `FONT_NAME`/`FONT_SIZE` env vars (skip the matching prompt) → TTY prompts on `-i` (family: 1 MiSans VF, 2 OPPO Sans 4.0, 3 free text; size 6–20, default 10) → defaults when non-interactive (`install_all`, CI, pipes). Selected families that are not installed fall back to MiSans VF, then to an empty name / `Sans`
- `-d, --download` only downloads MiSans + OPPO Sans (both, if missing), refreshes `fc-cache`, and skips GTK/fontconfig changes
- `fonts.conf` points `sans-serif`, `sans`, `system-ui`, `ui-sans-serif`, `-apple-system`, `BlinkMacSystemFont` at `$FONT_NAME`, plus the `Liberation Sans` rule that actually takes effect (Omarchy's `50-omarchy.conf` rewrites `sans-serif` to Liberation Sans first); `monospace` is untouched. A CJK/Nerd Font/emoji alias is appended. No empty `fonts.conf` is written when `FONT_NAME` is blank
- `-u` restores the three GTK keys from `gtk-fonts`, restores/removes `fonts.conf`, and deletes only font files recorded in `installed-fonts` (files it copied in that did not exist before); user-owned fonts stay, and `~/.local/share/fonts/` is kept when other files remain
- Chromium scale: `setup-chromium-scale.sh` writes `--force-device-scale-factor=1` into `~/.config/chromium-flags.conf`, preserves other flags, replaces an existing value in place, and creates the default flag block when the file is absent; `-u` restores the pre-install file (absent → removed)

### Input Method (fcitx5-rime)

- Direct file manipulation during `-i` (no `fcitx5-configtool`) because GUI tools block scripts; `-c` / post-install confirmation opens it detached with `nohup ... &`
- The written profile keeps only `rime` (no `keyboard-us`): English goes through rime's `ascii_mode`, Right Shift toggles. User-added IMs other than `keyboard-*` are preserved, and item indexes are rewritten contiguously
- fcitx5 rewrites `profile` at runtime (comments, ordering), so `check_fcitx5_profile` compares semantics (items and `DefaultIM`), not bytes; `fcitx5-remote -r` reloads it after writing
- Rime schema files go in `~/.local/share/fcitx5/rime/`
- v4 runs fcitx5 under systemd: `systemctl --user restart omarchy-fcitx5.service` (never `killall` + manual start)
- IM env vars (`QT_IM_MODULE` etc.) are Omarchy v4 defaults — scripts don't set them
- The script checks/repairs `~/.config/fcitx5/profile` (post-v4-upgrade corruption left rime unreachable)
- `-u` fully restores what `-i` changed in `~/.config/fcitx5/{profile,config}`: `-i` snapshots originals (via the shared `lib/common.sh` `snapshot_original` — never overwritten, `<name>.absent` marker when absent) to `~/.local/state/omarchy-custom-scripts/setup-input/`, so repeat `-i` keeps the true pre-install state; `-u` restores byte-identical via `restore_original`, removes files it created, and deletes the snapshot dir with `cleanup_state_dir`
- The custom rime yamls (`scj6.custom.yaml`, `default.custom.yaml`) are snapshotted before being overwritten and restored by `-u`; downloaded `rime-scj` yamls are recorded in `installed-rime-files`, and `-u` removes only those. It never touches `scj6.userdb`, `*.userdb`, `scj6.dict.yaml`, `build/` or `sync/`
- Auto-deploy: restart the service, wait up to 10s for `rime/build/`
- **kb_options must stay `compose:caps`** (v3 value): v4's default adds `shift:both_capslock_cancel`, which breaks rime's alone-Right-Shift CN/EN toggle (XKB-level interference). `setup-macos-input.sh` overrides this in its `input.lua` marker block — don't drop that line

## Adding New Features

When creating a new `setup-xxx.sh`:

1. Copy the structure from existing scripts (helpers, check_package, install/uninstall functions)
2. Make it idempotent (check if already configured)
3. Add proper cleanup in `-u` mode
4. **Pass the QA checklist below**
5. Register it in `test-idempotency.sh`'s `SCRIPT_CONFIG_MAP` (`script|config` lines, one line per config a script writes — a script may appear on several lines) so the idempotency harness covers it in both single-script and full-run modes
6. No registration needed — `setup-all.sh` auto-discovers scripts via `# Category:` / `# Description:` metadata headers (menu, install_all, uninstall_all, show_status all use discovery). Just make sure the headers exist. To keep a script out of the menu/status, add a `# Hidden:` header with `yes`/`true`/`1` — never a filename exclusion in `setup-all.sh`.
7. `setup-all.sh -s` probes each script's `-h` usage output for an `-s, --status` option line — keep that line in `usage()` or the script gets skipped in status.

#### **Mandatory QA Checklist for New Scripts**

Before merging any new script:

- [ ] **Idempotency test**: Run `-i` twice, verify config file unchanged
- [ ] **sed safety**: All `&` in sed replacements are escaped as `\&`
- [ ] **grep safety**: All `\s` in grep use `-E` flag; patterns starting with `-` use `--` separator
- [ ] **Status check works**: `-s` correctly detects when installed
- [ ] **Uninstall works**: `-u` completely removes all traces
- [ ] **No duplicates**: Verify no duplicate lines in config after re-runs
- [ ] **`./lint.sh --strict` passes** — includes the structural rules in the table below

## Important Files to Reference

- **README.md** - Contains detailed rationale for each design choice
- **`setup-macos-input.sh` / `setup-keybindings.sh`** - Reference pattern for v4 marker-block Lua config scripts
- **`setup-fonts.sh`** - Font defaults, TTY prompts, and snapshot round trips (`archive/fix-spotify-scale.sh` is the minimal append-only version)
- **`setup-chromium-scale.sh`** - Minimal single-file example: guard check, snapshot, `-u`; shows the `-i`/`-u` strict-pair pattern for a file that may not exist
- **`setup-all.sh`** - Shows how all scripts are orchestrated

## Dependencies

- **OS**: Omarchy Linux (Arch-based) with Hyprland
- **AUR helpers**: `paru` or `yay` (falls back to `sudo pacman`)
- **Wayland tools**: `wl-copy` (clipboard), `hyprctl` (Hyprland control)

## Agent skills

### Issue tracker

Issues and specs for this repo live as GitHub issues in `glasschan/omarchy-custom-scripts`, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical roles map to same-named GitHub labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` at the repo root plus ADRs in `docs/adr/`, both created lazily by `/domain-modeling`. See `docs/agents/domain.md`.
