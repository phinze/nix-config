# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: rec {
  ccusage = pkgs.callPackage ./ccusage {};
  gwq = pkgs.callPackage ./gwq {};
  git-trim = pkgs.callPackage ./git-trim.nix {inherit gwq;};
}
