---
name: nix-config
description: Map of Paul's nix-config (machine, home-manager, and Claude config) and how a change actually reaches a host via nix-config-sync. Load when changing machine config from any repo, when a change to a flake input repo (recto, pim-stuff, rig, nixvim-config, ...) needs to reach a machine, before reaching for nixos-rebuild, darwin-rebuild, nh os switch, or nix flake update, or when asked to "kick the sync", deploy, or pick up a new version.
---

# nix-config

`phinze/nix-config` holds every machine's config. Its `CLAUDE.md` has the
details. This is the map for getting around it, and for getting a change onto
a machine, from wherever you happen to be.

## Where things live

Work in a rig (`rig add phinze/nix-config`) or a jj workspace, not in
`~/src/github.com/phinze/nix-config`. The sync moves `main` under that
checkout.

- `nixos/<host>/`, `nix-darwin/phinze-mrn-mbp/`: system config per host
- `home-manager/phinze/`: the user environment shared across hosts
- `home-manager/phinze/claude-*`: Claude Code config, with skills in
  `claude-skills/`, global instructions in `claude-global.md`, and wiring in
  `claude-code.nix`. chief-of-staff and personal-tasks live in the private
  `agent-private` input instead, because they name Paul's own domains and
  hosts
- `flake.nix`: inputs, including Paul's own repos (recto, rig, pim-stuff, ...)

Flake inputs come in three kinds. Which kind an input is decides who moves
it. Inputs in `syncInputs` and `releaseInputs`
(`home-manager/phinze/modules/nix-config-sync.nix`) are bumped by the
foxtrotbase sync, which is their only integrator. The one exception is a
nix-config change that needs the new version to evaluate. In that case, bump
just that input in the same commit. Everything else (nixpkgs, home-manager,
...) moves by hand, when Paul decides.

## How a change lands

The sync deploys committed `main`. Agents don't switch hosts by hand. Some
downstream repo docs still say `nh os switch`, and those docs are stale.

- **A nix-config change:** eval or build in your workspace, then push to
  `main` and run `nix-config-sync kick`. When you need to try it live first,
  `sudo nixos-rebuild test --flake .#foxtrotbase` gives you a preview. The
  sync leaves the preview alone until `main` moves.
- **An upstream input change** (say, recto): push that repo and kick. The
  sync bumps the input and deploys it. A run that deploys a new `main` stops
  before the bump, so pushing to both repos takes two kicks.
- **The Mac** builds `main` but never bumps inputs. Kick it after
  foxtrotbase's bump lands: `ssh phinze-mrn-mbp nix-config-sync kick`. It
  builds only on AC power, and it waits for Paul to click **Install**. See
  `nix-darwin/phinze-mrn-mbp/SYNC.md`.
- **xiezhi, simurgh and homegate** have no sync. Ask Paul.

## Watching and verifying

`nix-config-sync logs` follows forever, so it will hang a foreground shell.
For a bounded read, use
`journalctl --user -u nix-config-sync.service --since -10min --no-pager`.

- **foxtrotbase is done** when the log shows `origin/main <sha> is active`.
  `~/.local/state/nix-config-sync-deployment` records the deployed rev and
  the system path.
- **The Mac is done** when `nix-config-sync status` shows `Installed <sha>`.
- A bump marked `SKIPPED (build failed)` has been benched in
  `~/.local/state/nix-config-sync-quarantine.json` and retries after 6h. The
  journal has the build error.

Pushing isn't the same as deploying. Report the change as landed once the
host says it is, and once you've seen the change itself working.
