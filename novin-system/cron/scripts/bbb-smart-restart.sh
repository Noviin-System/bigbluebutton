#!/bin/bash

# ==============================================================================
# Script:      bbb-smart-restart.sh
# Purpose:     Gracefully restarts BigBlueButton services at night if no active
#              meetings exist, preventing LibreOffice/Audio memory leaks.
# Target:      /usr/local/bin/bbb-smart-restart.sh
# Cron Job:    0 3 * * * /usr/local/bin/bbb-smart-restart.sh
# Log File:    /var/log/bbb-smart-restart.log
# ==============================================================================

SECRET=$(cat /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties | grep -w securitySalt | cut -d= -f2 | tr -d '\r')
URL=$(cat /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties | grep -w bigbluebutton.web.serverURL | cut -d= -f2 | tr -d '\r')

QUERY="getMeetings"
CHECKSUM=$(echo -n "${QUERY}${SECRET}" | sha1sum | awk '{print $1}')
API_CALL="${URL}/bigbluebutton/api/${QUERY}?checksum=${CHECKSUM}"

RESPONSE=$(curl -s "$API_CALL")

if echo "$RESPONSE" | grep -q "<meeting>"; then
    echo "$(date): Active meetings found. Skipping restart." >> /var/log/bbb-smart-restart.log
    exit 0
else
    echo "$(date): No active meetings. Restarting BBB..." >> /var/log/bbb-smart-restart.log
    /usr/bin/bbb-conf --restart >> /var/log/bbb-smart-restart.log 2>&1
fi