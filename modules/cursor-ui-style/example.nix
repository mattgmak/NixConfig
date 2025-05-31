# Example configuration for cursor-ui-style module
# Add this to your NixOS configuration to customize Cursor's UI

{
  # Enable the cursor UI style module
  programs.cursor-ui-style = {
    enable = true;
    autoApply = true;

    # Electron BrowserWindow options
    # These replicate the vscode-custom-ui-style extension settings:
    # "custom-ui-style.electron": {
    #   "frame": false,
    #   "titleBarStyle": "hiddenInset"
    # }
    electron = {
      # Remove window frame (no title bar, no window controls)
      frame = false;

      # Hide title bar but keep window controls accessible (macOS)
      titleBarStyle = "hiddenInset";

      # Optional: Set background color
      # backgroundColor = "#1e1e1e";

      # Optional: Disable rounded corners on macOS
      # roundedCorners = false;

      # Optional: Make window transparent
      # transparent = true;

      # Optional: Set window opacity (0.0 to 1.0)
      # opacity = 0.95;

      # Optional: Set minimum window size
      # minWidth = 800;
      # minHeight = 600;

      # Optional: Enable window resizing
      # resizable = true;

      # Optional: Set window to always be on top
      # alwaysOnTop = false;
    };
  };
}

# Alternative minimal configuration (just frameless window):
# {
#   programs.cursor-ui-style = {
#     enable = true;
#     electron.frame = false;
#   };
# }

# To disable the modifications temporarily:
# {
#   programs.cursor-ui-style = {
#     enable = true;
#     autoApply = false;  # This will use the original cursor package
#     electron.frame = false;
#   };
# }
