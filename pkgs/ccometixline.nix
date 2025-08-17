{ lib, rustPlatform, fetchFromGitHub }:

rustPlatform.buildRustPackage rec {
  pname = "ccometixline";
  version = "1.0.2";

  src = fetchFromGitHub {
    owner = "Haleclipse";
    repo = "CCometixLine";
    rev = "v${version}";
    hash = "sha256-F7QsWqGc4uj0cLWOAzSTQP9fxWUxG04DV0aDFiwmMhQ=";
  };

  cargoHash = "sha256-5mTuZzCsmlwsoRf2EkZRBeFXff8GKD39bkrrSa6sd4k=";

  buildFeatures = [ "tui" "self-update" ];

  meta = with lib; {
    description = "High-performance Claude Code StatusLine tool written in Rust";
    homepage = "https://github.com/Haleclipse/CCometixLine";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "ccometixline";
  };
}