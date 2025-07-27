#!/usr/bin/env nu

# Copy Zen Browser configuration files, excluding backup files
let source_dir = $"($env.HOME)/.zen/GoofyZen/chrome"
let target_dir = $"($env.HOME)/NixConfig/home-manager/desktop/zen-browser/chrome"

# Function to recursively copy files, excluding hm-backup files
def copy_recursive [source, target] {
    # Create the target directory if it doesn't exist
    if not ($target | path exists) {
        mkdir $target
    }

    # Get all files and directories in the source
    let items = (ls -a $source)

    # Process each item
    for item in $items {
        let item_name = $item.name
        let base_name = ($item_name | path basename)

        # Skip . and .. directories
        if $base_name == "." or $base_name == ".." {
            continue
        }

        # Skip files ending with hm-backup
        if ($base_name | str contains ".hm-backup") {
            continue
        }

        # Skip symlinks
        if ($item_name | path type) == "symlink" {
            print $"Skipping symlink: ($item_name)"
            continue
        }

        let target_path = $"($target)/($base_name)"

        if $item.type == "dir" {
            # Recursively copy directories
            copy_recursive $item_name $target_path
        } else {
            # Copy files
            cp $item_name $target_path
            print $"Copied: ($item_name)"
        }
    }
}

# Start the recursive copy
copy_recursive $source_dir $target_dir

print "Zen Browser configuration updated successfully!"
