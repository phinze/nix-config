{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  chromium,
}:
buildNpmPackage rec {
  pname = "pageres-cli";
  version = "8.0.0";

  src = fetchFromGitHub {
    owner = "sindresorhus";
    repo = "pageres-cli";
    rev = "v${version}";
    hash = "sha256-/gxa+veo+ycTmXWayMoyzlB777MPA0xYszNgreFu3Sk=";
  };

  npmDepsHash = "sha256-uwlfiqKroyVrl5JXDlcg4nZ3OCwWKZ4ov09AJAVd0mM=";

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  # Skip Puppeteer's Chrome download during npm install
  PUPPETEER_SKIP_DOWNLOAD = "1";

  # No build step needed for this CLI tool
  dontNpmBuild = true;
  
  # Skip npm prune as it's trying to download additional deps
  dontNpmPrune = true;

  postInstall = ''
    wrapProgram $out/bin/pageres \
      --set PUPPETEER_SKIP_CHROMIUM_DOWNLOAD 1 \
      --set PUPPETEER_EXECUTABLE_PATH ${chromium}/bin/chromium
  '';

  meta = with lib; {
    description = "Capture screenshots of websites in various resolutions";
    homepage = "https://github.com/sindresorhus/pageres-cli";
    license = licenses.mit;
    maintainers = [];
    mainProgram = "pageres";
  };
}