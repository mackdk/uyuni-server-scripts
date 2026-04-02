#!/bin/bash

{ # Start of wrapper block to prevent partial execution

install_scripts() {
    REPO_URL="https://github.com/mackdk/uyuni-server-scripts"
    TARBALL_URL="$REPO_URL/tarball/master"
    TEMP_TAR="repo_archive.tar.gz"

    echo "--- Pulling latest scripts from GitHub ---"

    # Using -f to fail silently on server errors so bash doesn't try to run an error page
    if ! curl -sSLf "$TARBALL_URL" -o "$TEMP_TAR"; then
        echo "Error: Could not reach GitHub. Check your connection."
        return 1
    fi

    # Extract and clean
    tar -xzf "$TEMP_TAR" --strip-components=1
    rm "$TEMP_TAR"

    echo "Done! Scripts updated in $(pwd)"
}

install_scripts

} # End of wrapper block
