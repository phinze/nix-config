{
  lib,
  stdenv,
  bash,
  git,
  gh,
  jq,
  makeWrapper,
}:
stdenv.mkDerivation rec {
  pname = "pr-review-download";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp ${./pr-review-download.sh} $out/bin/pr-review-download
    chmod +x $out/bin/pr-review-download

    wrapProgram $out/bin/pr-review-download \
      --prefix PATH : ${lib.makeBinPath [bash git gh jq]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Download and organize GitHub PR reviews and comments";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "pr-review-download";
  };
}
