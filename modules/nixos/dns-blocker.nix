# DNS-level ad/tracker/threat blocking via Blocky
#
# Designed to run on a Tailscale node and serve as the tailnet's
# global nameserver. Forwards *.ts.net queries back to MagicDNS
# so Tailscale hostnames keep working.
#
# After deploying, set this host's Tailscale IP as a Global Nameserver
# in the Tailscale admin console (DNS tab) with "Override local DNS" enabled.
{ config, pkgs, ... }:
let
  queryLogServer = pkgs.writeText "blocky-query-log-server.py" ''
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    from pathlib import Path
    from shutil import copyfileobj
    from urllib.parse import urlsplit

    LOG_DIRECTORY = Path("/var/log/blocky")


    class QueryLogHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            if urlsplit(self.path).path != "/queries.csv":
                self.send_error(404)
                return

            log_files = sorted(LOG_DIRECTORY.glob("*_ALL.log"))
            if not log_files:
                self.send_error(404, "No query log is available yet")
                return

            try:
                with log_files[-1].open("rb") as query_log:
                    size = query_log.seek(0, 2)
                    query_log.seek(0)
                    self.send_response(200)
                    self.send_header("Content-Type", "text/tab-separated-values; charset=utf-8")
                    self.send_header("Content-Length", str(size))
                    self.end_headers()
                    copyfileobj(query_log, self.wfile)
            except FileNotFoundError:
                self.send_error(404, "Query log rotated while it was being read")


    ThreadingHTTPServer(("0.0.0.0", 4001), QueryLogHandler).serve_forever()
  '';
in
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
          # "Focus mode" Ulysses-pact list. Normally empty; the blocky-allowlist
          # app on miren01 fills it with scroll-traps while focus mode is toggled
          # on, then empties it again on release. Deliberately a *separate* group
          # from `ads` so the temporary-allow escape hatch (which only whitelists
          # against `ads`) can't be used to dodge a focus block.
          focus = [
            "https://dns.inze.ph/focuslist.txt"
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
          "focus"
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
        target = "/var/log/blocky";
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

  # Lightweight HTTP server to expose Blocky's current daily query log at a
  # stable URL. It shares Blocky's DynamicUser so systemd grants it access to
  # the private LogsDirectory without making that directory globally readable.
  # The blocky-allowlist webapp on miren01 fetches this to show recent queries.
  systemd.services.blocky-query-log-server = {
    description = "Serve blocky query log CSV over HTTP";
    after = [
      "network.target"
      "blocky.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${queryLogServer}";
      User = "blocky";
      DynamicUser = true;
      LogsDirectory = "blocky";
      Restart = "always";
      RestartSec = 5;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };

  # Open HTTP API port + query log server port to tailnet
  networking.firewall.allowedTCPPorts = [
    4000
    4001
  ];
}
