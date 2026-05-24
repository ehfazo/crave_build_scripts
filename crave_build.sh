#!/bin/bash

set -uo pipefail

BUILD_LOG="crave_build.log"
ERROR_LOG="crave_error.log"

if [ ! -f ".env" ]; then
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│              ⚠️ .env file not found!                       │"
    echo "└────────────────────────────────────────────────────────────┘"
    exit 1
fi

# shellcheck disable=SC1091
source .env

send_telegram() {
    local FOOTER=".
    
                        _via Crave Remote Build_"
    local FINAL_TEXT="${1}${FOOTER}"

    local extra=()
    if [ -n "${TG_TOPIC:-}" ]; then
        extra+=(--data-urlencode "message_thread_id=${TG_TOPIC}")
    fi

    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        "${extra[@]}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${FINAL_TEXT}" >/dev/null || true
}

tmp_msgs=$(mktemp /tmp/crave_messages.XXXXXX)
if curl --fail --silent --show-error -L https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/config/messages.sh -o "$tmp_msgs"; then
    if [ -s "$tmp_msgs" ]; then
        # shellcheck disable=SC1090
        source "$tmp_msgs"
    fi
fi

if [ "${MESSAGES+x}" = "x" ] && [ "${#MESSAGES[@]}" -gt 0 ]; then
    idx=$((RANDOM % ${#MESSAGES[@]}))
    RANDOM_MSG=${MESSAGES[$idx]}
else
    RANDOM_MSG="🔥 Build started for ${DEVICE:-creek}!"
fi
rm -f "$tmp_msgs" || true

send_telegram "$RANDOM_MSG"

echo "┌────────────────────────────────────────────────────────────┐"
echo "│    🚀 Starting remote build queue...                       │"
echo "└────────────────────────────────────────────────────────────┘"

CRAVE_STATUS=0
crave run --projectID 93 --no-patch -- 'curl -sf https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/crave_run.sh | bash' >> "$BUILD_LOG" 2>&1 || CRAVE_STATUS=$?

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
