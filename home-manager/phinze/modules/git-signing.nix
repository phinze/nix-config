# Dynamic SSH git signing module
#
# Single source of truth for SSH signing keys. Derives:
# - git-ssh-sign wrapper: dynamically selects signing key from SSH agent
# - programs.git.signing.key
# - programs.git.extraConfig."gpg \"ssh\"".program
# - ~/.ssh/allowed_signers (generated from keys × emails)
{ config, lib, pkgs, ... }:
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
  allowedSignersContent = lib.concatStringsSep "\n" (
    lib.concatMap (email:
      map (key: "${email} ${key.publicKey}") cfg.keys
    ) cfg.emails
  ) + "\n";

  # 1Password agent socket path on macOS (use $HOME since ~ won't expand in the script)
  opAgentSock = "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";

  # Build the git-ssh-sign wrapper package
  gitSshSign = pkgs.callPackage ../../../pkgs/git-ssh-sign.nix {
    signingKeys = cfg.keys;
    sshAuthSock =
      if pkgs.stdenv.isDarwin
      then opAgentSock
      else null;
  };
in
{
  options.phinze.git.signing = {
    keys = lib.mkOption {
      type = lib.types.listOf keyType;
      default = [ ];
      description = "SSH signing keys in priority order";
    };

    emails = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Email addresses to trust for all signing keys";
    };
  };

  config = lib.mkIf (cfg.keys != [ ]) {
    # Generate ~/.ssh/allowed_signers from keys × emails
    home.file.".ssh/allowed_signers".text = allowedSignersContent;

    # git-ssh-sign wrapper overrides the key; git just needs a non-empty value
    programs.git.signing.key = "dynamic";

    programs.git.extraConfig = {
      gpg.format = "ssh";
      "gpg \"ssh\"" = {
        program = "${gitSshSign}/bin/git-ssh-sign";
        allowedSignersFile = "~/.ssh/allowed_signers";
      };
    };
  };
}
