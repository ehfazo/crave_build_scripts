#!/bin/bash

# Optional: ensure we are in correct directory
cd "$(dirname "$0")"

BUILD_LOG="crave_build.log"
ERROR_LOG="crave_error.log"

# Self-daemonize: if not already in bg, re-launch with nohup
if [ "$1" != "--daemon" ] && [ ! -f ".crave_bg" ]; then
    touch .crave_bg
    nohup bash "$0" --daemon > "$BUILD_LOG" 2> "$ERROR_LOG" &
    echo "🚀 Build launched in background (PID $!)"
    echo "📄 Tail logs: tail -f $BUILD_LOG"
    echo "❌ Tail errors: tail -f $ERROR_LOG"
    exit 0
fi
rm -f .crave_bg

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️ .env file not found!"
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
source messages.sh

# Pick a random index
RANDOM_MSG=${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}

# Build Queue notification
send_telegram "$RANDOM_MSG"

rm -f "$BUILD_LOG" "$ERROR_LOG"

# ================= CRAVE QUEUE & RETRY LOGIC =================
MAX_ATTEMPTS=3
ATTEMPT=1
DELAY_TIME="1m"
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "🚀 Starting remote build queue (Attempt $ATTEMPT of $MAX_ATTEMPTS)..."
    
    # Run the crave command (all output goes to BUILD_LOG)
    crave run --projectID 93 --no-patch -- 'curl -sf https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/crave_run.sh | bash' >> "$BUILD_LOG" 2>&1

    CRAVE_STATUS=$?

    if [ $CRAVE_STATUS -eq 0 ]; then
        echo "✅ Crave execution completed successfully!"
        break
        
    elif [ $CRAVE_STATUS -eq 130 ]; then
        ERROR_TEXT="<b>Build Cancelled:</b> User terminated the process manually."
        send_telegram "$ERROR_TEXT"
        exit 1
        
    else
        echo "⚠️ Crave run failed or was rejected with exit code $CRAVE_STATUS."
        
        if [ ! -f "$BUILD_LOG" ]; then
            echo "❌ Log file not found! Unable to verify container execution."
            ERROR_TEXT="🚨 ALERT: Build script failed to start! Check the setup"
            send_telegram "$ERROR_TEXT"
            exit 1
        fi

        if grep -q "Setting up workspace" "$BUILD_LOG"; then
            echo "✅ Container initialized but compilation failed downstream. Logs in $BUILD_LOG"
            break
        else
            echo "❌ Rejection or termination detected before container setup!"
            
            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                echo "🕒 Waiting $DELAY_TIME before retrying automatically..."
                TERMINATION_TEXT="🚨 ALERT: Build rejected before setup! Retrying attempt $((ATTEMPT + 1))..."
                send_telegram "$TERMINATION_TEXT"
                    
                sleep $DELAY_TIME
                ((ATTEMPT++))
            else
                echo "❌ All $MAX_ATTEMPTS build attempts have failed."
                TERMINATION_TEXT="🚨 ALERT: Build terminated! All ${ATTEMPT} attempts completely exhausted."
                send_telegram "$TERMINATION_TEXT"
                break
            fi
        fi
    fi
done
