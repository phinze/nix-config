{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
let
  releases = {
    x86_64-linux = {
      platform = "linux-amd64";
      hash = "sha256-skJo3MjDhuF8CUuWY4Vp8mNajg/NBZdsaOmqySWi86k=";
    };
    aarch64-linux = {
      platform = "linux-arm64";
      hash = "sha256-e/ZT2us2TFpmaen2u0D0LrZxYbIbNbEkIzv+suVxevQ=";
    };
    x86_64-darwin = {
      platform = "darwin-10.15-amd64";
      hash = "sha256-RpLzDJeIKVoP2ES9VYj04pL4hX/Td6aALJlYHYSYWUo=";
    };
    aarch64-darwin = {
      platform = "darwin-10.15-arm64";
      hash = "sha256-b6OxHDL9BOxEKTCFt+h+6/SWOZKFQw+3N09Yhu+UPdA=";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation rec {
  pname = "veans";
  version = "2.6.0";

  # Official standalone CLI releases; Linux binaries are statically linked.
  src = fetchurl {
    url = "https://github.com/go-vikunja/vikunja/releases/download/v${version}/veans-v${version}-${release.platform}-full.zip";
    inherit (release) hash;
  };
  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 veans-v${version}-${release.platform} "$out/bin/veans"
    install -Dm644 LICENSE "$out/share/licenses/veans/LICENSE"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    "$out/bin/veans" version
  '';

  meta = {
    description = "Agent-friendly CLI for Vikunja";
    homepage = "https://github.com/go-vikunja/vikunja/tree/v2.6.0/veans";
    license = lib.licenses.agpl3Plus;
    platforms = builtins.attrNames releases;
    mainProgram = "veans";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
