# Tailscale exit node module
#
# Layers exit-node-specific configuration on top of baseline.nix,
# which already provides:
#   services.tailscale.enable = true
#   services.tailscale.useRoutingFeatures = "both"
{ config, pkgs, ... }:
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

  # Optimize UDP GRO forwarding for better Tailscale exit node throughput
  # See: https://tailscale.com/s/ethtool-config-udp-gro
  systemd.services.tailscale-udp-gro = {
    description = "Optimize UDP GRO forwarding for Tailscale";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.ethtool ];
    script = ''
      for iface in /sys/class/net/*; do
        iface=$(basename "$iface")
        [ "$iface" = "lo" ] && continue
        [ "$iface" = "tailscale0" ] && continue
        ethtool -K "$iface" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
      done
    '';
  };
}
