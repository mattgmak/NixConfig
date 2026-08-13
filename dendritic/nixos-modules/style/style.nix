{
  flake.fonts =
    {
      pkgs,
      ...
    }:
    {
      fonts.packages = with pkgs; [
        nerd-fonts.iosevka-term
        inter
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
      ];
    };

  flake.stylixCommon =
    {
      lib,
      pkgs,
      ...
    }:
    {
      stylix = {
        enable = true;
        polarity = "dark";
        # base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyodark-terminal.yaml";
        base16Scheme = "${pkgs.base16-schemes}/share/themes/da-one-ocean.yaml";
        # base16Scheme = "${pkgs.base16-schemes}/share/themes/eldritch.yaml";
        # base16Scheme = "${pkgs.base16-schemes}/share/themes/gigavolt.yaml";
        # base16Scheme = "${pkgs.base16-schemes}/share/themes/moonlight.yaml";
        image = ./beautiful-mountains-landscape.jpg;

        fonts = {
          monospace = {
            package = pkgs.nerd-fonts.iosevka-term;
            name = "IosevkaTerm Nerd Font Propo";
          };
          sansSerif = {
            package = pkgs.inter;
            name = "Inter";
          };
          serif = {
            package = pkgs.noto-fonts-cjk-sans;
            name = "Noto Sans CJK HK";
          };
          emoji = {
            package = pkgs.noto-fonts-color-emoji;
            name = "Noto Color Emoji";
          };
        };
      };
    };

  flake.stylixLinux =
    {
      pkgs,
      lib,
      ...
    }:
    {
      # Stylix auto-detects the DE: with GNOME enabled (GDM/keyring) it picks
      # `qt.platform = "gnome"`, which is deprecated in HM (→ adwaita) and
      # unsupported in stylix (→ qtct), and drags in the unmaintained
      # qgnomeplatform packages. We use Hyprland, so force the supported qtct
      # path (qt5ct/qt6ct + Base16Kvantum theming). mkForce is required: the
      # stylix module assigns the auto-detected value at default priority.
      targets.qt.platform = lib.mkForce "qtct";

      # Icon theme shared by GTK + Qt (via qt5ct/qt6ct icon_theme). Without
      # this, the qtct platform leaves Qt tray icons (kdeconnect, caelestia
      # SNI tray) on Qt's minimal built-in theme.
      # stylix.icons is a NixOS-only option — skip on darwin.
      stylix.icons = {
        enable = true;
        package = pkgs.papirus-icon-theme;
        dark = "Papirus-Dark";
        light = "Papirus";
      };
    };

  flake.stylixCursor =
    { pkgs, ... }:
    {
      stylix = {
        cursor = {
          package = pkgs.bibata-cursors;
          name = "Bibata-Modern-Ice";
          size = 24;
        };
        targets.gnome-text-editor.enable = false;
      };
    };
}
