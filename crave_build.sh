#!/bin/bash

# Optional: ensure we are in correct directory
cd "$(dirname "$0")"

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
curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_scripts/lineage-23.2/config/messages.sh -o messages.sh
source messages.sh

# Pick a random index
RANDOM_MSG=${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}

# Build Queue notification
send_telegram "$RANDOM_MSG"

# set the container log file
LOG_FILE="crave_build.log"
rm -f "$LOG_FILE"

# ================= CRAVE QUEUE & RETRY LOGIC =================
MAX_ATTEMPTS=3
ATTEMPT=1
DELAY_TIME="1m" # 1 minutes delay
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "🚀 Starting remote build queue (Attempt $ATTEMPT of $MAX_ATTEMPTS)..."
    
    # Run the crave command
    crave run --projectID 93 --no-patch -- 'curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_scripts/lineage-23.2/crave_run.sh | bash' 2>&1 | tee $LOG_FILE

    # Capture the pipeline status thanks to set -o pipefail
    CRAVE_STATUS=${PIPESTATUS[0]}

    if [ $CRAVE_STATUS -eq 0 ]; then
        echo "✅ Crave execution completed successfully!"
        break
    else
        echo "⚠️ Crave run failed or was rejected with exit code $CRAVE_STATUS."
        
        if [ ! -f "$LOG_FILE" ]; then
            echo "❌ Log file not found! Unable to verify container execution."
            ERROR_TEXT="🚨 ALERT: Build script failed to start! Check the setup"
            send_telegram "$ERROR_TEXT"
            exit 1
        fi

        if grep -q "Setting up workspace" "$LOG_FILE"; then
            # Case A: The container started fine, but compilation failed later. 
            # Do NOT retry automatically; you need to inspect actual build logs.
            echo "✅ Container initialized but compilation failed downstream."
            break
        else
            # Case B: The container was rejected or dropped out before setting up.
            echo "❌ Rejection or termination detected before container setup!"
            
            if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
                echo "🕒 Waiting $DELAY_TIME before retrying automatically..."
                TERMINATION_TEXT="🚨 ALERT: Build rejected before setup! Retrying attempt $((ATTEMPT + 1))..."
                send_telegram "$TERMINATION_TEXT"
                    
                sleep $DELAY_TIME
                ((ATTEMPT++)) # Safely move to next attempt loop
            else
                echo "❌ All $MAX_ATTEMPTS build attempts have failed."
                TERMINATION_TEXT="🚨 ALERT: Build terminated! All ${ATTEMPT} attempts completely exhausted."
                send_telegram "$TERMINATION_TEXT"
                break
            fi
        fi
    fi
done
