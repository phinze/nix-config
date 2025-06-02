# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal Nix configuration repository that manages multiple machines using NixOS and nix-darwin. The owner primarily works in a tmux/neovim environment on NixOS VMs accessed via SSH, with macOS laptops as access points.

## Architecture

### Flake Structure
- `flake.nix` - Main entry point defining nixosConfigurations and darwinConfigurations
- `nixos/` - NixOS system configurations for VMs (foxtrotbase, victormike)
- `nix-darwin/` - macOS system configurations (manticore, phinze-mrn-mbp)
- `home-manager/` - User environment configs shared across all machines
- `modules/` - Reusable modules for different platform types
- `overlays/` - Custom package overlays and modifications
- `pkgs/` - Custom packages

### Host Types
- **NixOS VMs**: Development environments with Docker, SSH, Tailscale
- **macOS laptops**: Managed by nix-darwin with Homebrew for GUI apps

### Key Technologies
- Nix flakes with inputs following nixpkgs stable (24.11) and unstable
- Home Manager for user environment management
- Custom nixvim configuration (external flake)
- nix-index-database for command-not-found functionality
- Tailscale for networking between machines

## Common Commands

### Building and Switching Configurations

For NixOS systems:
```bash
# Build and switch on the current machine
sudo nixos-rebuild switch --flake .

# Build and switch a specific host
sudo nixos-rebuild switch --flake .#foxtrotbase
```

For macOS systems:
```bash
# Build and switch darwin configuration
darwin-rebuild switch --flake .

# Build and switch specific host
darwin-rebuild switch --flake .#phinze-mrn-mbp
```

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

## Important Notes

- The repository uses Determinate Nix on macOS (nix.enable = false in darwin configs)
- SSH keys are managed in system configurations for inter-machine access
- Home-manager configurations are platform-aware using conditional logic
- All machines share the same user (phinze) with consistent shell environment