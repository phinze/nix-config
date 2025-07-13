{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "gwq";
  version = "0.0.5";

  src = fetchFromGitHub {
    owner = "d-kuro";
    repo = "gwq";
    rev = "v${version}";
    hash = "sha256-oSgDH5E3ETSlpovhU+MNmDTpY2BRGsR9Bf57ot04Rng=";
  };

  vendorHash = "sha256-jP4arRoTDcjRXZvLx7R/1pp5gRMpfZa7AAJDV+WLGhY=";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/d-kuro/gwq/internal/cmd.version=${version}"
    "-X github.com/d-kuro/gwq/internal/cmd.commit=nixpkgs"
    "-X github.com/d-kuro/gwq/internal/cmd.date=unknown"
  ];

  subPackages = ["cmd/gwq"];

  meta = with lib; {
    description = "A CLI tool for efficiently managing Git worktrees";
    homepage = "https://github.com/d-kuro/gwq";
    license = licenses.asl20;
    maintainers = [];
    mainProgram = "gwq";
  };
}
