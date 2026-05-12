{ self, ... }:
{
  flake.nixosModules.syncthing =
    {
      username,
      hostname,
      lib,
      ...
    }:
    {
      services.syncthing = {
        enable = true;
        openDefaultPorts = true;
        user = username;
        group = "users";
        configDir = "/home/${username}/.config/syncthing";
        overrideDevices = true;
        settings =
          let
            phoneName = "phone";
          in
          {
            devices = {
              "${phoneName}" = {
                id = "LRGIDSH-W6NIW7U-SV62HMC-EMHYALK-RSK7Y5K-OOZK7WI-IEQR6ZU-CGWRWQT";
                addresses = [ "tcp://goofypixiepro:22000" ];
                autoAcceptFolders = true;
              };
            }
            // (
              with self.constants;
              removeAttrs {
                "${laptopName}" = {
                  id = "DD7OGGM-7JBLUOS-IKEJPZC-FU53EP7-SYGKUOC-5MFNMTI-MESKECM-N4HSVQB";
                  addresses = [ "tcp://goofyenvy:22000" ];
                  autoAcceptFolders = true;
                };
                "${desktopName}" = {
                  id = "WV4SN2U-47SFFUI-SCDA7UK-MKYM6LO-63S5Y6B-SSXQNXB-PCM427Z-ICFFHAH";
                  addresses = [ "tcp://goofydesky:22000" ];
                  autoAcceptFolders = true;
                };
                "${serverName}" = {
                  id = "KRZBZS4-FQ3LM4O-JCVDEE7-E7S2QM2-3HWIQYM-NXEH2FK-V5YGJ3H-FOSHOQV";
                  addresses = [ "tcp://goofeus:22000" ];
                  autoAcceptFolders = true;
                };
              } [ hostname ]
            );
            folders =
              let
                basePath =
                  if hostname != self.constants.serverName then
                    "/home/${username}"
                  else
                    "/mnt/2TBSeagateHDD/syncthing";
                devices =
                  with self.constants;
                  builtins.filter (d: d != hostname) [
                    phoneName
                    laptopName
                    desktopName
                    serverName
                  ];
                versioning = {
                  type = "trashcan";
                  params.cleanoutDays = "30";
                };
              in
              {
                Music = {
                  path = "${basePath}/Music";
                  inherit devices versioning;
                };
                Obsidian = {
                  path = "${basePath}/GoofyObsidian";
                  inherit devices versioning;
                };
                OfflineMedia = {
                  path = "${basePath}/OfflineMedia";
                  inherit devices versioning;
                };
              };
          };
      }
      // lib.optionalAttrs (hostname == self.constants.serverName) {
        dataDir = "/mnt/2TBSeagateHDD/syncthing/default";
        configDir = "/root/.config/syncthing";
      };

    };
}
