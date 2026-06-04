{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "recto";
  version = "0-unstable-2026-06-04";

  src = fetchFromGitHub {
    owner = "phinze";
    repo = "recto";
    rev = "dbfca8d8c6c4e7aea30841f054f21edbaf0dcb02";
    hash = "sha256-VAW/PF2Pv9AqcFvA4eQuCzMDcz8mr5ptCR2KcGZ6WZM=";
  };

  cargoHash = "sha256-3SfCwRriHI9NaVM0M2WPVswSy/oUcGzN5im2qAkz1Ms=";

  meta = with lib; {
    description = "jj-first terminal diff viewer for reviewing agent-authored changes";
    homepage = "https://github.com/phinze/recto";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "recto";
  };
}
