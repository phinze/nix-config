{
  pkgs,
  lib,
  ...
}:
let
  # Logitech R400 wireless presenter receiver
  r400Device = {
    vendor_id = 1133; # 0x046d Logitech
    product_id = 50477; # 0xc52d R400 receiver
  };

  karabinerConfig = {
    # Karabiner's `global` section is where the Settings UI's checkboxes live.
    # Anything omitted here falls back to the app's built-in default, so a
    # preference toggled in the UI survives only until the next activation
    # rewrites this file. Declare what we want rather than toggling it.
    global = {
      show_in_menu_bar = false;
    };

    profiles = [
      {
        name = "Default profile";
        selected = true;
        complex_modifications.rules = [
          {
            description = "Logitech R400 black-screen → Handy toggle (opt+space)";
            manipulators = [
              {
                type = "basic";
                from.key_code = "period";
                to_if_alone = [
                  {
                    key_code = "spacebar";
                    modifiers = [ "left_option" ];
                  }
                ];
                conditions = [
                  {
                    type = "device_if";
                    identifiers = [ r400Device ];
                  }
                ];
              }
            ];
          }
          {
            # Start/Stop button alternates F5/Escape internally; we only need to
            # remap F5 since Escape already passes through unchanged.
            description = "Logitech R400 start/stop → Handy cancel (escape)";
            manipulators = [
              {
                type = "basic";
                from.key_code = "f5";
                to_if_alone = [ { key_code = "escape"; } ];
                conditions = [
                  {
                    type = "device_if";
                    identifiers = [ r400Device ];
                  }
                ];
              }
            ];
          }
        ];
        virtual_hid_keyboard.keyboard_type_v2 = "ansi";
      }
    ];
  };

  karabinerJson = pkgs.writeText "karabiner.json" (builtins.toJSON karabinerConfig);
in
lib.mkIf pkgs.stdenv.isDarwin {
  # Karabiner rewrites its own config on UI changes, which conflicts with
  # home-manager's symlink mechanism (atomic-rename clobbers the symlink and
  # the next switch fails the .nix-backup check). Copy on activation instead
  # so the file is mutable in place; nix is the source of truth on every switch.
  home.activation.karabinerConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm 0644 ${karabinerJson} "$HOME/.config/karabiner/karabiner.json"
  '';
}
