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

EXIT_CODE=$(mktemp)
echo 1 >${EXIT_CODE}

# Create a temporary file to capture output for later use as a comment.
# Everything inside the braces is captured to both the GitHub step summary
# and the LOG file via "tee" at the end.
LOG=$(mktemp)
{
    # Generate comment header. @&ZeroWidthSpace to prevent @-mention notifications
    echo "Triggered from $(github_event .comment.html_url .pull_request.html_url) by [@&ZeroWidthSpace;${GITHUB_ACTOR}](https://github.com/$GITHUB_ACTOR)."
    echo

    # Get the base branch name
    BASE_REF=$(github_pull_request .base.ref)

    # Get the base branch SHA. 
    # If .git doesn't exist or branch is null, returns an empty string.
    BASE_SHA="$(test -d .git && git rev-parse origin/$BASE_REF 2>/dev/null || true)"

    # Could not resolve the SHA, clone the repository
    if [ -z "${BASE_SHA}" ]
    then
        CLONE_URL=$(github_pull_request .base.repo.clone_url)

        # Configure git credential helper to store credentials
        git config --global credential.helper store
        {
            echo "url=${CLONE_URL}"
            echo "username=${GITHUB_ACTOR}"
            echo "password=${GITHUB_TOKEN}"
        } | git credential approve

        # Inject credentials into clone URL
        CLONE_URL="${CLONE_URL%://*}://${GITHUB_ACTOR}@${CLONE_URL#*://}"

        # Clone only the base branch
        git clone --quiet --single-branch --branch "${BASE_REF}" "${CLONE_URL}" .

        # Get the base branch SHA
        BASE_SHA="$(git rev-parse origin/${BASE_REF} 2>/dev/null)"
    fi

    # Get the head branch ref and commit SHA
    HEAD_REF=$(github_pull_request .head.ref)
    HEAD_SHA=$(github_pull_request .head.sha)

    # Check if we have the PR commit already.
    # Required if we're in a fork.
    if ! git cat-file -e "${HEAD_SHA}" 2>/dev/null
    then
        # If PR is from a fork, fetch the fork's contents too
        CLONE_URL=$(github_pull_request .head.repo.clone_url)

        # Set up credentials again, but this time for the fork
        git config --global credential.helper store
        {
            echo "url=${CLONE_URL}"
            echo "username=${GITHUB_ACTOR}"
            echo "password=${GITHUB_TOKEN}"
        } | git credential approve

        # Inject credentials into clone URL
        CLONE_URL="${CLONE_URL%://*}://${GITHUB_ACTOR}@${CLONE_URL#*://}"

        # Fetch the PR commit
        git fetch --quiet "${CLONE_URL}" "${HEAD_SHA}"
    fi

    # Create a local branch reference for the PR
    git branch -f "pull_request/${HEAD_REF}" "${HEAD_SHA}"

    # Display dynamic message depending on if "merge" is enabled
    if [ "${1}" = "--merge" ]
    then
        echo -n "Trying to "
    else
        echo -n "Checking if we can "
    fi
    echo " fast forward \`${BASE_REF}\` (${BASE_SHA}) to \`${HEAD_REF}\` (${HEAD_SHA})."
    echo

    # Show the current state of the target branch
    echo "Target branch (\`${BASE_REF}\`):"
    echo
    echo '```shell'
    git log --decorate=short -n 1 "${BASE_SHA}"
    echo '```'
    echo

    # Show the current state of the head branch
    echo "Pull request (\`${HEAD_REF}\`):"
    echo
    echo '```shell'
    git log --decorate=short -n 1 "${HEAD_SHA}"
    echo '```'

    # Check if the base branch is a direct ancestor of the head branch
    if ! git merge-base --is-ancestor "${BASE_REF}" "${HEAD_SHA}"
    then
        # Fast-forward not possible
        echo -n "Can't fast forward \`${BASE_REF}\` (${BASE_SHA}) to"
        echo -n " \`${HEAD_REF}\` (${HEAD_SHA})."
        echo -n " \`${BASE_REF}\` (${BASE_SHA}) is not a direct ancestor of"
        echo -n " \`${HEAD_REF}\` (${HEAD_SHA})."

        # Get where the branches diverged
        MERGE_BASE=$(git merge-base "${BASE_SHA}" "${HEAD_SHA}" || true)
        if [ -z "${MERGE_BASE}" ]
        then
            # No common ancestor
            echo " Branches don't appear to have a common ancestor."
        else
            # Found divergence point
            echo " Branches appear to have diverged at ${MERGE_BASE}:"
            echo
            echo '```shell'

            # If ${MERGE_BASE} is a root (has no parent), then it is not a valid reference
            if [ "$(git cat-file -t "${MERGE_BASE}^")" = "commit" ]
            then
                # Exclude commits before the merge base from the graph
                EXCLUDE="^${MERGE_BASE}^"
            else
                # Merge base is a root commit, don't exclude anything
                EXCLUDE=
            fi

            # Display graph of diverged branches
            git log --pretty=oneline --graph \
                ${EXCLUDE} "${BASE_SHA}" "${HEAD_SHA}"
            echo

            # Display details of the divergence point
            git log --decorate=short -n 1 "${MERGE_BASE}"
            echo '```'
        fi
        echo
        echo "Rebase locally, and then force push to \`${HEAD_REF}\`."
    elif [ "${1}" = "--merge" ]
    then
        # Fast-forward is possible and "merge" is enabled.
        # Check that user has permission to push to the repository.
        COLLABORATORS_URL="$(github_event .repository.collaborators_url)"

        # Build URL used to check for permissions
        COLLABORATORS_URL="${COLLABORATORS_URL}%\{/collaborator\}"

        # Fetch the user's permissions from GitHub API
        PERM=$(mktemp)
        curl --silent --show-error -o "${PERM}" --location --globoff \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H "X-GitHub-Api-Version: 2026-03-10" \
            "${COLLABORATORS_URL}/$(github_event .sender.login)/permission"

        # Check if user has permission
        if [ "$(jq -r .user.permissions.push < ${PERM})" = "true" ]
        then
            # User has permission
            echo -n "Fast Forwarding \`${BASE_REF}\` (${BASE_SHA}) to"
            echo " \`${HEAD_REF}\` (${HEAD_SHA})."

            echo '```shell'
            (
                # Show the git command in the output
                PS4='$ '
                set -x

                # Push the commit directly to the base branch.
                # This fast-forwards BASE_REF to point to HEAD_SHA
                git push origin "${HEAD_SHA}:${BASE_REF}"
            )
            echo '```'
            echo 0 >${EXIT_CODE}
        else
            # User does not have permission to push
            echo -n "Sorry @$(github_event .sender.login),"
            echo -n " it is possible to fast forward \`${BASE_REF}\` (${BASE_SHA})"
            echo -n " to \`${HEAD_REF}\` (${HEAD_SHA}), but you don't appear to have"
            echo " permission to push to this repository."
        fi
    else
        # Fast-forwarding is possible, but "merge" is disabled
        echo -n "It is possible to fast forward \`${BASE_REF}\` (${BASE_SHA})"
        echo -n " to \`${HEAD_REF}\` (${HEAD_SHA}). If you have write access to the"
        echo -n " target repository, you can add a comment with"
        echo -n " \`/fast-forward\` to fast forward \`${BASE_REF}\` to"
        echo " \`${HEAD_REF}\`."
        echo 0 >${EXIT_CODE}
    fi
} 2>&1 | tee -a ${GITHUB_STEP_SUMMARY} "${LOG}"

COMMENT_CONTENT=$(mktemp)
jq -n --rawfile log "$LOG" '{ "body": $log }' >"${COMMENT_CONTENT}"

# Export the comment as a GitHub Actions output variable.
# Made available via ${{ steps.step-id.outputs.comment }} as an example.
{
    echo "comment<<EOF_${COMMENT_CONTENT}"
    cat "${COMMENT_CONTENT}"
    echo "EOF_${COMMENT_CONTENT}"
} | tee -a "${GITHUB_OUTPUT}"

# Determine whether to post the comment based on the setting
if [ "${COMMENT}" = "always" ] \
    || [ "${COMMENT}" = "on-error" -a "$(cat ${EXIT_CODE})" -ne 0 ]
then
    # Post the comment.
    COMMENTS_URL="$(github_pull_request .comments_url)"
    if [ -n "${COMMENTS_URL}" ]
    then
        echo "Posting comment to ${COMMENTS_URL}."
        curl --silent --show-error --location --globoff \
            -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H "X-GitHub-Api-Version: 2026-03-10" \
            "${COMMENTS_URL}" \
            -d "@${COMMENT_CONTENT}"
    else
        echo "Can't post a comment: github.event.pull_request.comments_url is not set." | tee -a ${GITHUB_STEP_SUMMARY}
    fi
else
    echo "Not posting comment."
fi

exit $(cat ${EXIT_CODE})
