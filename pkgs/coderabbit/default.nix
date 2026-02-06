{
  lib,
  stdenv,
  fetchurl,
  unzip,
  buildFHSEnv,
}:
let
  version = "0.3.5";

  selectSystem =
    system:
    {
      x86_64-linux = {
        os = "linux";
        arch = "x64";
        sha256 = "sha256-2j4wR6QJ36GsnN7yrBgvCWWb6l7DS29v4Sl4T16H7po=";
      };
      aarch64-linux = {
        os = "linux";
        arch = "arm64";
        sha256 = "sha256-LTrYcu2eYalLOSD+Su8sJ8hwiIQtHshnHWyL2MjvOFU=";
      };
      x86_64-darwin = {
        os = "darwin";
        arch = "x64";
        sha256 = "sha256-+AgQeptoac3Cg4A3Ssmui2ABqedIubYuB7lRp/B3WZ8=";
      };
      aarch64-darwin = {
        os = "darwin";
        arch = "arm64";
        sha256 = "sha256-w0PLGaKvsOYlHMWJW48fJUekEXSWdcECambWju8LdIE=";
      };
    }
    .${system} or (throw "Unsupported system: ${system}");

  systemInfo = selectSystem stdenv.hostPlatform.system;

  # The unwrapped, unpatched binary - DO NOT patch this!
  coderabbit-binary = stdenv.mkDerivation {
    pname = "coderabbit-binary";
    inherit version;

    src = fetchurl {
      url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-${systemInfo.os}-${systemInfo.arch}.zip";
      sha256 = systemInfo.sha256;
    };

    nativeBuildInputs = [ unzip ];

    # Disable all patching
    dontPatchELF = true;
    dontStrip = true;
    dontFixup = true;

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      # Keep the binary completely unmodified
      cp coderabbit $out/bin/coderabbit
      chmod +x $out/bin/coderabbit
      runHook postInstall
    '';
  };
in
if stdenv.isLinux then
  # On Linux, wrap the unpatched binary in an FHS environment
  buildFHSEnv {
    name = "coderabbit";
    targetPkgs = pkgs: [
      # The unpatched binary
      coderabbit-binary
      # Runtime dependencies
      pkgs.glibc
      pkgs.gcc.cc.lib
    ];
    runScript = "${coderabbit-binary}/bin/coderabbit";

    # Also create 'cr' alias
    extraInstallCommands = ''
      ln -s $out/bin/coderabbit $out/bin/cr
    '';

    meta = with lib; {
      description = "CodeRabbit CLI - AI-powered code review and analysis tool";
      homepage = "https://coderabbit.ai";
      license = licenses.unfreeRedistributable;
      maintainers = [ ];
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      mainProgram = "coderabbit";
    };
  }
else
  # On macOS, use the binary directly since it should work
  stdenv.mkDerivation {
    pname = "coderabbit";
    inherit version;

    src = fetchurl {
      url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-${systemInfo.os}-${systemInfo.arch}.zip";
      sha256 = systemInfo.sha256;
    };

    nativeBuildInputs = [ unzip ];
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 coderabbit $out/bin/coderabbit
      ln -s $out/bin/coderabbit $out/bin/cr
      runHook postInstall
    '';

    meta = with lib; {
      description = "CodeRabbit CLI - AI-powered code review and analysis tool";
      homepage = "https://coderabbit.ai";
      license = licenses.unfreeRedistributable;
      maintainers = [ ];
      platforms = [
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      mainProgram = "coderabbit";
    };
  }
