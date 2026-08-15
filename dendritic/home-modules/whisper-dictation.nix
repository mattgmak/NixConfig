{ inputs, ... }:
{
  flake.homeModules.whisper-dictation =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.whisperDictation;

      # The whisper-dictation flake pins python312 and lists scipy + numpy as deps, but its
      # src never imports them (dead deps). python3.12-scipy isn't in the binary cache, so it
      # source-builds (~20 min) and flakes on a Hypothesis test in TestDistributions (upstream
      # scipy/scipy#22789 — open, no fix; maintainers call these flaky and are removing
      # Hypothesis from the tests). overrideAttrs-swapping the flake env is fragile because
      # old.buildInputs entries are already-coerced store paths, so instead rebuild the package
      # here against host pkgs, where the python312 env's scipy has doCheck=false.
      pythonEnv = pkgs.python312.withPackages (
        ps: with ps; [
          evdev
          pygobject3
          pyaudio
          numpy
          (scipy.overridePythonAttrs (_: {
            doCheck = false;
          }))
          pyyaml
        ]
      );

      # Mirror of the flake's mkWhisperDictation (upstream flake.nix), but built against host
      # pkgs so the only python env referenced is pythonEnv above (scipy doCheck=false).
      # packageName picks the whisper.cpp flavor, same as the flake's packages attr.
      whisperCpp =
        if cfg.packageName == "whisper-dictation-vulkan" then pkgs.whisper-cpp-vulkan else pkgs.whisper-cpp;

      whisper-dictation-pkg = pkgs.stdenv.mkDerivation {
        pname = "whisper-dictation";
        version = "0.1.0";

        src = inputs.whisper-dictation;

        nativeBuildInputs = [ pkgs.makeWrapper ];

        buildInputs = [
          pythonEnv
          whisperCpp
          pkgs.ffmpeg
          pkgs.ydotool
          pkgs.libnotify
          pkgs.gtk4
          pkgs.gobject-introspection
        ];

        installPhase = ''
          mkdir -p $out/bin
          mkdir -p $out/lib/whisper-dictation

          # Copy Python source
          cp -r src/whisper_dictation $out/lib/whisper-dictation/

          # Create wrapper script
          makeWrapper ${pythonEnv}/bin/python3 $out/bin/whisper-dictation \
            --add-flags "-m whisper_dictation" \
            --set PYTHONPATH "$out/lib/whisper-dictation" \
            --prefix PATH : ${
              lib.makeBinPath [
                whisperCpp
                pkgs.ffmpeg
                pkgs.ydotool
                pkgs.libnotify
              ]
            } \
            --prefix GI_TYPELIB_PATH : "${pkgs.gtk4}/lib/girepository-1.0:${pkgs.gobject-introspection}/lib/girepository-1.0"

          # Copy systemd service
          mkdir -p $out/lib/systemd/user
          cp systemd/whisper-dictation.service $out/lib/systemd/user/
        '';

        meta = with lib; {
          description = "Local speech-to-text dictation with push-to-talk for NixOS";
          homepage = "https://github.com/jacopone/whisper-dictation";
          license = licenses.mit;
          platforms = platforms.linux;
        };
      };

      typelibPath = lib.makeSearchPathOutput "out" "lib/girepository-1.0" (
        with pkgs;
        [
          gtk4
          glib
          gobject-introspection
          pango
          gdk-pixbuf
          harfbuzz
          at-spi2-core
          graphene
        ]
      );

      libPath = lib.makeLibraryPath (
        with pkgs;
        [
          gtk4
          glib
          gobject-introspection
          pango
          gdk-pixbuf
          harfbuzz
          at-spi2-core
          wayland
          graphene
          fontconfig
          freetype
        ]
      );

      runtimePath = lib.makeBinPath (
        with pkgs;
        [
          ffmpeg
          ydotool
        ]
      );

      whisper-dictation-wrapped = pkgs.writeShellScriptBin "whisper-dictation" ''
        export GI_TYPELIB_PATH="${typelibPath}"
        export LD_LIBRARY_PATH="${libPath}:$LD_LIBRARY_PATH"
        export PATH="${runtimePath}:$PATH"
        export YDOTOOL_SOCKET="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/.ydotool_socket"
        exec ${whisper-dictation-pkg}/bin/whisper-dictation "$@"
      '';
    in
    {
      options.whisperDictation = {
        packageName = lib.mkOption {
          type = lib.types.str;
          default = "default";
          description = "Attribute name of the package in the whisper-dictation flake. Use \"whisper-dictation-vulkan\" for GPU acceleration (Vulkan).";
        };
        useGpu = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable whisper.use_gpu; only matters on GPU-enabled builds (Vulkan/CUDA/ROCm), CPU-only builds ignore it.";
        };
        inputDevice = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "evdev input device name or path substring to use for hotkey detection. Set to override auto-detection (e.g. \"Svalboard\").";
        };
      };

      config = {
        systemd.user.services = {
          whisper-dictation = {
            Unit = {
              Description = "Whisper Dictation";
              After = [ "graphical-session-pre.target" ];
              PartOf = [ "graphical-session.target" ];
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${whisper-dictation-wrapped}/bin/whisper-dictation --verbose";
              Restart = "on-failure";
              RestartSec = "5s";
            };
          };

          ydotoold = {
            Unit = {
              Description = "ydotool daemon";
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path=%t/.ydotool_socket --socket-perm=0600";
              Restart = "always";
            };
          };

          whisper-model-setup = {
            Unit = {
              Description = "Download whisper model if missing";
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "download-whisper-model" ''
                mkdir -p "$HOME/.local/share/whisper-models"
                if [ ! -f "$HOME/.local/share/whisper-models/ggml-base.bin" ]; then
                   echo "Downloading base model..."
                   ${pkgs.curl}/bin/curl -L -o "$HOME/.local/share/whisper-models/ggml-base.bin" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
                fi
              '';
            };
          };
        };

        home.packages = with pkgs; [
          whisper-dictation-wrapped
          ffmpeg
          ydotool
        ];

        xdg.configFile."whisper-dictation/config.yaml".text = ''
          hotkey:
            key: period
            modifiers:
              - super
          ${lib.optionalString (cfg.inputDevice != null) "input_device: ${cfg.inputDevice}"}
          whisper:
            model: base
            language: en
            threads: 16
            use_gpu: ${lib.boolToString cfg.useGpu}
          ui:
            show_waveform: true
            theme: dark
          processing:
            remove_filler_words: true
            auto_capitalize: false
            auto_punctuate: false
        '';
      };
    };
}
