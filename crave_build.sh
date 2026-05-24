#!/bin/bash

# Fail early on errors, undefined vars, and pipeline failures
set -euo pipefail

BUILD_LOG="crave_build.log"
ERROR_LOG="crave_error.log"
# Point launcher to the dedicated daemon script uploaded to the repo
BUILD_SCRIPT_URL="https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/crave_build_daemon.sh"

SENTINEL=".crave_bg"

# If this process was started as the daemon, claim the sentinel and
# ensure it's removed when the daemon exits.
if [ "${DAEMONIZED:-0}" = "1" ]; then
    echo "$$" > "$SENTINEL"
    trap 'rm -f "$SENTINEL"' EXIT
fi

sentinel_alive() {
    [ ! -f "$SENTINEL" ] && return 1
    OLD_PID=$(cat "$SENTINEL" 2>/dev/null)
    [ -z "$OLD_PID" ] && return 1
    kill -0 "$OLD_PID" 2>/dev/null && return 0
    rm -f "$SENTINEL"
    return 1
}

if [ "${DAEMONIZED:-0}" = "0" ] && ! sentinel_alive; then
    tmp_daemon=$(mktemp /tmp/crave_build_daemon.XXXXXX)
    if curl --fail --silent --show-error -L "$BUILD_SCRIPT_URL" -o "$tmp_daemon"; then
        chmod +x "$tmp_daemon"
        # If NO_DAEMON is set or we're running interactively, run in foreground.
        if [ "${NO_DAEMON:-0}" = "1" ] || [ -t 1 ]; then
            echo "🔎 Running daemon script in foreground"
            DAEMONIZED=1 bash "$tmp_daemon" > "$BUILD_LOG" 2> "$ERROR_LOG"
            rm -f "$tmp_daemon" || true
            exit 0
        else
            DAEMONIZED=1 nohup "$tmp_daemon" > "$BUILD_LOG" 2> "$ERROR_LOG" &
            echo "$!" > "$SENTINEL"
            echo "🚀 Build launched in background (PID $!)"
            echo "📄 Tail logs: tail -f $BUILD_LOG"
            echo "❌ Tail errors: tail -f $ERROR_LOG"
            exit 0
        fi
    else
        echo "❌ Failed to download daemon script from $BUILD_SCRIPT_URL" >&2
        rm -f "$tmp_daemon"
        exit 1
    fi
fi
# Do NOT remove the sentinel here — the daemon process should manage it.

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│              ⚠️ .env file not found!                       │"
    echo "└────────────────────────────────────────────────────────────┘"
    exit 1
fi

# Load your local secrets
# shellcheck disable=SC1091
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

# Fetch and load the funny messages from another file safely
tmp_msgs=$(mktemp /tmp/crave_messages.XXXXXX)
if curl --fail --silent --show-error -L https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/config/messages.sh -o "$tmp_msgs"; then
    # only source if file is non-empty
    if [ -s "$tmp_msgs" ]; then
        # shellcheck disable=SC1090
        source "$tmp_msgs"
    fi
fi
if [ "${MESSAGES+x}" = "x" ]; then
    cnt=${#MESSAGES[@]}
else
    cnt=0
fi

if [ "$cnt" -gt 0 ]; then
    idx=$((RANDOM % cnt))
    RANDOM_MSG=${MESSAGES[$idx]}
else
    RANDOM_MSG="🔥 Build started for ${DEVICE:-creek}!"
fi
rm -f "$tmp_msgs" || true

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
