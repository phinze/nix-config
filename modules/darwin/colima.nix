{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.colima;
in {
  options.services.colima = {
    enable = mkEnableOption "Colima - container runtimes on macOS";

    package = mkOption {
      type = types.package;
      default = pkgs.colima;
      defaultText = literalExpression "pkgs.colima";
      description = "The Colima package to use.";
    };

    docker = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Docker runtime support.";
    };

    cpus = mkOption {
      type = types.int;
      default = 2;
      description = "Number of CPUs to allocate to the VM.";
    };

    memory = mkOption {
      type = types.int;
      default = 4;
      description = "Amount of memory in GB to allocate to the VM.";
    };

    disk = mkOption {
      type = types.int;
      default = 60;
      description = "Disk size in GB for the VM.";
    };

    vmType = mkOption {
      type = types.enum ["qemu" "vz"];
      default = "qemu";
      description = "VM type to use. VZ requires macOS 13+.";
    };

    vzRosetta = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Rosetta for amd64 emulation. Only works with vmType = vz.";
    };

    mountType = mkOption {
      type = types.enum ["sshfs" "9p" "virtiofs"];
      default = "sshfs";
      description = "Mount type for the VM. virtiofs requires vmType = vz.";
    };

    arch = mkOption {
      type = types.enum ["x86_64" "aarch64"];
      default =
        if pkgs.stdenv.isDarwin && pkgs.stdenv.isAarch64
        then "aarch64"
        else "x86_64";
      description = "Architecture for the VM.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      cfg.package
      docker-client
      docker-compose
    ];

    environment.variables = {
      DOCKER_HOST = "unix://\${HOME}/.colima/default/docker.sock";
    };

    launchd.user.agents.colima = {
      path = [cfg.package pkgs.docker-client "/usr/bin" "/bin" "/usr/sbin" "/sbin"];
      serviceConfig = {
        ProgramArguments =
          [
            "${cfg.package}/bin/colima"
            "start"
            "--foreground" # foreground mode
            "--cpu"
            (toString cfg.cpus)
            "--memory"
            (toString cfg.memory)
            "--disk"
            (toString cfg.disk)
            "--vm-type"
            cfg.vmType
            "--mount-type"
            cfg.mountType
            "--arch"
            cfg.arch
          ]
          ++ optionals cfg.vzRosetta ["--vz-rosetta"]
          ++ optionals cfg.docker ["--runtime" "docker"];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/colima.out.log";
        StandardErrorPath = "/tmp/colima.err.log";
      };
    };
  };
}
