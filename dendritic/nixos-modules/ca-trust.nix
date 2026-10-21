# The eMudhra intermediate CA key compromise removes two roots (2026-10).
# The Droid target reads the Android store and stays uncovered.
{
  flake.nixosModules.caTrust = {
    security.pki.caCertificateBlacklist = [
      "Comodo AAA Services root"
      "emSign ECC Root CA - G3"
    ];
  };
}
