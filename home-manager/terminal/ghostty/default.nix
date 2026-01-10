{ pkgs, lib, inputs, ... }: {
  home.file.".config/ghostty/shaders" = {
    source = ./shaders;
    recursive = true;
  };
  programs.ghostty = {
    enable = true;
    package = if pkgs.stdenv.isLinux then
      inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default
    else
      pkgs.emptyDirectory;
    settings = {
      font-size = if pkgs.stdenv.isLinux then 14 else 20;
      font-family = "IosevkaTerm Nerd Font";
      quick-terminal-position = "center";
      command = lib.getExe pkgs.nushell;
      custom-shader = "shaders/cursor-smear.glsl";
      cursor-style = "block";
      cursor-color = "#B757CA";
      keybind = [
        "global:super+t=toggle_quick_terminal"
        # "super+alt+shift+j=write_screen_file:open"
        # "super+alt+shift+w=close_all_windows"
        # "super+alt+i=inspector:toggle"
        "ctrl+shift+w=close_tab"
        "ctrl+shift+t=new_tab"
        # "super+alt+up=goto_split:up"
        # "super+alt+down=goto_split:down"
        # "super+alt+right=goto_split:right"
        # "super+alt+left=goto_split:left"
        # "super+ctrl+f=toggle_fullscreen"
        # "super+ctrl+equal=equalize_splits"
        # "super+ctrl+up=resize_split:up,10"
        # "super+ctrl+down=resize_split:down,10"
        # "super+ctrl+right=resize_split:right,10"
        # "super+ctrl+left=resize_split:left,10"
        # "super+shift+d=new_split:down"
        # "super+shift+j=write_screen_file:paste"
        "ctrl+shift+v=paste_from_selection"
        # "super+shift+w=close_window"
        # "super+shift+comma=reload_config"
        "ctrl+page_up=previous_tab"
        "ctrl+page_down=next_tab"
        # "super+shift+up=jump_to_prompt:-1"
        # "super+shift+down=jump_to_prompt:1"
        # "super+shift+enter=toggle_split_zoom"
        "ctrl+shift+page_up=move_tab:-1"
        "ctrl+shift+page_down=move_tab:1"
        # "ctrl+shift+tab=previous_tab"
        # "super+a=select_all"
        "ctrl+shift+c=copy_to_clipboard"
        # "super+d=new_split:right"
        # "super+k=clear_screen"
        # "super+n=new_window"
        # "super+q=quit"
        "ctrl+shift+v=paste_from_clipboard"
        # "super+w=close_surface"
        # "super+zero=reset_font_size"
        # "super+physical:one=goto_tab:1"
        # "super+physical:two=goto_tab:2"
        # "super+physical:three=goto_tab:3"
        # "super+physical:four=goto_tab:4"
        # "super+physical:five=goto_tab:5"
        # "super+physical:six=goto_tab:6"
        # "super+physical:seven=goto_tab:7"
        # "super+physical:eight=goto_tab:8"
        # "super+physical:nine=last_tab"
        # "super+comma=open_config"
        "ctrl+minus=decrease_font_size:1"
        "ctrl+plus=increase_font_size:1"
        "ctrl+equal=increase_font_size:1"
        # "super+left_bracket=goto_split:previous"
        # "super+right_bracket=goto_split:next"
        # "super+up=jump_to_prompt:-1"
        # "super+down=jump_to_prompt:1"
        "ctrl+home=scroll_to_top"
        "ctrl+end=scroll_to_bottom"
        "ctrl+up=scroll_page_up"
        "ctrl+down=scroll_page_down"
        # "super+enter=toggle_fullscreen"
        # "super+backspace=text:x15"
        # "super+right=esc:f"
        # "super+left=esc:b"
        # "ctrl+tab=next_tab"
        "shift+up=adjust_selection:up"
        "shift+down=adjust_selection:down"
        "shift+right=adjust_selection:right"
        "shift+left=adjust_selection:left"
        "shift+home=adjust_selection:home"
        "shift+end=adjust_selection:end"
        "shift+page_up=adjust_selection:page_up"
        "shift+page_down=adjust_selection:page_down"
      ];
    };
  };
}
