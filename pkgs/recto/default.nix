{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "recto";
  version = "0-unstable-2026-06-04";

  src = fetchFromGitHub {
    owner = "phinze";
    repo = "recto";
    rev = "cd5ddc482421251aec6c5dfa10b4ed26268e6950";
    hash = "sha256-tO/Mj5kQGNkVSWJdUfFr7Via1TNnFA8aEvQ1XSKi+9s=";
  };

  cargoHash = "sha256-WP0lWXhDC3Gb4S5Z1FdCLLKL11wefNs+EC4Mr0dlH6c=";

  meta = with lib; {
    description = "jj-first terminal diff viewer for reviewing agent-authored changes";
    homepage = "https://github.com/phinze/recto";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "recto";
  };
}
