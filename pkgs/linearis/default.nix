{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:
buildNpmPackage rec {
  pname = "linearis";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "czottmann";
    repo = "linearis";
    rev = version;
    hash = "sha256-qLN3uGER8Et5IVxoODfEHj2AI8QhWgmkMlhcwWIISZQ=";
  };

  npmDepsHash = "sha256-AlXkX4sc2jdXqr4qwmoXl6lRFVMUM5YSwtywTtPM4xU=";

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
