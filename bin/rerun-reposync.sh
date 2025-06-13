#!/bin/bash

usage() {
    echo "$0 <channel> [reposync additional option]"
}

CHANNEL=$1
shift

if [ -z "$CHANNEL" ]; then
    echo "Missing channel name"
    echo
    usage
    exit 1
fi

REPOSYNC_FOLDER=/var/log/rhn/reposync
CHANNEL_LOG=$REPOSYNC_FOLDER/$CHANNEL.log

if [ ! -f "$CHANNEL_LOG" ]; then
    QUERY="SELECT st.label FROM rhnchannel ch INNER JOIN rhnchannelcontentsource cc ON ch.id = cc.channel_id INNER JOIN rhncontentsource cs ON cc.source_id = cs.id INNER JOIN rhncontentsourcetype st on cs.type_id = st.id WHERE ch.label = '$CHANNEL_TYPE';"
    CHANNEL_TYPE=$(spacewalk-sql --select-mode - <<< "$QUERY" | tail -n +3 | head -n -2 | head -n 1 | xargs)
    if [ -z "$CHANNEL_TYPE" ]; then
        echo "Unable to start reposync for $CHANNEL. No log file found and the repository type cannot be identified"
        exit 1
    fi

    REPOSYNC_COMMAND="/usr/bin/spacewalk-repo-sync --channel $CHANNEL --type $CHANNEL_TYPE --non-interactive"

    echo "Running $REPOSYNC_COMMAND"
    eval "$REPOSYNC_COMMAND"
    exit 0
fi

REPOSYNC_LOGGED_COMMAND=$(grep -m 1 "Command:" "$CHANNEL_LOG" | cut -c37-)
REPOSYNC_COMMAND=$(echo "$REPOSYNC_LOGGED_COMMAND" | sed "s/^\[//; s/\]$//; s/', '/ /g; s/'//g")

# Append any additional arguments passed to the script
if [ "$#" -gt 0 ]; then
    REPOSYNC_COMMAND="$REPOSYNC_COMMAND $*"
fi

echo "Running $REPOSYNC_COMMAND"
eval "$REPOSYNC_COMMAND"