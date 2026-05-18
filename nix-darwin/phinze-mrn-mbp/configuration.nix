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
    inputs.camlink-fix.darwinModules.default
    inputs.belowdeck.darwinModules.default
  ];

  networking.hostName = "phinze-mrn-mbp";

  # Cam Link 4K auto-fix on wake
  # Automatically resets the camera via USB power cycle when it becomes
  # unresponsive after sleep. Requires Cam Link to be plugged into a
  # uhubctl-compatible USB hub (VIA Labs chipset). Hub location and port
  # are discovered dynamically at runtime.
  services.camlink-fix = {
    enable = true;
    notify = true;
  };

  # Stream Deck Plus daemon
  # Secrets (API keys, tokens) are stored in macOS Keychain via `belowdeck setup`
  services.belowdeck = {
    enable = true;
    settings = {
      weather = {
        lat = "41.94358";
        lon = "-87.72418";
      };
      homeassistant = {
        server = "https://homeassistant.versa.inze.ph/";
        ring_light_entity = "light.elgato_dw01m1a02715";
        office_light_entity = "light.signe_gradient_floor_1";
      };
    };
  };

  # Add host-specific homebrew casks
  homebrew.casks = lib.mkAfter (config.home-manager.extraSpecialArgs.nodeConfig.extraCasks or [ ]);
}
