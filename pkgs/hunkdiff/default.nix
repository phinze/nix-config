{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  version = "0.10.0";

  sources = {
    "x86_64-linux" = {
      url = "https://registry.npmjs.org/hunkdiff-linux-x64/-/hunkdiff-linux-x64-${version}.tgz";
      hash = "sha512-me3Pl6Tqb46yoZP930iCUdE3pE5lDOtfsWUcCZXqEpsg0WPbW6PjO6tjX7MRnkLFPacPDrqfPZpEHr2bxK0X9A==";
    };
    "aarch64-linux" = {
      url = "https://registry.npmjs.org/hunkdiff-linux-arm64/-/hunkdiff-linux-arm64-${version}.tgz";
      hash = "sha512-h3yY1cxEmer3StCppvQ4kZyK10971t6dMO76jMnWNhREWML2H2hCiPrNw5Yjx0tI0AyI1P4D3guNCcvylLmO4A==";
    };
    "x86_64-darwin" = {
      url = "https://registry.npmjs.org/hunkdiff-darwin-x64/-/hunkdiff-darwin-x64-${version}.tgz";
      hash = "sha512-5sVwIN7OQ4x6/K1TfP4n0wUZinL9nPKmbZ/oHJWhMD6FScGuOOYYZQtN+q2j3ahzlu36Iio7OXajuyQZulwU4A==";
    };
    "aarch64-darwin" = {
      url = "https://registry.npmjs.org/hunkdiff-darwin-arm64/-/hunkdiff-darwin-arm64-${version}.tgz";
      hash = "sha512-oJALanUcIFp19LQbTTNKEk/RA0QIeeqwXzUciTzBlze1IA5GPe+rq+OLy66fFUA5tiO6qj6sXf1UqK9cL8o0Mw==";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "hunkdiff: unsupported system ${stdenv.hostPlatform.system}");

  # The main `hunkdiff` package ships the bundled skill markdown that the
  # binary looks up via `hunk skill path`. The prebuilt platform sub-package
  # only ships the binary, so we fetch the main package alongside for skills/.
  skillsSrc = fetchurl {
    url = "https://registry.npmjs.org/hunkdiff/-/hunkdiff-${version}.tgz";
    hash = "sha512-GfUYNCzEnZ0OTdg340YRFbW1SvvwgRMyQmn44t2GKoSjYqiXGaDCeOG66fpIzU8WRdbUi2uzdGIVkEsCps8TeA==";
  };
in
stdenv.mkDerivation {
  pname = "hunkdiff";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  # The npm tarball unpacks to a `package/` directory.
  sourceRoot = "package";

  dontConfigure = true;
  dontBuild = true;
  # bun --compile appends JS bytecode after the ELF; strip would corrupt it.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/hunk $out/bin/hunk

    # `hunk skill path` resolves to <bindir>/../skills/hunk-review/SKILL.md.
    mkdir -p $out/skills
    tar -xzf ${skillsSrc} -C $out/skills --strip-components=2 package/skills

    runHook postInstall
  '';

  meta = {
    description = "Review-first terminal diff viewer for agentic coders";
    homepage = "https://github.com/modem-dev/hunk";
    license = lib.licenses.mit;
    mainProgram = "hunk";
    platforms = lib.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
