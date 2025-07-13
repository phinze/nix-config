{
  lib,
  stdenv,
  makeWrapper,
  nodejs,
}:
stdenv.mkDerivation rec {
  pname = "ccusage";
  version = "15.3.1";

  src = null;
  dontUnpack = true;

  nativeBuildInputs = [makeWrapper];
  buildInputs = [nodejs];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/npx $out/bin/ccusage \
      --add-flags "-y --quiet ccusage@${version}" \
      --prefix PATH : ${nodejs}/bin \
      --set npm_config_update_notifier false

    runHook postInstall
  '';

  meta = with lib; {
    description = "Analyze your Claude Code token usage and costs from local JSONL files";
    homepage = "https://github.com/ryoppippi/ccusage";
    license = licenses.mit;
    maintainers = [];
    mainProgram = "ccusage";
  };
}