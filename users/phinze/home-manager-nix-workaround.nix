{ ... }:

{
  # Need to explicitly set nix.package when using home-manager by itself make
  # nix config work.
  # See: https://github.com/nix-community/home-manager/issues/3644#issuecomment-1418707189
  nix.package = pkgs.nix;
}
