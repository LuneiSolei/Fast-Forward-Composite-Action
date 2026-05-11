#!/bin/bash
# Scans host for public GPG keys, prompts the user for key selection, then
# exports selected public keys to a temporary file in the repository. Then
# a script under the "postCreateCommand" command will import said public GPG
# keys into the container for commit signing.

# Bash strict mode
set -euo pipefail

# Script source location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Temporary output file, relative to script source
mkdir -p "${1}/tmp"
OUTPUT_FILE="${1}/tmp/.gpg-export.gpg"

# Parse keys from host keyring
declare -a FINGERPRINTS=()
declare -a SHORT_IDS=()
declare -a UIDS=()

current_fpr=""
current_uid=""

while IFS=: read -r type t1 t2 t3 t4 t5 t6 t7 t8 fpr_uid rest; do
    case "$type" in
        pub)
            # Start of a new key
            if [[ -n "$current_fpr" && "$current_uid" ]]; then
                # Save what was collected from previous key
                FINGERPRINTS+=("$current_fpr")
                SHORT_IDS+=("${$current_fpr: -16}")
                UIDS+=("$current_uid")
            fi

            # Flush previous key
            current_fpr=""
            current_uid=""
            ;;
        fpr)
            [[ -z "$current_fpr" ]] && current_fpr="$fpr_uid"
            ;;
        uid)
            [[ -z "$current_uid" ]] && current_uid="$fpr_uid"
            ;;
    esac
done < <(gpg --list-keys --with-colons 2>/dev/null)

# Flush last key
if [[ -n "$current_fpr" && "$current_uid" ]]; then
    FINGERPRINTS+=("$current_fpr")
    SHORT_IDS+=("${current_fpr: -16}")
    UIDS+=("$current_uid")
fi

# Early exit if no keys
if [[ ${#FINGERPRINTS[@]} -eq 0 ]]; then
    echo -e "No GPG public keys found on host. Skipping public key import."
    rm -f "$OUTPUT_FILE"
    exit 0
fi

# Display Key selection header
echo ""
echo -e "GPG Key Selection for DevContainer"
echo -e "=================================="

# Display Key list
echo ""
echo -e "Keys available on host:"
echo ""
for i in "${!FINGERPRINTS[@]}"; do
    printf "    %d %s %s\n" $((i + 1)) "${SHORT_IDS[$i]}" "${UIDS[$i]}"
done

# Display user selection
echo ""
echo -e "    Enter numbers to import (space-separated), 'all', or 'none'"
echo -e "    default: all"
echo -n "    > "

# Read with a timeout (defaults to all)
if read -r -t 60 SELECTION; then
    SELECTION="${SELECTION:-all}"
else
    echo ""
    echo -e "    No input received - default to 'all'"
    SELECTION="all"
fi

# Process selection
declare -a KEYS_TO_EXPORT=()

if [[ "$SELECTION" == "none" ]]; then
    echo -e "\nSkipping GPG key import."
    rm -f "$OUTPUT_FILE"
    exit 0
elif [[ "$SELECTION" == "all" ]]; then
    KEYS_TO_EXPORT=(${FINGERPRINTS[@]})
else
    for token in $SELECTION; do
        if [[ "$token" =~ ^[0-9]+$ ]]; then
            i=$((token - 1))
            if [[ $i -ge 0 && $i -lt ${#FINGERPRINTS[@]} ]]; then
                KEYS_TO_EXPORT+=("${FINGERPRINTS[$i]}")
            else
                echo -e "    '$token' is out of range - skipping."
            fi
        else
            echo -e "    '$token' is not a valid number - skipping."
        fi
    done
fi

if [[ ${#KEYS_TO_EXPORT[@]} -eq 0 ]]; then
    echo -e "\nNo valid keys selected. Nothing will be imported."
    rm -f "$OUTPUT_FILE"
    exit 0
fi

# Export the public keys
echo ""
echo -e "Exporting ${#KEYS_TO_EXPORT[@]} key(s)..."
gpg --export "${KEYS_TO_EXPORT[@]}" > "$OUTPUT_FILE"
echo -e "Exported to $OUTPUT_FILE"
echo -e "Keys will be imported when the container starts."
echo ""

if [ -z "${XDG_RUNTIME_DIR}" ]; then
    echo "Error: Environment variable, 'XDG_RUNTIME_DIR', is not set. GPG agent forwarding will not work."
    exit 1
fi

if [ ! -S "${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.extra" ]; then
    echo "Error: GPG extra socket not found at ${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.extra"
    exit 1
fi