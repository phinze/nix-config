{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "linear-tui";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "roeyazroel";
    repo = "linear-tui";
    rev = "v${version}";
    hash = "sha256-oS0hR5/gdTPfeICAMuJfkIxLTxOAfxe2K8Nq8N2WPsU=";
  };

  vendorHash = "sha256-+yC22fb6GtfAXLCIwwSXNRV7FIpelSx25KVa8NiD3Ew=";

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X main.Commit=nixpkgs"
    "-X main.Date=unknown"
  ];

  subPackages = [ "cmd/linear-tui" ];

  meta = with lib; {
    description = "Terminal user interface for Linear built with Go and tview";
    homepage = "https://github.com/roeyazroel/linear-tui";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "linear-tui";
  };
}
