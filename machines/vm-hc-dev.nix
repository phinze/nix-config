{ config, pkgs, ... }: {
  imports = [
    ./vm-shared.nix
  ];

  networking.hostName = pkgs.lib.mkForce "hc-dev";

  networking.interfaces.ens18.useDHCP = true;

  # Enable qemu guest agent
  services.qemuGuest.enable = true;

  # Virtualbox for Vagrant dev
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = ["phinze"];

  # libvirt / qemu for Vagrant dev
  virtualisation.libvirtd.enable = true;
  users.extraGroups.libvirtd.members = ["phinze"];

  # NFS for Vagrant dev
  services.nfs.server = {
    enable = true;
    # fixed rpc.statd port; for firewall
    lockdPort = 4001;
    mountdPort = 4002;
    statdPort = 4000;
    extraNfsdConfig = '''';
  };
  networking.firewall.allowedTCPPorts = [ 2049 111 4000 4001 4002 ];
  networking.firewall.allowedUDPPorts = [ 2049 111 4000 4001 4002 ];
}
