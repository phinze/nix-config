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
    rev = "b0247f0877365f348a8643e611cc4a2c6e4f472e";
    hash = "sha256-Ij/hmyrgX4RjQxKWh6iZD6HSLToe9I2qwF2cUKrc04A=";
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
