# --- Utility and API Library ---

log() { 
    echo "$@";
}

log_detailed() {
    [ "$VERBOSE" = true ] && echo "DEBUG: $@"
}

# API Helper Function
# Usage: call_api <cookie_file> <endpoint> <json_data>
call_api() {
    local cookie_file="$1"
    local endpoint="$2"
    local data="$3" 
    
    local cmd="curl -s -k -b \"$cookie_file\" -X POST -H \"Content-Type: application/json\" -d '$data' -w \"%{http_code}\" \"$API_URL/$endpoint\""

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $cmd"
    else
        log_detailed "Executing: $cmd"
        local response=$(eval "$cmd")
        local http_code="${response: -3}"
        local body="${response%???}"
        
        if [ "$http_code" != "200" ]; then
            echo "Error: HTTP $http_code on /$endpoint" >&2
            exit 1
        fi

        if [[ "$body" != *"\"success\":true"* ]]; then
            local error_msg=$(echo "$body" | grep -oP '"message":\s*"\K[^"]*' | head -1)
            echo "Error: API operation failed on /$endpoint. Reason: ${error_msg:-Unknown}" >&2
            exit 1
        fi
    fi
}

# Auth Functions
# Returns: Path to the cookie file via stdout
login() {
    local user="$1"
    local pass="$2"
    local cookie_file=$(mktemp)
    
    local login_data="{\"login\": \"$user\", \"password\": \"$pass\"}"
    local cmd="curl -s -k -c \"$cookie_file\" -H \"Content-Type: application/json\" -d '$login_data' -w \"%{http_code}\" \"$API_URL/auth/login\""

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $cmd" >&2
        echo "$cookie_file" # Still return the path so the script can clean it up
        return 0
    fi

    log_detailed "Attempting login for $user..."
    local response=$(eval "$cmd")
    local http_code="${response: -3}"
    local body="${response%???}"

    if [ "$http_code" == "200" ] && [[ "$body" == *"\"success\":true"* ]]; then
        echo "$cookie_file"
        return 0
    else
        rm -f "$cookie_file"
        return 1
    fi
}

logout() {
    local cookie_file="$1"
    [ ! -f "$cookie_file" ] && return
    
    log_detailed "Closing API session..."
    # Direct curl to ensure cleanup happens even if the session is wonky
    curl -s -k -b "$cookie_file" -X POST -H "Content-Type: application/json" -d "{}" "$API_URL/auth/logout" > /dev/null 2>&1
    rm -f "$cookie_file"
}
