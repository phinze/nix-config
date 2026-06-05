{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule {
  pname = "rig";
  version = "0-unstable-2026-06-05";

  src = fetchFromGitHub {
    owner = "phinze";
    repo = "rig";
    rev = "4aea1961a43f2045ad501ea3200d45d92f09c630";
    hash = "sha256-NDer9VvHbGSXQB9CAY4NEmPmQn8lQ5WAMzwibpz0FuA=";
  };

  vendorHash = "sha256-76yvZ8MhGnJhkfBALS/MYAeEmkOcLX0VKu1zTtPLhxo=";

  meta = with lib; {
    description = "Workspace tool for task-shaped, multi-repo work (replaces jpickup/jreview)";
    homepage = "https://github.com/phinze/rig";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "rig";
  };
}
