{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  cmake,
  perl,
  git,
}:
rustPlatform.buildRustPackage rec {
  pname = "lumen";
  version = "2.22.0";

  src = fetchFromGitHub {
    owner = "jnsahaj";
    repo = "lumen";
    rev = "v${version}";
    hash = "sha256-ILAVTEo8t9+4QkIKJNPxMP7U3fSX2j3kqi9W99BdRB4=";
  };

  cargoHash = "sha256-gQ8CMB29uce9SIqE8lmMELtz8vfrxUeyQjiI8rHdn6Y=";

  # Skip the optional `jj` feature for now; we can re-enable later if we want
  # Jujutsu revset support. Trims jj-lib + transitive deps from the build.
  buildNoDefaultFeatures = true;

  nativeBuildInputs = [
    pkg-config
    cmake
    perl
  ];

  nativeCheckInputs = [ git ];

  # The sandbox has no global git config, so `git init` defaults to `master`
  # and these two tests can't find their `main` branch / open a repo at HOME.
  # The other 82 tests cover the same surface, so skipping is fine.
  checkFlags = [
    "--skip=vcs::git::tests::test_get_merge_base_returns_ancestor"
    "--skip=vcs::git::tests::test_working_copy_parent_ref_returns_head"
  ];

  meta = with lib; {
    description = "Beautiful git diff viewer with AI commit messages and explanations";
    homepage = "https://github.com/jnsahaj/lumen";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "lumen";
  };
}
