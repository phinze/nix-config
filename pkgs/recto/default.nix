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
    rev = "82e876724792f33193c7047a4e88da1214dc864b";
    hash = "sha256-97lMLEu5En0pIwcIErEHbxvANkj6VktEGV6JDy2osfo=";
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
