# Vendored from `rex terminfo show`.
{ pkgs }:
pkgs.runCommand "rex-terminfo" { nativeBuildInputs = [ pkgs.ncurses ]; } ''
  mkdir -p $out/share/terminfo
  tic -x -o $out/share/terminfo ${./xterm-rex.terminfo}
''
