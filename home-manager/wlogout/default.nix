{ pkgs, config, ... }: {
  home.packages = with pkgs; [ wlogout ];
  home.file = {
    ".config/wlogout/style.css".text = ''
      * {
        background-image: none;
        box-shadow: none;
      }

      window {
        background-color: rgba(12, 12, 12, 0.9);
      }

      button {
        border-radius: 16;
        border-color: black;
        text-decoration-color: #FFFFFF;
        color: #FFFFFF;
        background-color: ${config.lib.stylix.colors.base01};
        margin: 5px;
        background-repeat: no-repeat;
        background-position: center;
        background-size: 25%;
      }

      button:focus,
      button:active,
      button:hover {
        background-color: ${config.lib.stylix.colors.base0A};
        outline-style: none;
      }

      #lock {
        background-image: image(url("/usr/share/wlogout/icons/lock.png"), url("/usr/local/share/wlogout/icons/lock.png"));
      }

      #logout {
        background-image: image(url("/usr/share/wlogout/icons/logout.png"), url("/usr/local/share/wlogout/icons/logout.png"));
      }

      #suspend {
        background-image: image(url("/usr/share/wlogout/icons/suspend.png"), url("/usr/local/share/wlogout/icons/suspend.png"));
      }

      #hibernate {
        background-image: image(url("/usr/share/wlogout/icons/hibernate.png"), url("/usr/local/share/wlogout/icons/hibernate.png"));
      }

      #shutdown {
        background-image: image(url("/usr/share/wlogout/icons/shutdown.png"), url("/usr/local/share/wlogout/icons/shutdown.png"));
      }

      #reboot {
        background-image: image(url("/usr/share/wlogout/icons/reboot.png"), url("/usr/local/share/wlogout/icons/reboot.png"));
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
