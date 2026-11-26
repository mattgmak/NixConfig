{ ... }:
{
  flake.nixosModules.orca-slicer =
    { pkgs, ... }:
    let
      orca = pkgs.appimageTools.wrapType2 rec {
        pname = "orca-slicer";
        version = "2.5.2";
        src = pkgs.fetchurl {
          url = "https://github.com/OrcaSlicer/OrcaSlicer/releases/download/v2.5.2/OrcaSlicer_Linux_AppImage_Ubuntu2404_V2.5.2.AppImage";
          hash = "sha256-IvqIiE3sP9vSnpDLqZEvz/b7V6YLG9wabBicYaawqHA=";
        };

        # bwrap defaults to --die-with-parent, killing the app when the launcher helper exits.
        dieWithParent = false;

        extraPkgs =
          pkgs:
          with pkgs;
          [
            webkitgtk_4_1
            libsoup_3
            glib-networking
            gst_all_1.gst-plugins-base
            gst_all_1.gst-plugins-good
            gst_all_1.gst-plugins-bad
            gst_all_1.gst-libav
          ];

        extraInstallCommands = ''
          contents=${pkgs.appimageTools.extract { inherit pname version src; }}
          install -Dm444 $contents/com.orcaslicer.OrcaSlicer.desktop \
            $out/share/applications/OrcaSlicer.desktop
          substituteInPlace $out/share/applications/OrcaSlicer.desktop \
            --replace-fail 'Exec=AppRun' 'Exec=${pname}'
          cp -r --no-preserve=mode $contents/usr/share/icons $out/share/
          install -Dm444 $contents/OrcaSlicer.png \
            $out/share/icons/hicolor/256x256/apps/OrcaSlicer.png

          # Orca probes the Fedora CA path; point at the NixOS bundle instead.
          # GIO_EXTRA_MODULES: libsoup/WebKit find the gnutls backend only via this path.
          source ${pkgs.makeWrapper}/nix-support/setup-hook
          wrapProgram $out/bin/${pname} \
            --set-default SSL_CERT_FILE /etc/ssl/certs/ca-bundle.crt \
            --prefix GIO_EXTRA_MODULES : ${pkgs.glib-networking}/lib/gio/modules
        '';

        meta = {
          description = "OrcaSlicer ${version}";
          homepage = "https://github.com/OrcaSlicer/OrcaSlicer";
          mainProgram = pname;
        };
      };
    in
    {
      environment.systemPackages = [
        orca
        pkgs.nanum # for fixing https://github.com/OrcaSlicer/OrcaSlicer/issues/11641
      ];
    };
}
