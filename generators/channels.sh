#!/bin/bash

# --- Import Library ---
LIB_FILE="$(dirname "$0")/api_lib.sh"
if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
else
    echo "Error: Library file $LIB_FILE not found." >&2
    exit 1
fi

# --- Defaults ---
USER="${API_USER:-admin}"
PASS="${API_PASS:-admin}"
API_PATH="/rhn/manager/api"
TOTAL=1
WITH_CHILDREN=false
WITH_REPO=false
MIN_CHILDREN=10
MAX_CHILDREN=20
VERBOSE=false
DRY_RUN=false
HOST=""

# --- Usage Function ---
usage() {
    echo "Usage: $0 [options] <URL_HOST>"
    echo ""
    echo "Description:"
    echo "  Automates the creation of software channels and optional repositories."
    echo ""
    echo "Arguments:"
    echo "  URL_HOST             The hostname of the manager (e.g., manager.example.com)"
    echo ""
    echo "Options:"
    echo "  -u, --user           Username (Default: admin)"
    echo "  -w, --password       Prompt for password securely (interactive)"
    echo "  -t, --total          Total approximate channels to create (Default: 1)"
    echo "  -c, --with-children  Create child channels for each base channel"
    echo "  -r, --with-repo      Create and associate a repository for each channel"
    echo "  -n, --min-children   Min children per base channel (Default: 10)"
    echo "  -m, --max-children   Max children per base channel (Default: 20)"
    echo "  -d, --dry-run        Print curl commands without executing them"
    echo "  -v, --verbose        Enable detailed output"
    echo "  --help               Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  API_USER             Set the username via environment"
    echo "  API_PASS             Set the password via environment to avoid prompts"
    exit 0
}

# --- Recursive Business Logic ---
create_channel() {
    local cookie="$1"
    local id="$2"
    local -n result_var=$3
    local parent="${4:-}"
    
    local prefix="test-channel-"
    [ -n "$parent" ] && prefix="test-child-channel-"
    
    local ch_label="${prefix}${id}"
    local repo_label="test-repo-${id}"
    local count=1

    [ -z "$parent" ] && log "Generating base channel: $ch_label..." || log_detailed "Creating child: $ch_label (Parent: $parent)"

    # Create Channel
    call_api "$cookie" "channel/software/create" "{
        \"label\": \"$ch_label\",
        \"name\": \"Test $ch_label\",
        \"summary\": \"Fake Data\",
        \"archLabel\": \"channel-x86_64\",
        \"parentLabel\": \"$parent\",
        \"checksumType\": \"sha256\"
    }"

    # Conditionally Create Repo
    if [ "$WITH_REPO" = true ]; then
        log_detailed "Creating repository for $ch_label"
        call_api "$cookie" "channel/software/createRepo" "{\"label\": \"$repo_label\", \"type\": \"yum\", \"url\": \"http://repo.example.com/$repo_label\"}"
        call_api "$cookie" "channel/software/associateRepo" "{\"channelLabel\": \"$ch_label\", \"repoLabel\": \"$repo_label\"}"
    fi

    # Handle Recursion
    if [[ -z "$parent" && "$WITH_CHILDREN" = true ]]; then
        local num_children=$(( MIN_CHILDREN + RANDOM % (MAX_CHILDREN - MIN_CHILDREN + 1) ))
        log " -> Adding $num_children children to $ch_label..."
        
        for (( j=1; j<=num_children; j++ )); do
            local child_id="${id}-c${j}"
            local child_made=0
            create_channel "$cookie" "$child_id" child_made "$ch_label"
            count=$(( count + child_made ))
        done
    fi
    result_var=$count
}

# --- Argument Parsing ---
[ $# -lt 1 ] && usage

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--user)           USER="$2"; shift 2 ;;
        -w|--password)       printf "Password: "; read -s PASS; echo ""; shift ;;
        -t|--total)          TOTAL="$2"; shift 2 ;;
        -c|--with-children)  WITH_CHILDREN=true; shift ;;
        -r|--with-repo)      WITH_REPO=true; shift ;;
        -n|--min-children)   MIN_CHILDREN="$2"; shift 2 ;;
        -m|--max-children)   MAX_CHILDREN="$2"; shift 2 ;;
        -d|--dry-run)        DRY_RUN=true; shift ;;
        -v|--verbose)        VERBOSE=true; shift ;;
        --help)              usage ;;
        -*)                  echo "Unknown option: $1"; usage ;;
        *)                   [ -z "$HOST" ] && HOST="$1" || { echo "Error: Multiple hosts specified"; exit 1; }; shift ;;
    esac
done

[ -z "$HOST" ] && { echo "Error: No host specified"; exit 1; }

# --- Main Execution ---
API_URL="https://$HOST$API_PATH"

# SESSION_COOKIE now holds the path to the temp file returned by login
SESSION_COOKIE=$(login "$USER" "$PASS")

if [ $? -ne 0 ] || [ -z "$SESSION_COOKIE" ]; then
    echo "Error: Authentication failed for user '$USER'." >&2; exit 1
fi

# Trap handles cleanup using the path stored in the variable
trap 'logout "$SESSION_COOKIE"' EXIT

CURRENT_TOTAL=0
log "Targeting $TOTAL software channels on $HOST..."

while [ "$CURRENT_TOTAL" -lt "$TOTAL" ]; do
    RAND_ID=$(( $RANDOM % 10000 ))
    BATCH_MADE=0
    create_channel "$SESSION_COOKIE" "$RAND_ID" BATCH_MADE
    CURRENT_TOTAL=$(( CURRENT_TOTAL + BATCH_MADE ))
    log "Progress: $CURRENT_TOTAL / $TOTAL channels created."
done

log "Successfully created $CURRENT_TOTAL software channels."
