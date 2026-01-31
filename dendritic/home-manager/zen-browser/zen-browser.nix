{ inputs, ... }: {
  flake = {
    homeModules.zen-browser-legacy = { pkgs, ... }: {
      imports = [ inputs.zen-browser.homeModules.beta ];
      programs.zen-browser = {
        enable = true;
        nativeMessagingHosts = [ pkgs.firefoxpwa ];
        policies = {
          Preferences = let
            locked = value: {
              "Value" = value;
              "Status" = "locked";
            };
          in { "nebula-tab-switch-animation" = locked 4; };
          AutofillAddressEnabled = true;
          AutofillCreditCardEnabled = false;
          DisableAppUpdate = true;
          DisableFeedbackCommands = true;
          DisableFirefoxStudies = true;
          DisablePocket = true;
          DisableTelemetry = true;
          DontCheckDefaultBrowser = true;
          NoDefaultBookmarks = true;
          OfferToSaveLogins = false;
          EnableTrackingProtection = {
            Value = true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
          };
        };
      };

      home.file.".zen/GoofyZen/chrome" = {
        source = ./chrome;
        recursive = true;
      };
    };

    homeModules.zen-browser = { pkgs, ... }: {
      imports = [ inputs.zen-browser.homeModules.beta ];
      programs.zen-browser = {
        enable = true;
        nativeMessagingHosts = [ pkgs.firefoxpwa ];
        policies = let
          mkExtensionSettings = builtins.mapAttrs (_: pluginId: {
            install_url =
              "https://addons.mozilla.org/firefox/downloads/latest/${pluginId}/latest.xpi";
            installation_mode = "force_installed";
          });
        in {
          Preferences = let
            locked = value: {
              "Value" = value;
              "Status" = "locked";
            };
          in { "nebula-tab-switch-animation" = locked 4; };
          AutofillAddressEnabled = true;
          AutofillCreditCardEnabled = false;
          DisableAppUpdate = true;
          DisableFeedbackCommands = true;
          DisableFirefoxStudies = true;
          DisablePocket = true;
          DisableTelemetry = true;
          DontCheckDefaultBrowser = true;
          NoDefaultBookmarks = true;
          OfferToSaveLogins = false;
          EnableTrackingProtection = {
            Value = true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
          };
          ExtensionSettings = mkExtensionSettings {
            "{c4b582ec-4343-438c-bda2-2f691c16c262}" = "600-sound-volume";
            "maksimovic@outlook.com" = "github-whitespace-disabler";
            "youtube-timestamps@ris58h" = "youtube-timestamps";
            "{b9db16a4-6edc-47ec-a1f4-b86292ed211d}" = "video-downloadhelper";
            "duplicate-tab@firefox.stefansundin.com" = "duplicate-tab-shortcut";
            "adnauseam@rednoise.org" = "adnauseam";
            "firefox@betterttv.net" = "betterttv";
            "{446900e4-71c2-419f-a6a7-df9c091e268b}" =
              "bitwarden-password-manager";
            "addon@darkreader.org" = "darkreader";
            "enhancerforyoutube@maximerf.addons.mozilla.org" =
              "enhancer-for-youtube";
            "{85860b32-02a8-431a-b2b1-40fbd64c9c69}" = "github-file-icons";
            "{a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad}" = "refined-github-";
            "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" =
              "return-youtube-dislikes";
            "sponsorBlocker@ajay.app" = "sponsorblock";
            "uBlock0@raymondhill.net" = "ublock-origin";
            "vimium-c@gdh1995.cn" = "vimium-c";
          };
        };
        profiles.default = {
          mods = [
            "fd24f832-a2e6-4ce9-8b19-7aa888eb7f8e" # Quietify
          ];
        };
      };

      home.file.".zen/default/chrome" = {
        source = ./wireframe;
        recursive = true;
      };

    };
  };
}
