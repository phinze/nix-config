{
  pkgs,
  lib,
  ...
}:
let
  # Zen Space Routing: which space (and so which container) a URL opens in.
  # This is what puts mirendev links from Slack or the terminal into the Miren
  # space; finicky just hands everything to Zen and stays out of it. Spaces are
  # named as they appear in Zen's sidebar and resolved to UUIDs at activation.
  # First match wins. `match` is one of contains, equal-to, or regex.
  spaceRouting = {
    routes = [
      {
        match = "regex";
        url = ''^https://github\.com/mirendev(/|$)'';
        space = "Miren";
      }
      {
        match = "regex";
        url = ''^https://github\.com/phinze(/|$)'';
        space = "Personal";
      }
    ];
    # Where external links matching no route go: a space name, or
    # most-recent-space for whichever space was last active.
    defaultExternal = "most-recent-space";
  };

  routesJson = pkgs.writeText "zen-space-routing.json" (builtins.toJSON spaceRouting);

  zen-routes = pkgs.writeShellScriptBin "zen-routes" ''
    if [ "$1" = apply ]; then
      exec ${pkgs.python3}/bin/python3 ${./zen-routes.py} apply ${routesJson}
    fi
    exec ${pkgs.python3}/bin/python3 ${./zen-routes.py} "$@"
  '';
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.packages = [ zen-routes ];

  # Zen owns this file and rewrites it from memory whenever its routing dialog
  # saves, so a symlink would be clobbered and a write under a running Zen
  # would be lost. zen-routes skips the write (and says so) while Zen is up;
  # quit Zen and run `zen-routes apply` to pick up a change. Routes added
  # through the dialog are dropped on the next apply: declare them here.
  home.activation.zenSpaceRouting = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${zen-routes}/bin/zen-routes apply
  '';
}
