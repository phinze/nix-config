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
    rev = "a74f5d58c4872a12c8c447f380fa3448e7815fca";
    hash = "sha256-QETzE9VFOdXjiYbsMWYehwvXc7BwYGh1w6mADWmia+A=";
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
