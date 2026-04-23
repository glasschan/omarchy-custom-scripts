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
| `setup-keybindings.sh` | Custom screenshot/recording/clipboard bindings | `~/.config/hypr/bindings.conf` |
| `fix-chrome-keyring.sh` | Fix Chrome keyring password popup | `~/.local/share/keyrings/*` |
| `setup-gaming.sh` | Game compatibility for Wayland/Hyprland | `~/.config/hypr/envs.conf`, `~/.config/hypr/games.conf`, installs `gamescope` |

### Common Patterns Across All Scripts

1. **Helper functions at top**: `info()`, `warn()`, `error()`, `detail()`, `header()` - all use ANSI colors
2. **Idempotent checks**: Always check if already installed/configured before making changes
3. **Package detection**: Uses `pacman -Q pkgname` to check for existing packages
4. **AUR helper fallback**: `paru` → `yay` → `sudo pacman`
5. **No interactive prompts during install** (except confirmations for optional features)

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
4. Register it in `setup-all.sh`:
   - Add to menu (both install and uninstall sections)
   - Add case statement entries
   - Add to `install_all()` and `uninstall_all()`
   - Add status check in `show_status()`

## Important Files to Reference

- **README.md** - Contains detailed rationale for each design choice
- **`setup-keybindings.sh`** - Good example of proper script structure
- **`setup-all.sh`** - Shows how all scripts are orchestrated

## Dependencies

- **OS**: Omarchy Linux (Arch-based) with Hyprland
- **AUR helpers**: `paru` or `yay` (falls back to `sudo pacman`)
- **Wayland tools**: `wl-copy` (clipboard), `hyprctl` (Hyprland control)
