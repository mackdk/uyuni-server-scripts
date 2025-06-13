#!/bin/bash

LOG_DIR="/var/log/rhn/reposync"
SYNC_COMPLETE_MESSAGE="Sync completed."

# Function to get the currently running spacewalk-repo-sync channel
get_current_channel() {
    pgrep -af "spacewalk-repo-sync" | grep -oP ' --channel \K[^[:space:]]+' | uniq
}

timestamp() {
    date +"%Y/%m/%d %H:%M:%S %z" | sed 's/\([+-]\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1\2:\3/'
}

# Main loop
while true; do
    CURRENT_CHANNEL=$(get_current_channel)

    if [ -z "$CURRENT_CHANNEL" ]; then
        echo "$(timestamp) No running reposync. Waiting for one to start..."
        sleep 5 # Wait a bit before checking again
        continue
    fi

    LOG_FILE="$LOG_DIR/$CURRENT_CHANNEL.log"

    if [ ! -f "$LOG_FILE" ]; then
        echo "$(timestamp) Log file $LOG_FILE does not exist yet. Waiting for it to appear..."
        sleep 2 # Wait a bit for the log file to be created
        continue
    fi

    echo "$(timestamp) Tailing log for channel: $CURRENT_CHANNEL ($LOG_FILE)"

    # Tail the log file and check for completion
    tail -f "$LOG_FILE" | while IFS= read -r line; do
        echo "$line"
        if echo "$line" | grep -q "$SYNC_COMPLETE_MESSAGE"; then
            echo "$(timestamp) Sync completed for channel $CURRENT_CHANNEL. Looking for next running reposync..."
            break # Exit the inner while loop (tail monitoring)
        fi
    done

    # Small delay to prevent busy-waiting and allow spacewalk-repo-sync to potentially start the next channel
    sleep 1
done
