{
  config,
  lib,
  pkgs,
  nodeConfig ? { },
  ...
}:
let
  stateDir = "${config.home.homeDirectory}/.local/state/nix-config-sync-darwin";
  logDir = "${config.home.homeDirectory}/Library/Logs/nix-config-sync";
  activate = pkgs.writeShellApplication {
    name = "nix-config-sync-activate";
    text = ''
      if [[ $# -ne 1 || ! "$1" =~ ^/nix/store/[a-z0-9]{32}-[^/]+$ || ! -x "$1/sw/bin/darwin-rebuild" ]]; then
        echo "Expected a built Darwin system store path" >&2
        exit 2
      fi
      /nix/var/nix/profiles/default/bin/nix-env -p /nix/var/nix/profiles/system --set "$1"
      exec "$1/sw/bin/darwin-rebuild" activate
    '';
  };
  sync = pkgs.writeShellApplication {
    name = "nix-config-sync";
    runtimeInputs = [
      pkgs.git
      pkgs.coreutils
      pkgs.jq
      pkgs.gh
    ];
    text = ''
      export PATH="$PATH:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      STATE_DIR=${lib.escapeShellArg stateDir}
      LOG_DIR=${lib.escapeShellArg logDir}
      NOTIFIER=/opt/homebrew/bin/terminal-notifier
      ACTIVATOR=${lib.escapeShellArg "${activate}/bin/nix-config-sync-activate"}
      HOST=phinze-mrn-mbp
      LABEL=org.nix-community.home.nix-config-sync
      ${builtins.readFile ./nix-config-sync-darwin.sh}
      main "$@"
    '';
  };
in
lib.mkIf (pkgs.stdenv.isDarwin && (nodeConfig.isNixConfigDeployHost or false)) {
  home.packages = [ sync ];
  home.activation.nixConfigSyncSetup =
    lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ]
      ''
        run mkdir -p ${lib.escapeShellArg logDir}
        run /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
          -f /opt/homebrew/opt/terminal-notifier/terminal-notifier.app
      '';
  launchd.agents.nix-config-sync = {
    enable = true;
    config = {
      ProgramArguments = [
        "${sync}/bin/nix-config-sync"
        "run"
      ];
      StartCalendarInterval = map (hour: {
        Hour = hour * 2;
        Minute = 17;
      }) (lib.range 0 11);
      RunAtLoad = true;
      StandardOutPath = "${logDir}/agent.log";
      StandardErrorPath = "${logDir}/agent.log";
      ProcessType = "Background";
    };
  };
}
