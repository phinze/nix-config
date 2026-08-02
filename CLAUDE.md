# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal Nix configuration repository that manages multiple machines using NixOS and nix-darwin. The owner primarily works in a tmux/neovim environment on NixOS VMs accessed via SSH, with macOS laptops as access points.

## Architecture

### Flake Structure
- `flake.nix` - Main entry point defining nixosConfigurations and darwinConfigurations
- `nixos/` - NixOS system configurations (foxtrotbase, xiezhi, simurgh, homegate)
- `nix-darwin/` - macOS system configurations (phinze-mrn-mbp)
- `home-manager/` - User environment configs shared across all machines
- `modules/` - Reusable modules for different platform types
- `overlays/` - Custom package overlays and modifications
- `pkgs/` - Custom packages

### Host Types
- **NixOS VMs**: Development environments with Docker, SSH, Tailscale
- **macOS laptops**: Managed by nix-darwin with Homebrew for GUI apps

### Key Technologies
- Nix flakes with inputs following nixpkgs stable and unstable
- Home Manager for user environment management
- Custom nixvim configuration (external flake)
- nix-index-database for command-not-found functionality
- Tailscale for networking between machines

## Common Commands

### Building and Switching Configurations

The owner uses `nh` (nix-helper) interactively for its nice TUI progress display. When Claude Code needs to build or switch configurations, use the direct nix commands below instead. They produce clean output without a TTY.

Do NOT use `-L` (print-build-logs) by default. It dumps every line of compiler output during builds, which can be tens of thousands of lines. Only add `-L` when diagnosing a specific build failure. Use `--show-trace` only when debugging evaluation errors.

**Quick eval check** (catches most config errors in seconds, no build):
```bash
# NixOS
nix eval .#nixosConfigurations.foxtrotbase.config.system.build.toplevel.drvPath

# Darwin
nix eval .#darwinConfigurations.phinze-mrn-mbp.system.drvPath
```

**Build without activating** (proves the full closure builds):
```bash
# NixOS
nix build .#nixosConfigurations.foxtrotbase.config.system.build.toplevel --no-link

# Darwin
nix build .#darwinConfigurations.phinze-mrn-mbp.system --no-link
```

**Build and switch** (actually apply the configuration):
```bash
# NixOS
sudo nixos-rebuild switch --flake .

# Darwin
darwin-rebuild switch --flake .
```

Substitute the appropriate hostname for other hosts (NixOS: foxtrotbase, xiezhi, simurgh, homegate; Darwin: phinze-mrn-mbp).

### Maintenance Commands

```bash
# Update flake inputs
nix flake update

# Update specific input
nix flake lock --update-input nixvim-config

# Format nix files
nix fmt

# Check flake
nix flake check
```

### Development Workflow

The owner uses a ghq-based directory structure under `~/src` for organizing git repositories, accessible through fish shell functions and tmux session management.

### Workspace-Centric Config Workflow

Treat a nix-config workspace as an isolated development environment. Keep the
fast feedback loop in that workspace, while the host-side `nix-config-sync`
service remains responsible for converging foxtrotbase onto committed `main`.

1. Use `nix eval` or `nix build` while editing. These do not alter the running
   system.
2. When runtime behavior matters, use
   `sudo nixos-rebuild test --flake .#foxtrotbase`. Use `test`, not `switch`,
   because the preview should not become the boot default.
3. While `origin/main` is unchanged, `nix-config-sync` recognizes that the
   active system differs from its recorded closure and treats it as a
   development preview. It leaves the preview active and pauses automatic
   input bumps.
4. Once the change is ready, land and push it to `main`, then run
   `nix-config-sync kick`. The command asks the user service to reconcile in the
   background and returns once systemd accepts the request. Follow the run with
   `nix-config-sync logs` when you want to watch it build and activate the new
   `main` revision.
5. A reconciliation run that deploys a new `main` revision stops there.
   Automatic input bumps resume on the next idle timer tick.

If another change lands on `main` during a preview, committed `main` wins. The
sync service replaces the preview with the newer revision. An abandoned
`nixos-rebuild test` preview also disappears on reboot because it never changed
the boot default.

### How the Sync Bumps Inputs

Three classes of flake input, and which one something belongs to is the whole
decision. `syncInputs` follow their branch and get bumped every tick.
`releaseInputs` follow their newest non-prerelease GitHub release: each tick
resolves `releases/latest` and rewrites the tag pinned in `flake.nix`, so the
input is always on a real release and never on anyone's `main`. Their URL must
be `github:owner/repo/TAG` — that string is where the repo and current tag are
read from. Everything else is manual on purpose (nixpkgs, home-manager, and the
other release-branch pins), and should stay that way.

The bump is no longer all-or-nothing. It still takes one build in the happy
path, but a failure now bisects the moved inputs to find which one is actually
at fault, benches it in `nix-config-sync-quarantine.json`, and lands the rest.
A benched input is retried once its window (`RETRY_AFTER`, 6h) elapses, and
un-benches itself the moment it builds. Skips are named in the commit body and
posted to `rig notify`, because the failure mode this replaced wasn't the
breakage, it was that the breakage was *silent* — one bad upstream froze every
other input for two days at one wasted build per hour.

`scripts/test-nix-config-sync` covers the bisect and quarantine paths by lifting
the functions out of the generated script and stubbing the builds. Run it when
you touch that logic; it only executes when an upstream is broken, so it is
exactly the code that rots unwatched. It has already caught one real bug.

### Updating Package Hashes

When updating packages in `pkgs/`, use this command to get the correct SRI hash format:
```bash
nix-prefetch-url <url> | xargs -I {} nix hash to-sri --type sha256 {}
```

This converts the base32 hash from `nix-prefetch-url` to the SRI format (`sha256-...=`) that Nix derivations expect.

## Claude Code Configuration

This repo is the source of truth for Claude Code configuration. Skills, CLAUDE.md files, and settings are managed declaratively via home-manager in `home-manager/phinze/claude-code.nix` and deployed as symlinks.

- **Global CLAUDE.md** → `home-manager/phinze/claude-global.md`
- **Skills** → `home-manager/phinze/claude-skills/*.md`
- **Settings, plugins, wiring** → `home-manager/phinze/claude-code.nix`

## Important Notes

- The repository uses Determinate Nix on macOS (nix.enable = false in darwin configs)
- SSH keys are managed in system configurations for inter-machine access
- Home-manager configurations are platform-aware using conditional logic
- All machines share the same user (phinze) with consistent shell environment
