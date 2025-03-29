{ pkgs, config, ... }: {
  home.packages = with pkgs; [ wlogout ];
  home.file = let
    imageDir =
      "/etc/profiles/per-user/${config.home.username}/share/wlogout/icons";
  in {
    ".config/wlogout/style.css".text = ''
      * {
        background-image: none;
        box-shadow: none;
      }

      window {
        background-color: rgba(12, 12, 12, 0.9);
      }

      button {
        border-radius: 10px;
        border-color: black;
        text-decoration-color: #FFFFFF;
        margin: 10px;
        font-size: 24px;
        color: #FFFFFF;
        background-color: #${config.lib.stylix.colors.base01};
        border-style: solid;
        border-width: 5px;
        border-color: #${config.lib.stylix.colors.base0A};
        background-repeat: no-repeat;
        background-position: center;
        background-size: 25%;
      }

      button:focus,
      button:active,
      button:hover {
        border-color: #${config.lib.stylix.colors.base0C};
        outline-style: none;
      }

      #lock {
        margin: 10px;
        background-image: image(url("${imageDir}/lock.png"), url("${imageDir}/lock.png"));
      }

      #logout {
        margin: 10px;
        background-image: image(url("${imageDir}/logout.png"), url("${imageDir}/logout.png"));
      }

      #suspend {
        margin: 10px;
        background-image: image(url("${imageDir}/suspend.png"), url("${imageDir}/suspend.png"));
      }

      #hibernate {
        margin: 10px;
        background-image: image(url("${imageDir}/hibernate.png"), url("${imageDir}/hibernate.png"));
      }

      #shutdown {
        margin: 10px;
        background-image: image(url("${imageDir}/shutdown.png"), url("${imageDir}/shutdown.png"));
      }

      #reboot {
        margin: 10px;
        background-image: image(url("${imageDir}/reboot.png"), url("${imageDir}/reboot.png"));
      }
    '';
    ".config/wlogout/layout".text = ''
      {
          "label" : "lock",
          "action" : "loginctl lock-session",
          "text" : "[L] Lock",
          "keybind" : "l"
      }
      {
          "label" : "hibernate",
          "action" : "systemctl hibernate",
          "text" : "[H] Hibernate",
          "keybind" : "h"
      }
      {
          "label" : "logout",
          "action" : "loginctl terminate-user $USER",
          "text" : "[E] Logout",
          "keybind" : "e"
      }
      {
          "label" : "shutdown",
          "action" : "systemctl poweroff",
          "text" : "[S] Shutdown",
          "keybind" : "s"
      }
      {
          "label" : "suspend",
          "action" : "systemctl suspend",
          "text" : "[U] Suspend",
          "keybind" : "u"
      }
      {
          "label" : "reboot",
          "action" : "systemctl reboot",
          "text" : "[R] Reboot",
          "keybind" : "r"
      }

    '';
  };
}
