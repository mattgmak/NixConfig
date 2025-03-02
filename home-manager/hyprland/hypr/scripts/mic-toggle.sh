#!/usr/bin/env bash

# Mic toggle script that handles press and release events
# Uses a state file to toggle only on every other event

LOG_FILE="/tmp/mic_toggle.log"
STATE_FILE="/tmp/mic_toggle_state"

# Ensure log file exists and is writable
touch "$LOG_FILE" 2>/dev/null || {
  # If we can't write to /tmp, try the home directory
  LOG_FILE="$HOME/mic_toggle.log"
  touch "$LOG_FILE"
}

# Clear the log file
>"$LOG_FILE"

# Log function
log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S.%3N')] $1" >>"$LOG_FILE"
}

# Start logging
log_message "----------------------------------------"
log_message "Script started - Button event detected"
log_message "Running as user: $(whoami)"
log_message "Current directory: $(pwd)"
log_message "Script path: $0"

# Check if wpctl is available
if ! command -v wpctl &>/dev/null; then
  log_message "ERROR: wpctl command not found"
  log_message "Searching for wpctl: $(which wpctl 2>&1 || echo 'not found')"
  log_message "PATH: $PATH"
  exit 1
fi

# Read the current state (0 or 1)
if [ -f "$STATE_FILE" ]; then
  STATE=$(cat "$STATE_FILE")
  log_message "Current state: $STATE"
else
  # Initialize state file if it doesn't exist
  STATE=0
  echo "$STATE" >"$STATE_FILE"
  log_message "State file initialized to 0"
fi

# Toggle the state (0 -> 1 or 1 -> 0)
if [ "$STATE" -eq 0 ]; then
  NEW_STATE=1
  log_message "Changing state to 1 (will toggle mic)"

  # Get current mic status before toggle
  log_message "Running: wpctl get-volume @DEFAULT_AUDIO_SOURCE@"
  BEFORE_STATUS=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>&1)
  log_message "Raw output: $BEFORE_STATUS"
  BEFORE_MUTED=$(echo "$BEFORE_STATUS" | grep -o "MUTED" || echo "UNMUTED")
  log_message "Mic status before toggle: $BEFORE_MUTED"

  # Execute the actual command
  log_message "Running: wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
  RESULT=$?
  log_message "Command exit code: $RESULT"

  # Get status after toggle
  AFTER_STATUS=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>&1)
  log_message "Raw output: $AFTER_STATUS"
  AFTER_MUTED=$(echo "$AFTER_STATUS" | grep -o "MUTED" || echo "UNMUTED")
  log_message "Mic status after toggle: $AFTER_MUTED"

  log_message "Mic toggled successfully"
else
  NEW_STATE=0
  log_message "Changing state to 0 (skipping mic toggle - this is the release event)"
fi

# Save the new state
echo "$NEW_STATE" >"$STATE_FILE"
log_message "Saved new state: $NEW_STATE"

log_message "Script completed"
log_message "----------------------------------------"
