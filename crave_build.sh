#!/bin/bash

# Optional: ensure we are in correct directory
cd "$(dirname "$0")"

if [ ! -f "crave.yaml" ]; then
    echo "❌ Error: crave.yaml not found!"
    exit 1
fi

# Parse .env secrets from crave.yaml
awk '
/^env:/ {inenv=1; next}
/^[a-zA-Z]/ {inenv=0}
inenv {
    sub(/^[[:space:]]+/, "")
    if ($0 ~ /^[A-Za-z_]/) {
        split($0,a,":")
        key=a[1]
        sub(/^[^:]+:[[:space:]]*"?/, "")
        sub(/"?$/, "")
        print "export " key "=\"" $0 "\""
    } else {
        print
    }
}
' crave.yaml

# 2. Define the notification function properly
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
curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_scripts/lineage-23.2/messages.sh -o messages.sh
source messages.sh

# Pick a random index
RANDOM_MSG=${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}

# Build Queue notification
send_telegram "$RANDOM_MSG"

# Run your GitHub-hosted script
echo "🚀 Starting remote build queue..."
crave run --projectID 93 --no-patch -- 'curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_scripts/lineage-23.2/crave_run.sh | bash'
