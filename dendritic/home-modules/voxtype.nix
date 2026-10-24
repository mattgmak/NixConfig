{
  flake.homeModules.voxtype =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.voxtype;
    in
    {
      options.voxtype = {
        enable = lib.mkEnableOption "voxtype push-to-talk dictation daemon";

        asrBaseUrl = lib.mkOption {
          type = lib.types.str;
          example = "https://asr.example.ts.net";
          description = ''
            Base URL of the OpenAI-compatible ASR endpoint.
            voxtype appends /v1/audio/transcriptions itself.
          '';
        };

        asrModel = lib.mkOption {
          type = lib.types.str;
          default = "qwen3-asr";
          description = ''
            Model name sent in the transcription request. gufo rejects any
            name other than its model id, qwen3-asr, or qwen3-asr-1.7b.
          '';
        };

        asrTimeoutSecs = lib.mkOption {
          type = lib.types.ints.positive;
          default = 120;
          description = "Request timeout in seconds. A cold server load can pass 30 s.";
        };

        outputMode = lib.mkOption {
          type = lib.types.enum [
            "type"
            "clipboard"
            "paste"
          ];
          default = "type";
          description = "How voxtype delivers the transcript.";
        };
      };

      config = lib.mkIf cfg.enable {
        # The nixpkgs wrapper already puts wtype, dotool and wl-copy on the
        # daemon PATH.
        home.packages = [ pkgs.voxtype ];

        systemd.user.services.voxtype = {
          Unit = {
            Description = "voxtype push-to-talk dictation daemon";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${lib.getExe pkgs.voxtype} daemon";
            Restart = "on-failure";
            RestartSec = 5;
            Environment = [ "XDG_RUNTIME_DIR=%t" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        xdg.configFile."voxtype/config.toml".text = ''
          # state_file stays "auto": `voxtype record start` reads the daemon PID
          # from the runtime dir.
          state_file = "auto"

          [hotkey]
          enabled = false

          [audio]
          device = "default"
          # gufo resamples to 16 kHz itself, and rejects nothing on rate here.
          sample_rate = 16000

          [whisper]
          mode = "remote"
          remote_endpoint = "${cfg.asrBaseUrl}"
          remote_model = "${cfg.asrModel}"
          remote_timeout_secs = ${toString cfg.asrTimeoutSecs}

          [output]
          mode = "${cfg.outputMode}"
          fallback_to_clipboard = true
          driver_order = [ "wtype", "clipboard" ]

          [output.notification]
          on_recording_start = true
          on_transcription = true
        '';
      };
    };
}
