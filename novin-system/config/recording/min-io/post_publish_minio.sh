#!/bin/bash
set -euo pipefail

MEETING_ID=""

while getopts "m:" opt; do
  case "$opt" in
    m) MEETING_ID="$OPTARG" ;;
    *) exit 1 ;;
  esac
done

if [ -z "$MEETING_ID" ]; then
  exit 1
fi

LOG_FILE="/var/log/bigbluebutton/post_publish_minio.log"
RECORDING_DIR="/var/bigbluebutton/published/presentation/${MEETING_ID}"
RCLONE_CONFIG="/home/bigbluebutton/.config/rclone/rclone.conf"
REMOTE_DEST="minio:bbb-recordings/published/presentation/${MEETING_ID}"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting upload for meeting: ${MEETING_ID}" >> "$LOG_FILE"

if [ ! -d "$RECORDING_DIR" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Directory not found: ${RECORDING_DIR}" >> "$LOG_FILE"
  exit 1
fi

if rclone --config "$RCLONE_CONFIG" copy "$RECORDING_DIR" "$REMOTE_DEST" --transfers 8 --checkers 16 >> "$LOG_FILE" 2>&1; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Successfully uploaded: ${MEETING_ID}" >> "$LOG_FILE"

  # Keep local files or remove them to free up disk space:
  # rm -rf "$RECORDING_DIR"
  # echo "$(date '+%Y-%m-%d %H:%M:%S') - Cleaned local files for: ${MEETING_ID}" >> "$LOG_FILE"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Upload failed for: ${MEETING_ID}" >> "$LOG_FILE"
  exit 1
fi

exit 0
