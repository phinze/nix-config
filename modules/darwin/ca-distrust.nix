# Distrust the Sectigo cross-sign root behind the compromised eMudhra
# intermediates (CVE-2026-111943). cacert 3.131.1 drops the emSign roots
# outright, and buildcatrust fails the build if the blacklist names a cert
# that isn't there, so only the cross-sign root is left to list. NSS's
# certdata calls it "Comodo AAA Services root" rather than its subject CN.
#
# NixOS hard-codes this same entry in nixos/modules/security/ca.nix (nixpkgs
# a6401f2dcd, 2026-10-20). nix-darwin's pki module has no such default, so the
# darwin bundle (NIX_SSL_CERT_FILE) depends on this list.
#
# Removing it can break the odd site that still chains only through it.
# That's the trade NixOS upstream made too.
{
  security.pki.caCertificateBlacklist = [ "Comodo AAA Services root" ];
}
