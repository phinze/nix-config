{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "recto";
  version = "0-unstable-2026-05-17";

  src = fetchFromGitHub {
    owner = "phinze";
    repo = "recto";
    rev = "682583cd4379793b4dda75bad53adeaa2d73d39a";
    hash = "sha256-4lrFN4Gl94tu3HsqLE3QJYX+TXwiETI9gz0HMzQNE80=";
  };

  cargoHash = "sha256-H8+VGKHHRXQHhK0Ky9RL3rWpynAWc5DFqCVDn2fix+Q=";

  meta = with lib; {
    description = "jj-first terminal diff viewer for reviewing agent-authored changes";
    homepage = "https://github.com/phinze/recto";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "recto";
  };
}
