#! /bin/bash

set -e

# Returns the value of the first key in the github.event data structure that is not null.
while [ "$#" -gt 0 ]
do
    VALUE=$(jq -r "${1}" <"${GITHUB_EVENT_PATH}")
    if [ -n "${VALUE}" ] && [ "${VALUE}" != "null" ]
    then
        echo "${VALUE}"
        exit 0
    fi

    shift
done

echo "::error::No non-null value found in the provided event path '${GITHUB_EVENT_PATH}'"
exit 1
