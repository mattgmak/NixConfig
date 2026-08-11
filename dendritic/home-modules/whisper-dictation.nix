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

      whisper-dictation-pkg =
        (inputs.whisper-dictation.packages.${pkgs.stdenv.hostPlatform.system}.${cfg.packageName}).overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ./whisper-blank-filter.patch
          ];
        });

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
            ExecStart = "${whisper-dictation-wrapped}/bin/whisper-dictation";
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
