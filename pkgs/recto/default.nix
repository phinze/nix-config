{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "recto";
  version = "0-unstable-2026-05-15";

  src = fetchFromGitHub {
    owner = "phinze";
    repo = "recto";
    rev = "23734ee26c6dc0189c9c9d81d01b3464363be8c9";
    hash = "sha256-wnJRLJ65tk+ej6cZqgBMv+cDPTZZ6ytG6E+WDv6HPv8=";
  };

  cargoHash = "sha256-rsuxBA1pSnko1RtuvH1pKYgaufhXTMh8UP8QNut6420=";

  meta = with lib; {
    description = "jj-first terminal diff viewer for reviewing agent-authored changes";
    homepage = "https://github.com/phinze/recto";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "recto";
  };
}
