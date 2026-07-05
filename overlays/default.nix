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

    # nixpkgs' session-wizard wraps bin/t with makeWrapper but never runs
    # patchShebangs on the underlying script, so .t-wrapped keeps its upstream
    # `#!/bin/bash` shebang. That works on FHS distros but NixOS has no
    # /bin/bash, so the popup dies with "bad interpreter". Patch the shebangs.
    tmuxPlugins = prev.tmuxPlugins // {
      session-wizard = prev.tmuxPlugins.session-wizard.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          patchShebangs --build $target/bin
        '';
      });
    };

    # foreign-env's import loop runs `set -gx` on every inherited env var. When a
    # name isn't a valid fish identifier, fish 4 hard-errors and aborts the whole
    # import, so a single bad name takes out shell startup. gcloud is a repeat
    # offender: it exports CLOUDSDK_VMWARE_NODE-TYPE (and would export
    # CLOUDSDK_SECRETS_REPLICATION-POLICY) with a hyphen in the name, because its
    # property->env-var generator doesn't sanitize. Patch the plugin to skip
    # names fish can't represent. We patch the src rather than the build output
    # because home-manager consumes foreign-env.src directly while the NixOS
    # programs.fish module uses the built plugin; this fixes both.
    # Upstream gcloud bug: https://issuetracker.google.com/issues/522635666
    fishPlugins = prev.fishPlugins // {
      foreign-env = prev.fishPlugins.foreign-env.overrideAttrs (oldAttrs: {
        src = prev.applyPatches {
          inherit (oldAttrs) src;
          patches = [ ./foreign-env-skip-invalid-names.patch ];
        };
      });
    };
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };

  # My configured copy of neovim
  nixvim = final: _prev: {
    nixvim = inputs.nixvim-config.packages.${_prev.stdenv.hostPlatform.system}.default;
  };

  # recto ships its own flake package; pull it from the input rather than
  # re-packaging it here.
  recto = final: _prev: {
    recto = inputs.recto.packages.${final.stdenv.hostPlatform.system}.default;
  };

  # rig likewise ships its own flake package.
  rig = final: _prev: {
    rig = inputs.rig.packages.${final.stdenv.hostPlatform.system}.default;
  };

  # pim (personal-information CLI) likewise ships its own flake package.
  pim = final: _prev: {
    pim = inputs.pim-stuff.packages.${final.stdenv.hostPlatform.system}.default;
  };

}
