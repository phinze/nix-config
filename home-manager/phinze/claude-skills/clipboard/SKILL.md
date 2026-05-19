---
name: clipboard
description: Copy content to the user's system clipboard. Load whenever the user asks to copy something, put something on the clipboard, "gimme a clipboarded X", "add to clipboard", or similar. Covers the one reliable invocation and the common dead ends to skip.
---

# Clipboard

When the user asks you to copy content to their clipboard, the only
invocation you need is a quoted heredoc into `pbcopy`:

    cat <<'EOF' | pbcopy
    ...content here, verbatim...
    EOF

`pbcopy` is shimmed via OSC 52 (see `pkgs/osc-copy/`), so it works on
macOS, NixOS, through SSH, and inside tmux. The same binary is also
installed as `xclip` and `xsel` — they're symlinks, not separate tools.

## Do this

- **Heredoc, single-quoted (`<<'EOF'`)**, so `$vars`, backticks, and
  backslashes pass through verbatim. This is the default.
- **For file contents**: `cat path/to/file | pbcopy`.
- **After copying**, echo back what landed in the clipboard so the user
  can paste-test before sending. Keep it brief, they wrote the prompt
  and know roughly what's in there.

## Don't do this

- **Don't pipe from `echo` or `printf`**, they reach `pbcopy` as 0 bytes
  in this environment. Always heredoc.
- **Don't probe for `xclip` / `xsel` / `wl-copy`** with `command -v`.
  They all resolve to the same `pbcopy` shim; the probe wastes a turn.
- **Don't check `$DISPLAY` / `$WAYLAND_DISPLAY` / `$XDG_SESSION_TYPE`**.
  OSC 52 doesn't need them.
- **Don't write to `/tmp/foo.txt` first** and then figure out how to
  copy it. Just heredoc into `pbcopy`.
- **Don't reach for `tmux load-buffer` / `tmux set-buffer`**. The
  `pbcopy` shim already wraps OSC 52 in the tmux passthrough sequence
  when `$TMUX` is set.
- **Don't use an unquoted heredoc (`<<EOF`)** unless you actually want
  shell interpolation. Default to quoted.

## Interpolation, if you really need it

If the content needs a shell variable expanded, use an unquoted heredoc
and escape any literal `$`, backtick, or `\` in the payload:

    cat <<EOF | pbcopy
    Build: $build_id
    Cost: \$5.20
    EOF

Most copy-this-message asks don't need this. Stick with `<<'EOF'`.
