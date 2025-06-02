# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  linear-mcp-server = pkgs.callPackage ./linear-mcp-server { };
}
