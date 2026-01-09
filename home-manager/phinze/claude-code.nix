{
  config,
  lib,
  pkgs,
  ...
}: {
  # Claude Code package
  home.packages = with pkgs; [
    claude-code
    ccometixline
  ];

  # Claude Code settings with CCometixLine statusline
  home.file.".claude/settings.json" = {
    text = builtins.toJSON {
      statusLine = {
        type = "command";
        command = "${pkgs.ccometixline}/bin/ccometixline";
        padding = 0;
      };
      includeCoAuthoredBy = false;
      hooks = {
        SessionStart = [
          {
            hooks = [
              {
                type = "command";
                command = ''[ -d "$CLAUDE_PROJECT_DIR/.swt" ] && swt agent-help || true'';
              }
            ];
          }
        ];
      };
    };
    force = true;
  };
}
