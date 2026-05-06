#!/bin/bash

set -e

# Temp file for storing comment output information
COMMENT_FILE=$(mktemp)
{
  # Display dynamic message depending on if "auto merge" is enabled
  case "${AUTO_MERGE}" in
    "true")
      printf 'Trying to '
      ;;
    "false")
      printf 'Checking if we can '
      ;;
  esac
  
  printf 'fast forward `%s` (%s) to `%s` (%s).\n\n' "${BASE_REF}" "${BASE_SHA}" "${HEAD_REF}" "${HEAD_SHA}"
  
  # Show the current state of the target branch
  printf 'Target branch (`%s`):\n\n' "${BASE_REF}"
  printf '```shell\n'
  git log --decorate=short -n 1 "${BASE_SHA}"
  printf '```\n\n'
  
  # Show the current state of the head branch
  printf 'Pull request (`%s`):\n\n' "${HEAD_REF}"
  printf '```shell\n'
  git log --decorate=short -n 1 "${HEAD_SHA}"
  printf '```\n'
} 2>&1 | tee -a "${GITHUB_STEP_SUMMARY}"

if [[ "${IS_POSSIBLE}" == "false" ]]
then
  # Capture comment output for later step
  printf 'Can\'t fast forward `%s` (%s) to `%s` (%s). ' "${BASE_REF}" "${BASE_SHA}" "${HEAD_REF}" "${HEAD_SHA}" >> "${COMMENT_FILE}"
  printf '`%s` (%s) is not a direct ancestor of `%s` (%s). ' "${BASE_REF}" "${BASE_SHA}" "${HEAD_REF}" "${HEAD_SHA}" >> "${COMMENT_FILE}"

  # Get where the branches diverged
  MERGE_BASE=$(git merge-base "${BASE_SHA}" "${HEAD_SHA}" || true)
  if [[ -z "${MERGE_BASE}" ]]
  then
    # No common ancestor
    printf 'Branches don\'t appear to have a common ancestor.' >> "${COMMENT_FILE}"
  else
    # Found divergence point
    printf 'Branches appear to have diverged at %s\n\n' "${MERGE_BASE}" >> "${COMMENT_FILE}"
    printf '```shell\n' >> "${COMMENT_FILE}"
  
    # If ${MERGE_BASE} is a root (has no parent), then it is not a valid reference
    if git cat-file -t "${MERGE_BASE}^" &>/dev/null
    then
      # Exclude commits before the merge base from the graph
      EXCLUDE="^${MERGE_BASE}^"
    else
      # Merge base is a root commit, don't exclude anything
      EXCLUDE=
    fi
  
    # Display graph of diverged branches
    git log --pretty=oneline --graph ${EXCLUDE} "${BASE_SHA}" "${HEAD_SHA}" >> "${COMMENT_FILE}"
      
    printf '\n' >> "${COMMENT_FILE}"
  
    # Display details of the divergence point
    git log --decorate=short -n 1 "${MERGE_BASE}" >> "${COMMENT_FILE}"
    printf '```\n' >> "${COMMENT_FILE}"
  fi
  printf '\n' >> "${COMMENT_FILE}"
  printf 'Rebase locally and then force push to `%s`.\n' "${HEAD_REF}" >> "${COMMENT_FILE}"
elif [[ "${AUTO_MERGE}" == "false" ]]
then
  # Fast-forwarding is possible, but "auto merge" is disabled
  printf 'It is possible to fast forward `%s` (%s) to `%s` (%s), ' "${BASE_REF}" "${BASE_SHA}" "${HEAD_REF}" "${HEAD_SHA}" >> "${COMMENT_FILE}"
  printf 'but \'auto_merge\' has been disabled.\N' >> "${COMMENT_FILE}"
  
  echo "EXIT_CODE=0" >> ${GITHUB_ENV}
elif [[ "${HAS_PERMS}" == "false" ]]
then
  # User does not have permission to push
  printf 'Sorry, @%s' "$(${GITHUB_ACTION_PATH}/scripts/github-event.sh .sender.login), " >> "${COMMENT_FILE}"
  printf 'it is possible to fast forward `%s` (%s) to ' "${BASE_REF}" "${BASE_SHA}"
  printf '`%s` (%s), but you don\'t appear to have ' "${HEAD_REF}" "${HEAD_SHA}" >> "${COMMENT_FILE}"
  printf 'permission to push to this repository.\N' >> "${COMMENT_FILE}"
  
  echo "EXIT_CODE=0" >> ${GITHUB_ENV}
elif [[ -n "${MERGE_COMMAND}" ]]
then
  printf 'It is possible to fast forward `%s` (%s) ' "${BASE_REF}" "${BASE_SHA}" >> "${COMMENT_FILE}"
  printf 'to `%s` (%s). If you have write access to the ' "${HEAD_REF}" "${HEAD_SHA}" >> "${COMMENT_FILE}"
  printf 'target repository, you can add the comment `/fastforward` to fast forward ' >> "${COMMENT_FILE}" 
  printf '`%s` to `%s`.\n' "${BASE_REF}" "${HEAD_REF}" >> "${COMMENT_FILE}"
  
  echo "EXIT_CODE=0" >> ${GITHUB_ENV}
fi

COMMENT_CONTENT=$(mktemp)
# Write to GitHub output
{
  printf 'comment-body<<EOF'
  cat "${COMMENT_FILE}"
  printf '\n'
  cat "${PUSH_LOG}"
  printf '\n'
} >> "${COMMENT_CONTENT}"

# Determine whether to post the comment based on the setting
if [ "${COMMENT}" = "always" ] || [ "${COMMENT}" = "on-error" -a "$(cat ${EXIT_CODE})" -ne 0 ]
then
  # Post the comment.
  COMMENTS_URL="$(${GITHUB_ACTION_PATH}/scripts/github-pull-request.sh .comments_url)"
  if [ -n "${COMMENTS_URL}" ]
  then
    printf 'Posting comment to %s.' "${COMMENTS_URL}"
    curl --silent --show-error --location --globoff \
      -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "X-GitHub-Api-Version: 2026-03-10" \
      "${COMMENTS_URL}" \
      -d "@${COMMENT_CONTENT}"
  else
      printf '::error::Can\'t post a comment: github.event.pull_request.comments_url is not set.' | tee -a ${GITHUB_STEP_SUMMARY}
  fi
else
    echo "Not posting comment."
fi
