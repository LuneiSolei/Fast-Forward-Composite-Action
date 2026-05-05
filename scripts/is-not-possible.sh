#! /bin/bash

set -e

# Fast-forward not possible
echo -n "Can't fast forward \`${BASE_REF}\` (${BASE_SHA}) to"
echo -n " \`${HEAD_REF}\` (${HEAD_SHA})."
echo -n " \`${BASE_REF}\` (${BASE_SHA}) is not a direct ancestor of"
echo -n " \`${HEAD_REF}\` (${HEAD_SHA})."

# Get where the branches diverged
MERGE_BASE=$(git merge-base "${BASE_SHA}" "${HEAD_SHA}" || true)
if [[ -z "${MERGE_BASE}" ]]
then
  # No common ancestor
  echo " Branches don't appear to have a common ancestor."
else
  # Found divergence point
  echo " Branches appear to have diverged at ${MERGE_BASE}:"
  echo
  echo '```shell'

  # If ${MERGE_BASE} is a root (has no parent), then it is not a valid reference
  if [[ "$(git cat-file -t "${MERGE_BASE}^")" == "commit" ]]
  then
    # Exclude commits before the merge base from the graph
    EXCLUDE="^${MERGE_BASE}^"
  else
    # Merge base is a root commit, don't exclude anything
    EXCLUDE=
  fi

  # Display graph of diverged branches
  git log --pretty=oneline --graph \
    ${EXCLUDE} "${BASE_SHA}" "${HEAD_SHA}"
  echo

  # Display details of the divergence point
  git log --decorate=short -n 1 "${MERGE_BASE}"
  echo '```'
fi
echo
echo "Rebase locally, and then force push to \`${HEAD_REF}\`."
