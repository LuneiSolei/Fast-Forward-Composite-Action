#!/bin/bash

set -e

# Create a temporary file to capture output for later use as a comment.
# Everything inside the braces is captured to both the GitHub step summary
# and the LOG file via "tee" at the end.
LOG=$(mktemp)
{
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
} 2>&1 | tee -a "${GITHUB_STEP_SUMMARY}" "${LOG}"
