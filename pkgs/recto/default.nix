{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "recto";
  version = "0-unstable-2026-05-23";

  src = fetchFromGitHub {
    owner = "phinze";
    repo = "recto";
    rev = "74e6730512c07d02b2eae4b6509cf18d9a1f617c";
    hash = "sha256-ZsMFyS6GC/epGjNcHs6cc31PSJEqlVI5FVkzVM5d5Zc=";
  };

  cargoHash = "sha256-1Ls1c7agPoF1y3bbgzZ990hKP5CtwAVVib44j3YVpLM=";

  meta = with lib; {
    description = "jj-first terminal diff viewer for reviewing agent-authored changes";
    homepage = "https://github.com/phinze/recto";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "recto";
  };
}
