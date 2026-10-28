# Distrust the roots behind the compromised eMudhra intermediates
# (CVE-2026-111943). Shared by NixOS (via baseline.nix) and nix-darwin (via
# common.nix); both expose security.pki.caCertificateBlacklist and feed it to
# cacert, which drops the plain PEM block and leaves an explicit reject rule.
#
# Names are as they appear in NSS's certdata, so the Sectigo cross-sign root
# shows up as "Comodo AAA Services root" rather than its subject CN.
#
# NixOS 26.05 grew the same list as a hard-coded default in
# nixos/modules/security/ca.nix (nixpkgs a6401f2dcd, 2026-10-20), and cacert
# 3.131.1 drops the emSign roots outright. Duplicating it is harmless, and it
# covers hosts on an older stable pin. nix-darwin's pki module has no such
# default, so the darwin bundle (NIX_SSL_CERT_FILE) depends on this list for good.
#
# Removing "Comodo AAA Services root" can break the odd site that still chains
# only through it. That's the trade NixOS upstream made too.
{
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
  ];
}
