{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:
buildNpmPackage rec {
  pname = "linearis";
  version = "2025.12.3";

  src = fetchFromGitHub {
    owner = "czottmann";
    repo = "linearis";
    rev = "v${version}";
    hash = "sha256-8Sz1RQJKbimPsGKUpHvqbkXnxxoUHppl4EA2+BjzryM=";
  };

  npmDepsHash = "sha256-PUXLphH82leQLHj5+BIxezKSpRiK/S9WevzK0duwo28=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  # Build TypeScript to JavaScript
  npmBuildScript = "build";

  meta = with lib; {
    description = "CLI tool for Linear.app with JSON output, smart ID resolution, and optimized GraphQL queries";
    homepage = "https://github.com/czottmann/linearis";
    license = licenses.mit;
    maintainers = [];
    mainProgram = "linearis";
    platforms = platforms.all;
  };
}
