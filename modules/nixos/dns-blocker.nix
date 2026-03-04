# DNS-level ad/tracker/threat blocking via Blocky
#
# Designed to run on a Tailscale node and serve as the tailnet's
# global nameserver. Forwards *.ts.net queries back to MagicDNS
# so Tailscale hostnames keep working.
#
# After deploying, set this host's Tailscale IP as a Global Nameserver
# in the Tailscale admin console (DNS tab) with "Override local DNS" enabled.
{ config, pkgs, ... }:
{
  # Disable systemd-resolved so Blocky can bind port 53
  services.resolved.enable = false;

  services.blocky = {
    enable = true;
    settings = {
      ports = {
        dns = 53;
        http = 4000;
      };

      upstreams = {
        groups.default = [
          "https://one.one.one.one/dns-query"
          "https://dns.quad9.net/dns-query"
        ];
        strategy = "parallel_best";
        timeout = "2s";
      };

      bootstrapDns = [
        { upstream = "https://one.one.one.one/dns-query"; ips = [ "1.1.1.1" "1.0.0.1" ]; }
        { upstream = "https://dns.quad9.net/dns-query"; ips = [ "9.9.9.9" "149.112.112.112" ]; }
      ];

      # Forward Tailscale MagicDNS queries so tailnet hostnames resolve
      conditional.mapping = {
        "ts.net" = "100.100.100.100";
        "100.in-addr.arpa" = "100.100.100.100";
      };

      blocking = {
        denylists = {
          ads = [
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro.txt"
          ];
          threats = [
            "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/tif.txt"
          ];
        };
        allowlists = {
          ads = [
            # Local allowlist for temporary unblocking via the API tool
            "/var/lib/blocky/allowlist.txt"
          ];
        };
        clientGroupsBlock.default = [ "ads" "threats" ];
        blockType = "zeroIp";
        blockTTL = "1m";
        loading = {
          refreshPeriod = "4h";
          strategy = "fast";
          downloads = {
            timeout = "60s";
            attempts = 5;
            cooldown = "10s";
          };
        };
      };

      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
        prefetchExpires = "2h";
        prefetchThreshold = 5;
      };

      prometheus = {
        enable = true;
        path = "/metrics";
      };

      log = {
        level = "info";
        format = "text";
        timestamp = true;
      };
    };
  };

  # Ensure the local allowlist file exists so Blocky doesn't complain
  systemd.tmpfiles.rules = [
    "f /var/lib/blocky/allowlist.txt 0644 root root -"
  ];

  # Open HTTP API port to tailnet (DNS 53 is already covered by trustedInterfaces)
  networking.firewall.allowedTCPPorts = [ 4000 ];
}
