#!/bin/bash
# ==============================================================================
# Script:      bbb-smart-restart.sh
# Purpose:     Gracefully restarts BigBlueButton services at night if no active
#              meetings exist, preventing LibreOffice/Audio memory leaks.
# Target:      /usr/local/bin/bbb-smart-restart.sh
# Cron Job:    0 3 * * * /usr/local/bin/bbb-smart-restart.sh
# Log File:    /var/log/bbb-smart-restart.log
# ==============================================================================

set -euo pipefail

# Ensure standard binaries are in path for cron execution
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LOG_FILE="/var/log/bbb-smart-restart.log"
DATE_TAG="$(date '+%Y-%m-%d %H:%M:%S')"

log() {
    echo "[$DATE_TAG] $1" >> "$LOG_FILE"
}

# 1. Fetch BigBlueButton API URL and Secret dynamically
SECRET=""
URL=""

if [ -f /etc/bigbluebutton/bbb-web.properties ]; then
    SECRET=$(grep -E "^securitySalt=" /etc/bigbluebutton/bbb-web.properties | cut -d= -f2 | tr -d '\r ' || true)
    URL=$(grep -E "^bigbluebutton.web.serverURL=" /etc/bigbluebutton/bbb-web.properties | cut -d= -f2 | tr -d '\r ' || true)
fi

# Fallback to upstream default properties if not overridden in /etc
if [ -z "$SECRET" ] && [ -f /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties ]; then
    SECRET=$(grep -E "^securitySalt=" /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties | cut -d= -f2 | tr -d '\r ' || true)
fi

if [ -z "$URL" ] && [ -f /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties ]; then
    URL=$(grep -E "^bigbluebutton.web.serverURL=" /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties | cut -d= -f2 | tr -d '\r ' || true)
fi

# Fallback to bbb-conf parser if still empty
if [ -z "$SECRET" ] || [ -z "$URL" ]; then
    CONF_OUTPUT=$(bbb-conf --secret 2>/dev/null || true)
    URL=$(echo "$CONF_OUTPUT" | grep "URL:" | awk '{print $2}' | tr -d '\r ')
    SECRET=$(echo "$CONF_OUTPUT" | grep "Secret:" | awk '{print $2}' | tr -d '\r ')
fi

if [ -z "$SECRET" ] || [ -z "$URL" ]; then
    log "ERROR: Could not resolve BigBlueButton API credentials. Skipping restart."
    exit 1
fi

# 2. Build Checksum and API Call for getMeetings
QUERY="getMeetings"
CHECKSUM=$(echo -n "${QUERY}${SECRET}" | sha1sum | awk '{print $1}')
API_CALL="${URL}/bigbluebutton/api/${QUERY}?checksum=${CHECKSUM}"

# 3. Query BigBlueButton API (with 15s timeout to prevent hanging)
RESPONSE=$(curl -k -s --max-time 15 "$API_CALL" || true)

# 4. Check API response
if [ -z "$RESPONSE" ]; then
    log "WARNING: API did not respond (service might be frozen). Forcing restart..."
    /usr/bin/bbb-conf --restart >> "$LOG_FILE" 2>&1
    exit 0
fi

if echo "$RESPONSE" | grep -q "<returncode>FAILED</returncode>"; then
    ERROR_MSG=$(echo "$RESPONSE" | grep -oPm1 "(?<=<message>)[^<]+" || echo "Unknown API error")
    log "ERROR: getMeetings API call failed ($ERROR_MSG). Skipping restart to prevent dropping users."
    exit 1
fi

# 5. Evaluate Active Meetings
# Check if there is any meeting element present in the XML
if echo "$RESPONSE" | grep -q "<meeting>"; then
    ACTIVE_COUNT=$(echo "$RESPONSE" | grep -c "<meeting>" || true)
    log "Active meetings found (${ACTIVE_COUNT} meeting(s)). Skipping restart."
    exit 0
else
    log "No active meetings detected. Starting BigBlueButton restart..."
    /usr/bin/bbb-conf --restart >> "$LOG_FILE" 2>&1
    log "BigBlueButton restarted successfully."
fi
