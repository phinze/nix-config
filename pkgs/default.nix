# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  ccusage = pkgs.callPackage ./ccusage {};
  gwq = pkgs.callPackage ./gwq {};
  linear-mcp-server = pkgs.callPackage ./linear-mcp-server {};
}
