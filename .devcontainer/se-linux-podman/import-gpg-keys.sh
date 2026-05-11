#!/bin/bash

KEY_FILE="/workspaces/${1}/tmp/.gpg-export.gpg"
echo "Importing GPG keys from $KEY_FILE"

if [ -f "$KEY_FILE" ]; then
    if gpg --import "$KEY_FILE"; then
        echo "GPG keys imported. Removing temporary file: $KEY_FILE}"
        rm -f "$KEY_FILE"
    else
        echo "Warning: gpg import failed for $KEY_FILE">&2
        exit 1
    fi
fi

# Additional Commands