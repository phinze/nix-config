# Rex server on a headless NixOS host. On Linux Rex is only the server; the
# Mac app reaches it with Add Remote Host… at https://<host>.<tailnet>.ts.net.
#
# The login server is the mode even with one user. It's the only one that
# both runs Rex as phinze (the shared server runs everything as a `rex` system
# account) and rides the host's own Tailscale via Serve (a personal server can
# only go remote through Rex's built-in Tailscale, which joins the tailnet as
# a second device). On a logind host the account's server is the same personal
# server local `rex` commands use, so both see the same sessions, and those
# sessions survive the login server restarting when the sync bumps the input.
{ inputs, ... }:
{
  imports = [ inputs.rex.nixosModules.default ];

  # Until Rex's first stable release, pkgs.superlogical.com wants the alpha
  # package token to fetch the `rex` flake input. It lives in this file, put
  # there by hand from 1Password (never the store, never this repo):
  #
  #   machine pkgs.superlogical.com login rex password <token>
  #
  # Flake inputs are fetched by the evaluating nix process, which is phinze's
  # shell and the nix-config-sync user service, not the daemon. So the file is
  # root:wheel 0640 rather than root-only. /etc/nix/netrc is already nix's
  # default; it's spelled out so the dependency is visible from here.
  nix.settings.netrc-file = "/etc/nix/netrc";

  services.rex.loginServer = {
    enable = true;
    accounts.phinze.principals = [ "tailscale:phinze@github" ];
    tailscaleServe.enable = true;
  };
}
