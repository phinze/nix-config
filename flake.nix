{
  description = "Phinze's nix configs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Fast lane for the jj toolchain. Same packages as nixos-unstable, but the
    # small channel advances days rather than weeks earlier — and jj cuts a
    # release monthly, which was otherwise waiting on a manual nixpkgs-unstable
    # bump that history says happens every month or two. Only jujutsu, jjui and
    # yt-dlp read from this (see overlays/default.nix), so unlike nixpkgs-unstable it
    # can ride in syncInputs: bumping it rebuilds two packages, not the world.
    # Resist the urge to pull anything else from here without weighing that.
    nixpkgs-small.url = "github:nixos/nixpkgs/nixos-unstable-small";

    systems.url = "github:nix-systems/default";

    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixvim-config.url = "github:phinze/nixvim-config";

    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    bankshot.url = "github:phinze/bankshot";
    bankshot.inputs.nixpkgs.follows = "nixpkgs-unstable";
    bankshot.inputs.flake-utils.follows = "flake-utils";

    # recto builds against unstable (2024 edition + let-chains), so follow
    # nixpkgs-unstable to keep one rustc in the closure.
    recto.url = "github:phinze/recto";
    recto.inputs.nixpkgs.follows = "nixpkgs-unstable";
    recto.inputs.flake-utils.follows = "flake-utils";

    # rig pins go_1_27 and its go.mod floors at 1.27.1, so follow unstable.
    # Bumping rig past a Go floor means bumping nixpkgs-unstable with it.
    rig.url = "github:phinze/rig";
    rig.inputs.nixpkgs.follows = "nixpkgs-unstable";
    rig.inputs.flake-utils.follows = "flake-utils";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs-unstable";

    double-agent.url = "github:phinze/double-agent";
    double-agent.inputs.nixpkgs.follows = "nixpkgs-unstable";
    double-agent.inputs.flake-utils.follows = "flake-utils";

    sophon.url = "github:phinze/sophon";
    sophon.inputs.nixpkgs.follows = "nixpkgs-unstable";
    sophon.inputs.flake-utils.follows = "flake-utils";

    understudy.url = "github:phinze/understudy";

    belowdeck.url = "github:phinze/belowdeck";
    belowdeck.inputs.nixpkgs.follows = "nixpkgs-unstable";
    belowdeck.inputs.flake-utils.follows = "flake-utils";

    # pim-stuff's go.mod floors at go 1.25.5; follow unstable to stay ahead of
    # stable nixpkgs's Go, matching the rig/recto pattern. It's a private repo,
    # so use git+https (git credential auth) rather than the github: fetcher,
    # like the mirendev inputs below.
    pim-stuff.url = "git+https://github.com/phinze/pim-stuff.git";
    pim-stuff.inputs.nixpkgs.follows = "nixpkgs-unstable";
    pim-stuff.inputs.flake-utils.follows = "flake-utils";

    # Keys, hostnames and coordinates kept out of this public repo.
    nix-private.url = "git+https://github.com/phinze/nix-private.git";

    # Upstream's flake, not nixpkgs'. We sat on v18.18.1 for a while because
    # v18.19.0's move to native-tls (atuinsh/atuin#3807) left the installed
    # binary with no RPATH for libssl.so.3, so it died the moment home-manager
    # ran `atuin init fish`. v18.24.0 patchelfs the RPATH in (atuinsh/atuin#3852),
    # builds without the implicit arboard feature (#610), and is the first tag
    # with threads (`atuin resume`), which is what we came for.
    #
    # Two things worth knowing before you touch this. Their CI only runs
    # `nix build`, so a broken binary can still build cleanly; after a bump,
    # run `atuin init fish` and `atuin doctor`, not just the build. And don't
    # "simplify" this to nixpkgs' atuin: atuin runs sqlx migrations with
    # validation on, so a binary older than the history DB refuses to open it,
    # and nixpkgs trails upstream by several releases.
    #
    # No `inputs.nixpkgs.follows` on purpose. Upstream builds with crane, one
    # derivation per crate, which saturates foxtrotbase for a long while.
    # Building against their own nixpkgs pin keeps our derivation identical to
    # the one their CI pushes to atuin.cachix.org (see modules/nixos/baseline.nix),
    # so Linux substitutes instead of compiling. They don't cache Darwin, so the
    # Mac compiles regardless.
    atuin.url = "github:atuinsh/atuin/v18.24.0";

    claude-code-nix.url = "github:sadjow/claude-code-nix";
    claude-code-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
    codex-cli-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
    codex-cli-nix.inputs.flake-utils.follows = "flake-utils";

    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };
    claude-plugin-miren-skills = {
      url = "github:mirendev/miren-skills";
      flake = false;
    };
    # Private repo, so use git+https (git credential auth) rather than the
    # github: fetcher, like the other mirendev inputs.
    claude-plugin-miren-team = {
      url = "git+https://github.com/mirendev/claude-skills.git";
      flake = false;
    };
    claude-plugin-interface-design = {
      url = "github:Dammyjay93/interface-design";
      flake = false;
    };

    # Miren brand system (palette, type, logo assets). Private, so git+https
    # like the other mirendev inputs. Pinned here so the miren-brand skill can
    # point every session at a copy that's always on disk, rather than assuming
    # a checkout exists at some path under ~/src.
    miren-brand = {
      url = "git+https://github.com/mirendev/brand.git";
      flake = false;
    };

    # Miren CLI release build, the same zip the homebrew cask installs.
    # Release-tracked by nix-config-sync, which reads the newest version from
    # api.miren.cloud and rewrites the vX.Y.Z segment below, so keep the url on
    # one line in this exact shape. x86_64-linux only, which is every NixOS
    # host that runs home-manager.
    miren-cli.url = "https://api.miren.cloud/assets/release/miren/v0.17.2/miren-linux-amd64.zip";
    miren-cli.flake = false;

    iso.url = "git+https://github.com/mirendev/iso.git";

    multipass.url = "git+https://github.com/mirendev/multipass.git";
    multipass.inputs.nixpkgs.follows = "nixpkgs-unstable";
    multipass.inputs.flake-utils.follows = "flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      ...
    }@inputs:
    let
      inherit (self) outputs;

      eachSystem = nixpkgs.lib.genAttrs (import inputs.systems);
    in
    {
      # Your custom packages
      # Accessible through 'nix build', 'nix shell', etc
      #
      # These get nixpkgs with the unstable-packages overlay rather than the
      # bare legacyPackages set, because several of them are pinned to unstable
      # through `pkgs.unstable` and a bare set doesn't have it. The host configs
      # apply the overlay themselves, so this output was the only place the
      # attribute went missing — which meant `nix flake check` failed on a
      # package the system built fine. Only the unstable overlay belongs here:
      # `additions` is this very file's output and would recurse.
      packages = eachSystem (
        system:
        import ./pkgs (
          import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ outputs.overlays.unstable-packages ];
          }
        )
      );
      # Formatter for your nix files, available through 'nix fmt'
      formatter = eachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      # Dev shell with repo-local helpers
      devShells = eachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          nhs = pkgs.writeShellScriptBin "nhs" ''
            if [[ "$(uname)" == "Darwin" ]]; then
              nh darwin switch . "$@"
            else
              nh os switch . "$@"
            fi
          '';
        in
        {
          default = pkgs.mkShell {
            packages = [ nhs ];
          };
        }
      );

      # Your custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };
      # Reusable nixos modules you might want to export
      # These are usually stuff you would upstream into nixpkgs
      nixosModules = import ./modules/nixos;
      # Reusable home-manager modules you might want to export
      # These are usually stuff you would upstream into home-manager
      # homeManagerModules = import ./modules/home-manager;

      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = {
        foxtrotbase = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            # > Our main nixos configuration file <
            ./nixos/foxtrotbase/configuration.nix
            ./nixos/foxtrotbase/home-manager.nix
          ];
        };

        # Framework 12" laptop
        xiezhi = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nixos/xiezhi/configuration.nix
            ./nixos/xiezhi/home-manager.nix
          ];
        };

        # Supermicro NAS server with ZFS
        simurgh = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nixos/simurgh/configuration.nix
            ./nixos/simurgh/home-manager.nix
          ];
        };

        # Dedicated Tailscale exit node
        homegate = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nixos/homegate/configuration.nix
          ];
        };
      };

      # Darwin machines
      # Run with `darwin-rebuild --flake .`
      darwinConfigurations = {
        phinze-mrn-mbp = nix-darwin.lib.darwinSystem {
          specialArgs = { inherit inputs outputs; };
          modules = [
            ./nix-darwin/phinze-mrn-mbp/configuration.nix
            ./nix-darwin/phinze-mrn-mbp/home-manager.nix
          ];
        };
      };
    };
}
