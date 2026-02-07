{ inputs, self, ... }:
{
  flake = {
    homeModules.zen-browser-legacy =
      { pkgs, ... }:
      {
        imports = [ inputs.zen-browser.homeModules.beta ];
        programs.zen-browser = {
          enable = true;
          nativeMessagingHosts = [ pkgs.firefoxpwa ];
          policies = {
            Preferences =
              let
                locked = value: {
                  "Value" = value;
                  "Status" = "locked";
                };
              in
              {
                "nebula-tab-switch-animation" = locked 4;
              };
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

    homeModules.zen-browser =
      { pkgs, ... }:
      {
        imports = [ inputs.zen-browser.homeModules.beta ];
        programs.zen-browser = {
          enable = true;
          nativeMessagingHosts = [ pkgs.firefoxpwa ];
          policies =
            let
              mkExtensionSettings = builtins.mapAttrs (
                _: pluginId: {
                  install_url = "https://addons.mozilla.org/firefox/downloads/latest/${pluginId}/latest.xpi";
                  installation_mode = "force_installed";
                }
              );
            in
            {
              Preferences =
                let
                  locked = value: {
                    "Value" = value;
                    "Status" = "locked";
                  };
                in
                {
                  "nebula-tab-switch-animation" = locked 4;
                };
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
                "{446900e4-71c2-419f-a6a7-df9c091e268b}" = "bitwarden-password-manager";
                "addon@darkreader.org" = "darkreader";
                "enhancerforyoutube@maximerf.addons.mozilla.org" = "enhancer-for-youtube";
                "{85860b32-02a8-431a-b2b1-40fbd64c9c69}" = "github-file-icons";
                "{a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad}" = "refined-github-";
                "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" = "return-youtube-dislikes";
                "sponsorBlocker@ajay.app" = "sponsorblock";
                # "uBlock0@raymondhill.net" = "ublock-origin";
                "vimium-c@gdh1995.cn" = "vimium-c";
              };
            };
          profiles.default = rec {
            mods = [
              "fd24f832-a2e6-4ce9-8b19-7aa888eb7f8e" # Quietify
            ];

            settings = {
              "accessibility.blockautorefresh" = true;
              "accessibility.typeaheadfind.flashBar" = 0;
              "browser.aboutConfig.showWarning" = false;
              "browser.bookmarks.editDialog.confirmationHintShowCount" = 3;
              "browser.bookmarks.restore_default_bookmarks" = false;
              "browser.bookmarks.showMobileBookmarks" = true;
              "browser.contentblocking.category" = "custom";
              "browser.ctrlTab.sortByRecentlyUsed" = true;
              "browser.discovery.enabled" = true;
              "browser.download.lastDir" = "/home/goofy/Downloads";
              "browser.download.panel.shown" = true;
              "browser.eme.ui.firstContentShown" = true;
              "browser.engagement.ctrlTab.has-used" = true;
              "browser.engagement.downloads-button.has-used" = true;
              "browser.firefox-view.feature-tour" = "{\"screen\":\"\",\"complete\":true}";
              "browser.launcherProcess.enabled" = true;
              "browser.ml.enable" = true;
              "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.havePinned" = "google";
              "browser.newtabpage.enabled" = false;
              "browser.urlbar.maxRichResults" = 12;
              "browser.urlbar.placeholderName" = "Google";
              # browser.urlbar.placeholderName.private = "Google";
              "browser.urlbar.quicksuggest.scenario" = "history";
              "browser.urlbar.showSearchSuggestionsFirst" = false;
              "browser.urlbar.tabToSearch.onboard.interactionsLeft" = 1;
              # devtools.aboutdebugging.collapsibilities.processes = false;
              # devtools.chrome.enabled = true;
              # devtools.debugger.remote-enabled = true;
              # devtools.everOpened = true;
              # devtools.inspector.activeSidebar = "computedview";
              # devtools.inspector.selectedSidebar = "computedview";
              # devtools.netmonitor.filters = "[\"html\",\"xhr\"]";
              # devtools.netmonitor.msg.visibleColumns = "[\"data\",\"time\"]";
              # devtools.responsive.reloadNotification.enabled = false;
              # devtools.responsive.viewport.angle = 90;
              # devtools.responsive.viewport.height = 900;
              # devtools.responsive.viewport.width = 1600;
              # devtools.toolbox.footer.height = 526;
              # devtools.toolbox.host = "right";
              # devtools.toolbox.previousHost = "window";
              # devtools.toolbox.sidebar.width = 724;
              # devtools.toolbox.zoomValue = "1.6";
              # devtools.toolsidebar-height.inspector = 350;
              # devtools.toolsidebar-width.inspector = 536;
              # devtools.toolsidebar-width.inspector.splitsidebar = 229;
              "findbar.highlightAll" = true;
              "font.name.monospace.x-western" = "IosevkaTerm Nerd Font";
              "font.name.sans-serif.x-western" = "Inter";
              "font.name.serif.x-western" = "Inter";
              "font.size.monospace.x-western" = 14;
              "intl.accept_languages" = "en";
              "tab.groups.add-arrow" = true;
              "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
              "uc.erics-zen-ui-tweak-box.exit-button-padding-right.enabled" = false;
              "uc.erics-zen-ui-tweak-box.floating-url-bar-tweaks.enabled" = false;
              "uc.erics-zen-ui-tweak-box.fun-colors.enabled" = false;
              "uc.erics-zen-ui-tweak-box.new-tab-button-text.enabled" = false;
              "uc.erics-zen-ui-tweak-box.new-tab-separator-when-no-unpinned-tabs.enabled" = false;
              "uc.erics-zen-ui-tweak-box.page-canvas-shadows.enabled" = false;
              "uc.erics-zen-ui-tweak-box.pinned-tabs-layout.enabled" = false;
              "uc.erics-zen-ui-tweak-box.remove-url-bar-border.enabled" = false;
              "uc.erics-zen-ui-tweak-box.tab-bar-top-padding.enabled" = false;
              "uc.erics-zen-ui-tweak-box.tab-button-tweaks.enabled" = false;
              "uc.erics-zen-ui-tweak-box.toolbar-button-tweaks.enabled" = true;
              "uc.erics-zen-ui-tweak-box.url-bar-tweaks.enabled" = false;
              "uc.erics-zen-ui-tweak-box.workspace-button-tweaks.enabled" = true;
              "uc.essentials.color-scheme" = "transparent";
              "uc.essentials.gap" = "Normal";
              "uc.essentials.position" = "bottom";
              "uc.essentials.width" = "Normal";
              "uc.favicon.size" = "small";
              "uc.fixcontext.ergonomicsfortabs" = true;
              "uc.fixcontext.extensionmargins" = false;
              "uc.floatingfindbar.compact.enabled" = true;
              "uc.floatingfindbar.increase.spacing" = false;
              "uc.floatingtoolbar.compact.enabled" = false;
              "uc.floatingtoolbar.increase.spacing" = true;
              "uc.floatingtoolbar.merge.bookmarks" = true;
              "uc.hidecontext.bookmark" = true;
              "uc.hidecontext.closemultiple" = true;
              "uc.hidecontext.copylink" = true;
              "uc.hidecontext.movetaboptions" = true;
              "uc.hidecontext.newtab" = true;
              "uc.hidecontext.printselection" = true;
              "uc.hidecontext.reloadtab" = true;
              "uc.hidecontext.screenshot" = true;
              "uc.hidecontext.searchinpriv" = true;
              "uc.hidecontext.selectalltabs" = true;
              "uc.hidecontext.selectalltext" = true;
              "uc.hidecontext.separators" = false;
              "uc.minimal-sidebar.compact-spacing.enabled" = false;
              "uc.minimal-sidebar.fix-sidebar-width.enabled" = false;
              "uc.minimal-sidebar.hide-alltabs-button.enabled" = true;
              "uc.minimal-sidebar.hide-bookmark-button.enabled" = true;
              "uc.minimal-sidebar.hide-expand-sidebar-button.enabled" = false;
              "uc.minimal-sidebar.hide-history-button.enabled" = true;
              "uc.minimal-sidebar.hide-newtab-button.enabled" = false;
              "uc.minimal-sidebar.hide-preferences-button.enabled" = true;
              "uc.minimal-sidebar.hide-profile-button.enabled" = true;
              "uc.minimal-sidebar.hide-sidebar.enabled" = false;
              "uc.minimal-sidebar.hide-sidepanel-button.enabled" = true;
              "uc.pinned.height" = "small";
              "uc.pins.bg-color.pop" = false;
              "uc.pins.border" = false;
              "uc.pins.box-like-corners" = false;
              "uc.pins.disable-bg-color" = false;
              "uc.pins.gap" = "Normal";
              "uc.pins.margins.compact" = false;
              "uc.pins.tall" = false;
              "uc.pins.width" = "Normal";
              "uc.right_on_hover_sidebar.hover_width" = "2px";
              "uc.right_on_hover_sidebar.stay_on_focus" = false;
              "uc.right_on_hover_sidebar.width" = "300px";
              "uc.superpins.border" = "pins";
              "uc.tabs.dim-type" = "both";
              "uc.tabs.show-separator" = "pinned-shown";
              "uc.urlbar.blur-intensity" = "Normal";
              "uc.urlbar.border" = false;
              "uc.urlbar.border-radius" = false;
              "uc.urlbar.custom-bg-color.mode" = "";
              "uc.urlbar.hide.container-info" = "hideIconLabel";
              "uc.urlbar.icon.bookmark.removed" = false;
              "uc.urlbar.icon.pip.removed" = true;
              "uc.urlbar.icon.reader-mode.removed" = true;
              "uc.urlbar.icon.shield.removed" = true;
              "uc.urlbar.icon.show-on-hover" = false;
              "uc.urlbar.icon.split-view.removed" = true;
              "uc.urlbar.icon.zoom.removed" = true;
              "uc.urltext.center" = "normal";
              "uc.workspace.current.icon.size" = "small";
              "uc.workspace.icon.size" = "x-small";
              "uc.zen-sidebar.float-at-right-side" = false;
              "uc.zen-sidebar.pin-at-right-side" = false;
              "ui.osk.debug.keyboardDisplayReason" = "IKPOS: Keyboard presence confirmed.";
              "userChromeJS.allowUnsafeWrites" = true;
              "userChromeJS.enabled" = true;
              "userChromeJS.firstRunShown" = true;
              "userChromeJS.persistent_domcontent_callback" = true;
              "userChromeJS.scriptsDisabled" = "";
              "widget.use-xdg-desktop-portal.file-picker" = 1;
              "zen.glance.activation-method" = "shift";
              "zen.mods.AudioIndicatorEnhanced.audioWave.colorMuted" =
                "color-mix(in srgb, -moz-dialogtext 50%, rgb(129, 0, 0) 50%)";
              "zen.mods.AudioIndicatorEnhanced.audioWave.colorPlaying" = "-moz-dialogtext";
              "zen.mods.AudioIndicatorEnhanced.audioWave.enabled" = true;
              "zen.mods.AudioIndicatorEnhanced.audioWave.opacity" = "0.2";
              "zen.mods.AudioIndicatorEnhanced.hoverScaleAnimationEnabled" = true;
              "zen.mods.AudioIndicatorEnhanced.returnOldIcons" = true;
              "zen.mods.auto-update" = false;
              "zen.pinned-tab-manager.close-shortcut-behavior" = "reset";
              "zen.sidebar.enabled" = false;
              "zen.site-data-panel.show-callout" = false;
              "zen.tab-unloader.timeout-minutes" = 90;
              "zen.tabs.vertical.right-side" = true;
              "zen.theme.accent-color" = "#f6b0ea";
              "zen.theme.color-prefs.colorful" = true;
              "zen.theme.pill-button" = true;
              "zen.themes.disable-all" = false;
              "zen.themes.updated-value-observer" = true;
              "zen.urlbar.behavior" = "float";
              "zen.view.compact.enable-at-startup" = false;
              "zen.view.compact.hide-toolbar" = true;
              "zen.view.compact.should-enable-at-startup" = false;
              "zen.view.show-newtab-button-top" = false;
              "zen.view.sidebar-expanded.on-hover" = false;
              "zen.view.split-view.change-on-hover" = true;
              "zen.view.window.scheme" = 0;
              "zen.welcome-screen.seen" = true;
              "zen.welcomeScreen.seen" = true;
              "zen.workspaces.container-specific-essentials-enabled" = true;
              "zen.workspaces.indicator-position" = "top";
              "zen.workspaces.show-workspace-indicator" = false;

              "wireframe.urlbar.position.top" = true;
              "wireframe.webview.border_radius" = 16;
              "wireframe.window.border_radius" = 16;
              "wireframe.tab.border_radius" = 16;
              "wireframe.essentials.border_radius" = 16;
            };

            search = {
              force = true;
              default = "google";
              engines = {
                # My NixOS Option and package search shortcut
                mynixos = {
                  name = "My NixOS";
                  urls = [
                    {
                      template = "https://mynixos.com/search?q={searchTerms}";
                      params = [
                        {
                          name = "query";
                          value = "searchTerms";
                        }
                      ];
                    }
                  ];

                  icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                  definedAliases = [ "@nx" ]; # Keep in mind that aliases defined here only work if they start with "@"
                };
              };
            };

            keyboardShortcuts = self.zenBrowserShortcuts;
            # Fails activation on schema changes to detect potential regressions
            # Find this in about:config or prefs.js of your profile
            keyboardShortcutsVersion = 13;

            userChrome = ./wireframe/userChrome.css;
            userContent = ./wireframe/userContent.css;

            containersForce = true;
            pinsForce = true;
            containers = {
              Personal = {
                color = "pink";
                icon = "fingerprint";
                id = 1;
              };
              Work = {
                color = "blue";
                icon = "briefcase";
                id = 2;
              };
            };

            pins = {
              "Whatsapp" = {
                id = "8af62707-0722-4049-9801-bedced343333";
                container = containers.Personal.id;
                url = "https://web.whatsapp.com";
                isEssential = true;
                position = 101;
              };
            };

          };
        };

        home.file.".zen/default/chrome/modules" = {
          source = ./wireframe/modules;
          recursive = true;
        };
        home.file.".zen/default/chrome/preferences.json" = {
          source = ./wireframe/preferences.json;
        };

      };
  };
}
