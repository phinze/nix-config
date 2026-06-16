{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  version = "1.0.9";
  buildId = "1.0.9-6422111942737920";

  sources = {
    x86_64-linux = {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${buildId}/linux-x64/cli_linux_x64.tar.gz";
      sha256 = "sha256-Qzx5KWlAd1amFImSYYg6jhMPD6+fQwIGcBXgNImDvUY=";
    };
    aarch64-linux = {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${buildId}/linux-arm/cli_linux_arm64.tar.gz";
      sha256 = "sha256-VLCDOyNK8TwJCafdN5BSC60Uenf+gm+uyFYPLgsEpBc=";
    };
    x86_64-darwin = {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${buildId}/darwin-x64/cli_mac_x64.tar.gz";
      sha256 = "sha256-zvDp0yerDpIdLSRN72YTGfApMSO/NhFSuOChFMCaCng=";
    };
    aarch64-darwin = {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${buildId}/darwin-arm/cli_mac_arm64.tar.gz";
      sha256 = "sha256-sOmQPQr4IfwKltc/u1H23aCBD5UgAoZinZVrOH8/jIE=";
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
