{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      vesktop = pkgs.callPackage (
        {
          lib,
          stdenv,
          fetchurl,
          autoPatchelfHook,
          copyDesktopItems,
          makeWrapper,
          alsa-lib,
          at-spi2-core,
          cups,
          dbus,
          expat,
          fontconfig,
          glib,
          gsettings-desktop-schemas,
          gtk3,
          libdrm,
          libGL,
          libgbm,
          libxkbcommon,
          nspr,
          nss,
          pango,
          xorg,
        }:
        stdenv.mkDerivation (finalAttrs: {
          pname = "vesktop";
          version = "1.7.0";

          # TODO: drop once nixpkgs ships vesktop 1.7.0 (pin 3ed67ec has 1.6.7 with
          # electron_43; upstream 1.7.0 pins electron 45.4.1).
          # Upstream electron-builder output: electron binary plus resources/app.asar.
          src = fetchurl {
            url =
              let
                suffix = lib.optionalString stdenv.hostPlatform.isAarch64 "-arm64";
              in
              "https://github.com/Vencord/Vesktop/releases/download/v${finalAttrs.version}/vesktop-${finalAttrs.version}${suffix}.tar.gz";
            hash =
              if stdenv.hostPlatform.isAarch64 then
                "sha256-doKOUn+4Ja8qYObPIemozIrRfHJqugg6xYdvg4Vkeq8="
              else
                "sha256-mtAPSK00TuHU8Bqn1PRK+yeDaldNEykfJ52GYFU3dwU=";
          };

          sourceRoot = "vesktop-${finalAttrs.version}";

          # Upstream tarball ships no icon; fetch the app icon from the repo.
          icon = fetchurl {
            url = "https://raw.githubusercontent.com/Vencord/Vesktop/v${finalAttrs.version}/build/icon.svg";
            hash = "sha256-fQ+dvbPIb4AFd9f7JqIt7+twJdEMQF9jTTwrk5p1vn8=";
          };

          nativeBuildInputs = [
            autoPatchelfHook
            copyDesktopItems
            makeWrapper
          ];

          buildInputs = [
            alsa-lib
            at-spi2-core
            cups
            dbus
            expat
            fontconfig
            glib
            gsettings-desktop-schemas
            gtk3
            libdrm
            libGL
            libgbm
            libxkbcommon
            nspr
            nss
            pango
            xorg.libX11
            xorg.libXcomposite
            xorg.libXdamage
            xorg.libXext
            xorg.libXfixes
            xorg.libXrandr
            xorg.libxshmfence
          ];

          # Prebuilt binary: keep its symbols and bundled libraries.
          dontStrip = true;

          installPhase = ''
            runHook preInstall
            install -d $out/lib/vesktop
            cp -r . $out/lib/vesktop/
            install -d $out/share/icons/hicolor/scalable/apps
            install -m644 ${finalAttrs.icon} $out/share/icons/hicolor/scalable/apps/vesktop.svg
            runHook postInstall
          '';

          postFixup = ''
            makeWrapper $out/lib/vesktop/vesktop $out/bin/vesktop \
              --add-flags "''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
          '';

          desktopItems = [
            (pkgs.makeDesktopItem {
              name = "vesktop";
              desktopName = "Vesktop";
              exec = "vesktop %U";
              icon = "vesktop";
              startupWMClass = "Vesktop";
              genericName = "Internet Messenger";
              keywords = [
                "discord"
                "vencord"
                "electron"
                "chat"
              ];
              categories = [
                "Network"
                "InstantMessaging"
                "Chat"
              ];
              mimeTypes = [
                "x-scheme-handler/discord"
              ];
            })
          ];

          meta = {
            description = "Alternative Discord client with Vencord built-in";
            homepage = "https://github.com/Vencord/Vesktop";
            changelog = "https://github.com/Vencord/Vesktop/releases/tag/v${finalAttrs.version}";
            license = lib.licenses.gpl3Only;
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            mainProgram = "vesktop";
            platforms = [
              "x86_64-linux"
              "aarch64-linux"
            ];
          };
        })
      ) { };
    in
    {
      # Upstream ships no darwin tarball; darwin hosts keep nixpkgs' vesktop.
      packages = pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.isLinux) {
        inherit vesktop;
      };
    };
}
