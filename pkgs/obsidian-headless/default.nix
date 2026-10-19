{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs_22,
  python3,
}:
# Headless Obsidian Sync client (`ob`). Runs the memex Obsidian bridge on
# foxtrotbase; see memex Projects/Ideas/memex-obsidian-sync.md.
buildNpmPackage rec {
  pname = "obsidian-headless";
  version = "0.0.14";

  # The published tarball: cli.js is a prebuilt bundle, and the GitHub repo
  # holds only the README.
  src = fetchurl {
    url = "https://registry.npmjs.org/obsidian-headless/-/obsidian-headless-${version}.tgz";
    hash = "sha256-73UpjtOjVtyypN6Yxu/hCyrGSwBVYAcRi2rHBTXnMVY=";
  };

  # The tarball has no lockfile. Regenerate with:
  #   npm install --package-lock-only --ignore-scripts
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-BqPUZYpuLKENogvXemH1dTaCxJ6sXB70B+JNtwurheo=";

  nodejs = nodejs_22;
  # better-sqlite3's install script falls back to node-gyp when it can't
  # download a prebuilt binary, which it never can in the sandbox.
  nativeBuildInputs = [ python3 ];
  dontNpmBuild = true;

  meta = {
    description = "Headless client for Obsidian Sync and Obsidian Publish";
    homepage = "https://github.com/obsidianmd/obsidian-headless";
    license = lib.licenses.unfree;
    mainProgram = "ob";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
