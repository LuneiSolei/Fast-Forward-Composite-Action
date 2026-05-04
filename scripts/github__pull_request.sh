#! /bin/bash

set -e

# Create a temp file for storing metadata
GITHUB_PR=$(mktemp)

# Returns the first non-null value from the provided paths
function github_pull_request {
    # Attempt to get PR URL from issue_comment first, then pull_request event data
    PR_URL="$(github_event .issue.pull_request.url .pull_request.url)"
    if [ -z "${PR_URL}" ] || [ "${PR_URL}" = "null" ]
    then
        # Nothing was found
        echo "Unable to find pull request's context." >&2
        exit 1
    fi

    # Using our newly found URL, get the full PR object
    curl --silent --show-error --location --globoff \
    -X GET \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: 2026-03-10" \
    "${PR_URL}" >${GITHUB_PR}

    # Do some debug logging, if enabled
    if [ "${DEBUG}" -gt 0 ]
    then
        {
            echo "pull_request (${GITHUB_PR}):"
            cat "${GITHUB_PR}"
        } >&2
    fi

    # Extract field(s) from our now cached PR data by returning
    # the first non-null value from the provided paths
    while [ "$#" -gt 0 ]
    do
        VALUE=$(jq -r "$1" <${GITHUB_PR})
        if [ -n "${VALUE}" ] && [ "${VALUE}" != null ]
        then
            echo "${VALUE}"
            break
        fi

        # This was empty, try the next path
        shift
    done
}
