# Dynamic SSH git signing module
#
# Single source of truth for SSH signing keys. Derives:
# - git-ssh-sign wrapper: dynamically selects signing key from SSH agent
# - programs.git.signing.key
# - programs.git.settings."gpg \"ssh\"".program
# - ~/.ssh/allowed_signers (generated from keys × emails)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.phinze.git.signing;

  keyType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Human-readable name for this key (e.g. device name)";
      };
      publicKey = lib.mkOption {
        type = lib.types.str;
        description = "Full SSH public key string (e.g. ssh-ed25519 AAAA...)";
      };
    };
  };

  # Build the allowed_signers content: every key trusted for every email
  allowedSignersContent =
    lib.concatStringsSep "\n" (
      lib.concatMap (email: map (key: "${email} ${key.publicKey}") cfg.keys) cfg.emails
    )
    + "\n";

  # 1Password agent socket path on macOS (use $HOME since ~ won't expand in the script)
  opAgentSock = "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";

  # Build the git-ssh-sign wrapper package
  gitSshSign = pkgs.callPackage ../../../pkgs/git-ssh-sign.nix {
    signingKeys = cfg.keys;
    sshAuthSock = if pkgs.stdenv.hostPlatform.isDarwin then opAgentSock else null;
    inherit (cfg) localKeyFile;
  };

  # ssh-keygen asks SSH_AUTH_SOCK whether the agent holds the key before it
  # reads the file, and there's no flag to skip that (-U only forces the
  # agent). With nothing forwarded, double-agent falls back to the Mac, and a
  # sleeping Mac stalls every signature about 5s. The key is on disk, so hide
  # the agent.
  sshKeygenNoAgent = pkgs.writeShellScript "ssh-keygen-no-agent" ''
    unset SSH_AUTH_SOCK
    exec ${pkgs.openssh}/bin/ssh-keygen "$@"
  '';
in
{
  options.phinze.git.signing = {
    keys = lib.mkOption {
      type = lib.types.listOf keyType;
      default = [ ];
      description = "SSH signing keys in priority order";
    };

    localKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Private key file on this host to sign with instead of the agent, when it exists";
    };

    emails = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Email addresses to trust for all signing keys";
    };
  };

  config = lib.mkIf (cfg.keys != [ ]) (
    lib.mkMerge [
      {
        # Generate ~/.ssh/allowed_signers from keys × emails
        home.file.".ssh/allowed_signers".text = allowedSignersContent;

        # git-ssh-sign wrapper overrides the key; git just needs a non-empty value
        programs.git.signing.key = "dynamic";

        programs.git.settings = {
          gpg.format = "ssh";
          "gpg \"ssh\"" = {
            program = "${gitSshSign}/bin/git-ssh-sign";
            allowedSignersFile = "~/.ssh/allowed_signers";
          };
        };
      }

      # jj ignores git's signing config, so commits made with jj (which is nearly
      # all of them) went out unsigned. A host with its own key signs for free,
      # so jj signs there too. Hosts without a local key stay as they were,
      # since there every signature would be a 1Password prompt.
      #
      # It signs every commit as jj writes it, not at push. Signing at push
      # rewrote each commit on its way out, so the id an agent had already
      # quoted, watched for, or relayed was dead by the time it landed. A local
      # key costs about 50ms per rewrite, so the id you see is the id that
      # ships. The push-time revset stays as a backstop for commits written
      # before this, or by another tool.
      #
      # jj calls ssh-keygen on the key file directly rather than the wrapper,
      # because the wrapper falls back to the agent and, at one signature per
      # snapshot, a missing key would mean a 1Password prompt per jj command.
      # Without the fallback a missing key makes jj fail loudly instead. It goes
      # through sshKeygenNoAgent so no signature waits on an agent.
      (lib.mkIf (cfg.localKeyFile != null) {
        xdg.configFile."jj/conf.d/signing.toml".text = ''
          [signing]
          behavior = "own"
          backend = "ssh"
          key = "${cfg.localKeyFile}"
          backends.ssh.program = "${sshKeygenNoAgent}"
          backends.ssh.allowed-signers = "${config.home.homeDirectory}/.ssh/allowed_signers"

          [revsets]
          git-sign-on-push = "~signed() & mine()"
        '';
      })
    ]
  );
}
