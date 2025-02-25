#! /usr/bin/env nu

let baseTempDir = "/tmp/Natsumi-Browser"
let baseConfigDir = $"($env.HOME)/NixConfig/home-manager/zen-browser/chrome"
# Clone the natsumi-browser repository
git clone https://github.com/greeeen-dev/natsumi-browser.git $baseTempDir --depth 1

# Copy the natsumi-pages directory to the chrome directory
cp -r "/tmp/Natsumi-Browser/natsumi-pages" $"($baseConfigDir)/natsumi-pages"

# Copy the natsumi directory to the chrome directory
cp -r "/tmp/Natsumi-Browser/natsumi" $"($baseConfigDir)/natsumi"

# Copy the natsumi-config.css file to the chrome directory
cp -r "/tmp/Natsumi-Browser/natsumi-config.css" $"($baseConfigDir)/natsumi-config.css"

# Remove the Natsumi-Browser directory
rm -rf $baseTempDir
