{
  flake.nixosModules.syncthing =
    {
      username,
      ...
    }:
    {
      services.syncthing = {
        enable = true;
        openDefaultPorts = true;
        user = username;
        group = "users";
        configDir = "/home/${username}/.config/syncthing";
        settings = {
          devices = {
            phone.id = "LRGIDSH-W6NIW7U-SV62HMC-EMHYALK-RSK7Y5K-OOZK7WI-IEQR6ZU-CGWRWQT";
          };
          folders = {
            Music = {
              path = "/home/${username}/Music";
              devices = [ "phone" ];
            };
            Obsidian = {
              path = "/home/${username}/GoofyObsidian";
              devices = [ "phone" ];
            };
            OfflineMedia = {
              path = "/home/${username}/OfflineMedia";
              devices = [ "phone" ];
            };
          };
        };
      };
    };
}
