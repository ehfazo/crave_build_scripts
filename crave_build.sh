#!/bin/bash

BUILD_LOG="crave_build.log"
ERROR_LOG="crave_error.log"
BUILD_SCRIPT_URL="https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/crave_build.sh"

SENTINEL=".crave_bg"

sentinel_alive() {
    [ ! -f "$SENTINEL" ] && return 1
    OLD_PID=$(cat "$SENTINEL" 2>/dev/null)
    [ -z "$OLD_PID" ] && return 1
    kill -0 "$OLD_PID" 2>/dev/null && return 0
    rm -f "$SENTINEL"
    return 1
}

if [ "${DAEMONIZED:-0}" = "0" ] && ! sentinel_alive; then
    curl -sfL "$BUILD_SCRIPT_URL" -o /tmp/crave_build_daemon.sh
    chmod +x /tmp/crave_build_daemon.sh
    DAEMONIZED=1 nohup /tmp/crave_build_daemon.sh > "$BUILD_LOG" 2> "$ERROR_LOG" &
    echo "$!" > "$SENTINEL"
    echo "🚀 Build launched in background (PID $!)"
    echo "📄 Tail logs: tail -f $BUILD_LOG"
    echo "❌ Tail errors: tail -f $ERROR_LOG"
    exit 0
fi
trap 'rm -f "$SENTINEL"' EXIT

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│              ⚠️ .env file not found!                       │"
    echo "└────────────────────────────────────────────────────────────┘"
    exit 1
fi

# Load your local secrets
source .env

# Define the notification function properly
send_telegram() {
    local FOOTER=".
    
                        _via Crave Remote Build_"
    local FINAL_TEXT="${1}${FOOTER}"

    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "message_thread_id=${TG_TOPIC}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${FINAL_TEXT}" >/dev/null
}

# Fetch and load the funny messages from another file
curl -sf https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/config/messages.sh -o messages.sh
if [ -f "messages.sh" ]; then
    source messages.sh
    RANDOM_MSG=${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}
else
    RANDOM_MSG="🔥 Build started for ${DEVICE:-creek}!"
fi

# Build Queue notification
send_telegram "$RANDOM_MSG"

# ================= CRAVE QUEUE =================
echo "┌────────────────────────────────────────────────────────────┐"
echo "│    🚀 Starting remote build queue...                       │"
echo "└────────────────────────────────────────────────────────────┘"

crave run --projectID 93 --no-patch -- 'curl -sf https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/crave_run.sh | bash' >> "$BUILD_LOG" 2>&1

CRAVE_STATUS=$?

if [ $CRAVE_STATUS -eq 0 ]; then
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│         ✅ Crave execution completed successfully!         │"
    echo "└────────────────────────────────────────────────────────────┘"
elif [ $CRAVE_STATUS -eq 130 ]; then
    send_telegram "*Build Cancelled:* User terminated the process manually."
    exit 1
else
    echo "⚠️ Crave run failed with exit code $CRAVE_STATUS."
    send_telegram "🚨 ALERT: Build script failed with exit code ${CRAVE_STATUS}."
    exit 1
fi
