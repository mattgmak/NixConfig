{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      # Iosevka Charon plus Iosevka Charon Mono from the upstream release.
      # nixpkgs ships plain iosevka only, so vendor the zip here. The zip has
      # three top-level entries, so fetchzip refuses it: use fetchurl + unzip.
      packages.iosevka-charon = pkgs.stdenvNoCC.mkDerivation {
        pname = "iosevka-charon";
        version = "34.801";
        src = pkgs.fetchurl {
          url = "https://github.com/jul-sh/iosevka-charon/releases/download/v34.801/iosevka-charon.zip";
          hash = "sha256-4AscQdafBFvjTtoCiVm/lDZ9CwU/5+K9TMq4sapY7TI=";
        };
        nativeBuildInputs = [ pkgs.unzip ];
        phases = [ "unpackPhase" "installPhase" ];
        unpackPhase = ''
          runHook preUnpack
          unzip -q $src -d iosevka-charon
          runHook postUnpack
        '';
        installPhase = ''
          runHook preInstall
          install -d $out/share/fonts/truetype
          cp iosevka-charon/iosevkacharon/*.ttf $out/share/fonts/truetype/
          cp iosevka-charon/iosevkacharonmono/*.ttf $out/share/fonts/truetype/
          install -m 644 iosevka-charon/OFL.txt $out/share/fonts/truetype/OFL-iosevka-charon.txt
          runHook postInstall
        '';
        meta = {
          description = "Iosevka Charon and Iosevka Charon Mono fonts";
          homepage = "https://github.com/jul-sh/iosevka-charon";
          license = lib.licenses.ofl;
        };
      };
    };
}
