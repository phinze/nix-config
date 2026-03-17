# Dynamic SSH git signing module
#
# Single source of truth for SSH signing keys. Derives:
# - git-ssh-sign wrapper (Linux): dynamically selects key from agent
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

  # Build the git-ssh-sign wrapper package
  gitSshSign = pkgs.callPackage ../../../pkgs/git-ssh-sign.nix {
    signingKeys = cfg.keys;
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

    programs.git.signing.key =
      if pkgs.stdenv.isLinux
      then "dynamic"  # wrapper overrides; git needs a non-empty value
      else (builtins.head cfg.keys).publicKey;  # macOS: 1Password handles selection

    programs.git.extraConfig = {
      gpg.format = "ssh";
      "gpg \"ssh\"" = lib.mkMerge [
        (lib.mkIf pkgs.stdenv.isDarwin {
          program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
        })
        (lib.mkIf pkgs.stdenv.isLinux {
          program = "${gitSshSign}/bin/git-ssh-sign";
          allowedSignersFile = "~/.ssh/allowed_signers";
        })
      ];
    };
  };
}
