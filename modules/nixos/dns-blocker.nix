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
        {
          upstream = "https://one.one.one.one/dns-query";
          ips = [
            "1.1.1.1"
            "1.0.0.1"
          ];
        }
        {
          upstream = "https://dns.quad9.net/dns-query";
          ips = [
            "9.9.9.9"
            "149.112.112.112"
          ];
        }
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
            # Temporary allowlist served by blocky-allowlist on miren01 (dns.inze.ph)
            "https://dns.inze.ph/allowlist.txt"
          ];
        };
        clientGroupsBlock.default = [
          "ads"
          "threats"
        ];
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

      # Query log for the dns.inze.ph "Recent Queries" UI
      queryLog = {
        type = "csv";
        target = "/var/log/blocky/queries.csv";
        logRetentionDays = 1;
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

  # Lightweight HTTP server to expose the query log CSV to the tailnet.
  # The blocky-allowlist webapp on miren01 fetches this to show recent queries.
  # Blocky uses DynamicUser=true with LogsDirectory="blocky", which creates
  # /var/log/blocky (0755) with files readable by anyone. We run the file
  # server as nobody to keep it unprivileged.
  systemd.services.blocky-query-log-server = {
    description = "Serve blocky query log CSV over HTTP";
    after = [ "network.target" "blocky.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server 4001 --directory /var/log/blocky --bind 0.0.0.0";
      User = "nobody";
      Group = "nogroup";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Open HTTP API port + query log server port to tailnet
  networking.firewall.allowedTCPPorts = [ 4000 4001 ];
}
