{ pkgs, lib, ... }:

{
  # Only configure Karabiner on Darwin systems
  xdg.configFile."karabiner/karabiner.json" = lib.mkIf pkgs.stdenv.isDarwin {
    text = builtins.toJSON {
    global = {
      check_for_updates_on_startup = true;
      show_in_menu_bar = true;
      show_profile_name_in_menu_bar = false;
      ask_for_confirmation_before_quitting = true;
    };
    profiles = [
      {
        name = "Default profile";
        selected = true;
        simple_modifications = [];
        fn_function_keys = [
          {
            from = { key_code = "f1"; };
            to = [{ consumer_key_code = "display_brightness_decrement"; }];
          }
          {
            from = { key_code = "f2"; };
            to = [{ consumer_key_code = "display_brightness_increment"; }];
          }
          {
            from = { key_code = "f3"; };
            to = [{ apple_vendor_keyboard_key_code = "mission_control"; }];
          }
          {
            from = { key_code = "f4"; };
            to = [{ apple_vendor_keyboard_key_code = "spotlight"; }];
          }
          {
            from = { key_code = "f5"; };
            to = [{ consumer_key_code = "dictation"; }];
          }
          {
            from = { key_code = "f6"; };
            to = [{ key_code = "f6"; }];
          }
          {
            from = { key_code = "f7"; };
            to = [{ consumer_key_code = "rewind"; }];
          }
          {
            from = { key_code = "f8"; };
            to = [{ consumer_key_code = "play_or_pause"; }];
          }
          {
            from = { key_code = "f9"; };
            to = [{ consumer_key_code = "fast_forward"; }];
          }
          {
            from = { key_code = "f10"; };
            to = [{ consumer_key_code = "mute"; }];
          }
          {
            from = { key_code = "f11"; };
            to = [{ consumer_key_code = "volume_decrement"; }];
          }
          {
            from = { key_code = "f12"; };
            to = [{ consumer_key_code = "volume_increment"; }];
          }
        ];
        complex_modifications = {
          parameters = {
            "basic.simultaneous_threshold_milliseconds" = 50;
            "basic.to_delayed_action_delay_milliseconds" = 500;
            "basic.to_if_alone_timeout_milliseconds" = 1000;
            "basic.to_if_held_down_threshold_milliseconds" = 500;
          };
          rules = [
            {
              description = "Left Cmd + Tab triggers Raycast's Switch Windows extension";
              manipulators = [
                {
                  type = "basic";
                  from = {
                    key_code = "tab";
                    modifiers = {
                      mandatory = ["left_command"];
                      optional = ["any"];
                    };
                  };
                  to = [
                    {
                      key_code = "w";
                      modifiers = ["left_control" "left_option" "left_shift" "left_command"];
                    }
                  ];
                }
              ];
            }
            {
              description = "Caps Lock → Escape on tap, Control on hold";
              manipulators = [
                {
                  type = "basic";
                  from = {
                    key_code = "caps_lock";
                    modifiers = {
                      optional = ["any"];
                    };
                  };
                  to = [
                    {
                      key_code = "left_control";
                      lazy = true;
                    }
                  ];
                  to_if_alone = [
                    {
                      key_code = "escape";
                    }
                  ];
                }
              ];
            }
            {
              description = "Hold semicolon for vim navigation layer (hjkl → arrows)";
              manipulators = [
                {
                  type = "basic";
                  from = {
                    key_code = "h";
                    modifiers = {
                      optional = ["any"];
                    };
                  };
                  to = [
                    {
                      key_code = "left_arrow";
                    }
                  ];
                  conditions = [
                    {
                      type = "variable_if";
                      name = "semicolon_layer";
                      value = 1;
                    }
                  ];
                }
                {
                  type = "basic";
                  from = {
                    key_code = "j";
                    modifiers = {
                      optional = ["any"];
                    };
                  };
                  to = [
                    {
                      key_code = "down_arrow";
                    }
                  ];
                  conditions = [
                    {
                      type = "variable_if";
                      name = "semicolon_layer";
                      value = 1;
                    }
                  ];
                }
                {
                  type = "basic";
                  from = {
                    key_code = "k";
                    modifiers = {
                      optional = ["any"];
                    };
                  };
                  to = [
                    {
                      key_code = "up_arrow";
                    }
                  ];
                  conditions = [
                    {
                      type = "variable_if";
                      name = "semicolon_layer";
                      value = 1;
                    }
                  ];
                }
                {
                  type = "basic";
                  from = {
                    key_code = "l";
                    modifiers = {
                      optional = ["any"];
                    };
                  };
                  to = [
                    {
                      key_code = "right_arrow";
                    }
                  ];
                  conditions = [
                    {
                      type = "variable_if";
                      name = "semicolon_layer";
                      value = 1;
                    }
                  ];
                }
                {
                  type = "basic";
                  from = {
                    key_code = "semicolon";
                    modifiers = {
                      optional = ["any"];
                    };
                  };
                  to = [
                    {
                      set_variable = {
                        name = "semicolon_layer";
                        value = 1;
                      };
                    }
                  ];
                  to_after_key_up = [
                    {
                      set_variable = {
                        name = "semicolon_layer";
                        value = 0;
                      };
                    }
                  ];
                  to_if_alone = [
                    {
                      key_code = "semicolon";
                    }
                  ];
                }
              ];
            }
          ];
        };
        devices = [];
        virtual_hid_keyboard = {
          country_code = 0;
          indicate_sticky_modifier_keys_state = true;
          mouse_key_xy_scale = 100;
        };
      }
    ];
  };
  };
}