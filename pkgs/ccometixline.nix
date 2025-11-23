{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "ccometixline";
  version = "1.0.8";

  src = fetchFromGitHub {
    owner = "Haleclipse";
    repo = "CCometixLine";
    rev = "v${version}";
    hash = "sha256-OcK0UZDHAJTQOVqBUZbI9g7Q/ChYJ5Ukc+hdDUi6tPM=";
  };

  cargoHash = "sha256-PMmyJhbeXgxncXZh/RV0uyuWl9TmCeJAICxWXn0uB0o=";

  buildFeatures = ["tui" "self-update"];

  meta = with lib; {
    description = "High-performance Claude Code StatusLine tool written in Rust";
    homepage = "https://github.com/Haleclipse/CCometixLine";
    license = licenses.mit;
    maintainers = [];
    mainProgram = "ccometixline";
  };
}
