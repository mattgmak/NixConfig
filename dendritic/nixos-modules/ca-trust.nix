# The eMudhra intermediate CA key compromise (2026-10) leaked chains to two roots.
# Mozilla's NSS store carries "Comodo AAA Services root" and omits the emSign ECC
# G3 root. Naming an absent CA aborts the cacert build with exit 3, so list only
# the present one. The Droid target reads the Android store and stays uncovered.
{
  flake.nixosModules.caTrust = {
    security.pki.caCertificateBlacklist = [
      "Comodo AAA Services root"
    ];
  };
}
