# cmux CLI on PATH.
#
# cmux runs on its self-updating "nightly" channel, installed out-of-band as
# /Applications/cmux NIGHTLY.app and kept current by its own Sparkle updater.
# A nix-store copy can't self-update (read-only), and Homebrew's stable `cmux`
# cask tracks only release builds while wiring its CLI symlink to the wrong
# bundle. So we don't try to own the app: the cask is dropped (see
# common.nix) and nix owns just the `cmux` CLI symlink, pointing at the
# nightly bundle's CLI. If the app moves or the channel name changes, update
# cmuxApp below.
{ pkgs, ... }:
let
  cmuxApp = "/Applications/cmux NIGHTLY.app";
  cmux-cli = pkgs.runCommand "cmux-cli" { } ''
    mkdir -p "$out/bin"
    ln -s "${cmuxApp}/Contents/Resources/bin/cmux" "$out/bin/cmux"
  '';
in
{
  environment.systemPackages = [ cmux-cli ];
}
