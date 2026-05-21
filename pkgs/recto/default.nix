{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "recto";
  version = "0-unstable-2026-05-21";

  src = fetchFromGitHub {
    owner = "phinze";
    repo = "recto";
    rev = "36b0034b5103457c2225246b34edb0312b34a4c4";
    hash = "sha256-85DDWw4zUVYiCMKzXIwYcSGj7A+TO24rJXpUdwlR/NI=";
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
