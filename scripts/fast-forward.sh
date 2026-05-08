#!/bin/bash

set -e

PUSH_LOG=$(mktemp)
if [[ "${HAS_PERMS}" == "true" ]] && [[ "${IS_POSSIBLE}" == "true" ]] && [[ "${AUTO_MERGE}" == "true" ]]
then
  {
    printf "Fast Forwarding \`%s\` (%s) to " "${BASE_REF}" "${BASE_SHA}"
    printf "\`%s\` (%s)." "${HEAD_REF}" "${HEAD_SHA}"
  
    printf "\`\`\`shell\n"
    (
      # Show the git command in the output
      PS4="$ "
      set -x
  
      # Push the commit directly to the base branch.
      # This fast-forwards BASE_REF to point to HEAD_SHA
      git config user.name "github-actions[bot]"
      git config user.email "github-actions[bot]@users.noreply.github.com"
      git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
      git push origin "${HEAD_SHA}:${BASE_REF}"
    )
    printf "\`\`\`\n"
  } 2>&1 | tee -a "${GITHUB_STEP_SUMMARY}" | tee "${PUSH_LOG}"
fi

echo "PUSH_LOG path ${PUSH_LOG}"
printf "PUSH_LOG contents: %s\n" "$(cat "${PUSH_LOG}")"


# Write to GitHub output
printf "PUSH_LOG=%s\n" "${PUSH_LOG}" >> "${GITHUB_ENV}"
