# Configuration sync on phinze-mrn-mbp

The Mac deploys committed `main`. Foxtrotbase remains the only automated input
integrator: this job never updates flake inputs, commits, or pushes. It uses its
own checkout under `~/.local/state/nix-config-sync-darwin`, not a development
workspace.

At 17 minutes past every even-numbered hour, and when its LaunchAgent loads, the
job checks for changes. Missed calendar events coalesce into one check on wake.
On battery it skips the check. On AC power it fetches and builds the Mac system
as the logged-in user, with lockfile updates and writes disabled. An unchanged
revision or an already active closure doesn't produce an install prompt.

Once a build is ready, a notification offers **Install** for 15 minutes. Clicking
the notification body, dismissing it, or letting it expire does not install
anything. The next scheduled run or manual kick can offer it again. A single
notification group keeps offers from piling up.

Install starts a separate one-shot LaunchAgent. It uses the same lock as the
scheduled job, then asks for the normal sudo Touch ID prompt without opening
Terminal. `sudo -S -v` runs with stdin closed: the existing `pam_reattach` and
`pam_tid` configuration supplies Touch ID, but password fallback cannot wait
for invisible input. Cancellation or unavailable authentication defers the
install and posts a notification. No passwordless sudo rule is added.

After authentication, the installer checks power and the active system again.
It activates the exact closure offered using `sudo -n`, so activation cannot
produce a second authentication prompt. It does not fetch newer code after
approval. Newer `main` revisions wait for the next run.

The temporary installer agent isn't managed by Home Manager, so replacing the
scheduled agent doesn't terminate activation. Its plist explicitly disables
KeepAlive; a failure must not restart authentication or activation. On ordinary
exit it removes its plist and unloads itself. A crash that bypasses cleanup can
leave a stopped job and plist until logout or manual cleanup, but does not
restart the install.

Unplugging during a build lets that build finish but suppresses the offer.
Unplugging before activation defers installation. Once activation starts, the
job does not interrupt it, even if power disconnects. Authentication cancellation
or activation failure leaves the last successful deployment record unchanged.
Activation is not transactional: failures may leave partial changes, including
a changed system profile, and need inspection before retrying.

## Commands

- `nix-config-sync kick` asks launchd to check now, without bypassing AC power.
  If a check is already running or waiting for a click, it remains that check;
  kick doesn't kill it or start a competing run.
- `nix-config-sync status` prints the last recorded phase and timestamp. This
  is a record, not a live process-health check; an interrupted run can leave an
  old phase behind.
- `nix-config-sync logs` follows the agent and install logs in
  `~/Library/Logs/nix-config-sync/`.

If the active system differs from the last recorded deployment while `main`
hasn't changed, sync preserves that manual configuration. A new `main` can
produce a new offer, but still needs an Install click. A manual activation after
an offer invalidates that offer rather than silently overwriting the preview.

## First use

After deploying this configuration, allow terminal-notifier to send
notifications. Choose Banners or Alerts in System Settings → Notifications →
terminal-notifier. A button can require hovering over a banner; Alerts keep it
visible. Focus and notification settings can suppress delivery. Without an
Install click, no authentication or activation happens.

Homebrew installs `terminal-notifier`; there is no custom Nix package. Sync uses
`/opt/homebrew/bin/terminal-notifier` directly. Home activation registers the
Homebrew app bundle with LaunchServices
before starting the agent; without registration macOS can reject even the
permission request. After a Homebrew upgrade, notification permissions may
need checking again.

Homebrew updates and cleanup remain part of the normal Darwin activation. An
Install click approves that activation too, not just a Nix profile change.

## Validation

Run `scripts/test-nix-config-sync-darwin` for mocked reconciliation and install
tests. These cover power changes, previews, unchanged closures, failed builds,
notification dismissal, expired offers, authentication cancellation, and failed
activation without invoking sudo or changing a real system.

Build the generated command to run its ShellCheck validation, and evaluate both
host configurations to check that the Darwin module doesn't change the Linux
integrator. The native launchd test uses an unprivileged fake activation to
check background handoff and cleanup. Notification delivery, Touch ID, and a
real system activation still require an interactive smoke test on the Mac.

`scripts/prototype-nix-sync-auth /opt/homebrew/bin/terminal-notifier sudo-touch-id`
offers an Install button and checks the background sudo route by running only
`id -u` as root. The earlier `native` mode uses AppleScript administrator
authorization, which produced a password prompt instead of Touch ID on this
Mac.
