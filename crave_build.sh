#!/bin/bash

BUILD_LOG="crave_build.log"
ERROR_LOG="crave_error.log"
BUILD_SCRIPT_URL="https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/crave_build.sh"

# Self-daemonize: if not already in bg, re-launch with nohup
if [ "$1" != "--daemon" ] && [ ! -f ".crave_bg" ]; then
    touch .crave_bg
    # Save self to temp file so daemon works with curl | bash too
    SELF="/tmp/.crave_build.sh"
    curl -sfL "$BUILD_SCRIPT_URL" -o "$SELF"
    chmod +x "$SELF"
    nohup bash "$SELF" --daemon > "$BUILD_LOG" 2> "$ERROR_LOG" &
    echo "🚀 Build launched in background (PID $!)"
    echo "📄 Tail logs: tail -f $BUILD_LOG"
    echo "❌ Tail errors: tail -f $ERROR_LOG"
    exit 0
fi
rm -f .crave_bg

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

# ================= CRAVE QUEUE & RETRY LOGIC =================
MAX_ATTEMPTS=3
ATTEMPT=1
DELAY_TIME="1m"
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
                echo "│  🕒 Waiting $DELAY_TIME before retrying...                 │"
                echo "└────────────────────────────────────────────────────────────┘"
                TERMINATION_TEXT="🚨 ALERT: Build rejected before setup! Retrying attempt $((ATTEMPT + 1))..."
                send_telegram "$TERMINATION_TEXT"
                    
                sleep $DELAY_TIME
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
