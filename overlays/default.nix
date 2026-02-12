# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });

    # Apply Wayland fixes from https://github.com/NixOS/nixpkgs/pull/422792
    # Only on Linux since macOS uses homebrew cask for 1Password
    _1password-gui =
      if prev.stdenv.isLinux then
        prev._1password-gui.overrideAttrs (oldAttrs: {
          installPhase = oldAttrs.installPhase + ''
            # Add Wayland support flags to the desktop file
            substituteInPlace $out/share/applications/1password.desktop \
              --replace "Exec=1password %U" \
              "Exec=1password --ozone-platform-hint=auto %U"
          '';
        })
      else
        prev._1password-gui;
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };

  # My configured copy of neovim
  nixvim = final: _prev: {
    nixvim = inputs.nixvim-config.packages.${_prev.system}.default;
  };

  # Multipass CLI for GCP Workload Identity Federation auth
  multipass = final: _prev: {
    multipass = final.unstable.buildGoModule {
      pname = "multipass";
      version = "0-unstable-2026-02-12";
      src = inputs.multipass-src;
      vendorHash = "sha256-8RMRoFt0ZC8i6W+ojNSdZyivW/xofVt1HW3IvJp/HSE=";
      subPackages = [ "cmd/multipass" ];
      env.CGO_ENABLED = 0;
      meta = {
        description = "Auth CLI with GCP Workload Identity Federation support";
        mainProgram = "multipass";
      };
    };
  };
}
