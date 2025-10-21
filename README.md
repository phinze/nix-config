# My Nix Configs

This repository contains my Nix configuration files for all of my machines. This includes NixOS VMs and MacOS laptops managed by nix-darwin.

## How I work

I do most of my work SSHed into a NixOS VM running in my homelab. I use a `tmux` and `neovim` based development environment.

## Bootstrap and Private Packages

This configuration includes packages from private GitHub repositories (currently `iso` from `mirendev/iso`). These packages require GitHub authentication via `gh` to fetch during build.

### Normal Usage

Private packages are included by default. The configuration uses `git+https://` URLs which leverage the `gh` credential helper configured in the git settings.

```bash
# Standard rebuild includes private packages
nh os switch .        # NixOS
nh darwin switch .    # macOS
```

### Bootstrap Scenario

When setting up a new machine before `gh auth login` has been run, you can skip private packages:

```bash
# Skip private packages during initial setup
SKIP_PRIVATE_PACKAGES=1 nh os switch .

# After setup, authenticate with GitHub
gh auth login

# Rebuild to include private packages
nh os switch .
```

The private packages are conditionally included via `builtins.getEnv "SKIP_PRIVATE_PACKAGES"` check in the home-manager configuration.

## Using this repo

These configs are not designed for anybody else but me to use, but you're welcome to look through them and ask questions if you like.

Reading other people's published configs is a major part of how I've learned Nix, and so I publish my configs in that same spirit of shared knowledge and learning.

If you're looking for a starting point, I'd recommend [Misterio77's starter configs](https://github.com/Misterio77/nix-starter-configs), which is what I used as the starting point for this repo.
