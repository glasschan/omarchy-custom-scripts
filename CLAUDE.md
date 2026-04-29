# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Glass Omarchy Custom Scripts** - A collection of bash scripts for personalizing an Omarchy Linux (Arch-based) Hyprland environment with macOS-like behavior. The theme is "bringing macOS UX to Arch Linux".

**Design Philosophy:**
- Personal use only - not generic installation scripts
- Fully automated - no GUI tools or interactive wizards
- Idempotent - safe to re-run; can restore/reinstall without polluting system

## Code Architecture

### Entry Point
- **`setup-all.sh`** - Main interactive menu that orchestrates all other scripts. Provides:
  - Interactive menu mode (`-m`)
  - One-click install all (default)
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
|--------|---------|-------------------|
| `setup-fonts.sh` | Fonts + Chromium scale fix | `~/.config/fontconfig/fonts.conf`, `~/.config/chromium-flags.conf`, gsettings |
| `setup-input.sh` | fcitx5-rime + Quick Cangjie input method | `~/.local/share/fcitx5/rime/*`, `~/.config/fcitx5/config` |
| `setup-macos-input.sh` | macOS-like keyboard/trackpad behavior | `~/.config/hypr/input.conf` |
| `setup-keyboard-swap.sh` | Swap Super/Alt on built-in keyboard (optional) | `~/.config/hypr/input.conf` |
| `setup-distrobox.sh` | Distrobox + DistroShelf container tools | `~/.bashrc`, `~/.config/distrobox/distrobox.ini` |
| `setup-keybindings.sh` | Custom screenshot/recording/clipboard bindings | `~/.config/hypr/bindings.conf`, `~/.config/elephant/clipboard.toml` |
| `fix-chrome-keyring.sh` | Fix Chrome keyring password popup | `~/.local/share/keyrings/*` |
| `setup-gaming.sh` | Game compatibility for Wayland/Hyprland | `~/.config/hypr/envs.conf`, `~/.config/hypr/games.conf`, installs `gamescope` |

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

`wtype` sends keystrokes via the Wayland protocol, which requires a focused window. When a launcher like walker closes after item selection, there's a focus transition where `wtype` can't deliver keystrokes. Use `hyprctl dispatch sendshortcut` instead — it works at the compositor level:

```bash
# ❌ UNRELIABLE - fails during focus transitions
command = 'wl-copy && sleep 0.2 && wtype -M shift -k Insert -m shift'

# ✅ CORRECT - compositor-level, no focus dependency
command = 'wl-copy && hyprctl dispatch sendshortcut "SHIFT, Insert,"'
```

#### **grep Whitespace Regex - Use `-E` for `\s`**

`\s` (whitespace) only works in extended regex mode. Always use `grep -E` when you need `\s`:

```bash
# ❌ UNRELIABLE - may match literal "\s" on some systems
grep -q '^command\s*=' file

# ✅ CORRECT - extended regex mode
grep -Eq '^command\s*=' file
```

#### **Idempotency is Mandatory - Test It**

**Always run your script twice in a row** and verify the config file is identical both times:
```bash
./script.sh -i && md5sum ~/.config/target.conf  # Run 1
./script.sh -i && md5sum ~/.config/target.conf  # Run 2 - MUST match!
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

## Key Implementation Details

### Hyprland Config Files
- User configs go in `~/.config/hypr/`
- `hyprland.conf` sources other files (input.conf, bindings.conf, envs.conf, games.conf)
- Never edit `~/.local/share/omarchy/` (Omarchy defaults)

### Input Method (fcitx5-rime)
- Direct file manipulation (no `fcitx5-configtool`) because GUI tools block scripts
- Rime schema files go in `~/.local/share/fcitx5/rime/`
- Auto-deploy: kill fcitx5, restart, wait up to 10s for build

### Per-device Keyboard Settings
- Hyprland supports per-device XKB options via `input[<device>]:xkb_options = altwin:swap_alt_win`
- Used by `setup-keyboard-swap.sh` to swap Super/Alt ONLY on built-in keyboard

### Game Compatibility
- `gamescope` is the standard fix for Unity/SDL games not showing windows on Wayland
- `SDL_VIDEODRIVER=x11` environment variable forces XWayland for games
- Steam launch option: `gamescope -W 1920 -H 1080 -f -- %command%`

## Adding New Features

When creating a new `setup-xxx.sh`:
1. Copy the structure from existing scripts (helpers, check_package, install/uninstall functions)
2. Make it idempotent (check if already configured)
3. Add proper cleanup in `-u` mode
4. **Pass the QA checklist below**
5. Register it in `setup-all.sh`:
   - Add to menu (both install and uninstall sections)
   - Add case statement entries
   - Add to `install_all()` and `uninstall_all()`
   - Add status check in `show_status()`

#### **Mandatory QA Checklist for New Scripts**

Before merging any new script:

- [ ] **Idempotency test**: Run `-i` twice, verify config file unchanged
- [ ] **sed safety**: All `&` in sed replacements are escaped as `\&`
- [ ] **grep safety**: All `\s` in grep use `-E` flag
- [ ] **Status check works**: `-s` correctly detects when installed
- [ ] **Uninstall works**: `-u` completely removes all traces
- [ ] **No duplicates**: Verify no duplicate lines in config after re-runs

## Important Files to Reference

- **README.md** - Contains detailed rationale for each design choice
- **`setup-keybindings.sh`** - Contains the clipboard `sed &` bug fix reference; see "Pitfalls" below
- **`setup-fonts.sh` / `setup-distrobox.sh`** - Good examples of proper guard patterns
- **`setup-all.sh`** - Shows how all scripts are orchestrated

## Dependencies

- **OS**: Omarchy Linux (Arch-based) with Hyprland
- **AUR helpers**: `paru` or `yay` (falls back to `sudo pacman`)
- **Wayland tools**: `wl-copy` (clipboard), `hyprctl` (Hyprland control)
