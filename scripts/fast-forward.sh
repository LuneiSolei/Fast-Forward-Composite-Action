#! /bin/bash

set -e

# Ensure DEBUG value is valid
case "${DEBUG:-true}" in
    false) DEBUG=0;;
    true) DEBUG=1;;
    *)
        echo "Warning: Invalid value '$DEBUG' for DEBUG. Using default value 'true'." >&2;
        DEBUG=1
        ;;
esac

# Ensure COMMENT value is valid
case "${COMMENT:-always}" in
    never) COMMENT=never;;
    always) COMMENT=always;;
    on-error) COMMENT=on-error;;
    *)
        echo "Warning: Invalid value '$COMMENT' for COMMENT. Using default value 'always'" >&2;
        COMMENT=on-error
        ;;
esac

# Ensure we're running via GitHub Actions
if [ -z "${GITHUB_EVENT_PATH:-}" ]
then
    echo "GITHUB_EVENT_PATH environment variable must be set."
fi

# Do some logging if DEBUG is enabled
if [ "${DEBUG}" -eq 1 ]
then
    {
        echo env
        env
        echo GITHUB_ENV: ${GITHUB_ENV}
        cat ${GITHUB_ENV}
        echo GITHUB_EVENT_PATH: ${GITHUB_EVENT_PATH}
        cat ${GITHUB_EVENT_PATH}
    } >&2
fi

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

GITHUB_PR=$(mktemp)
function github_pull_request {
    PR_URL="$(github_event .issue.pull_request.url .pull_request.url)"
    if [ -z "${PR_URL}" ] || [ "${PR_URL}" = "null" ]
    then
        echo "Unable to find pull request's context." >&2
        exit 1
    fi
    
    curl --silent --show-error --location --globoff \
    -X GET \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: 2026-03-10" \
    "${PR_URL}" >${GITHUB_PR}

    if [ "${DEBUG}" -gt 0 ]
    then
        {
            echo "pull_request (${GITHUB_PR}):"
            cat "${GITHUB_PR}"
        } >&2
    fi

    while [ "$#" -gt 0 ]
    do
        VALUE=$(jq -r "$1" <${GITHUB_PR})
        if [ -n "${VALUE}" ] && [ "${VALUE}" != null]
        then
            echo "${VALUE}"
            break
        fi

        shift
    done
}

EXIT_CODE=$(mktemp)
echo 1 >${EXIT_CODE}

LOG=$(mktemp)
{
    echo "Triggered from $(github_event .comment.html_url .pull_request.html_url) by [@&ZeroWidthSpace;${GITHUB_ACTOR}](https://github.com/$GITHUB_ACTOR)."
    echo

    # Symbolic name
    BASE_REF=$(github_pull_request .base.ref)

    # Update sha
    BASE_SHA="$(test -d .git && git rev-parse origin/$BASE_REF 2>/dev/null || true)"
    if [ -z "${BASE_SHA}" ]
    then
        CLONE_URL=$(github_pull_request .base.repo.clone_url)
        git config --global credential.helper store
        {
            echo "url=${CLONE_URL}"
            echo "username=${GITHUB_ACTOR}"
            echo "password=${GITHUB_TOKEN}"
        } | git credential approve

        CLONE_URL="${CLONE_URL%://*}://${GITHUB_ACTOR}@${CLONE_URL#*://}"
        git clone --quiet --single-branch --branch "${BASE_REF}" "${CLONE_URL}" .

        BASE_SHA="$(git rev-parse origin/${BASE_REF} 2>/dev/null)"
    fi

    PR_REF=$(github_pull_request .head.ref)
    PR_SHA=$(github_pull_request .head.sha)

    if ! git cat-file -e "${PR_SHA}" 2>/dev/null
    then
        # If PR is from a fork, fetch the fork's contents too
        CLONE_URL=$(github_pull_request .head.repo.clone_url)
        git config --global credential.helper store
        {
            echo "url=${CLONE_URL}"
            echo "username=${GITHUB_ACTOR}"
            echo "password=${GITHUB_TOKEN}"
        } | git credential approve

        CLONE_URL="${CLONE_URL%://*}://${GITHUB_ACTOR}@${CLONE_URL#*://}"
        git fetch --quiet "${CLONE_URL}" "${PR_SHA}"
    fi

    git branch -f "pull_request/${PR_REF}" "${PR_SHA}"
    if [ "${1}" = "--merge" ]
    then
        echo -n "Trying to "
    else
        echo -n "Checking if we can "
    fi
    echo " fast forward \`${BASE_REF}\` (${BASE_SHA}) to \`${PR_REF}\` (${PR_SHA})."
    echo
    echo "Target branch (\`${BASE_REF}\`):"
    echo
    echo '```shell'
    
    git log --decorate=short -n 1 "${BASE_SHA}"

    echo '```'
    echo
    echo "Pull request (\`${PR_REF}\`):"
    echo
    echo '```shell'

    git log --decorate=short -n 1 "${PR_SHA}"

    echo '```'
    if ! git merge-base --is-ancestor "${BASE_REF}" "${PR_SHA}"
    then
        # PR needs to be rebased.
        echo -n "Can't fast forward \`${BASE_REF}\` (${BASE_SHA}) to"
        echo -n " \`${PR_REF}\` (${PR_SHA})."
        echo -n " \`${BASE_REF}\` (${BASE_SHA}) is not a direct ancestor of"
        echo -n " \`${PR_REF}\` (${PR_SHA})."

        MERGE_BASE=$(git merge-base "${BASE_SHA}" "${PR_SHA}" || true)
        if [ -z "${MERGE_BASE}" ]
        then
            echo " Branches don't appear to have a common ancestor."
        else
            echo " Branches appear to have diverged at ${MERGE_BASE}:"
            echo
            echo '```shell'

            # If ${MERGE_BASE} is a root (has no parents), then it is not a valid reference
            if [ "$(git cat-file -t "${MERGE_BASE}^")" = "commit" ]
            then
                EXCLUDE="^${MERGE_BASE}^"
            else
                EXCLUDE=
            fi

            git log --pretty=oneline --graph \
                ${EXCLUDE} "${BASE_SHA}" "${PR_SHA}"
            echo
            git log --decorate=short -n 1 "${MERGE_BASE}"
            echo '```'
        fi
        echo
        echo "Rebase locally, and then force push to \`${PR_REF}\`."
    elif [ "${1}" = "--merge" ]
    then
        # Check that user is allowed and fast forward the target branch
        COLLABORATORS_URL="$(github_event .repository.collaborators_url)"
        COLLABORATORS_URL="${COLLABORATORS_URL}%\{/collaborator\}"

        PERM=$(mktemp)
        curl --silent --show-error -o "${PERM}" --location --globoff \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H "X-GitHub-Api-Version: 2026-03-10" \
            "${COLLABORATORS_URL}/$(github_event .sender.login)/permission"
        if [ "$(jq -r .user.permissions.push < ${PERM})" = "true" ]
        then
            echo -n "Fast Forwarding \`${BASE_REF}\` (${BASE_SHA}) to"
            echo " \`${PR_REF}\` (${PR_SHA})."

            echo '```shell'
            (
                PS4='$ '
                set -x
                git push origin "${PR_SHA}:${BASE_REF}"
            )
            echo '```'
            echo 0 >${EXIT_CODE}
        else
            echo -n "Sorry @$(github_event .sender.login),"
            echo -n " it is possible to fast forward \`${BASE_REF}\` (${BASE_SHA})"
            echo -n " to \`${PR_REF}\` (${PR_SHA}), but you don't appear to have"
            echo " permission to push to this repository."
        fi
    else
        # We're just checking if fast forwarding is possible
        echo -n "It is possible to fast forward \`${BASE_REF}\` (${BASE_SHA})"
        echo -n " to \`${PR_REF}\` (${PR_SHA}). If you have write access to the"
        echo -n " target repository, you can add a comment with"
        echo -n " \`/fast-forward\` to fast forward \`${BASE_REF}\` to"
        echo " \`${PR_REF}\`."
        echo 0 >${EXIT_CODE}
    fi
} 2>&1 | tee -a ${GITHUB_STEP_SUMMARY} "${LOG}"

COMMENT_CONTENT=$(mktemp)
jq -n --rawfile log "$LOG" '{ "body": $log }' >"${COMMENT_CONTENT}"

# Set the comment output variable
{
    echo "comment<<EOF_${COMMENT_CONTENT}"
    cat "${COMMENT_CONTENT}"
    echo "EOF_${COMMENT_CONTENT}"
} | tee -a "${GITHUB_OUTPUT}"

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
