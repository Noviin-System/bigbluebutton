#!/bin/bash
# ==============================================================================
# Script:      check-presentation-errors.sh
# Target:      BigBlueButton presentation upload/conversion diagnostic tool
# Description: Inspects bbb-web logs for CountingPageException, timeouts,
#              and conversion failures for today or an archived date.
# Usage:
#              ./check-presentation-errors.sh             # Checks current live log
#              ./check-presentation-errors.sh 2026-09-02  # Checks specific archived log
# ==============================================================================

set -euo pipefail

LOG_DIR="/var/log/bigbluebutton"
CURRENT_LOG="${LOG_DIR}/bbb-web.log"
TARGET_DATE="${1:-}"

echo "=========================================================="
echo " BigBlueButton Presentation Diagnostic Tool"
echo "=========================================================="

if [ -z "$TARGET_DATE" ]; then
    echo "[*] Checking live log: ${CURRENT_LOG}"
    if [ ! -f "$CURRENT_LOG" ]; then
        echo "[-] Error: Log file ${CURRENT_LOG} not found."
        exit 1
    fi

    echo -e "\n[1] Checking for CountingPageException (First match + 60 lines context):"
    echo "----------------------------------------------------------"
    if grep -q "CountingPageException" "$CURRENT_LOG"; then
        grep -m 1 -A 60 "CountingPageException" "$CURRENT_LOG"
    else
        echo "[+] No CountingPageException found in live log."
    fi

    echo -e "\n[2] Checking recent errors/failures/timeouts (Last 50 entries):"
    echo "----------------------------------------------------------"
    grep -iE "error|failed|CountingPageException|Timeout" "$CURRENT_LOG" | tail -n 50 || echo "[+] No critical matching errors found."

else
    ARCHIVED_LOG="${LOG_DIR}/bbb-web.${TARGET_DATE}.log.gz"
    echo "[*] Checking archived log for date: ${TARGET_DATE} (${ARCHIVED_LOG})"
    
    if [ ! -f "$ARCHIVED_LOG" ]; then
        echo "[-] Error: Archive log ${ARCHIVED_LOG} does not exist."
        exit 1
    fi

    echo -e "\n[1] Checking for CountingPageException in archive:"
    echo "----------------------------------------------------------"
    if zgrep -q "CountingPageException" "$ARCHIVED_LOG"; then
        zgrep -m 1 -A 60 "CountingPageException" "$ARCHIVED_LOG"
    else
        echo "[+] No CountingPageException found in ${ARCHIVED_LOG}."
    fi

    echo -e "\n[2] Checking recent errors/failures/timeouts in archive (Last 50 entries):"
    echo "----------------------------------------------------------"
    zcat "$ARCHIVED_LOG" | grep -iE "error|failed|CountingPageException|Timeout" | tail -n 50 || echo "[+] No critical matching errors found."
fi

echo -e "\n=========================================================="
echo " Diagnostics completed."
echo "=========================================================="
