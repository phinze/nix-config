{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  version = "1.0.0";
  buildId = "1.0.0-5288553236791296";

  sources = {
    x86_64-linux = {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${buildId}/linux-x64/cli_linux_x64.tar.gz";
      sha256 = "sha256-cAljQFdPr8SgbE08gFcxTiLUdc4cgg0K1R/wf7fpnrY=";
    };
    aarch64-linux = {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${buildId}/linux-arm/cli_linux_arm64.tar.gz";
      sha256 = "sha256-9Nx8lsGDawB2jYpuxurMeFHzQkvW9Ovk2LhIplIHKoU=";
    };
    x86_64-darwin = {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${buildId}/darwin-x64/cli_mac_x64.tar.gz";
      sha256 = "sha256-dEoaJdzwv2Yo463XZNIVXETX0XTt+LGBp0J/fZ+z+1M=";
    };
    aarch64-darwin = {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${buildId}/darwin-arm/cli_mac_arm64.tar.gz";
      sha256 = "sha256-ZcL3teJ6Ie+YOxYe11hm6JE5poKt9nkADhpdnTdOMgo=";
    };
  };

  src = fetchurl (
    sources.${stdenv.hostPlatform.system}
      or (throw "antigravity-cli: unsupported system ${stdenv.hostPlatform.system}")
  );
in
stdenv.mkDerivation {
  pname = "antigravity-cli";
  inherit version src;

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 antigravity $out/bin/agy
    runHook postInstall
  '';

  meta = {
    description = "Google Antigravity CLI (agy) — terminal coding agent powered by Gemini";
    homepage = "https://antigravity.google/product/antigravity-cli";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames sources;
    mainProgram = "agy";
  };
}
