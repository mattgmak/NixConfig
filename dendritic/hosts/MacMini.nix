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
      mac-mini-home
      atuin
      zoxide
      zen-browser
      nushell
      zsh
      bash
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
    ];
    stylix.targets.bat.enable = false;
  };

  flake.darwinModules.${hostname} =
    {
      pkgs,
      lib,
      hostname,
      username,
      mv,
      common-overlays,
      common-nixpkgs-config,
      ...
    }:
    let
      # Compromised intermediate CA keys force two roots out of the trust store.
      # Each p11-kit entry opens with its alias line, so the filter cuts whole entries.
      cacertFiltered = pkgs.runCommand "cacert-filtered" { } ''
        src=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
        dest=$out/etc/ssl/certs/ca-bundle.crt
        install -d $out/etc/ssl/certs
        ${pkgs.gawk}/bin/awk '
          /^-----BEGIN/ { inblock = 1 }
          /^-----END/ { inblock = 0 }
          !inblock && /^[^ \t-]/ && $0 !~ /^(Trusted for:|Traditional PEM block omitted:)/ {
            drop = ($0 == "Comodo AAA Services root" || $0 == "emSign ECC Root CA - G3")
          }
          !drop { print }
        ' $src > $dest

        # Guard against an upstream alias rename, which would silence the filter.
        ${pkgs.gnugrep}/bin/grep -qE '^(Comodo AAA Services root|emSign ECC Root CA - G3)$' $dest && {
          echo "filtered CA bundle still holds a revoked root" >&2
          exit 1
        }
        test $(${pkgs.gnugrep}/bin/grep -c '^-----BEGIN' $dest) -lt \
          $(${pkgs.gnugrep}/bin/grep -c '^-----BEGIN' $src) || {
          echo "filtered CA bundle lost no certificate blocks" >&2
          exit 1
        }
      '';
      caBundle = "${cacertFiltered}/etc/ssl/certs/ca-bundle.crt";
      # Homebrew ruby, python and uv trust the rustls/OpenSSL default store, so
      # each toolchain gets its own name for the filtered bundle.
      # Bun adds an env root to its own embedded store. Only the install bundle
      # marks the revoked roots as reject entries, so SSL_CERT_FILE keeps it.
      caEnv = {
        SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
        NIX_SSL_CERT_FILE = caBundle;
        CURL_CA_BUNDLE = caBundle;
        GIT_SSL_CAINFO = caBundle;
        REQUESTS_CA_BUNDLE = caBundle;
        CARGO_HTTP_CAINFO = caBundle;
        UV_SYSTEM_CERTS = "1";
      };
      # environment.variables reaches shells only, through /etc/static/zshenv.
      # GUI apps and launchd jobs read the launchd user domain, so seed that
      # domain once per login. Running apps keep the old env until relaunch.
      caEnvSetenv = pkgs.writeShellScript "ca-env-setenv" (
        lib.concatStrings (
          lib.mapAttrsToList (name: value: "/bin/launchctl setenv ${name} ${lib.escapeShellArg value}\n") caEnv
        )
      );
      # Apple ships its own /etc/ssl/cert.pem and it keeps both revoked roots.
      # This root job strips them at boot, then probes the advisory hosts.
      fixSslCertPem = pkgs.writeShellScript "fix-ssl-cert-pem" ''
        set -eu

        file=/etc/ssl/cert.pem
        aaa='CN=AAA Certificate Services'
        emsign='CN=emSign ECC Root CA - G3'
        grep=${pkgs.gnugrep}/bin/grep
        awk=${pkgs.gawk}/bin/awk

        [ -f "$file" ] && [ -r "$file" ] || exit 0

        if ! "$grep" -qF "$aaa" "$file" && ! "$grep" -qF "$emsign" "$file"; then
          echo "clean: $file holds no revoked root"
          exit 0
        fi

        blocks=$("$grep" -c '^-----BEGIN CERTIFICATE-----' "$file" || true)
        entries=$("$grep" -c '^=== ' "$file" || true)
        if [ "$blocks" -lt 100 ] || [ "$entries" -lt 100 ]; then
          echo "refuse: damaged $file, $blocks BEGIN blocks, $entries entries"
          exit 2
        fi

        stamp=$(date +%Y%m%d-%H%M%S)
        backup="$file.bak.$stamp"
        n=0
        while [ -e "$backup" ]; do
          n=$((n + 1))
          backup="$file.bak.$stamp-$n"
        done
        cp -p "$file" "$backup"
        echo "backup: $backup"

        tmp="$file.tmp.$$"
        # The advisory filter leaves the ### header of each cut entry behind, so
        # drop that header too. A rerun then finds no trace and reports clean.
        "$awk" '/^(###|===) /{skip=0} /^=== .*\/CN=(AAA Certificate Services|emSign ECC Root CA - G3)$/{skip=1} !skip' "$backup" \
          | "$grep" -vE '^(###|===) .*/CN=(AAA Certificate Services|emSign ECC Root CA - G3)$' >"$tmp"
        chmod 644 "$tmp"
        chown root:wheel "$tmp"
        mv "$tmp" "$file"

        # Offline proof. A broken filter must not pass as a fix.
        if "$grep" -qF "$aaa" "$file" || "$grep" -qF "$emsign" "$file"; then
          cp -p "$backup" "$file"
          echo "patch failed, rolled back"
          exit 1
        fi

        # curl exit 60 means the peer refuses the chain. That is the wanted state.
        # Exit 0 means the chain still validates. Any other exit gives no verdict,
        # so a boot without network must not count as success.
        # The probe reads $file, not the environment. caEnv points curl at the
        # filtered bundle, so an ambient run would hide a bad patch.
        probe() {
          rc=0
          ${pkgs.coreutils}/bin/env -u SSL_CERT_FILE -u CURL_CA_BUNDLE -u NIX_SSL_CERT_FILE \
            /usr/bin/curl -s -o /dev/null --max-time 10 --cacert "$file" "https://$1/" || rc=$?
          echo "$rc"
        }

        aaa_state=0
        emudhra_state=0
        attempt=1
        while [ "$attempt" -le 12 ]; do
          aaa_code=$(probe dv-g3b-aaa-emudhra.we-have-a-problem.com)
          emudhra_code=$(probe dv-g3b-emudhra.we-have-a-problem.com)
          echo "probe $attempt: aaa exit $aaa_code, emudhra exit $emudhra_code"
          if [ "$aaa_code" -eq 0 ] || [ "$emudhra_code" -eq 0 ]; then
            cp -p "$backup" "$file"
            echo "EXPOSED, rolled back"
            exit 1
          fi
          if [ "$aaa_code" -eq 60 ]; then aaa_state=1; fi
          if [ "$emudhra_code" -eq 60 ]; then emudhra_state=1; fi
          if [ "$aaa_state" -eq 1 ] && [ "$emudhra_state" -eq 1 ]; then
            echo "fixed: stripped revoked roots from $file"
            exit 0
          fi
          attempt=$((attempt + 1))
          if [ "$attempt" -le 12 ]; then sleep 10; fi
        done

        echo "unverified: probes got no verdict, patch kept"
        exit 2
      '';
      crawl4aiPort = 11235;
      crawl4aiImage = "docker.io/unclecode/crawl4ai:latest";
      crawl4aiApiToken = builtins.substring 0 64 (
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
          podman machine init --cpus 2 --memory 4096 --disk-size 30
          podman machine start
          configure_podman_socket
          wait_for_podman
        }

        ensure_podman() {
          if [ -z "$(podman machine list -q 2>/dev/null | head -n1)" ]; then
            podman machine init --cpus 2 --memory 4096 --disk-size 30
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
      # A flake input source tree is neither a derivation nor an output, so no
      # keep-* setting roots it. This roots the trees of the current lock.
      rootFlakeSources = pkgs.writeShellApplication {
        name = "root-flake-sources";
        runtimeInputs = with pkgs; [
          nix
          python3
          coreutils
        ];
        text = builtins.readFile ../../scripts/root-flake-sources.sh;
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

      # Same two roots as dendritic/nixos-modules/ca-trust.nix.
      security.pki.installCACerts = true;
      security.pki.caCertificateBlacklist = [
        "Comodo AAA Services root"
        "emSign ECC Root CA - G3"
      ];

      nix = {
        enable = false;
      };

      # Determinate Nix manages daemon itself; nix-darwin's nix.gc options
      # are inert.  Ditch old profile generations daily with nh instead.
      # Two earlier faults: nothing ran at boot, so the job never left
      # "never exited"; and launchd hands out a bare PATH, so nh missed nix.
      # A calendar time survives the daemon re-bootstrap every switch does.
      # /nix is a noauto volume that mounts late at boot, so a raw /nix/store
      # program fails to spawn. Wait for the mount before exec.
      launchd.daemons.nix-gc = {
        serviceConfig = {
          ProgramArguments = [
            "/bin/sh"
            "-c"
            "/bin/wait4path /nix/store && exec ${pkgs.nh}/bin/nh clean all --keep 3 --optimise --no-direnv"
          ];
          StartCalendarInterval = [ { Hour = 4; Minute = 0; } ];
          RunAtLoad = true;
          EnvironmentVariables = caEnv // {
            PATH = "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          };
          StandardOutPath = "/var/log/nix-gc.stdout";
          StandardErrorPath = "/var/log/nix-gc.stderr";
        };
      };

      # The root job above sees system and root profiles only. Home-manager
      # generations sit in the user profile, so a user agent prunes those.
      launchd.user.agents.nix-gc = {
        serviceConfig = {
          ProgramArguments = [
            "${pkgs.nh}/bin/nh"
            "clean"
            "user"
            "--keep"
            "3"
            "--no-direnv"
          ];
          StartCalendarInterval = [ { Hour = 4; Minute = 0; } ];
          RunAtLoad = true;
          EnvironmentVariables.PATH = "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          StandardOutPath = "/Users/${username}/Library/Logs/nix-gc.stdout.log";
          StandardErrorPath = "/Users/${username}/Library/Logs/nix-gc.stderr.log";
        };
      };

      # /etc/ssl/cert.pem is root-owned, so this needs a daemon, not an agent.
      launchd.daemons.fix-ssl-cert-pem = {
        serviceConfig = {
          ProgramArguments = [
            "/bin/sh"
            "-c"
            "/bin/wait4path /nix/store && exec ${fixSslCertPem}"
          ];
          RunAtLoad = true;
          # A macOS update can restore the file between reboots. A clean run exits
          # before any network probe, so the interval costs nothing.
          StartInterval = 86400;
          EnvironmentVariables = caEnv;
          StandardOutPath = "/var/log/fix-ssl-cert-pem.log";
          StandardErrorPath = "/var/log/fix-ssl-cert-pem.log";
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
            "/bin/sh"
            "-c"
            "/bin/wait4path /nix/store && exec ${self.packages.${system}.engram}/bin/engram serve"
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
            PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${pkgs.podman}/bin:${pkgs.coreutils}/bin";
          };
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 30;
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
          ProgramArguments = [
            "/bin/sh"
            "-c"
            "/bin/wait4path /nix/store && exec ${piCrawl4aiServe}/bin/pi-crawl4ai-serve"
          ];
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
          ProgramArguments = [
            "/bin/sh"
            "-c"
            "/bin/wait4path /nix/store && exec ${piSearxngServe}/bin/pi-searxng-serve"
          ];
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
        users.${username} = lib.mkMerge [
          self.homeConfigurations.MacMini
          {
            home.activation.rootFlakeSources = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              log="$HOME/Library/Logs/root-flake-sources.log"
              mkdir -p "$HOME/Library/Logs"
              ${lib.getExe rootFlakeSources} ${lib.escapeShellArg self.outPath} >>"$log" 2>&1 || true
              tail -n 200 "$log" >"$log.trimmed" && mv "$log.trimmed" "$log"
            '';
          }
        ];
      };

      environment.variables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
        DEVELOPER_DIR = "/Applications/Xcode.app/Contents/Developer";
        SHELL = "${pkgs.zsh}/bin/zsh";
      } // caEnv;

      launchd.user.agents.ca-env-setenv = {
        serviceConfig = {
          ProgramArguments = [ "${caEnvSetenv}" ];
          RunAtLoad = true;
          StartInterval = 300;
          StandardOutPath = "/Users/${username}/Library/Logs/ca-env-setenv.stdout.log";
          StandardErrorPath = "/Users/${username}/Library/Logs/ca-env-setenv.stderr.log";
        };
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
          go_1_27
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
          # Argent MCP server: pi's mcp.json spawns bare "argent", so it must be on the
          # global PATH, not just a devshell. Deduplicated from dev-shells/drpom.
          self.packages.${pkgs.stdenv.hostPlatform.system}.argent
          self.packages.${pkgs.stdenv.hostPlatform.system}.launchk
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
          "vorssaint"
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
