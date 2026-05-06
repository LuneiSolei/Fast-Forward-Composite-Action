#!/bin/bash

set -e

# Temp file for storing comment output information
COMMENT_FILE=$(mktemp)
{
  # Display dynamic message depending on if "auto merge" is enabled
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
} 2>&1 | tee -a "${GITHUB_STEP_SUMMARY}" "${LOG}"

if [[ "${IS_POSSIBLE}" == "false" ]]
then
  # Capture comment output for later step
  echo -n "Can't fast forward \`${BASE_REF}\` (${BASE_SHA}) to" >> "${COMMENT_FILE}"
  echo -n " \`${HEAD_REF}\` (${HEAD_SHA})." >> "${COMMENT_FILE}"
  echo -n " \`${BASE_REF}\` (${BASE_SHA}) is not a direct ancestor of" >> "${COMMENT_FILE}"
  echo -n " \`${HEAD_REF}\` (${HEAD_SHA})." >> "${COMMENT_FILE}"

  # Get where the branches diverged
  MERGE_BASE=$(git merge-base "${BASE_SHA}" "${HEAD_SHA}" || true)
  if [[ -z "${MERGE_BASE}" ]]
  then
    # No common ancestor
    echo " Branches don't appear to have a common ancestor." >> "${COMMENT_FILE}"
  else
    # Found divergence point
    echo " Branches appear to have diverged at ${MERGE_BASE}:" >> "${COMMENT_FILE}"
    echo "" >> "${COMMENT_FILE}"
    echo '```shell' >> "${COMMENT_FILE}"
  
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
      
    echo "" >> "${COMMENT_FILE}"
  
    # Display details of the divergence point
    git log --decorate=short -n 1 "${MERGE_BASE}" >> "${COMMENT_FILE}"
    echo '```' >> "${COMMENT_FILE}"
  fi
  echo "" >> "${COMMENT_FILE}"
  echo "Rebase locally, and then force push to \`${HEAD_REF}\`." >> "${COMMENT_FILE}"
elif [[ "${AUTO_MERGE}" == "false" ]]
then
  # Fast-forwarding is possible, but "auto merge" is disabled

elif [[ "${HAS_PERMS}" == "false" ]]
then
  # User does not have permission to push
  echo -n "Sorry @$(${GITHUB_ACTION_PATH}/scripts/github-event.sh .sender.login),"
  echo -n " it is possible to fast forward \`${BASE_REF}\` (${BASE_SHA})"
  echo -n " to \`${HEAD_REF}\` (${HEAD_SHA}), but you don't appear to have"
  echo " permission to push to this repository."
elif [[ -n "${MERGE_COMMAND}" ]]
then
  echo -n "It is possible to fast forward \`${BASE_REF}\` (${BASE_SHA})"
  echo -n " to \`${HEAD_REF}\` (${HEAD_SHA}). If you have write access to the"
  echo -n " target repository, you can add a comment with"
  echo -n " \`/fast-forward\` to fast forward \`${BASE_REF}\` to"
  echo " \`${HEAD_REF}\`."
  echo "EXIT_CODE=0" >> ${GITHUB_ENV}
fi

COMMENT_CONTENT=$(mktemp)
# Write to GitHub output
{
  echo "comment-body<<EOF"
  cat "${COMMENT_FILE}"
  echo ""
  cat "${PUSH_LOG}"
  echo "EOF"
} >> "${COMMENT_CONTENT}"

# Determine whether to post the comment based on the setting
if [ "${COMMENT}" = "always" ] || [ "${COMMENT}" = "on-error" -a "$(cat ${EXIT_CODE})" -ne 0 ]
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
      echo "::error::Can't post a comment: github.event.pull_request.comments_url is not set." | tee -a ${GITHUB_STEP_SUMMARY}
  fi
else
    echo "Not posting comment."
fi
