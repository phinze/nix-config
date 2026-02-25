# homegate — dedicated Tailscale exit node on Proxmox
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/baseline.nix
    ../../modules/nixos/exit-node.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "homegate";

  services.qemuGuest.enable = true;

  system.stateVersion = "25.05";
}
