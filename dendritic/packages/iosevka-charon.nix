{ lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      py = pkgs.python3.withPackages (ps: [ ps.fonttools ]);

      metricsPy = pkgs.writeText "set-metrics.py" ''
        import sys
        from fontTools.ttLib import TTFont

        path, asc, desc = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
        font = TTFont(path)
        font["hhea"].ascender = asc
        font["hhea"].descender = desc
        font["OS/2"].sTypoAscender = asc
        font["OS/2"].sTypoDescender = desc
        font["OS/2"].usWinAscent = asc
        font["OS/2"].usWinDescent = -desc
        font.save(path)
      '';
    in
    {
      # Iosevka Charon plus Iosevka Charon Mono from the upstream release.
      # nixpkgs ships plain iosevka only, so vendor the zip here. The zip has
      # three top-level entries, so fetchzip refuses it: use fetchurl + unzip.

      # The release declares leading 1.28em (ascender 1015, descender -265). Measured
      # ink in the shipped TTFs: caps and ascenders reach 735, descenders -223, and
      # acutecomb 763. Caron composites reach 985. The box at 763/-223 covers every
      # glyph except caron composites, which clip as they do upstream. A box shorter
      # than the ink makes GTK4 clip drawing to the allocation.
      packages.iosevka-charon = pkgs.stdenvNoCC.mkDerivation {
        pname = "iosevka-charon";
        version = "34.801";
        src = pkgs.fetchurl {
          url = "https://github.com/jul-sh/iosevka-charon/releases/download/v34.801/iosevka-charon.zip";
          hash = "sha256-4AscQdafBFvjTtoCiVm/lDZ9CwU/5+K9TMq4sapY7TI=";
        };
        nativeBuildInputs = [
          pkgs.unzip
          py
        ];
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
          for f in $out/share/fonts/truetype/*.ttf; do
            ${py}/bin/python3 ${metricsPy} "$f" 763 -223
          done
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
