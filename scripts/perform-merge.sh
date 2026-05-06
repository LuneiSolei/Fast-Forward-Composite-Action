#!/bin/bash

set -e

PUSH_LOG=$(mktemp)
if [[ "${HAS_PERMS}" == "true" ]] && [[ "${IS_POSSIBLE}" == "true" ]] && [[ "${AUTO_MERGE}" == "true" ]]
then
  {
    echo -n "Fast Forwarding \`${BASE_REF}\` (${BASE_SHA}) to"
    echo " \`${HEAD_REF}\` (${HEAD_SHA})."
  
    echo '```shell'
    (
      # Show the git command in the output
      PS4='$ '
      set -x
  
      # Push the commit directly to the base branch.
      # This fast-forwards BASE_REF to point to HEAD_SHA
      git push origin "${HEAD_SHA}:${BASE_REF}"
    )
    echo '```'
  } 2>&1 | tee "${PUSH_LOG}"
fi

# Write to GitHub output
{
  echo "push-output<<EOF"
  cat "${PUSH_LOG}"
  echo "EOF"
} >> "${GITHUB_OUTPUT}"
