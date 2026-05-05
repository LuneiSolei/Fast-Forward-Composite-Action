#!/bin/bash

set -e

# Fast-forward is possible and "merge" is enabled.
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
