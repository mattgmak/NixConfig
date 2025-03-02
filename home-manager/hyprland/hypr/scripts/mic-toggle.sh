#!/usr/bin/env bash

# Simple debounce script for mic mute toggle with logging
# Creates a lock file to prevent rapid successive executions

LOG_FILE="/tmp/mic_toggle.log"
LOCK_FILE="/tmp/mic_toggle.lock"

# Ensure log file exists and is writable
touch "$LOG_FILE" 2>/dev/null || {
  # If we can't write to /tmp, try the home directory
  LOG_FILE="$HOME/mic_toggle.log"
  touch "$LOG_FILE"
}

# Log function
log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S.%3N')] $1" >>"$LOG_FILE"
}

# Start logging
log_message "----------------------------------------"
log_message "Script started - Button pressed"
log_message "Running as user: $(whoami)"
log_message "Current directory: $(pwd)"
log_message "Script path: $0"

# Check if wpctl is available
if ! command -v wpctl &>/dev/null; then
  log_message "ERROR: wpctl command not found"
  # Try to find it
  log_message "Searching for wpctl: $(which wpctl 2>&1 || echo 'not found')"
  log_message "PATH: $PATH"
  exit 1
fi

# Check if the lock file exists and is less than 500ms old
if [ -f "$LOCK_FILE" ]; then
  CURRENT_TIME=$(date +%s%N)
  FILE_TIME=$(stat -c %Y "$LOCK_FILE" | xargs -I{} date +%s%N -d @{})

  # Convert to milliseconds
  DIFF=$(((CURRENT_TIME - FILE_TIME) / 1000000))

  log_message "Lock file exists, age: ${DIFF}ms"

  if [ "$DIFF" -lt 500 ]; then
    # Less than 500ms since last execution, exit
    log_message "Debounced: exiting without toggling mic (< 500ms)"
    exit 0
  else
    log_message "Lock file older than 500ms, proceeding"
  fi
else
  log_message "No lock file found, proceeding"
fi

# Create/update the lock file
touch "$LOCK_FILE"
log_message "Lock file created/updated"

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

log_message "Script completed"
log_message "----------------------------------------"
