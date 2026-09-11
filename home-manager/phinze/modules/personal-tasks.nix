{
  config,
  lib,
  pkgs,
  ...
}:
let
  projects = builtins.fromJSON (builtins.readFile ../personal-tasks/projects.json);
  contextRoot = "${config.xdg.configHome}/personal-tasks";
  helper = pkgs.writeShellApplication {
    name = "personal-tasks";
    text = ''
      exec ${lib.getExe pkgs.python3} ${../scripts/personal-tasks.py} \
        ${lib.escapeShellArg contextRoot} ${lib.getExe pkgs.veans} "$@"
    '';
  };
  memex = {
    personal = "memex/PIM/Personal.md";
    ctl = "memex/PIM/CTL.md";
    ndsm = "memex/PIM/NDSM.md";
  };
in
{
  home.packages = [
    pkgs.veans
    helper
  ];

  # JSON is valid YAML. These files contain IDs only; veans keeps credentials
  # in the OS keychain or ~/.config/veans/credentials.yml, outside the store.
  xdg.configFile = lib.foldlAttrs (
    files: domain: project:
    files
    // {
      "personal-tasks/${domain}/.veans.yml".text = builtins.toJSON project;
      "personal-tasks/${domain}/context.json".text = builtins.toJSON {
        memex = memex.${domain};
        human = {
          username = "phinze";
          user_id = 3;
        };
      };
    }
  ) { } projects;
}
