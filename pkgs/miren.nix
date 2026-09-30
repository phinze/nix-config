# The Miren CLI, straight from the release build. `src` is the miren-cli flake
# input, which nix-config-sync keeps on the newest release (see releaseInputs
# in home-manager/phinze/modules/nix-config-sync.nix). The binary is static Go,
# so there is nothing to patch; this just puts it on PATH under both names.
#
# For something newer than the latest release, drop a build in ~/bin. It comes
# ahead of the nix profile on PATH, so it wins until you delete it.
{ stdenvNoCC, src }:
stdenvNoCC.mkDerivation {
  pname = "miren";
  version = "release";
  inherit src;

  dontBuild = true;
  installPhase = ''
    install -Dm755 miren $out/bin/miren
    ln -s miren $out/bin/m
  '';

  meta.mainProgram = "miren";
}
