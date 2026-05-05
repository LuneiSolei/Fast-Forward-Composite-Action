# Create a local branch reference for the PR
git branch -f "pull_request/${HEAD_REF}" "${HEAD_SHA}"

# Check if the base branch is a direct ancestor of the head branch
if ! git merge-base --is-ancestor "${BASE_REF}" "${HEAD_SHA}"
then
  printf 'is-possible=%s\n' "false" >> "${GITHUB_OUTPUT}"
elif [[ "${AUTO_MERGE}" == "true" ]]
then
  printf 'is-possible=%s\n' "true" >> "${GITHUB_OUTPUT}"
fi
