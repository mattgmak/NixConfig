{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      srcDir = ../../vendor/Ronin-CK/HyprQuickFrame;

      # Upstream temp mode copies and stops. Keep the notification Edit action so
      # the annotation editor opens from the notification, as the old script did.
      tempOld =
        "        const tempPlainCommand =\n"
        + "            `\${grimRegion} - | wl-copy --type image/png `\n"
        + "            + `&& notify-send -a \"HyprQuickFrame\" \"Screenshot Copied\" \"Copied to clipboard\"`;";

      # notify-send -A blocks until a click. The old chain held quickshell open,
      # so the next launch lost the instance lock. Detach the notify and satty step.
      notifyScript = pkgs.writeShellScript "hyprquickframe-temp-notify" ''
        img="$1"
        outDir="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
        out="$outDir/screenshot-$(date +%F_%H-%M-%S).png"
        ${pkgs.libnotify}/bin/notify-send -a "HyprQuickFrame" -i "$img" \
          -h "string:image-path:$img" -p -A edit=Edit \
          "Screenshot Copied" "Copied to clipboard" \
          | ${pkgs.gnugrep}/bin/grep -q edit \
          && ${pkgs.coreutils}/bin/mkdir -p "$outDir" \
          && ${pkgs.satty}/bin/satty --filename "$img" --output-filename "$out" \
            --early-exit --copy-command "wl-copy --type image/png" \
            --disable-notifications
        if [ -f "$out" ]; then
          ${pkgs.libnotify}/bin/notify-send -a "HyprQuickFrame" -i "$out" \
            -h "string:image-path:$out" "Screenshot Saved" "Saved to $out"
        fi
        ${pkgs.coreutils}/bin/rm -f "$img"
      '';

      tempNew =
        "        const tempPlainCommand =\n"
        + "            `\${grimRegion} \${eTempSnip} `\n"
        + "            + `&& wl-copy --type image/png < \${eTempSnip} `\n"
        + "            + `&& (${notifyScript} \${eTempSnip} >/dev/null 2>&1 &)`;";

      hideOld = "        if (root.editActive)\n            hideOverlaysTimer.start();";

      hideNew = "        if (root.editActive || root.tempActive)\n            hideOverlaysTimer.start();";

      shellQml =
        let
          original = builtins.readFile "${srcDir}/shell.qml";
          step1 = builtins.replaceStrings [ tempOld ] [ tempNew ] original;
          patched = builtins.replaceStrings [ hideOld ] [ hideNew ] step1;
        in
          if step1 == original then
            throw "hyprquickframe: upstream tempPlainCommand changed, update tempOld/tempNew"
          else if patched == step1 then
            throw "hyprquickframe: upstream hide timer changed, update hideOld/hideNew"
          else
            pkgs.writeText "shell.qml" patched;

      hyprquickframe = pkgs.stdenv.mkDerivation {
        pname = "hyprquickframe";
        version = "0.1.0";

        src = srcDir;
        dontBuild = true;
        nativeBuildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          runHook preInstall

          mkdir -p $out/share/hyprquickframe
          cp -r $src/. $out/share/hyprquickframe/
          rm -rf $out/share/hyprquickframe/.git
          chmod -R u+w $out/share/hyprquickframe
          cp ${shellQml} $out/share/hyprquickframe/shell.qml

          mkdir -p $out/bin
          makeWrapper ${inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/quickshell \
            $out/bin/hyprquickframe \
            --prefix PATH : ${
              pkgs.lib.makeBinPath [
                pkgs.bash
                pkgs.coreutils
                pkgs.gnugrep
                pkgs.grim
                pkgs.libnotify
                pkgs.satty
                pkgs.wl-clipboard
              ]
            } \
            --add-flags "-c $out/share/hyprquickframe -n"

          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "Quickshell screenshot overlay for Hyprland, patched to keep the notification Edit action";
          homepage = "https://github.com/Ronin-CK/HyprQuickFrame";
          license = licenses.mit;
          mainProgram = "hyprquickframe";
          platforms = platforms.linux;
        };
      };
    in
    {
      packages.hyprquickframe = hyprquickframe;
    };
}
