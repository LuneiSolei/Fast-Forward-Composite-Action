#! /bin/bash

set -e

# Generate comment header. @&ZeroWidthSpace to prevent @-mention notifications
echo "Triggered from $(${GITHUB_ACTION_PATH}/scripts/github-event.sh .comment.html_url .pull_request.html_url) by [@&ZeroWidthSpace;${GITHUB_ACTOR}](https://github.com/$GITHUB_ACTOR)." >> ${GITHUB_STEP_SUMMARY}

# Get the base branch name
BASE_REF=$(${GITHUB_ACTION_PATH}/scripts/github-pull-request.sh .base.ref)
echo "base-ref=${BASE_REF}" >> ${GITHUB_OUTPUT}

# Get the base branch SHA. 
# If .git doesn't exist or branch is null, returns an empty string.
BASE_SHA="$(test -d .git && git rev-parse origin/$BASE_REF 2>/dev/null || true)"
echo "base-sha=${BASE_SHA}" >> ${GITHUB_OUTPUT}

# Could not resolve the SHA, clone the repository
if [[ -z "${BASE_SHA}" ]]
then
  CLONE_URL=$(${GITHUB_ACTION_PATH}/scripts/github-pull-request.sh .base.repo.clone_url)

  # Configure git credential helper to store credentials
  git config --global credential.helper store
  {
    echo "url=${CLONE_URL}"
    echo "username=${GITHUB_ACTOR}"
    echo "password=${GITHUB_TOKEN}"
  } | git credential approve

  # Inject credentials into clone URL
  CLONE_URL="${CLONE_URL%://*}://${GITHUB_ACTOR}@${CLONE_URL#*://}"

  # Clone only the base branch
  git clone --quiet --single-branch --branch "${BASE_REF}" "${CLONE_URL}" .

  # Get the base branch SHA
  BASE_SHA="$(git rev-parse origin/${BASE_REF} 2>/dev/null)"
fi

# Get the head branch ref and commit SHA
HEAD_REF=$(${GITHUB_ACTION_PATH}/scripts/github-pull-request.sh .head.ref)
echo "head-ref=${HEAD_REF}" >> ${GITHUB_OUTPUT}

HEAD_SHA=$(${GITHUB_ACTION_PATH}/scripts/github-pull-request.sh .head.sha)
echo "head-sha=${HEAD_SHA}" >> ${GITHUB_OUTPUT}

# Check if we have the PR commit already.
# Required if we're in a fork.
if ! git cat-file -e "${HEAD_SHA}" 2>/dev/null
then
  # If PR is from a fork, fetch the fork's contents too
  CLONE_URL=$(${GITHUB_ACTION_PATH}/scripts/github-pull-request.sh .head.repo.clone_url)

  # Set up credentials again, but this time for the fork
  git config --global credential.helper store
  {
    echo "url=${CLONE_URL}"
    echo "username=${GITHUB_ACTOR}"
    echo "password=${GITHUB_TOKEN}"
  } | git credential approve

  # Inject credentials into clone URL
  CLONE_URL="${CLONE_URL%://*}://${GITHUB_ACTOR}@${CLONE_URL#*://}"

  # Fetch the PR commit
  git fetch --quiet "${CLONE_URL}" "${HEAD_SHA}"
fi
