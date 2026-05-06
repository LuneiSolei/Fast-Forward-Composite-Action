#!/bin/bash

set -e

# Check that user has permission to push to the repository.
COLLABORATORS_URL="$(${GITHUB_ACTION_PATH}/scripts/github-event.sh .repository.collaborators_url)"

# Build URL used to check for permissions
COLLABORATORS_URL="${COLLABORATORS_URL}%\{/collaborator\}"

# Fetch the user's permissions from GitHub API
PERM=$(mktemp)
curl --silent --show-error -o "${PERM}" --location --globoff \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2026-03-10" \
  "${COLLABORATORS_URL}/$(${GITHUB_ACTION_PATH}/scripts/github-event.sh .sender.login)/permission"

# Output push permissions state
printf 'HAS_PERMS=%s\n' "$(jq -r .user.permissions.push < ${PERM})" >> "${GITHUB_ENV}"

# Verify if fast forwarding is possible
# Create a local branch reference for the PR
git branch -f "pull_request/${HEAD_REF}" "${HEAD_SHA}"

# Check if the base branch is a direct ancestor of the head branch
IS_POSSIBLE=! git merge-base --is-ancestor "${BASE_REF}" "${HEAD_SHA}"
printf 'IS_POSSIBLE=%s\n' "${IS_POSSIBLE}" >> "${GITHUB_ENV}"
