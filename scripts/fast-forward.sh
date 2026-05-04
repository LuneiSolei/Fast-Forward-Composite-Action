#!/bin/bash

set -e

EXIT_CODE=$(mktemp)
echo 1 >${EXIT_CODE}

# Create a temporary file to capture output for later use as a comment.
# Everything inside the braces is captured to both the GitHub step summary
# and the LOG file via "tee" at the end.
LOG=$(mktemp)
{
  # Get PR data
  ./get-pr.sh
  
  # Create a local branch reference for the PR
  git branch -f "pull_request/${HEAD_REF}" "${HEAD_SHA}"

  # Display dynamic message depending on if "merge" is enabled
  case "${AUTO_MERGE}" in
    "true")
      echo -n "Trying to "
      ;;
    "false")
      echo -n "Checking if we can "
      ;;
  esac
  
  echo "fast forward \`${BASE_REF}\` (${BASE_SHA}) to \`${HEAD_REF}\` (${HEAD_SHA})."
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
    ./show-not-possible.sh

  elif [[ "${AUTO_MERGE}" == "true" ]]
  then
    ./show-is-possible.sh
  fi
} 2>&1 | tee -a "${GITHUB_STEP_SUMMARY}" "${LOG}"

COMMENT_CONTENT=$(mktemp)
jq -n --rawfile log "$LOG" '{ "body": $log }' >"${COMMENT_CONTENT}"

# Export the comment as a GitHub Actions output variable.
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
  COMMENTS_URL="$(./github-pull-request.sh .comments_url)"
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
