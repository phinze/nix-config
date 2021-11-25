{ config, pkgs, ... }: {
  imports = [
    ./vm-shared.nix
  ];

  networking.hostName = pkgs.lib.mkForce "tunnel";

  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "${pkgs.i3}/bin/i3";
  networking.firewall.allowedTCPPorts = [ 3389 ];

  networking.interfaces.ens18.useDHCP = true;
}
