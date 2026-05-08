#!/bin/bash

set -e

REPO_OWNER="$("${GITHUB_ACTION_PATH}"/scripts/github-event.sh .repository.owner.login)"
USERNAME="$("${GITHUB_ACTION_PATH}"/scripts/github-event.sh .sender.login)"

# Check if user is owner or has collaborator access
if [[ "${REPO_OWNER}" == "${USERNAME}" ]]
then
  # User is the repository owner, they have permissions to push
  HAS_PERMS=true
else
  # Build URL used to check for permissions
  COLLABORATORS_URL="$("${GITHUB_ACTION_PATH}"/scripts/github-event.sh .repository.collaborators_url)"
  COLLABORATORS_URL="${COLLABORATORS_URL/\{\/collaborator\}/}/${USERNAME}"
fi



# Fetch the user's permissions from GitHub API
PERM=$(mktemp)
curl --silent --show-error -o "${PERM}" --location --globoff \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2026-03-10" \
  "${COLLABORATORS_URL}"

echo "${COLLABORATORS_URL}"

# Output push permissions state
printf "HAS_PERMS=%s\n" "$(jq -r '(.user.permissions.maintain // false) or (.user.permissions.admin // false)' < "${PERM}")" >> "${GITHUB_ENV}"

# Verify if fast forwarding is possible
# Create a local branch reference for the PR
git branch -f "pull_request/${HEAD_REF}" "${HEAD_SHA}"

# Check if the base branch is a direct ancestor of the head branch
IS_POSSIBLE=$(git merge-base --is-ancestor "${BASE_REF}" "${HEAD_SHA}" && echo true || echo false)
printf "IS_POSSIBLE=%s\n" "${IS_POSSIBLE}" >> "${GITHUB_ENV}"

printf "User has permission to push to target branch: %s\n" "${HAS_PERMS}" >> "${GITHUB_STEP_SUMMARY}"
printf "Fast forwarding is possible: %s\n" "${IS_POSSIBLE}" >> "${GITHUB_STEP_SUMMARY}"