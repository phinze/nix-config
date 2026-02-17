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

  # Syncthing CLI for manually triggering scans
  environment.systemPackages = [
    pkgs.syncthing
  ];

  # Add host-specific homebrew casks
  homebrew.casks = lib.mkAfter (config.home-manager.extraSpecialArgs.nodeConfig.extraCasks or [ ]);

  # Syncthing for syncing CleanShot screenshots to NixOS VM
  # Using Homebrew since nix-darwin doesn't have services.syncthing
  homebrew.brews = lib.mkAfter [
    {
      name = "syncthing";
      start_service = true; # Auto-start as a background service
    }
  ];

  # One-time setup instructions (do this after applying the config):
  # 1. Visit http://localhost:8384 on Mac
  # 2. Click "Actions" → "Show ID" and copy your Mac's device ID
  # 3. SSH to foxtrotbase and visit http://localhost:8384
  # 4. Click "Add Remote Device" and paste the Mac's device ID
  # 5. On Mac, accept the connection from foxtrotbase
  # 6. On Mac, add folder: ~/Library/Application Support/CleanShot/media
  #    - Set as "Send Only"
  #    - Share with foxtrotbase
  #    - Add ignore patterns: .DS_Store, *.tmp, *.cache, .cleanshot-*
  # 7. On foxtrotbase, accept the folder share
  #    - Set path to: ~/Library/Application Support/CleanShot/media
  #    - Will automatically be "Receive Only" since Mac is send-only
  # 8. In Syncthing settings (both sides), configure for Tailscale:
  #    - Actions → Settings → Connections
  #    - Disable "Global Discovery"
  #    - Disable "Enable Relaying"
  #    - Disable "Enable NAT traversal"
  #    - Keep "Local Discovery" enabled
  #
  # This config will persist across rebuilds!
}
