# Cursor Injection Module

A Home Manager module that provides comprehensive customization capabilities for the Cursor editor. This module allows you to inject custom CSS, JavaScript, and modify Electron window options to achieve complete UI customization, including frameless windows, hidden title bars, custom styling, and behavioral modifications.

## Features

- **Custom CSS Injection**: Inject custom CSS files for complete UI styling
- **Custom JavaScript Injection**: Add custom JavaScript for behavioral modifications
- **Frameless Windows**: Remove window frame and title bar via Electron options
- **Custom Title Bar Styles**: Hide title bar while keeping controls accessible
- **Background Color**: Set custom window background colors
- **Transparency**: Make windows transparent or semi-transparent
- **Window Properties**: Control rounded corners, opacity, size constraints, etc.
- **Build-time Modifications**: Changes are applied during Nix build, making them persistent
- **Custom Package Support**: Works with pinned or custom Cursor builds via `programs.cursor-injection.package`

## How It Works

This module creates a modified Cursor package by:

1. Taking `programs.cursor-injection.package` (defaults to `pkgs.code-cursor`)
2. Extracting the Cursor installation during build
3. Locating the main Electron process file (`main.js`) and `workbench.html` files
4. Injecting custom Electron BrowserWindow options into the main process
5. Injecting CSS and JavaScript file stubs into HTML templates
6. Returning an overridden package with all modifications applied

The approach is safer than runtime file modification because:

- Changes are applied at build time in the Nix store
- Original files are preserved
- Easy rollback by disabling the module
- No need for file system permissions or backup management

## Installation

### Home Manager Configuration (Recommended)

1. Import the module in your Home Manager configuration:

```nix
# In your home-manager/home.nix (or module list)
{
  imports = [
    # ... other imports
    # If using this repo's flake module export:
    inputs.self.homeModules.cursorInjection
  ];
}
```

1. Configure custom files and options:

```nix
# In a Home Manager module
{ pkgs-for-cursor, ... }: {
  # Create custom CSS/JS files in ~/.cursor/extensions/custom/
  home.file = {
    ".cursor/extensions/custom/custom.css".source = ./custom.css;
    ".cursor/extensions/custom/custom.js".source = ./custom.js;
  };

  programs.cursor-injection = {
    enable = true;
    # Optional: use a pinned/custom cursor package
    package = pkgs-for-cursor.code-cursor;
    electron = {
      frame = false;
      titleBarStyle = "hiddenInset";
    };
    customCSSFileStubs = [ "custom.css" ];
    customJSFileStubs = [ "custom.js" ];
  };
}
```

1. Rebuild your Home Manager configuration:

```bash
home-manager switch
# or if using NixOS with Home Manager
sudo nixos-rebuild switch
```

## Configuration Options

### `programs.cursor-injection.enable`

- **Type**: boolean
- **Default**: false
- **Description**: Enable the cursor injection module

### `programs.cursor-injection.electron`

- **Type**: attribute set
- **Default**: {}
- **Description**: Electron BrowserWindow options to apply to Cursor's main process

### `programs.cursor-injection.package`

- **Type**: package
- **Default**: `pkgs.code-cursor`
- **Description**: Cursor package used as the base before injection (use this for pinned nixpkgs/package variants)

### `programs.cursor-injection.customCSSFileStubs`

- **Type**: list of strings
- **Default**: []
- **Description**: List of CSS file names to inject into Cursor's workbench.html. Files should be placed in `~/.cursor/extensions/custom/`
- **Example**: `[ "custom.css" "theme.css" ]`

### `programs.cursor-injection.customJSFileStubs`

- **Type**: list of strings
- **Default**: []
- **Description**: List of JavaScript file names to inject into Cursor's workbench.html. Files should be placed in `~/.cursor/extensions/custom/`
- **Example**: `[ "custom.js" "behaviors.js" ]`

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
  programs.cursor-injection = {
    enable = true;
    electron.frame = false;
  };
}
```

### CSS/JS Injection Only

```nix
{
  programs.cursor-injection = {
    enable = true;
    customCSSFileStubs = [ "dark-theme.css" "custom-styles.css" ];
    customJSFileStubs = [ "shortcuts.js" "enhancements.js" ];
  };
}
```

### Complete Custom Setup

```nix
{
  programs.cursor-injection = {
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
    customCSSFileStubs = [ "custom.css" ];
    customJSFileStubs = [ "custom.js" ];
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
  programs.cursor-injection = {
    enable = true;
    electron = {
      frame = false;
      titleBarStyle = "hiddenInset";
    };
  };
}
```

### Using with Pinned Cursor Version

```nix
# When using a pinned nixpkgs instance for Cursor
{ pkgs-for-cursor, ... }: {
  programs.cursor-injection = {
    enable = true;
    package = pkgs-for-cursor.code-cursor;
    electron = {
      frame = false;
      titleBarStyle = "hiddenInset";
    };
  };

  # Injection is applied to the package specified above
}
```

## Troubleshooting

### Changes Not Taking Effect

- **Restart Cursor completely** (not just reload) - Use Ctrl+Q to quit, then reopen
- Verify the module is imported in your Home Manager configuration
- Check that CSS/JS files exist in `~/.cursor/extensions/custom/`
- Ensure file names in `customCSSFileStubs` and `customJSFileStubs` match actual files
- For Home Manager: run `home-manager switch` to apply changes

### CSS/JS Files Not Loading

- Files must be placed in `~/.cursor/extensions/custom/` directory
- File names must exactly match those listed in `customCSSFileStubs` and `customJSFileStubs`
- Check file permissions and accessibility
- Use developer tools (Ctrl+Shift+I) to check for loading errors

### Electron Options Not Applied

- Electron options only affect new window creation
- Some options may require specific combinations (e.g., `transparent = true` with `frame = false`)
- Check Electron documentation for option compatibility

### Checking Applied Modifications

The build log includes messages from the injection step, for example:

```text
Injecting cursor customizations...
Patching main.js with electron options...
Successfully patched main.js
Cursor injection complete on extracted directory.
```

### Reverting Changes

To completely remove:

```nix
{
  programs.cursor-injection.enable = false;
}
```

To disable specific features:

```nix
{
  programs.cursor-injection = {
    enable = true;
    electron = {};  # Remove electron modifications
    customCSSFileStubs = [];  # Remove CSS injections
    customJSFileStubs = [];   # Remove JS injections
  };
}
```

### Build Errors

If you encounter build errors:

1. Check that your electron options are valid JSON
2. Ensure all string values are properly quoted
3. Verify the cursor package is available in your nixpkgs
4. If using a pinned Cursor package, set `programs.cursor-injection.package` explicitly
5. Check that CSS/JS file paths are correct

## Comparison with VSCode Extensions

|Feature|VSCode Extensions|This Module|
|---|---|---|
|File Modification|Runtime|Build-time|
|CSS/JS Injection|Extension-based|Direct HTML injection|
|Persistence|Requires backup management|Automatic via Nix|
|Rollback|Manual script|Disable module|
|Permissions|Needs write access|No runtime permissions needed|
|Safety|Risk of corruption|Isolated in Nix store|
|Version Pinning|Not supported|Supported via `programs.cursor-injection.package`|

## File Structure

When using this module, your file structure should look like:

```text
~/.cursor/extensions/custom/
├── custom.css          # Your custom CSS
├── custom.js           # Your custom JavaScript
├── theme.css          # Additional CSS files
└── behaviors.js       # Additional JS files
```

## CSS/JS Development Tips

### CSS Injection

- Target Cursor's workbench elements directly
- Use browser dev tools to inspect element structure
- Changes take effect after Cursor restart

### JavaScript Injection

- JavaScript is injected into the renderer process
- Access to Cursor's internal APIs may be limited
- Use `console.log()` for debugging - visible in dev tools

## References

- [Electron BrowserWindow Documentation](https://www.electronjs.org/docs/latest/api/browser-window)
- [Original vscode-custom-ui-style Extension](https://github.com/subframe7536/vscode-custom-ui-style)
- [Electron Window Customization Guide](https://www.electronjs.org/docs/latest/tutorial/custom-window-styles)
- [Nixpkgs Overlays Documentation](https://nixos.org/manual/nixpkgs/stable/#chap-overlays)

## Contributing

This Home Manager module is part of the NixConfig repository. To contribute:

1. Test your changes thoroughly with Home Manager
2. Update documentation as needed
3. Follow Nix module conventions
4. Consider backward compatibility
5. Test with both pinned and regular nixpkgs instances
6. Ensure proper Home Manager integration
