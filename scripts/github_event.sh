#! /bin/bash

set -e

# Returns the value of the first key in the github.event data structure that is not null.
function github_event {
    while [ "$#" -gt 0 ]
    do
        VALUE=$(jq -r "${1}" <"${GITHUB_EVENT_PATH}")
        if [ -n "${VALUE}" ] && [ "${VALUE}" != "null" ]
        then
            echo "${VALUE}"
            return 0
        fi

        shift
    done

    return 1
}
