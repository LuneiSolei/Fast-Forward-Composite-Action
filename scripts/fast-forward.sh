#!/bin/bash

set -e

EXIT_CODE=$(mktemp)
echo 1 >${EXIT_CODE}

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
  COMMENTS_URL="$(${GITHUB_ACTION_PATH}/scripts/github-pull-request.sh .comments_url)"
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
