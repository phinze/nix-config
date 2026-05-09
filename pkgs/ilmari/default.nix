{
  lib,
  rustPlatform,
  fetchFromGitHub,
  git,
}:
rustPlatform.buildRustPackage rec {
  pname = "ilmari";
  version = "0.1.5";

  src = fetchFromGitHub {
    owner = "bnomei";
    repo = "ilmari";
    rev = "v${version}";
    hash = "sha256-EhlDIsKo4kioaRcMnSe+zt5TYuSSrzdUGCBg8rvm+x0=";
  };

  cargoHash = "sha256-bcyu9Wo6MYRUiCd0D78KEyVAoCHqgYforCx7hQ98HGM=";

  # Recognize the nix-wrapped `.claude-unwrapped` command so panes show up
  # even when Claude Code has overwritten the tmux pane title with a task
  # summary. Touches the same literal in src/agents/mod.rs and src/process.rs.
  # See: https://github.com/bnomei/ilmari/issues (TODO: file upstream)
  postPatch = ''
    substituteInPlace src/agents/mod.rs src/process.rs \
      --replace-fail '&["claude", "claude-code"]' \
                     '&["claude", "claude-code", "claude-unwrapped", ".claude-unwrapped"]'

    # Also bind Esc to quit, to match tmux session-wizard muscle memory.
    # Flip the assertion in the upstream test that locks in the opposite.
    substituteInPlace src/app.rs \
      --replace-fail "(KeyCode::Char('q'), _) => {" \
                     "(KeyCode::Char('q'), _) | (KeyCode::Esc, _) => {" \
      --replace-fail "assert!(!app.should_quit);" \
                     "assert!(app.should_quit);"
  '';

  # Tests shell out to `git` to set up scratch repos.
  nativeCheckInputs = [ git ];

  meta = with lib; {
    description = "Minimal tmux popup radar for Codex, Amp, Claude Code, OpenCode, Pi, Gemini CLI, and Auggie";
    homepage = "https://github.com/bnomei/ilmari";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "ilmari";
  };
}
