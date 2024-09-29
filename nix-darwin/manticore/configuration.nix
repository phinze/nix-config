{...}: {
  imports = [
    ../common.nix
  ];

  homebrew.casks = [
    "calibre"
    "teamviewer"
  ];

  homebrew.masApps = {
    "Bear Notes" = 1091189122;
    "Paprika Recipe Manager 3" = 1303222628;
  };
}
