{ pkgs, ... }:

{
  # https://github.com/nix-community/home-manager/pull/2408
  environment.pathsToLink = [ "/share/fish" ];

  users.users.phinze = {
    isNormalUser = true;
    home = "/home/phinze";
    extraGroups = [ "docker" "wheel" ];
    shell = pkgs.fish;
    hashedPassword = "$6$Q/O4KQMXp7e9wPEo$XYxU5wFxk8NzqiozL7w0ZYFgXs8/W2FvGm3ovJdH8Mfvq.JEIBagq.DshoFbZP.HCdyaAuBt9CaoT5DUg3VWy.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIzuIlDCddhK8kGCtaytBs1wfzPb976Z8iHAgkB7h2eX phinze@manticore"
    ];
  };

  nixpkgs.overlays = import ../../lib/overlays.nix ++ [
    (import ./vim.nix)
    (import (builtins.fetchTarball {
      url = https://github.com/nix-community/neovim-nightly-overlay/archive/3bbb08eace50f391839a898c944a226d9e32a71d.tar.gz;
      sha256 = "1cw9f2dfd8i5s3zkri0n37dqdbraqjvxpnwdsgmsv7an9wcb8a7n";
    }))
  ];
}
