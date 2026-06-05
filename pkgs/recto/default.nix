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
    rev = "d4a325410ef994909c7a9e83eef62755138a8ab2";
    hash = "sha256-wEdjlPKkjsql0qu6W3N2CCDSdAbP3MkUi/1QVssEcwc=";
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
