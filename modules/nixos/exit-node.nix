# Tailscale exit node module
#
# Layers exit-node-specific configuration on top of baseline.nix,
# which already provides:
#   services.tailscale.enable = true
#   services.tailscale.useRoutingFeatures = "both"
{ config, ... }:
{
  # IP forwarding for exit node traffic
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Auto-join tailnet on first boot using auth key from cloud-init
  services.tailscale.authKeyFile = "/etc/tailscale/authkey";

  # Advertise as an exit node (applied by tailscaled-autoconnect via authKeyFile)
  services.tailscale.extraUpFlags = [ "--advertise-exit-node" ];

  # Clean up the auth key after tailscale has connected
  systemd.services.tailscale-authkey-cleanup = {
    after = [ "tailscaled-autoconnect.service" ];
    requires = [ "tailscaled-autoconnect.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      rm -f /etc/tailscale/authkey
    '';
  };

  # NAT/masquerade so forwarded traffic can reach the internet
  networking.nat = {
    enable = true;
    internalInterfaces = [ "tailscale0" ];
    externalInterface = "ens18"; # Proxmox virtio default
  };

  # Firewall: allow Tailscale, block everything else from the outside
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };
}
