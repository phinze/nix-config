{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../common.nix
    inputs.understudy.darwinModules.default
    inputs.belowdeck.darwinModules.default
  ];

  # macOS keeps three separate names and nix-darwin maps one option to each:
  # hostName -> HostName, computerName -> ComputerName, localHostName ->
  # LocalHostName. Declaring only hostName left the other two at whatever Setup
  # Assistant guessed, which a wipe makes visible. Tailscale reads the machine
  # name when it registers a node and keeps it thereafter, so setting all three
  # here means a rebuilt machine joins the tailnet correctly named.
  networking.hostName = "phinze-mrn-mbp";
  networking.computerName = "phinze-mrn-mbp";
  networking.localHostName = "phinze-mrn-mbp";

  # Understudy keeps the Cam Link 4K usable. Meeting apps use the
  # "Understudy" virtual camera; the agent behind it is the real Cam Link's
  # only client and power-cycles it (uhubctl, VIA Labs hub) when its own
  # frames stop, while the app sees a card instead of a dead device. Needs
  # Understudy.app installed via understudy's mac/bundle.sh --install; until
  # then the agent just doesn't run. `understudy kick` forces a reset.
  services.understudy = {
    enable = true;
    notify = true;
  };

  # Stream Deck Plus daemon
  # Secrets (API keys, tokens) are stored in macOS Keychain via `belowdeck setup`
  services.belowdeck = {
    enable = true;
    settings = {
      weather = {
        inherit (inputs.nix-private.data.location) lat lon;
      };
      homeassistant = {
        server = "https://homeassistant.versa.inze.ph/";
        ring_light_entity = "light.elgato_dw01m1a02715";
        office_light_entity = "light.signe_gradient_floor_1";
      };
    };
  };

  # Claim xterm-rex outright rather than via Rex's ssh guard. An agent rather
  # than launchd.user.envVariables, which only setenvs during activation and
  # so is gone after a reboot.
  launchd.user.agents.rex-term.serviceConfig = {
    ProgramArguments = [
      "/bin/launchctl"
      "setenv"
      "REX_TERM"
      "xterm-rex"
    ];
    RunAtLoad = true;
  };

  # The terminfo to go with that claim (by path: no `additions` overlay here).
  environment.systemPackages = [ (pkgs.callPackage ../../pkgs/rex-terminfo { }) ];

  homebrew.brews = [ "terminal-notifier" ];

  # Add host-specific homebrew casks
  homebrew.casks = lib.mkAfter (config.home-manager.extraSpecialArgs.nodeConfig.extraCasks or [ ]);
}
