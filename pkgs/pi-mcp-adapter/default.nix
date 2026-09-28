{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:
# MCP client extension for the Pi coding agent. Pi has no MCP of its own, and
# this is what gives it Linear. Pi would normally `pi install npm:...` it into
# ~/.pi/agent/npm at runtime, which needs npm on PATH and drifts on its own
# schedule; building it here lets settings.json point at a store path instead.
buildNpmPackage rec {
  pname = "pi-mcp-adapter";
  version = "3.1.0";

  # The published tarball, not the GitHub source: it ships the prebuilt dist/
  # alongside the .ts files Pi loads directly, so there is nothing to compile.
  src = fetchurl {
    url = "https://registry.npmjs.org/pi-mcp-adapter/-/pi-mcp-adapter-${version}.tgz";
    hash = "sha256-MvcEnQnohzabJExF/3dpKKvIQ+c/Uni0dAlUyQfEt9I=";
  };

  # The tarball has no lockfile. Ours was generated from its package.json with
  # devDependencies removed (they pull in the whole Pi stack plus vitest, ~500
  # packages), so postPatch strips them here too to keep `npm ci` in agreement.
  # Regenerate with:
  #   jq 'del(.devDependencies)' package.json > p && mv p package.json
  #   npm install --package-lock-only --legacy-peer-deps --ignore-scripts
  postPatch = ''
    ${lib.getExe jq} 'del(.devDependencies)' package.json > package.json.new
    mv package.json.new package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-+QwlszatFxsXC72nhFt7Ir+968kMFHk0W6jgVwOxMz0=";

  # Peer deps (pi-ai, pi-tui, typebox) are supplied by the Pi host at load
  # time; installing our own copies would shadow the host's. Scripts are off
  # because `prepack` would try to rebuild dist/ with a tsc we don't ship.
  npmFlags = [
    "--legacy-peer-deps"
    "--ignore-scripts"
  ];
  npmPackFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  meta = {
    description = "MCP client extension for the Pi coding agent";
    homepage = "https://github.com/nicobailon/pi-mcp-adapter";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
