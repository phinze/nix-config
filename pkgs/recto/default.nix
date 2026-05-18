{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "recto";
  version = "0-unstable-2026-05-18";

  src = fetchFromGitHub {
    owner = "phinze";
    repo = "recto";
    rev = "b111f896cda0f3ebeb34a97da39a74ad03743ac2";
    hash = "sha256-hjxlYcCA89+tK+44OIFGAU6ktCgvyrC9HUgQfYG1R9k=";
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
