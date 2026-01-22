#!/usr/bin/env bash

urls=(
  "https://addons.mozilla.org/en-US/firefox/addon/600-sound-volume/"
)
for url in $urls; do

  # Store the input URL
  PLUGIN_URL="$url"

  # Create temporary directory
  TEMP_DIR="extension-id-$(date +%s)"
  mkdir "$TEMP_DIR" || { echo "Failed to create directory"; exit 1; }
  cd "$TEMP_DIR" || { echo "Failed to change directory"; exit 1; }

  # Extract extension name and construct download URL
  DOWNLOAD_URL=$(echo "$PLUGIN_URL" \
      | sed -E 's|https://addons.mozilla.org/firefox/downloads/file/[0-9]+/([^/]+)-[^/]+\.xpi|\1|' \
      | tr '_' '-' \
      | awk '{print "https://addons.mozilla.org/firefox/downloads/latest/" $1 "/latest.xpi"}')

  # Download the extension
  wget -q "$DOWNLOAD_URL" -O latest.xpi || { echo "Failed to download extension"; cd ..; rm -rf "$TEMP_DIR"; exit 1; }

  # Unzip the extension
  unzip -q latest.xpi -d unpacked || { echo "Failed to unzip extension"; cd ..; rm -rf "$TEMP_DIR"; exit 1; }

  # Extract and display the ID
  echo "The extension-ID is:"
  jq -r '.browser_specific_settings.gecko.id' unpacked/manifest.json || { echo "Failed to extract entry key"; cd ..; rm -rf "$TEMP_DIR"; exit 1; }

  # Cleanup
  cd ..
  rm -rf "$TEMP_DIR"
done
