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
      # so jj signs there too, through the same wrapper. It signs at push rather
      # than on every rewrite, which is jj's advice for a signer that isn't
      # instant and costs nothing here. Hosts without a local key stay as they
      # were, since there every signature would be a 1Password prompt.
      (lib.mkIf (cfg.localKeyFile != null) {
        xdg.configFile."jj/conf.d/signing.toml".text = ''
          [signing]
          behavior = "drop"
          backend = "ssh"
          key = "dynamic"
          backends.ssh.program = "${gitSshSign}/bin/git-ssh-sign"
          backends.ssh.allowed-signers = "${config.home.homeDirectory}/.ssh/allowed_signers"

          [git]
          sign-on-push = true
        '';
      })
    ]
  );
}
