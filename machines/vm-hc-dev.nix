{ config, pkgs, ... }: {
  imports = [
    ./vm-shared.nix
  ];

  networking.hostName = pkgs.lib.mkForce "hc-dev";

  networking.interfaces.ens18.useDHCP = true;

  # Enable qemu guest agent
  services.qemuGuest.enable = true;

  # Virtualbox for Vagrant dev
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = ["phinze"];

  # libvirt / qemu for Vagrant dev
  virtualisation.libvirtd.enable = true;
  users.extraGroups.libvirtd.members = ["phinze"];
  # The libvirtd module currently requires Polkit to be enabled
  security.polkit.enable = true;

  # NFS for Vagrant dev
  services.nfs.server = {
    enable = true;
    # fixed rpc.statd port; for firewall
    lockdPort = 4001;
    mountdPort = 4002;
    statdPort = 4000;
    extraNfsdConfig = '''';
  };
  networking.firewall.allowedTCPPorts = [ 2049 111 4000 4001 4002 ];
  networking.firewall.allowedUDPPorts = [ 2049 111 4000 4001 4002 ];


  # Trust HC Root CA
  security.pki.certificates = [
    ''
    -----BEGIN CERTIFICATE-----
    MIIFKTCCAxGgAwIBAgIUVKR+j9sOxXTBaX8OWFQD3sW6FMowDQYJKoZIhvcNAQEL
    BQAwHDEaMBgGA1UEAxMRSGFzaGlDb3JwIFJvb3QgQ0EwHhcNMjAwNDE2MTgxODE0
    WhcNNDAwNDE2MTgxODQxWjAcMRowGAYDVQQDExFIYXNoaUNvcnAgUm9vdCBDQTCC
    AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMbBtS53Cyw6NsCbfgW/V/V1
    TrRQOMFaRAzYyGqO3OmNbRQfhUNn/JNzo7FZaKz+i9UM9JsPkowVpmdhJTaVUjKI
    jlFQgffakMtfOQeBM08PQfWHRtgUM11A3KBesXo8WNaha59Cyn+Sx88VUl3Kndd1
    rOpJDsQHoZ7v61S9BoDxXprilkUJDCQaPXf22PVHysDmaD/5/q2pQV+kVsWTYJJq
    /X/4ZN8WekvvXKMCDqEzz5XQOb/8kNWOTG6/HXfQlXFJfmTu0jTk57TkjF+aO397
    FzvHokxRhsq1+Ablujj594s87ok2/psDg7R+zhPujtsaB0gmAFMy3JaBihp2rbWR
    QaLG3HCNQWla+uYThYgx8gtsMhbAfUWtrlbv3gX7ouVmFCbjJkHq7+EBC3yf2He6
    J/QkG39zkDfmPcN0nuFy3K+i1qivY6pids/eaztTTTa5YTYss0a9f24iedDQbrdM
    COD44p69UGqzeLBEAcyIthkLVhX99UA0kgMf5RLzCXweO+Xy9YaGP2+hIXrD1pCF
    c+hQU1ifHKmwcWsroxqBHtcXbHxxmUlQ9PIFsULBf31MF1ANARpVGxMyP0fhDau3
    xN0/Xz0DiXJtxphnXPkvPkxSnSVsQU6GmZcANyszWLhLaCgZl5ysWJZXIWclbyiy
    RYT1V/6BjaX5sAqIDCDdAgMBAAGjYzBhMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMB
    Af8EBTADAQH/MB0GA1UdDgQWBBRO1SmNzUJY+jBki/dsmMPlgIxJojAfBgNVHSME
    GDAWgBRO1SmNzUJY+jBki/dsmMPlgIxJojANBgkqhkiG9w0BAQsFAAOCAgEASFHC
    rGXT/6Z1tBq4PkgK91xDWT+Nz6yMvBe3XdwKgEwVbjJyIUIW3kUfKztBe1Xr9TNQ
    nADZtAzpskuwpvxQFhEqqUaN1vjinz55dR8sMm81w8Os1SGtSzM0jUyp+619d6WN
    oK1MNIi463PGQQO5WQVo4GPL/Z7Maq08NtaFVjscL3YcSk9vswRk/Ruyn3T1AUg2
    wNMyFQvlEYpzTZSZOWzryYf0eDHUD52MU7of4flBeNVRA503f74GL6aM6CygzWNf
    apHfWfGvJhd5g51DNo1y0d7UonNznoopVNq7gZckAO2HQN4ogKEs3zEiZ6O4gYup
    P4T88lbbkldVIYu1HFrvMrTrbYBxdcctUsUSRtDgZyNueSJgQEqI/0mA3W8vfQ2M
    G9BjrkyIFi9UHS0A9JR9WfjgXD/NGJgmyGBI2wptQcM3lid2WTKAM5r04Ig9FkWb
    j/4mKHDPE7jrg5ZtgBtonY4G7OeXfF+JxQNJ29FbiS43Do3BZj2xKob7EGBp3wc3
    VdNHUjaZlidQBOdiKjsTbKQVvVrjZQSX6kELyaOdopg54O9+sBqzSO7O/VvhxL17
    xCi9ndxW/NfEnnBnrIgmsTGHAWnyqsQhxVP2aqHm7ajvY+P0IiLOzS3XIameJVN9
    XvvHECvAsa59PxcrFXawYLjneZSulXVRM1GxpdU=
    -----END CERTIFICATE-----
    ''
  ];
}
