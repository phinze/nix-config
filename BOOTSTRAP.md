# Bootstrapping a wiped Mac

The order is load-bearing. GitHub auth has to come before the first switch,
because private flake inputs are fetched at evaluation time and evaluation
fails without it. Homebrew and 1Password have to be installed by hand, because
they are prerequisites of the switch that would otherwise install them.

## What the switch already sets

No need to make any of this permanent yourself:

- Caps Lock remapped to Control
- Natural scrolling off
- Dock autohidden, hot corners disabled, persistent apps cleared, Downloads
  pinned as a stack
- Analog menu bar clock
- Touch ID for `sudo`, including inside tmux via `pam_reattach`
- File descriptor limit raised to 524288
- All three machine names (`ComputerName`, `LocalHostName`, `HostName`)

Caps Lock lands the moment the switch runs, applied with `hidutil property
--set` from an activation script and re-applied at boot, so it needs no logout.
The rest are `defaults write` calls and activation only restarts the Dock, so
log out once afterward to pick up natural scrolling and the other
`NSGlobalDomain` settings.

Set Caps Lock in System Settings if you want it before then. The switch
converges it either way.

Machine names are set at step 7, before Tailscale logs in at step 9, so they
need no attention. The exception is bringing Tailscale up early to work
remotely during the long build: a node keeps whatever name it registered with,
so set the names first if you do that.

```bash
sudo scutil --set ComputerName phinze-mrn-mbp
sudo scutil --set LocalHostName phinze-mrn-mbp
sudo scutil --set HostName phinze-mrn-mbp
```

## 1. macOS Setup Assistant, and the old tailnet node

Sign into iCloud, and sign into the App Store specifically, since `mas`
installs `homebrew.masApps` during the switch and needs an account.

If one of them fails with

    Error: No apps found in the App Store for ADAM ID <id>

the ID has most likely been retired rather than anything being wrong with the
account. Check `https://apps.apple.com/us/app/id<id>`: a 404 means it is dead.
Apple folds apps into new universal listings and drops the old Mac-only IDs, so
an entry that worked for years can stop resolving. Already-installed titles
report `Using <name>` and are skipped, so this only surfaces on a machine that
actually has to download the app.

If this machine is already in the tailnet, delete the old node from the
Tailscale admin console now. The name is otherwise taken when the new machine
joins and you get `phinze-mrn-mbp-2` permanently.

## 2. Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

No need to run `xcode-select --install` first. The installer handles the
Command Line Tools: a headless `softwareupdate -i`, falling back to
`xcode-select --install` with a GUI popup, then `xcode-select --switch` either
way. That also provides `/usr/bin/git` for step 6.

nix-darwin's `homebrew.*` options manage the Brewfile but do not install
Homebrew. Without it, activation prints `error: Homebrew is not installed,
skipping...` and carries on, so the switch reports success and you are left
with none of the casks. It does not fail, which makes it easy to miss.

## 3. 1Password, and its SSH agent

```bash
brew install --cask 1password
```

Sign in, then open Settings → Developer and turn on **Use the SSH agent**.
Verify the socket:

```bash
ls ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

Nothing can declare this for you. `programs.ssh` points `IdentityAgent` at that
socket and all commit signing goes through it (`modules/git-signing.nix`), so
Nix can write the config that references the socket but cannot create it.

Install it by hand rather than waiting for the declared cask, because you need
a password manager to log into GitHub at step 5.

## 4. Determinate Nix

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
```

Determinate specifically, not the upstream installer. `nix-darwin/common.nix`
sets `nix.enable = false` to hand daemon and `/etc/nix/nix.conf` ownership to
Determinate; upstream Nix fights it over the same files.

Open a new shell afterward so `/nix/var/nix/profiles/default/bin` is on PATH.

## 5. gh, authenticated, with the credential helper wired up

```bash
nix profile add nixpkgs#gh
gh auth login
git config --global credential.helper "!$HOME/.nix-profile/bin/gh auth git-credential"
```

Install gh into the profile rather than using `nix run`. The credential helper
has to invoke a gh that still exists later, and the helper is what lets Nix
fetch the private `git+https` inputs, since Nix shells out to `git` and git
reads the global config.

`gh` stores its token in the login keychain, which releases it only to the
exact binary that asked. Expect a keychain prompt the first time git uses the
helper, and click **Always Allow**. Denied access surfaces as an invalid token
rather than a permissions error, so it is worth recognising.

`nix profile add nixpkgs#gh` works on a bare Determinate install with no
checkout, because its `extra-nix-path` points `nixpkgs` at a FlakeHub weekly
snapshot.

## 6. Clone the config

```bash
mkdir -p ~/src/github.com/phinze
git clone https://github.com/phinze/nix-config.git ~/src/github.com/phinze/nix-config
cd ~/src/github.com/phinze/nix-config
```

Use the ghq path under `~/src`, not `/tmp`, which macOS sweeps.

Confirm auth works before committing to a long build:

```bash
nix eval .#darwinConfigurations.phinze-mrn-mbp.system.drvPath
```

A `.drv` path means the private inputs are fetching. `Failed to fetch git
repository` means step 5 did not take.

## 7. First switch

There is no `darwin-rebuild` yet, and `nh` arrives with home-manager. Build the
system closure using the nix-darwin pinned in `flake.lock`, then run the
`darwin-rebuild` that falls out of it:

```bash
nix build .#darwinConfigurations.phinze-mrn-mbp.system
sudo ./result/sw/bin/darwin-rebuild switch --flake .
```

Prefer this to `sudo nix run nix-darwin -- switch`, which resolves an unpinned
nix-darwin that need not match what the config expects.

The build is pure nix and touches Homebrew not at all; it only produces the
generated Brewfile. Casks, formulae and Mac App Store apps are installed by
`brew bundle`, which nix-darwin runs from an activation script during the
switch. So expect the long tail of downloads to arrive in the second command,
not the first.

Files you wrote by hand that home-manager also manages are moved aside rather
than clobbered: `backupFileExtension = "nix-backup"`, so `~/.ssh/config`
becomes `~/.ssh/config.nix-backup`.

Every rebuild after this one is `nh darwin switch .`.

## 8. Make fish the login shell

nix-darwin's `users.users.<name>.shell` does not actually change the shell
(LnL7/nix-darwin#779), so do it once by hand:

```bash
echo /etc/profiles/per-user/phinze/bin/fish | sudo tee -a /etc/shells
chsh -s /etc/profiles/per-user/phinze/bin/fish
```

## 9. Sign in and grant permissions

None of this is declarable:

- **Tailscale**: open the app and log in.
- **Karabiner-Elements**: Input Monitoring and Accessibility, then approve its
  system extension in Login Items.
- **Raycast, Rectangle, CleanShot, iStat Menus**: Accessibility and Screen
  Recording, plus their licences.
- **belowdeck**: `belowdeck setup` to put API keys in the macOS Keychain. The
  Stream Deck settings in `configuration.nix` assume they are there.
- **Colima**: `colima start` on first use, or let the launchd agent handle it.
- **atuin**: `atuin login` to sync shell history.

Once the switch has landed, `nix profile remove gh`. Home-manager provides it
from then on.
