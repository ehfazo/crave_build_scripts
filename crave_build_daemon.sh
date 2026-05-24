#!/bin/bash

# Daemon script for remote Crave builds.
# Intended to be downloaded to a temp file and executed by the launcher.

set -euo pipefail

BUILD_LOG="crave_build.log"
 # shellcheck disable=SC2034
ERROR_LOG="crave_error.log"
SENTINEL=".crave_bg"

# If running from a temp file, mark so we can remove it on exit
_IS_TMP=0
case "$0" in
    /tmp/crave_build_daemon.*) _IS_TMP=1 ;;
esac

echo "$$" > "$SENTINEL"
# Claim sentinel
echo "$$" > "$SENTINEL"

# shellcheck disable=SC2317

cleanup() {
    rm -f "$SENTINEL" || true
    if [ "${_IS_TMP:-0}" = "1" ] && [ -f "$0" ]; then
        rm -f "$0" || true
    fi
}
trap cleanup EXIT INT TERM

# Check for .env
if [ ! -f ".env" ]; then
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│              ⚠️ .env file not found!                       │"
    echo "└────────────────────────────────────────────────────────────┘"
    exit 1
fi

# Load local secrets
# shellcheck disable=SC1091
source .env

send_telegram() {
    local FOOTER=".\n\n                        _via Crave Remote Build_"
    local FINAL_TEXT="${1}${FOOTER}"

    curl --silent --show-error -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "message_thread_id=${TG_TOPIC}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${FINAL_TEXT}" >/dev/null || true
}

# Fetch funny messages safely
tmp_msgs=$(mktemp /tmp/crave_messages.XXXXXX)
if curl --fail --silent --show-error -L https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/config/messages.sh -o "$tmp_msgs"; then
    if [ -s "$tmp_msgs" ]; then
        # shellcheck disable=SC1090
        source "$tmp_msgs"
    fi
fi

if [ "${#MESSAGES[@]:-0}" -gt 0 ]; then
    idx=$((RANDOM % ${#MESSAGES[@]}))
    RANDOM_MSG=${MESSAGES[$idx]}
else
    RANDOM_MSG="🔥 Build started for ${DEVICE:-creek}!"
fi
rm -f "$tmp_msgs" || true

# Notify queue
send_telegram "$RANDOM_MSG"

# ================= CRAVE QUEUE =================
echo "┌────────────────────────────────────────────────────────────┐"
echo "│    🚀 Starting remote build queue...                       │"
echo "└────────────────────────────────────────────────────────────┘"

crave run --projectID 93 --no-patch -- 'curl -sf https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/crave_run.sh | bash' >> "$BUILD_LOG" 2>&1 || true

CRAVE_STATUS=$?

if [ $CRAVE_STATUS -eq 0 ]; then
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│         ✅ Crave execution completed successfully!         │"
    echo "└────────────────────────────────────────────────────────────┘"
    send_telegram "✅ Build completed successfully for ${DEVICE:-creek}."
    exit 0
elif [ $CRAVE_STATUS -eq 130 ]; then
    send_telegram "*Build Cancelled:* User terminated the process manually."
    exit 1
else
    echo "⚠️ Crave run failed with exit code $CRAVE_STATUS."
    send_telegram "🚨 ALERT: Build script failed with exit code ${CRAVE_STATUS}."
    exit 1
fi
