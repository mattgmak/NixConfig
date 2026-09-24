{
  inputs,
  self,
  withSystem,
  ...
}:
let
  hostname = self.constants.macMiniName;
  system = "aarch64-darwin";
in
{
  flake.darwinConfigurations.${hostname} = withSystem system (
    { self', config, ... }:
    inputs.nix-darwin.lib.darwinSystem {
      specialArgs = rec {
        inherit system;
        inherit inputs hostname;
        inherit (config) common-overlays common-nixpkgs-config;
        mv = self'.legacyPackages.mv;
        username = "mattgmak";
      };
      modules = [
        self.darwinModules.${hostname}
        self.nixConfig
        inputs.agenix.darwinModules.default
      ];
    }
  );

  flake.homeConfigurations.MacMini = {
    imports = with self.homeModules; [
      darwin-home
      atuin
      zoxide
      zen-browser
      nushell
      wezterm
      neovim
      starship
      yazi
      git
      delta
      gh
      direnv
      devenv
      lazygit
      ghostty
      # cursor
      pi-coding-agent
      carapace
      zellij
      tmux
      worktrunk
      gh-dash
      btop
      # bat
      nix-index-database
      opencode
    ];
    stylix.targets.bat.enable = false;
  };

  flake.darwinModules.${hostname} =
    {
      pkgs,
      hostname,
      username,
      mv,
      common-overlays,
      common-nixpkgs-config,
      ...
    }:
    let
      crawl4aiPort = 11235;
      crawl4aiImage = "docker.io/unclecode/crawl4ai:latest";
      crawl4aiApiToken =
        builtins.substring 0 64 (
          builtins.hashString "sha256" "pi-crawl4ai-/Users/${username}"
        );
      searxngPort = 8888;
      # Pin the multi-arch OCI *index* digest, not a platform sub-manifest: podman
      # then selects the native image. Pinning the amd64 sub-manifest digest made
      # arm64 hosts run the image under qemu, which segfaults.
      searxngImage = "docker.io/searxng/searxng:2026.9.22-2ed96e6fc@sha256:f6f67c89efdac7b1bd4805703764ecaa9d0777b86a101b86cae4f1563de4d627";
      podmanBootstrap = ''
        configure_podman_socket() {
          socket=$(
            podman machine inspect podman-machine-default \
              --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null || true
          )
          if [ -n "$socket" ] && [ -S "$socket" ]; then
            export CONTAINER_HOST="unix://$socket"
          fi
        }

        wait_for_podman() {
          for _ in $(seq 1 120); do
            podman info >/dev/null 2>&1 && return 0
            sleep 2
          done
          echo "podman API not ready after 240s" >&2
          return 1
        }

        reset_podman_machine() {
          echo "resetting podman machine after storage failure" >&2
          podman machine stop 2>/dev/null || true
          podman machine rm -f podman-machine-default 2>/dev/null || true
          podman machine init --cpus 2 --memory 4096
          podman machine start
          configure_podman_socket
          wait_for_podman
        }

        ensure_podman() {
          if [ -z "$(podman machine list -q 2>/dev/null | head -n1)" ]; then
            podman machine init --cpus 2 --memory 4096
          fi
          if ! podman info >/dev/null 2>&1; then
            if ! podman machine start; then
              reset_podman_machine
              return 0
            fi
          fi
          configure_podman_socket
          wait_for_podman
        }

        storage_error() {
          grep -qE 'lower layer|overlay/diff' "$1" 2>/dev/null
        }

        ensure_podman_storage() {
          local errfile="$storageCheckErrfile"
          podman pull "$image" || true
          if podman run --rm --entrypoint "" "$image" /bin/sh -c "exit 0" 2>"$errfile"; then
            return 0
          fi
          if storage_error "$errfile"; then
            reset_podman_machine
            podman pull "$image" || true
            podman run --rm --entrypoint "" "$image" /bin/sh -c "exit 0" 2>"$errfile" || {
              cat "$errfile" >&2
              return 1
            }
            return 0
          fi
          cat "$errfile" >&2
          return 1
        }
      '';
      piCrawl4aiServe = pkgs.writeShellApplication {
        name = "pi-crawl4ai-serve";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.podman
        ];
        text = ''
          set -euo pipefail
          port=${toString crawl4aiPort}
          image=${crawl4aiImage}
          token=${crawl4aiApiToken}
          stateDir="$HOME/.local/state"
          lockDir="$stateDir/crawl4ai-serve.lock"
          mkdir -p "$stateDir"

          # Homebrew podman owns the macOS VM; prepend without clobbering runtimeInputs PATH.
          export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

          service_healthy() {
            curl -sf -o /dev/null "http://127.0.0.1:$port/health" 2>/dev/null
          }

          clear_stale_lock() {
            if [ ! -d "$lockDir" ]; then
              return 0
            fi
            if service_healthy; then
              return 0
            fi
            if pgrep -f 'pi-crawl4ai-serve' >/dev/null 2>&1; then
              return 0
            fi
            echo "clearing stale crawl4ai lock" >&2
            rmdir "$lockDir" 2>/dev/null || true
          }

          clear_stale_lock
          if ! mkdir "$lockDir" 2>/dev/null; then
            echo "crawl4ai serve already starting; deferring to launchd retry" >&2
            exit 1
          fi
          trap 'rmdir "$lockDir" 2>/dev/null || true' EXIT

          storageCheckErrfile="$stateDir/crawl4ai.storage-check.stderr"
          ${podmanBootstrap}
          ensure_podman
          ensure_podman_storage

          podman rm -f pi-crawl4ai 2>/dev/null || true
          exec podman run --rm --name pi-crawl4ai --shm-size=1g \
            -p "127.0.0.1:$port:11235" \
            -e "CRAWL4AI_API_TOKEN=$token" \
            "$image"
        '';
      };
      piSearxngServe = pkgs.writeShellApplication {
        name = "pi-searxng-serve";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.podman
        ];
        text = ''
          set -euo pipefail
          port=${toString searxngPort}
          image=${searxngImage}
          stateDir="$HOME/.local/state"
          lockDir="$stateDir/searxng-serve.lock"
          settingsFile="$HOME/.local/share/pi-searxng/settings.yml"
          mkdir -p "$stateDir"

          # Homebrew podman owns the macOS VM; prepend without clobbering runtimeInputs PATH.
          export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

          if [ -L "$settingsFile" ]; then
            echo "$settingsFile must be a regular file, not a symlink: podman-machine VM cannot resolve /nix/store symlinks" >&2
            exit 1
          fi

          if [ ! -f "$settingsFile" ]; then
            echo "missing $settingsFile; must be written by the home-manager pi-coding-agent activation" >&2
            exit 1
          fi

          service_healthy() {
            curl -sf -o /dev/null "http://127.0.0.1:$port/healthz"
          }

          clear_stale_lock() {
            if [ ! -d "$lockDir" ]; then
              return 0
            fi
            if service_healthy; then
              return 0
            fi
            if pgrep -f 'pi-searxng-serve' >/dev/null 2>&1; then
              return 0
            fi
            echo "clearing stale searxng lock" >&2
            rmdir "$lockDir" 2>/dev/null || true
          }

          clear_stale_lock
          if ! mkdir "$lockDir" 2>/dev/null; then
            echo "searxng serve already starting; deferring to launchd retry" >&2
            exit 1
          fi
          trap 'rmdir "$lockDir" 2>/dev/null || true' EXIT

          storageCheckErrfile="$stateDir/searxng.storage-check.stderr"
          ${podmanBootstrap}
          ensure_podman
          ensure_podman_storage

          podman rm -f pi-searxng 2>/dev/null || true
          exec podman run --rm --name pi-searxng \
            -p "127.0.0.1:$port:8080" \
            -v "$HOME/.local/share/pi-searxng/settings.yml:/etc/searxng/settings.yml:ro" \
            "$image"
        '';
      };
    in
    {
      nixpkgs.overlays = common-overlays;
      nixpkgs.config = common-nixpkgs-config;
      nixpkgs.hostPlatform = "aarch64-darwin";
      system.stateVersion = 6;
      # The "options.json ... without a proper context" eval warning actually
      # came from home-manager's reference manpage (manual.manpages.enable,
      # disabled in home-modules/home.nix), not from nix-darwin. Keep the
      # nix-darwin manual disabled anyway — it is unnecessary on macOS.
      documentation.enable = false;
      nix = {
        enable = false;
      };

      # Determinate Nix manages daemon itself; nix-darwin's nix.gc options
      # are inert.  Ditch old profile generations weekly with nh instead.
      launchd.daemons.nix-gc = {
        serviceConfig = {
          ProgramArguments = [
            "${pkgs.nh}/bin/nh"
            "clean"
            "all"
            "--keep"
            "3"
          ];
          StartInterval = 604800; # weekly
          RunAtLoad = false;
          StandardOutPath = "/var/log/nix-gc.stdout";
          StandardErrorPath = "/var/log/nix-gc.stderr";
        };
      };

      # Engram persistent-memory HTTP server (default port 7437). The
      # gentle-engram Pi extension talks to this over localhost; without it
      # mem_* tools fail with "Engram server not running". RunAtLoad starts it
      # at login, KeepAlive restarts it on crash/exit. DB + logs live in
      # ~/.engram (created on first serve).
      launchd.agents.engram = {
        serviceConfig = {
          ProgramArguments = [
            "${self.packages.${system}.engram}/bin/engram"
            "serve"
          ];
          # nix-darwin loads agents into the system domain here; without
          # UserName the job would run as root. Pin the user explicitly.
          UserName = username;
          # launchd daemon/agent context does not set $HOME; engram refuses
          # to start without it ("determine home directory: $HOME is not
          # defined"). Pin it so the DB stays at ~/.engram.
          EnvironmentVariables = {
            HOME = "/Users/${username}";
            USER = username;
          };
          RunAtLoad = true;
          KeepAlive = true;
          WorkingDirectory = "/Users/${username}";
          StandardOutPath = "/Users/${username}/.engram/serve.stdout.log";
          StandardErrorPath = "/Users/${username}/.engram/serve.stderr.log";
        };
      };

      # Crawl4AI fetch server for pi-web-access (fetch_content fallback).
      # Linux pi hosts use systemd.user.services.crawl4ai in pi-coding-agent.nix;
      # darwin has no user systemd, so mirror engram with a launchd agent.
      launchd.agents.crawl4ai = {
        serviceConfig = {
          ProgramArguments = [ "${piCrawl4aiServe}/bin/pi-crawl4ai-serve" ];
          UserName = username;
          EnvironmentVariables = {
            HOME = "/Users/${username}";
            USER = username;
            PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${pkgs.podman}/bin:${pkgs.coreutils}/bin";
          };
          RunAtLoad = true;
          KeepAlive = true;
          # Avoid overlapping podman machine boots when the agent restarts quickly.
          ThrottleInterval = 30;
          WorkingDirectory = "/Users/${username}";
          StandardOutPath = "/Users/${username}/.local/state/crawl4ai.stdout.log";
          StandardErrorPath = "/Users/${username}/.local/state/crawl4ai.stderr.log";
        };
      };

      # SearXNG meta-search for pi web-search (http://127.0.0.1:8888).
      # Linux pi hosts use systemd.user.services.searxng in pi-coding-agent.nix;
      # darwin has no user systemd, so mirror engram with a launchd agent.
      launchd.agents.searxng = {
        serviceConfig = {
          ProgramArguments = [ "${piSearxngServe}/bin/pi-searxng-serve" ];
          UserName = username;
          EnvironmentVariables = {
            HOME = "/Users/${username}";
            USER = username;
            PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${pkgs.podman}/bin:${pkgs.coreutils}/bin";
          };
          RunAtLoad = true;
          KeepAlive = true;
          # Avoid overlapping podman machine boots when the agent restarts quickly.
          ThrottleInterval = 30;
          WorkingDirectory = "/Users/${username}";
          StandardOutPath = "/Users/${username}/.local/state/searxng.stdout.log";
          StandardErrorPath = "/Users/${username}/.local/state/searxng.stderr.log";
        };
      };

      imports = [
        inputs.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
        inputs.stylix.darwinModules.stylix
        self.fonts
        self.stylixCommon
      ];

      users.users.${username} = {
        home = "/Users/${username}";
        shell = pkgs.zsh;
      };

      environment.shells = with pkgs; [
        bashInteractive
        zsh
      ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit
            inputs
            hostname
            username
            mv
            ;
        };
        backupFileExtension = "hm-backup";
        users.${username} = self.homeConfigurations.MacMini;
      };

      environment.variables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
        DEVELOPER_DIR = "/Applications/Xcode.app/Contents/Developer";
        SHELL = "${pkgs.nushell}/bin/nu";
      };

      environment.systemPackages =
        with pkgs;
        [
          fzf
          ripgrep
          nixfmt
          nixd
          nh
          nvd
          nix-output-monitor
          fastfetch
          stats
          base16-shell-preview
          jq
          mas
          git-credential-manager
          cocoapods
          ruby_3_4
          nix-search-cli
          swift-format
          swiftlint
          xcbeautify
          sourcekit-lsp
          dua
          eza
          ollama
          stylua
          podman-tui
          go
          cursor-cli
          bat
          llama-cpp
          inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.agenix
          inputs.codegraph.packages.${pkgs.stdenv.hostPlatform.system}.default
          nightlight
          bash-language-server
          shfmt
          shellcheck
          uv
        ]
        ++ (with pkgs.darwin; [
          file_cmds
          text_cmds
          developer_cmds
        ]);

      nix-homebrew = {
        enable = true;
        enableRosetta = true;
        user = username;
        autoMigrate = true;
      };

      homebrew = {
        enable = true;
        casks = [
          "google-chrome"
          "github-copilot-for-xcode"
          "vial"
          "android-studio"
          "android-platform-tools"
          "locationsimulator"
          "zulu@17"
          # "chromium"
          "ghostty"
          "figma"
        ];
        brews = [
          "xcode-build-server"
          "podman"
          "podman-compose"
          "fastlane"
          "blueutil"
        ];
        onActivation.cleanup = "zap";
        # masApps = { "Yoink" = 457622435; };
      };

      fonts.packages = with pkgs; [
        nerd-fonts.iosevka-term
        inter
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
      ];

      services.aerospace = {
        enable = true;
        settings = {
          "config-version" = 2;
          "default-root-container-layout" = "tiles";
          "default-root-container-orientation" = "auto";
          "enable-normalization-flatten-containers" = true;
          "enable-normalization-opposite-orientation-for-nested-containers" = true;
          "accordion-padding" = 30;

          "key-mapping"."preset" = "qwerty";

          # Match prior yabai gap behavior as closely as possible.
          gaps = {
            inner = {
              horizontal = 5;
              vertical = 5;
            };
            outer = {
              left = 0;
              bottom = 0;
              top = 0;
              right = 0;
            };
          };

          mode.main.binding = {
            # Focus navigation (Vim-style hjkl directional mapping)
            "alt-h" = "focus left";
            "alt-j" = "focus down";
            "alt-k" = "focus up";
            "alt-l" = "focus right";

            # Swap windows
            "alt-shift-h" = "swap left";
            "alt-shift-j" = "swap down";
            "alt-shift-k" = "swap up";
            "alt-shift-l" = "swap right";

            # Window management
            "alt-f" = "fullscreen";
            "alt-t" = "layout floating tiling";
            "alt-d" = "close";

            # Workspace switching
            "alt-0" = "workspace 0";

            # Workspace 1 for ghostty
            "alt-1" = "workspace 1";
            "alt-w" = "workspace 1";

            # Workspace 2 for cursor
            "alt-2" = "workspace 2";
            "alt-e" = "workspace 2";

            # Workspace 3 for zen
            "alt-3" = "workspace 3";
            "alt-r" = "workspace 3";

            "alt-4" = "workspace 4";
            "alt-5" = "workspace 5";
            "alt-6" = "workspace 6";
            "alt-7" = "workspace 7";
            "alt-8" = "workspace 8";
            "alt-9" = "workspace 9";

            # Move windows to workspaces
            "alt-shift-0" = "move-node-to-workspace --focus-follows-window 0";
            "alt-shift-1" = "move-node-to-workspace --focus-follows-window 1";
            "alt-shift-2" = "move-node-to-workspace --focus-follows-window 2";
            "alt-shift-3" = "move-node-to-workspace --focus-follows-window 3";
            "alt-shift-4" = "move-node-to-workspace --focus-follows-window 4";
            "alt-shift-5" = "move-node-to-workspace --focus-follows-window 5";
            "alt-shift-6" = "move-node-to-workspace --focus-follows-window 6";
            "alt-shift-7" = "move-node-to-workspace --focus-follows-window 7";
            "alt-shift-8" = "move-node-to-workspace --focus-follows-window 8";
            "alt-shift-9" = "move-node-to-workspace --focus-follows-window 9";

            # Resize windows (closest AeroSpace equivalents)
            "alt-u" = "resize height -50";
            "alt-i" = "resize height +50";
            "alt-o" = "resize width -50";
            "alt-p" = "resize width +50";
            "alt-shift-u" = "resize height +50";
            "alt-shift-i" = "resize height -50";
            "alt-shift-o" = "resize width +50";
            "alt-shift-p" = "resize width -50";

            # Focus key apps
            # "alt-w" = "exec-and-forget osascript -e 'tell application \"Ghostty\" to activate'";
            # "alt-e" = "exec-and-forget osascript -e 'tell application \"Cursor\" to activate'";
            # "alt-r" = "exec-and-forget osascript -e 'tell application \"Zen\" to activate'";
            "alt-x" = "exec-and-forget osascript -e 'tell application \"Xcode\" to activate'";
            "alt-a" = "exec-and-forget osascript -e 'tell application \"Android Studio\" to activate'";
            "alt-s" = "exec-and-forget osascript -e 'tell application \"Simulator\" to activate'";
            "alt-c" = "exec-and-forget osascript -e 'tell application \"Google Chrome\" to activate'";

          };

          on-window-detected = [
            {
              "if".app-id = "com.mitchellh.ghostty";
              run = "layout floating";
            }
          ];
        };
      };

      system = {
        defaults = {
          finder = {
            AppleShowAllFiles = true;
            AppleShowAllExtensions = true;
          };
          dock = {
            autohide = true;
            autohide-delay = 0.0;
            autohide-time-modifier = 0.2;
            expose-animation-duration = 0.2;
            persistent-apps = [ ];
          };
          NSGlobalDomain = {
            ApplePressAndHoldEnabled = false;
            _HIHideMenuBar = true;
          };
          CustomUserPreferences = {
            "com.apple.loginwindow" = {
              LoginwindowLaunchesRelaunchApps = false;
            };
          };
        };
        primaryUser = username;
      };
    };

}
