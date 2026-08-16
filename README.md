# My Nix Configs

This repository contains my Nix configuration files for all of my machines. This includes NixOS VMs and MacOS laptops managed by nix-darwin.

## How I work

I do most of my work SSHed into a NixOS VM running in my homelab. I use a `tmux` and `neovim` based development environment.

## Setting up a new machine

See [BOOTSTRAP.md](BOOTSTRAP.md). Several flake inputs live in private GitHub repos and are fetched over `git+https`, so an authenticated `gh` is a hard prerequisite rather than something you get to defer — evaluation fails without it, well before any package is built.

## Everyday rebuilds

```bash
nh os switch .        # NixOS
nh darwin switch .    # macOS
```

## Using this repo

These configs are not designed for anybody else but me to use, but you're welcome to look through them and ask questions if you like.

Reading other people's published configs is a major part of how I've learned Nix, and so I publish my configs in that same spirit of shared knowledge and learning.

If you're looking for a starting point, I'd recommend [Misterio77's starter configs](https://github.com/Misterio77/nix-starter-configs), which is what I used as the starting point for this repo.
