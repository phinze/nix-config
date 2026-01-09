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

  # Claude Code slash commands
  home.file.".claude/commands/review-pr.md" = {
    text = ''
      # PR Review Skill

      Review pull request: $ARGUMENTS

      Think hard and carefully about the code changes.

      ## Instructions

      0. **If no PR specified** (empty $ARGUMENTS):
         - Run `gh pr list` to show open PRs
         - Ask which one I'd like to review
         - Continue with the selected PR number

      1. **Fetch PR metadata and diff**:
         - Run `gh pr view $ARGUMENTS --json number,title,body,author,baseRefName,headRefName,url`
         - Run `gh pr diff $ARGUMENTS`

      2. **Summarize the PR**:
         - What is this PR trying to accomplish?
         - Who authored it?
         - What's the scope (files changed, rough size)?

      3. **Walk through the changes**:
         - Group changes logically (by feature, by file, or by layer)
         - Explain what each change does
         - **Flag areas of concern**: complexity, edge cases, security issues, missing tests, unclear intent, potential bugs

      4. **Pause for discussion**:
         - Ask if I have questions or want to dive deeper into any area
         - We'll discuss before drafting comments

      5. **Draft PR comments**:
         - When I'm ready, draft individual comments in raw markdown
         - Use fenced code blocks so the markdown is visible (not rendered)
         - Format each comment like:

      ~~~markdown
      **File**: `path/to/file.ts` (lines 42-45)

      Your comment text here...
      ~~~

      **Tone**: Concise, informal, and friendly. Use "we" pronouns in the spirit of collective code ownership (e.g., "we might want to handle..." not "you should...").

      Focus on:
      - Questions that clarify intent
      - Potential issues or edge cases
      - Suggestions for improvement (not nitpicks)
    '';
  };
}
