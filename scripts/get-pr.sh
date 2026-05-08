#!/bin/bash

set -e

# Used to approve git credentials for fetching commits from the base and head branches.
approve_git_creds() {
  local url="${1}" user="${2}" pass="$3"
  printf "%s\n" "url=${url}" "username=${user}" "password=${pass}" | git credential approve
}

# Generate comment header. @&ZeroWidthSpace to prevent @-mention notifications
printf "%s\n" "Triggered from $("${GITHUB_ACTION_PATH}"/scripts/github-event.sh .comment.html_url \
.pull_request.html_url) by [@&ZeroWidthSpace;${GITHUB_ACTOR}](https://github.com/$GITHUB_ACTOR)." \
>> "${GITHUB_STEP_SUMMARY}"

# Get the base branch name
BASE_REF=$("${GITHUB_ACTION_PATH}"/scripts/github-pull-request.sh .base.ref)

# Get the base branch SHA.
# If .git doesn't exist or branch is null, returns an empty string.
BASE_SHA="$( (test -d ".git" && git rev-parse "origin/${BASE_REF}" 2>/dev/null) || true)"

# Could not resolve the SHA, clone the repository
if [[ -z "${BASE_SHA}" ]]
then
  printf "::warning::Unable to resolve the base branch '%s' SHA. Cloning the repository to fetch it.\n" "${BASE_REF}" \
  >> "${GITHUB_STEP_SUMMARY}"

  CLONE_URL=$("${GITHUB_ACTION_PATH}"/scripts/github-pull-request.sh .base.repo.clone_url)
  approve_git_creds "${CLONE_URL}" "${GITHUB_ACTOR}" "${GITHUB_TOKEN}"

  # Inject credentials into clone URL
  CLONE_URL="${CLONE_URL%://*}://${GITHUB_ACTOR}@${CLONE_URL#*://}"

  # Clone only the base branch
  git clone --quiet --single-branch --branch "${BASE_REF}" "${CLONE_URL}" .

  # Get the base branch SHA
  BASE_SHA="$(git rev-parse origin/"${BASE_REF}" 2>/dev/null)"
fi

# Get the head branch ref and commit SHA
HEAD_REF=$("${GITHUB_ACTION_PATH}"/scripts/github-pull-request.sh .head.ref)
HEAD_SHA=$("${GITHUB_ACTION_PATH}"/scripts/github-pull-request.sh .head.sha)

# Check if we have the PR commit already.
# Required if we're in a fork.
if ! git cat-file -e "${HEAD_SHA}" 2>/dev/null
then
  printf "::warning::Unable to resolve the head commit '%s' SHA. Fetching it from the remote repository.\n" \
  "${HEAD_SHA}" >> "${GITHUB_STEP_SUMMARY}"

  # If PR is from a fork, fetch the fork's contents too
  CLONE_URL=$("${GITHUB_ACTION_PATH}"/scripts/github-pull-request.sh .head.repo.clone_url)
  approve_git_creds "${CLONE_URL}" "${GITHUB_ACTOR}" "${GITHUB_TOKEN}"

  # Inject credentials into clone URL
  CLONE_URL="${CLONE_URL%://*}://${GITHUB_ACTOR}@${CLONE_URL#*://}"

  # Fetch the PR commit
  git fetch --quiet "${CLONE_URL}" "${HEAD_SHA}"
fi

# Set environment variables
{
  printf "BASE_REF=%s\n" "${BASE_REF}"
  printf "BASE_SHA=%s\n" "${BASE_SHA}"
  printf "HEAD_REF=%s\n" "${HEAD_REF}"
  printf "HEAD_SHA=%s\n" "${HEAD_SHA}"
} >> "${GITHUB_ENV}"
