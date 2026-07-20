# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: rec {
  ccusage = pkgs.callPackage ./ccusage { };
  gwq = pkgs.callPackage ./gwq { };
  hunkdiff = pkgs.callPackage ./hunkdiff { };
  # lumen's genai dep uses `if let && ` chains stabilized in rustc 1.88, build against unstable
  lumen = pkgs.unstable.callPackage ./lumen { };
  # Use unstable jujutsu so the reap script can read repos the user is
  # actively working in with their interactive jj (which is also unstable).
  # Version skew → "Failed to load the repo" errors → silent fail-open in
  # the bookmark/safety checks.
  dev-session-cleanup = pkgs.callPackage ./dev-session-cleanup.nix {
    inherit gwq;
    jujutsu = pkgs.unstable.jujutsu;
  };
  dev-host-cleanup = pkgs.callPackage ./dev-host-cleanup.nix { };
  git-trim = pkgs.callPackage ./git-trim.nix { inherit gwq; };
  ccometixline = pkgs.callPackage ./ccometixline.nix { };
  pageres-cli = pkgs.callPackage ./pageres-cli { };
  coderabbit = pkgs.callPackage ./coderabbit { };
  antigravity-cli = pkgs.callPackage ./antigravity-cli { };
  linearis = pkgs.callPackage ./linearis { };
  osc-copy = pkgs.callPackage ./osc-copy { };
  whoson = pkgs.callPackage ./whoson.nix { };
}
