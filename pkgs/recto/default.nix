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
    rev = "cb10b285a501060da1734847f9d346ec6fa300cc";
    hash = "sha256-2pXiAOZ5xQVHV5NCABvSWHPj66NYY5N75QW9g4TMS6Y=";
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
