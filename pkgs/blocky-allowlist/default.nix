{ buildGoModule }:
buildGoModule {
  pname = "blocky-allowlist";
  version = "0.1.0";
  src = builtins.path {
    path = ./src;
    name = "blocky-allowlist-src";
  };
  vendorHash = null; # stdlib only
  ldflags = [
    "-s"
    "-w"
  ];
}
