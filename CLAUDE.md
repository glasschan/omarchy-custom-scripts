# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Glass Omarchy Custom Scripts** - A collection of bash scripts for personalizing an Omarchy Linux (Arch-based) Hyprland environment with macOS-like behavior. The theme is "bringing macOS UX to Arch Linux".

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

### Script Modules

All scripts follow this pattern:

```bash
./script.sh -i  # install/apply
./script.sh -u  # uninstall/restore
./script.sh -h  # help
```

| Script | Purpose | Key Files Modified |
| -------- | --------- | ------------------- |
| `install-wizard.sh` | Interactive TUI installer (lazy-pack style): device prompt, checkbox menu, submenus | runs selected setup scripts' `-i` |
| `setup-fonts.sh` | Install choice of CJK fonts, no system-font change | `~/.local/share/fonts/`; `--fonts misans,opposans` |
| `setup-input.sh` | fcitx5-rime + selectable schema set | `~/.local/share/fcitx5/rime/*`, `~/.config/fcitx5/{config,profile}`; `--schemas scj6,quick5,…` |
| `setup-keyboard.sh` | Keyboard repeat/caps/numlock | `~/.config/hypr/input.lua` (marker block) |
| `setup-macos-touchpad.sh` | Laptop touchpad macOS style | `~/.config/hypr/input.lua` (marker block) |
| `setup-distrobox.sh` | Distrobox + DistroShelf container tools | `~/.bashrc`, `~/.config/distrobox/distrobox.ini` |
| `setup-keybindings.sh` | Clipboard manager binding | `~/.config/hypr/bindings.lua` (marker block) |

Removed in v4 (kept on `v3` branch): `setup-keyboard-swap.sh`, `setup-gaming.sh`, `lib/elephant-clipboard-activate.sh`.

### Common Patterns Across All Scripts

 1. **Helper functions at top**: `info()`, `warn()`, `error()`, `detail()`, `header()` - all use ANSI colors
 2. **Idempotent checks**: Always check if already installed/configured before making changes
 3. **Package detection**: Uses `pacman -Q pkgname` to check for existing packages
 4. **AUR helper fallback**: `paru` → `yay` → `sudo pacman`
 5. **No interactive prompts during install** (except confirmations for optional features)

### ⚠️ Critical Shell Scripting Pitfalls (Hard Learned)

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
# Interactive menu (most used)
./setup-all.sh -m

# Install all
./setup-all.sh

# Check status
./setup-all.sh -s

# Run individual script
./setup-fonts.sh -i
./setup-fonts.sh -u
```

### Testing

There is no formal test suite. Test by:

1. Running the script with `-i` on a fresh Omarchy system
2. Running with `-u` to verify clean removal
3. Running the same command twice to verify idempotency
4. Using the idempotency test script:

```bash
# Test all scripts
./test-idempotency.sh

# Test a single script
./test-idempotency.sh setup-keybindings.sh
```

## Key Implementation Details

### Hyprland Config Files (v4 Lua)

- User configs go in `~/.config/hypr/*.lua` — auto-loaded after Omarchy defaults: `monitors.lua`, `input.lua`, `bindings.lua`, `looknfeel.lua`, `autostart.lua` (plus `hyprland.lua` itself for anything else)
- Lua API: `hl.config({...})` for variables, `o.bind("KEYS", "desc", "cmd")` for bindings, `hl.unbind`, `o.window(class, rules)` for window rules, `hl.env`, `hl.curve`/`hl.animation` for animations
- Our scripts append `-- BEGIN/END ... (setup-X.sh)` marker blocks; `-u`/force-rewrite strips exactly that block (`strip_block_range`) — multiple blocks may coexist in one file, never truncate from BEGIN to EOF
- When updating a block's content, always strip the whole block and re-append it — never sed-patch values inside an existing block (substring replaces hit the wrong node: the fonts.conf `sans-serif` `<string>` got overwritten by a family-name sed)
- Validate after any Lua change: `hyprctl reload && hyprctl configerrors` (empty output = clean); check bindings with `omarchy menu keybindings --print`
- Never edit `/usr/share/omarchy/` or `~/.local/share/omarchy/` (Omarchy defaults; reading is fine)

### Input Method (fcitx5-rime)

- Direct file manipulation (no `fcitx5-configtool`) because GUI tools block scripts
- Rime schema files go in `~/.local/share/fcitx5/rime/`
- v4 runs fcitx5 under systemd: `systemctl --user restart omarchy-fcitx5.service` (never `killall` + manual start)
- IM env vars (`QT_IM_MODULE` etc.) are Omarchy v4 defaults — scripts don't set them
- The script checks/repairs `~/.config/fcitx5/profile` (post-v4-upgrade corruption left rime unreachable)
- Auto-deploy: restart the service, wait up to 10s for `rime/build/`
- **kb_options must stay `compose:caps`** (v3 value): v4's default adds `shift:both_capslock_cancel`, which breaks rime's alone-Right-Shift CN/EN toggle (XKB-level interference). `setup-keyboard.sh` overrides this in its `input.lua` marker block — don't drop that line

## Adding New Features

When creating a new `setup-xxx.sh`:

1. Copy the structure from existing scripts (helpers, check_package, install/uninstall functions)
2. Make it idempotent (check if already configured)
3. Add proper cleanup in `-u` mode
4. **Pass the QA checklist below**
5. No registration needed — `setup-all.sh` auto-discovers scripts via `# Category:` / `# Description:` metadata headers (menu, install_all, uninstall_all, show_status all use discovery). Just make sure the headers exist.

#### **Mandatory QA Checklist for New Scripts**

Before merging any new script:

- [ ] **Idempotency test**: Run `-i` twice, verify config file unchanged
- [ ] **sed safety**: All `&` in sed replacements are escaped as `\&`
- [ ] **grep safety**: All `\s` in grep use `-E` flag; patterns starting with `-` use `--` separator
- [ ] **Status check works**: `-s` correctly detects when installed
- [ ] **Uninstall works**: `-u` completely removes all traces
- [ ] **No duplicates**: Verify no duplicate lines in config after re-runs

## Important Files to Reference

- **README.md** - Contains detailed rationale for each design choice
- **`setup-macos-input.sh` / `setup-keybindings.sh`** - Reference pattern for v4 marker-block Lua config scripts
- **`setup-fonts.sh` / `setup-distrobox.sh`** - Good examples of proper guard patterns
- **`setup-all.sh`** - Shows how all scripts are orchestrated

## Dependencies

- **OS**: Omarchy Linux (Arch-based) with Hyprland
- **AUR helpers**: `paru` or `yay` (falls back to `sudo pacman`)
- **Wayland tools**: `wl-copy` (clipboard), `hyprctl` (Hyprland control)
