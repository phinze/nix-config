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
    rev = "6c832fcc71a5549c676ddb95e0e5344ea1edc4c0";
    hash = "sha256-WKqHMJ+G8VXkIB6XqdrKuNakrNMBcqcwJA24l6DTLgw=";
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
