{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "recto";
  version = "0-unstable-2026-05-19";

  src = fetchFromGitHub {
    owner = "phinze";
    repo = "recto";
    rev = "a27ed1c4e641dd3b5ace026b64fa49e01ad94dfd";
    hash = "sha256-N3OFNlaorW3LypqZh/JXGKL6p7U2y/0sWiSzICkcTLc=";
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
