{ ... }:
let
in {
  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    # Jetpack preset
    # settings = {
    #   add_newline = true;
    #   continuation_prompt = "[▸▹ ](dimmed white)";

    #   format = ''
    #     ($nix_shell$container$fill$git_metrics
    #     )$cmd_duration$hostname$localip$shlvl$shell$env_var$jobs$sudo$username$character'';

    #   right_format =
    #     "$singularity$kubernetes$directory$vcsh$fossil_branch$git_branch$git_commit$git_state$git_status$hg_branch$pijul_channel$docker_context$package$c$cpp$cmake$cobol$daml$dart$deno$dotnet$elixir$elm$erlang$fennel$golang$guix_shell$haskell$haxe$helm$java$julia$kotlin$gradle$lua$nim$nodejs$ocaml$opa$perl$php$pulumi$purescript$python$raku$rlang$red$ruby$rust$scala$solidity$swift$terraform$vlang$vagrant$zig$buf$conda$pixi$meson$spack$memory_usage$aws$gcloud$openstack$azure$crystal$custom$status$os$battery$time";

    #   fill = { symbol = " "; };

    #   character = {
    #     format = "$symbol ";
    #     success_symbol = "[◎](bold italic bright-yellow)";
    #     error_symbol = "[○](italic purple)";
    #     vimcmd_symbol = "[■](italic dimmed green)";
    #     vimcmd_replace_one_symbol = "◌";
    #     vimcmd_replace_symbol = "□";
    #     vimcmd_visual_symbol = "▼";
    #   };

    #   env_var.VIMSHELL = {
    #     format = "[$env_value]($style)";
    #     style = "green italic";
    #   };

    #   sudo = {
    #     format = "[$symbol]($style)";
    #     style = "bold italic bright-purple";
    #     symbol = "⋈┈";
    #     disabled = false;
    #   };

    #   username = {
    #     style_user = "bright-yellow bold italic";
    #     style_root = "purple bold italic";
    #     format = "[⭘ $user]($style) ";
    #     disabled = false;
    #     show_always = false;
    #   };

    #   directory = {
    #     home_symbol = "⌂";
    #     truncation_length = 2;
    #     truncation_symbol = "□ ";
    #     read_only = " ◈";
    #     use_os_path_sep = true;
    #     style = "italic blue";
    #     format = "[$path]($style)[$read_only]($read_only_style)";
    #     repo_root_style = "bold blue";
    #     repo_root_format =
    #       "[$before_root_path]($before_repo_root_style)[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) [△](bold bright-blue)";
    #   };

    #   cmd_duration = { format = "[◄ $duration ](italic white)"; };

    #   jobs = {
    #     format = "[$symbol$number]($style) ";
    #     style = "white";
    #     symbol = "[▶](blue italic)";
    #   };

    #   localip = {
    #     ssh_only = true;
    #     format = " ◯[$localipv4](bold magenta)";
    #     disabled = false;
    #   };

    #   time = {
    #     disabled = false;
    #     format = "[ $time]($style)";
    #     time_format = "%R";
    #     utc_time_offset = "local";
    #     style = "italic dimmed white";
    #   };

    #   battery = {
    #     format = "[ $percentage $symbol]($style)";
    #     full_symbol = "█";
    #     charging_symbol = "[↑](italic bold green)";
    #     discharging_symbol = "↓";
    #     unknown_symbol = "░";
    #     empty_symbol = "▃";
    #     display = [
    #       {
    #         threshold = 20;
    #         style = "italic bold red";
    #       }
    #       {
    #         threshold = 60;
    #         style = "italic dimmed bright-purple";
    #       }
    #       {
    #         threshold = 70;
    #         style = "italic dimmed yellow";
    #       }
    #     ];
    #   };

    #   git_branch = {
    #     format = " [$branch(:$remote_branch)]($style)";
    #     symbol = "[△](bold italic bright-blue)";
    #     style = "italic bright-blue";
    #     truncation_symbol = "⋯";
    #     truncation_length = 11;
    #     ignore_branches = [ "main" "master" ];
    #     only_attached = true;
    #   };

    #   git_metrics = {
    #     format = "([▴$added]($added_style))([▿$deleted]($deleted_style))";
    #     added_style = "italic dimmed green";
    #     deleted_style = "italic dimmed red";
    #     ignore_submodules = true;
    #     disabled = false;
    #   };

    #   git_status = {
    #     style = "bold italic bright-blue";
    #     format =
    #       "([⎪$ahead_behind$staged$modified$untracked$renamed$deleted$conflicted$stashed⎥]($style))";
    #     conflicted = "[◪◦](italic bright-magenta)";
    #     ahead = "[▴│[\${count}](bold white)│](italic green)";
    #     behind = "[▿│[\${count}](bold white)│](italic red)";
    #     diverged =
    #       "[◇ ▴┤[\${ahead_count}](regular white)│▿┤[\${behind_count}](regular white)│](italic bright-magenta)";
    #     untracked = "[◌◦](italic bright-yellow)";
    #     stashed = "[◃◈](italic white)";
    #     modified = "[●◦](italic yellow)";
    #     staged = "[▪┤[$count](bold white)│](italic bright-cyan)";
    #     renamed = "[◎◦](italic bright-blue)";
    #     deleted = "[✕](italic red)";
    #   };

    #   deno = {
    #     format = " [deno](italic) [∫ $version](green bold)";
    #     version_format = "\${raw}";
    #   };

    #   lua = {
    #     format = " [lua](italic) [\${symbol}\${version}]($style)";
    #     version_format = "\${raw}";
    #     symbol = "⨀ ";
    #     style = "bold bright-yellow";
    #   };

    #   nodejs = {
    #     format = " [node](italic) [◫ ($version)](bold bright-green)";
    #     version_format = "\${raw}";
    #     detect_files = [ "package-lock.json" "yarn.lock" ];
    #     detect_folders = [ "node_modules" ];
    #     detect_extensions = [ ];
    #   };

    #   python = {
    #     format = " [py](italic) [\${symbol}\${version}]($style)";
    #     symbol = "[⌉](bold bright-blue)⌊ ";
    #     version_format = "\${raw}";
    #     style = "bold bright-yellow";
    #   };

    #   ruby = {
    #     format = " [rb](italic) [\${symbol}\${version}]($style)";
    #     symbol = "◆ ";
    #     version_format = "\${raw}";
    #     style = "bold red";
    #   };

    #   rust = {
    #     format = " [rs](italic) [$symbol$version]($style)";
    #     symbol = "⊃ ";
    #     version_format = "\${raw}";
    #     style = "bold red";
    #   };

    #   package = {
    #     format = " [pkg](italic dimmed) [$symbol$version]($style)";
    #     version_format = "\${raw}";
    #     symbol = "◨ ";
    #     style = "dimmed yellow italic bold";
    #   };

    #   swift = {
    #     format = " [sw](italic) [\${symbol}\${version}]($style)";
    #     symbol = "◁ ";
    #     style = "bold bright-red";
    #     version_format = "\${raw}";
    #   };

    #   aws = {
    #     disabled = true;
    #     format = " [aws](italic) [$symbol $profile $region]($style)";
    #     style = "bold blue";
    #     symbol = "▲ ";
    #   };

    #   buf = {
    #     symbol = "■ ";
    #     format = " [buf](italic) [$symbol $version $buf_version]($style)";
    #   };

    #   c = {
    #     symbol = "ℂ ";
    #     format = " [$symbol($version(-$name))]($style)";
    #   };

    #   cpp = {
    #     symbol = "ℂ ";
    #     format = " [$symbol($version(-$name))]($style)";
    #   };

    #   conda = {
    #     symbol = "◯ ";
    #     format = " conda [$symbol$environment]($style)";
    #   };

    #   pixi = {
    #     symbol = "■ ";
    #     format = " pixi [$symbol$version ($environment )]($style)";
    #   };

    #   dart = {
    #     symbol = "◁◅ ";
    #     format = " dart [$symbol($version )]($style)";
    #   };

    #   docker_context = {
    #     symbol = "◧ ";
    #     format = " docker [$symbol$context]($style)";
    #   };

    #   elixir = {
    #     symbol = "△ ";
    #     format = " exs [$symbol $version OTP $otp_version ]($style)";
    #   };

    #   elm = {
    #     symbol = "◩ ";
    #     format = " elm [$symbol($version )]($style)";
    #   };

    #   golang = {
    #     symbol = "∩ ";
    #     format = " go [$symbol($version )]($style)";
    #   };

    #   haskell = {
    #     symbol = "❯λ ";
    #     format = " hs [$symbol($version )]($style)";
    #   };

    #   java = {
    #     symbol = "∪ ";
    #     format = " java [\${symbol}(\${version} )]($style)";
    #   };

    #   julia = {
    #     symbol = "◎ ";
    #     format = " jl [$symbol($version )]($style)";
    #   };

    #   memory_usage = {
    #     symbol = "▪▫▪ ";
    #     format = " mem [\${ram}( \${swap})]($style)";
    #   };

    #   nim = {
    #     symbol = "▴▲▴ ";
    #     format = " nim [$symbol($version )]($style)";
    #   };

    #   nix_shell = {
    #     style = "bold italic dimmed blue";
    #     symbol = "✶";
    #     format = "[$symbol nix⎪$state⎪]($style) [$name](italic dimmed white)";
    #     impure_msg = "[⌽](bold dimmed red)";
    #     pure_msg = "[⌾](bold dimmed green)";
    #     unknown_msg = "[◌](bold dimmed yellow)";
    #   };

    #   spack = {
    #     symbol = "◇ ";
    #     format = " spack [$symbol$environment]($style)";
    #   };
    # };

    # Nerd Font symbols preset
    settings = {
      format = ''
        $username$hostname$localip$shlvl$singularity$kubernetes$directory$vcsh$fossil_branch$fossil_metrics$git_branch$git_commit$git_state$git_metrics$git_status$hg_branch$pijul_channel$docker_context$package$c$cmake$cobol$daml$dart$deno$dotnet$elixir$elm$erlang$fennel$gleam$golang$guix_shell$haskell$haxe$helm$java$julia$kotlin$gradle$lua$nim$nodejs$ocaml$opa$perl$php$pulumi$purescript$python$quarto$raku$rlang$red$ruby$rust$scala$solidity$swift$terraform$typst$vlang$vagrant$zig$buf$nix_shell$conda$meson$spack$memory_usage$aws$gcloud$openstack$azure$nats$direnv$env_var$mise$crystal$custom$sudo$cmd_duration$character$jobs$battery$time$status$os$container$netns$shell$line_break
      '';
      character = {
        success_symbol = "[](bold green) $line_break";
        error_symbol = "[](bold red) $line_break";
      };

      aws = { symbol = "  "; };

      buf = { symbol = " "; };

      bun = { symbol = " "; };

      c = { symbol = " "; };

      cpp = { symbol = " "; };

      cmake = { symbol = " "; };

      conda = { symbol = " "; };

      crystal = { symbol = " "; };

      dart = { symbol = " "; };

      deno = { symbol = " "; };

      directory = { read_only = " 󰌾"; };

      docker_context = { symbol = " "; };

      elixir = { symbol = " "; };

      elm = { symbol = " "; };

      fennel = { symbol = " "; };

      fossil_branch = { symbol = " "; };

      gcloud = { symbol = "  "; };

      git_branch = { symbol = " "; };

      git_commit = { tag_symbol = "  "; };

      golang = { symbol = " "; };

      guix_shell = { symbol = " "; };

      haskell = { symbol = " "; };

      haxe = { symbol = " "; };

      hg_branch = { symbol = " "; };

      hostname = { ssh_symbol = " "; };

      java = { symbol = " "; };

      julia = { symbol = " "; };

      kotlin = { symbol = " "; };

      lua = { symbol = " "; };

      memory_usage = { symbol = "󰍛 "; };

      meson = { symbol = "󰔷 "; };

      nim = { symbol = "󰆥 "; };

      nix_shell = { symbol = " "; };

      nodejs = { symbol = " "; };

      ocaml = { symbol = " "; };

      os.symbols = {
        Alpaquita = " ";
        Alpine = " ";
        AlmaLinux = " ";
        Amazon = " ";
        Android = " ";
        Arch = " ";
        Artix = " ";
        CachyOS = " ";
        CentOS = " ";
        Debian = " ";
        DragonFly = " ";
        Emscripten = " ";
        EndeavourOS = " ";
        Fedora = " ";
        FreeBSD = " ";
        Garuda = "󰛓 ";
        Gentoo = " ";
        HardenedBSD = "󰞌 ";
        Illumos = "󰈸 ";
        Kali = " ";
        Linux = " ";
        Mabox = " ";
        Macos = " ";
        Manjaro = " ";
        Mariner = " ";
        MidnightBSD = " ";
        Mint = " ";
        NetBSD = " ";
        NixOS = " ";
        Nobara = " ";
        OpenBSD = "󰈺 ";
        openSUSE = " ";
        OracleLinux = "󰌷 ";
        Pop = " ";
        Raspbian = " ";
        Redhat = " ";
        RedHatEnterprise = " ";
        RockyLinux = " ";
        Redox = "󰀘 ";
        Solus = "󰠳 ";
        SUSE = " ";
        Ubuntu = " ";
        Unknown = " ";
        Void = " ";
        Windows = "󰍲 ";
      };

      package = { symbol = "󰏗 "; };

      perl = { symbol = " "; };

      php = { symbol = " "; };

      pijul_channel = { symbol = " "; };

      pixi = { symbol = "󰏗 "; };

      python = { symbol = " "; };

      rlang = { symbol = "󰟔 "; };

      ruby = { symbol = " "; };

      rust = { symbol = "󱘗 "; };

      scala = { symbol = " "; };

      swift = { symbol = " "; };

      zig = { symbol = " "; };

      gradle = { symbol = " "; };

    };
  };
  # home.file = { ".config/starship.toml".source = ./starship.toml; };
}
