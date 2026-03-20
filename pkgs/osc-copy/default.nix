{
  lib,
  stdenv,
  bash,
  coreutils,
}:
stdenv.mkDerivation {
  pname = "osc-copy";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp ${./pbcopy.sh} $out/bin/pbcopy
    chmod +x $out/bin/pbcopy

    # Linux-flavored clipboard commands that tools like Claude reach for
    ln -s pbcopy $out/bin/xclip
    ln -s pbcopy $out/bin/xsel

    runHook postInstall
  '';

  meta = with lib; {
    description = "Copy to clipboard via OSC 52 escape sequence (provides pbcopy, xclip, xsel on Linux)";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "pbcopy";
  };
}
