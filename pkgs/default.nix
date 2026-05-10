# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: rec {
  ccusage = pkgs.callPackage ./ccusage { };
  gwq = pkgs.callPackage ./gwq { };
  hunkdiff = pkgs.callPackage ./hunkdiff { };
  # ilmari pulls Rust deps that require rustc 1.88+, so build against unstable
  ilmari = pkgs.unstable.callPackage ./ilmari { };
  # lumen's genai dep uses `if let && ` chains stabilized in rustc 1.88, build against unstable
  lumen = pkgs.unstable.callPackage ./lumen { };
  dev-session-cleanup = pkgs.callPackage ./dev-session-cleanup.nix { inherit gwq; };
  git-trim = pkgs.callPackage ./git-trim.nix { inherit gwq; };
  ccometixline = pkgs.callPackage ./ccometixline.nix { };
  pageres-cli = pkgs.callPackage ./pageres-cli { };
  coderabbit = pkgs.callPackage ./coderabbit { };
  linearis = pkgs.callPackage ./linearis { };
  osc-copy = pkgs.callPackage ./osc-copy { };
  synckick = pkgs.callPackage ./synckick.nix { };
  whoson = pkgs.callPackage ./whoson.nix { };
}
