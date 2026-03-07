# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: rec {
  ccusage = pkgs.callPackage ./ccusage { };
  gwq = pkgs.callPackage ./gwq { };
  git-trim = pkgs.callPackage ./git-trim.nix { inherit gwq; };
  ccometixline = pkgs.callPackage ./ccometixline.nix { };
  pageres-cli = pkgs.callPackage ./pageres-cli { };
  coderabbit = pkgs.callPackage ./coderabbit { };
  linearis = pkgs.callPackage ./linearis { };
  osc-copy = pkgs.callPackage ./osc-copy { };
  synckick = pkgs.callPackage ./synckick.nix { };
  whoson = pkgs.callPackage ./whoson.nix { };
}
