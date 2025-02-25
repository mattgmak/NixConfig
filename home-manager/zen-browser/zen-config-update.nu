#!/usr/bin/env nu

# Copy Zen Browser configuration files, excluding backup files
let source_dir = "~/.zen/GoofyZen/chrome"
let target_dir = "~/NixConfig/home-manager/zen-browser/chrome"

# Remove existing target directory if it exists
if ($target_dir | path exists) {
    rm -rf $target_dir
}

# Create target directory
mkdir $target_dir

# Copy files, excluding hm-backup files
ls $source_dir | where name !~ '.*\.hm-backup$' | each { |file|
    if ($file.type == "dir") {
        cp -r $file.name $target_dir
    } else {
        cp $file.name $target_dir
    }
    print $"Copied: ($file.name)"
}

print "Zen Browser configuration updated successfully!"
