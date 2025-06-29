{
  lib,
  stdenv,
  makeWrapper,
  nodejs,
}: let
  pname = "linear-mcp-server";
  version = "1.0.0";
in
  stdenv.mkDerivation {
    inherit pname version;

    src = null;
    dontUnpack = true;

    nativeBuildInputs = [makeWrapper];
    buildInputs = [nodejs];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      makeWrapper ${nodejs}/bin/npx $out/bin/linear-mcp-server \
        --add-flags "-y mcp-remote https://mcp.linear.app/sse" \
        --prefix PATH : ${nodejs}/bin

      runHook postInstall
    '';

    meta = with lib; {
      description = "Linear MCP server for Claude Desktop";
      homepage = "https://linear.app/docs/mcp";
      license = licenses.mit;
      maintainers = [];
      platforms = platforms.all;
    };
  }
