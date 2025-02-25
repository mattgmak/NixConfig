#! /usr/bin/env nu

let baseTempDir = "/tmp/Natsumi-Browser"
let baseConfigDir = $"($env.HOME)/NixConfig/home-manager/zen-browser/chrome"
# Clone the natsumi-browser repository
git clone https://github.com/Natsumi-Browser/Natsumi-Browser.git $baseTempDir

# Copy the natsumi-pages directory to the chrome directory
cp -r "/tmp/Natsumi-Browser/natsumi-pages" $"($baseConfigDir)/natsumi-pages"

# Copy the natsumi directory to the chrome directory
cp -r "/tmp/Natsumi-Browser/natsumi" $"($baseConfigDir)/natsumi"

# Copy the natsumi-config directory to the chrome directory
cp -r "/tmp/Natsumi-Browser/natsumi-config" $"($baseConfigDir)/natsumi-config"

# Remove the Natsumi-Browser directory
rm -rf $baseTempDir
