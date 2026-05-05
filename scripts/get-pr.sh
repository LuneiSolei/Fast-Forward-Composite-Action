#!/bin/bash

set -e

approve_git_creds() {
  local url="${1}" user="${2}" pass="$3"
  printf '%s\n' "url=${url}" "username=${user}" "password=${pass}" | git credential approve
}

# Generate comment header. @&ZeroWidthSpace to prevent @-mention notifications
printf '%s\n' "Triggered from $(${GITHUB_ACTION_PATH}/scripts/github-event.sh .comment.html_url \
.pull_request.html_url) by [@&ZeroWidthSpace;${GITHUB_ACTOR}](https://github.com/$GITHUB_ACTOR)." \
>> "${GITHUB_STEP_SUMMARY}"

echo "WE'RE HERE"

# Get the base branch name
BASE_REF=$(${GITHUB_ACTION_PATH}/scripts/github-pull-request.sh .base.ref)
printf 'base-ref=%s\n' "${BASE_REF}" >> "${GITHUB_OUTPUT}"

# Get the base branch SHA. 
# If .git doesn't exist or branch is null, returns an empty string.
BASE_SHA="$(test -d .git && git rev-parse origin/${BASE_REF} 2>/dev/null || true)"
printf 'base-sha=%s\n' "${BASE_SHA}" >> "${GITHUB_OUTPUT}"

# Could not resolve the SHA, clone the repository
if [[ -z "${BASE_SHA}" ]]
then
  CLONE_URL=$(${GITHUB_ACTION_PATH}/scripts/github-pull-request.sh .base.repo.clone_url)
  approve_git_creds "${CLONE_URL}" "${GITHUB_ACTOR}" "${GITHUB_TOKEN}"

  # Inject credentials into clone URL
  CLONE_URL="${CLONE_URL%://*}://${GITHUB_ACTOR}@${CLONE_URL#*://}"

  # Clone only the base branch
  git clone --quiet --single-branch --branch "${BASE_REF}" "${CLONE_URL}" .

  # Get the base branch SHA
  BASE_SHA="$(git rev-parse origin/${BASE_REF} 2>/dev/null)"
fi

# Get the head branch ref and commit SHA
HEAD_REF=$(${GITHUB_ACTION_PATH}/scripts/github-pull-request.sh .head.ref)
printf 'head-ref=%s\n' "${HEAD_REF}" >> "${GITHUB_OUTPUT}"

HEAD_SHA=$(${GITHUB_ACTION_PATH}/scripts/github-pull-request.sh .head.sha)
printf 'head-sha=%s\n' "${HEAD_SHA}" >> "${GITHUB_OUTPUT}"

# Check if we have the PR commit already.
# Required if we're in a fork.
if ! git cat-file -e "${HEAD_SHA}" 2>/dev/null
then
  # If PR is from a fork, fetch the fork's contents too
  CLONE_URL=$(${GITHUB_ACTION_PATH}/scripts/github-pull-request.sh .head.repo.clone_url)
  approve_git_creds "${CLONE_URL}" "${GITHUB_ACTOR}" "${GITHUB_TOKEN}"

  # Inject credentials into clone URL
  CLONE_URL="${CLONE_URL%://*}://${GITHUB_ACTOR}@${CLONE_URL#*://}"

  # Fetch the PR commit
  git fetch --quiet "${CLONE_URL}" "${HEAD_SHA}"
fi
