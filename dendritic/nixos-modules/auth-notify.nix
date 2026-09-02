{
  flake.nixosModules.authNotify =
    {
      lib,
      pkgs,
      ...
    }:
    let
      authNotifyDismiss = pkgs.writeShellScriptBin "auth-notify-dismiss" ''
        stateFile="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sudo-auth-notif"
        export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

        [ -f "$stateFile" ] || exit 0

        notifId=$(cat "$stateFile")
        rm -f "$stateFile"

        ${pkgs.dbus}/bin/dbus-send --session --print-reply --dest=org.freedesktop.Notifications \
          /org/freedesktop/Notifications \
          org.freedesktop.Notifications.CloseNotification \
          uint32:"$notifId" >/dev/null 2>&1 || true
      '';

      authNotify = pkgs.writeShellScriptBin "auth-notify" ''
        stateFile="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sudo-auth-notif"
        export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

        findSudoPid() {
          pid=$PPID
          while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
            comm=$(${pkgs.procps}/bin/ps -o comm= -p "$pid" 2>/dev/null || true)
            case "$comm" in
              sudo) echo "$pid"; return 0 ;;
            esac
            pid=$(${pkgs.procps}/bin/ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
          done
          return 1
        }

        replaceArgs=()
        if [ -f "$stateFile" ]; then
          replaceArgs=(-r "$(cat "$stateFile")")
        fi

        notifId=$(${pkgs.libnotify}/bin/notify-send -p -u critical -a "Auth" -e \
          "Authentication required" \
          "sudo waiting — finger or password in terminal" \
          "''${replaceArgs[@]}")

        echo "$notifId" > "$stateFile"

        sudoPid=$(findSudoPid) || exit 0

        (
          while ${pkgs.coreutils}/bin/kill -0 "$sudoPid" 2>/dev/null; do
            [ -f "$stateFile" ] || exit 0
            sleep 0.2
          done
          ${authNotifyDismiss}/bin/auth-notify-dismiss
        ) &
      '';
    in
    {
      security.pam.services.sudo.text = lib.mkBefore ''
        auth     optional       pam_exec.so quiet ${authNotify}/bin/auth-notify
        account  optional       pam_exec.so quiet ${authNotifyDismiss}/bin/auth-notify-dismiss
      '';

      environment.systemPackages = [
        authNotify
        authNotifyDismiss
      ];
    };
}
