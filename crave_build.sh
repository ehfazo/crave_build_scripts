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
    rm -f /tmp/crave_build_daemon.sh
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

# ================= DELAY BEFORE BUILD =================
START_DELAY=600
send_telegram "⏳ *Build will start in ${START_DELAY}s* — you have time to push fixes."
echo "┌────────────────────────────────────────────────────────────┐"
echo "│  ⏳ Build starts in ${START_DELAY}s. Push fixes now!       │"
echo "└────────────────────────────────────────────────────────────┘"
for ((i=START_DELAY; i>0; i-=60)); do
    echo "  ${i}s remaining..."
    sleep 60
done
sleep $((START_DELAY % 60))

# ================= CRAVE QUEUE & RETRY LOGIC =================
MAX_ATTEMPTS=3
ATTEMPT=1
RETRY_DELAY=600
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "┌────────────────────────────────────────────────────────────┐"
    echo "│    🚀 Starting remote build queue (Attempt $ATTEMPT of $MAX_ATTEMPTS)...│"
    echo "└────────────────────────────────────────────────────────────┘"
    
    # Run the crave command (all output goes to BUILD_LOG)
    crave run --projectID 93 --no-patch -- 'curl -sf https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/crave_run.sh | bash' >> "$BUILD_LOG" 2>&1

    CRAVE_STATUS=$?

    if [ $CRAVE_STATUS -eq 0 ]; then
        echo "┌────────────────────────────────────────────────────────────┐"
        echo "│         ✅ Crave execution completed successfully!         │"
        echo "└────────────────────────────────────────────────────────────┘"
        break
        
    elif [ $CRAVE_STATUS -eq 130 ]; then
        ERROR_TEXT="*Build Cancelled:* User terminated the process manually."
        send_telegram "$ERROR_TEXT"
        exit 1
        
    else
        echo "⚠️ Crave run failed or was rejected with exit code $CRAVE_STATUS."
        
        if [ ! -f "$BUILD_LOG" ]; then
            echo "┌────────────────────────────────────────────────────────────┐"
            echo "│   ❌ Log file not found! Unable to verify container exec. │"
            echo "└────────────────────────────────────────────────────────────┘"
            ERROR_TEXT="🚨 ALERT: Build script failed to start! Check the setup"
            send_telegram "$ERROR_TEXT"
            exit 1
        fi

        if grep -q "Setting up workspace" "$BUILD_LOG"; then
            echo "┌────────────────────────────────────────────────────────────┐"
            echo "│  ✅ Container initialized but compilation failed downstream│"
            echo "└────────────────────────────────────────────────────────────┘"
            break
        else
            echo "┌────────────────────────────────────────────────────────────┐"
            echo "│  ❌ Rejection or termination detected before setup!        │"
            echo "└────────────────────────────────────────────────────────────┘"
            
            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                echo "┌────────────────────────────────────────────────────────────┐"
                echo "│  🕒 Waiting ${RETRY_DELAY}s before retrying...                │"
                echo "└────────────────────────────────────────────────────────────┘"
                TERMINATION_TEXT="🚨 ALERT: Build rejected before setup! Retrying attempt $((ATTEMPT + 1)) in ${RETRY_DELAY}s..."
                send_telegram "$TERMINATION_TEXT"
                for ((i=RETRY_DELAY; i>0; i-=60)); do
                    echo "  ${i}s remaining..."
                    sleep 60
                done
                sleep $((RETRY_DELAY % 60))
                ((ATTEMPT++))
            else
                echo "┌────────────────────────────────────────────────────────────┐"
                echo "│     ❌ All $MAX_ATTEMPTS build attempts have failed.        │"
                echo "└────────────────────────────────────────────────────────────┘"
                TERMINATION_TEXT="🚨 ALERT: Build terminated! All ${ATTEMPT} attempts completely exhausted."
                send_telegram "$TERMINATION_TEXT"
                break
            fi
        fi
    fi
done
