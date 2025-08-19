{
  config,
  lib,
  pkgs,
  ...
}: {
  homebrew.casks = [
    "karabiner-elements"
  ];

  system.activationScripts.configureKarabiner.text = ''
    KARABINER_CONFIG_DIR="/Users/${config.system.primaryUser}/.config/karabiner"
    KARABINER_COMPLEX_MODS="$KARABINER_CONFIG_DIR/assets/complex_modifications"
    FIRST_RUN_FLAG="$KARABINER_CONFIG_DIR/.nix-darwin-configured"

    # Create directories if they don't exist
    sudo -u ${config.system.primaryUser} mkdir -p "$KARABINER_COMPLEX_MODS"

    # Write the Cmd+Tab to Raycast configuration (always overwrite to ensure it's up to date)
    sudo -u ${config.system.primaryUser} cat > "$KARABINER_COMPLEX_MODS/cmd-tab-raycast.json" << 'EOF'
    {
      "title": "Cmd + Tab → Raycast Switch Windows",
      "rules": [
        {
          "description": "Left Cmd + Tab triggers Raycast's Switch Windows extension",
          "manipulators": [
            {
              "type": "basic",
              "from": {
                "key_code": "tab",
                "modifiers": {
                  "mandatory": ["left_command"],
                  "optional": ["any"]
                }
              },
              "to": [
                {
                  "key_code": "w",
                  "modifiers": ["left_control", "left_option", "left_shift", "left_command"]
                }
              ]
            }
          ]
        }
      ]
    }
    EOF

    # Check if karabiner.json exists, if not create a basic one
    if [ ! -f "$KARABINER_CONFIG_DIR/karabiner.json" ]; then
      sudo -u ${config.system.primaryUser} cat > "$KARABINER_CONFIG_DIR/karabiner.json" << 'EOF'
    {
      "global": {
        "check_for_updates_on_startup": true,
        "show_in_menu_bar": true,
        "show_profile_name_in_menu_bar": false
      },
      "profiles": [
        {
          "name": "Default profile",
          "selected": true,
          "complex_modifications": {
            "parameters": {
              "basic.simultaneous_threshold_milliseconds": 50,
              "basic.to_delayed_action_delay_milliseconds": 500,
              "basic.to_if_alone_timeout_milliseconds": 1000,
              "basic.to_if_held_down_threshold_milliseconds": 500
            },
            "rules": []
          },
          "devices": [],
          "fn_function_keys": [],
          "simple_modifications": [],
          "virtual_hid_keyboard": {
            "country_code": 0,
            "indicate_sticky_modifier_keys_state": true,
            "mouse_key_xy_scale": 100
          }
        }
      ]
    }
    EOF
    fi

    # Only show instructions on first run
    if [ ! -f "$FIRST_RUN_FLAG" ]; then
      echo "Karabiner-Elements configuration completed."
      echo "Please:"
      echo "1. Open Karabiner-Elements if not already running"
      echo "2. Go to Complex Modifications tab"
      echo "3. Click 'Add rule' and enable 'Left Cmd + Tab triggers Raycast's Switch Windows extension'"
      echo "4. In Raycast, set the Switch Windows extension hotkey to: Ctrl+Opt+Shift+Cmd+W"

      # Mark as configured
      sudo -u ${config.system.primaryUser} touch "$FIRST_RUN_FLAG"
    fi
  '';
}
