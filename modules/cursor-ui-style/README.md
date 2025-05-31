# Cursor UI Style Module

A NixOS module that replicates the functionality of the `vscode-custom-ui-style` extension for Cursor editor. This module allows you to customize Cursor's Electron window options to achieve effects like frameless windows, hidden title bars, and other UI modifications.

## Features

- **Frameless Windows**: Remove window frame and title bar
- **Custom Title Bar Styles**: Hide title bar while keeping controls accessible
- **Background Color**: Set custom window background colors
- **Transparency**: Make windows transparent or semi-transparent
- **Window Properties**: Control rounded corners, opacity, size constraints, etc.
- **Build-time Modifications**: Changes are applied during Nix build, making them persistent

## How It Works

This module creates a modified version of the Cursor package by:

1. Copying the original Cursor installation
2. Locating the main Electron process file (`main.js`)
3. Injecting your custom Electron BrowserWindow options
4. Creating a new package with the modifications

The approach is safer than runtime file modification because:

- Changes are applied at build time in the Nix store
- Original files are preserved
- Easy rollback by disabling the module
- No need for file system permissions or backup management

## Installation

1. Add the module to your NixOS configuration imports:

```nix
# In your hosts/common.nix or similar
{
  imports = [
    # ... other imports
    ../modules/cursor-ui-style
  ];
}
```

2. Configure the module in your host configuration:

```nix
# In your host configuration (e.g., hosts/GoofyEnvy/default.nix)
{
  programs.cursor-ui-style = {
    enable = true;
    autoApply = true;
    electron = {
      frame = false;
      titleBarStyle = "hiddenInset";
    };
  };
}
```

3. Rebuild your system:

```bash
sudo nixos-rebuild switch
```

## Configuration Options

### `programs.cursor-ui-style.enable`

- **Type**: boolean
- **Default**: false
- **Description**: Enable the cursor UI style module

### `programs.cursor-ui-style.autoApply`

- **Type**: boolean
- **Default**: true
- **Description**: Whether to automatically use the modified cursor package. If false, the original cursor package will be used.

### `programs.cursor-ui-style.electron`

- **Type**: attribute set
- **Default**: {}
- **Description**: Electron BrowserWindow options to apply to Cursor

## Electron Options

Common Electron BrowserWindow options you can use:

### Window Frame and Title Bar

```nix
electron = {
  # Remove window frame completely
  frame = false;

  # Hide title bar but keep window controls (macOS)
  titleBarStyle = "hiddenInset";
  # Other options: "hidden", "customButtonsOnHover"
};
```

### Appearance

```nix
electron = {
  # Set background color
  backgroundColor = "#1e1e1e";

  # Make window transparent
  transparent = true;

  # Set opacity (0.0 to 1.0)
  opacity = 0.95;

  # Disable rounded corners (macOS)
  roundedCorners = false;
};
```

### Window Behavior

```nix
electron = {
  # Set minimum size
  minWidth = 800;
  minHeight = 600;

  # Set maximum size
  maxWidth = 1920;
  maxHeight = 1080;

  # Control resizing
  resizable = true;

  # Always on top
  alwaysOnTop = false;

  # Fullscreen mode
  fullscreen = false;
  fullscreenable = true;
};
```

## Example Configurations

### Minimal Frameless Window

```nix
{
  programs.cursor-ui-style = {
    enable = true;
    electron.frame = false;
  };
}
```

### Complete Custom Setup

```nix
{
  programs.cursor-ui-style = {
    enable = true;
    electron = {
      frame = false;
      titleBarStyle = "hiddenInset";
      backgroundColor = "#1e1e1e";
      roundedCorners = false;
      opacity = 0.95;
      minWidth = 1000;
      minHeight = 700;
    };
  };
}
```

### Replicating vscode-custom-ui-style Extension

```nix
# This replicates the VSCode extension settings:
# "custom-ui-style.electron": {
#   "frame": false,
#   "titleBarStyle": "hiddenInset"
# }
{
  programs.cursor-ui-style = {
    enable = true;
    electron = {
      frame = false;
      titleBarStyle = "hiddenInset";
    };
  };
}
```

## Troubleshooting

### Changes Not Taking Effect

- Ensure you've completely restarted Cursor (not just reloaded)
- Check that `autoApply = true` in your configuration
- Verify the module is imported in your NixOS configuration

### Checking Applied Modifications

Run the info command to see what modifications are active:

```bash
cursor-ui-info
```

### Reverting Changes

To temporarily disable modifications:

```nix
{
  programs.cursor-ui-style = {
    enable = true;
    autoApply = false;  # Uses original cursor package
    electron = { /* your settings */ };
  };
}
```

To completely remove:

```nix
{
  programs.cursor-ui-style.enable = false;
}
```

### Build Errors

If you encounter build errors:

1. Check that your electron options are valid JSON
2. Ensure all string values are properly quoted
3. Verify the cursor package is available in your nixpkgs

## Comparison with VSCode Extension

| Feature | VSCode Extension | This Module |
|---------|------------------|-------------|
| File Modification | Runtime | Build-time |
| Persistence | Requires backup management | Automatic via Nix |
| Rollback | Manual script | Disable module |
| Permissions | Needs write access | No runtime permissions needed |
| Safety | Risk of corruption | Isolated in Nix store |

## References

- [Electron BrowserWindow Documentation](https://www.electronjs.org/docs/latest/api/browser-window)
- [Original vscode-custom-ui-style Extension](https://github.com/subframe7536/vscode-custom-ui-style)
- [Electron Window Customization Guide](https://www.electronjs.org/docs/latest/tutorial/custom-window-styles)

## Contributing

This module is part of the NixConfig repository. To contribute:

1. Test your changes thoroughly
2. Update documentation as needed
3. Follow Nix module conventions
4. Consider backward compatibility
