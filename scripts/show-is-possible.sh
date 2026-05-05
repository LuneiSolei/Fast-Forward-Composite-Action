#! /bin/bash

set -e

# Check if user has permission
if [[ "$(jq -r .user.permissions.push < ${PERM})" == "true" ]]
then
  # User has permission
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
  echo "EXIT_CODE=0" >> ${GITHUB_ENV}
else
  # User does not have permission to push
  echo -n "Sorry @$(${GITHUB_ACTION_PATH}/scripts/github-event.sh .sender.login),"
  echo -n " it is possible to fast forward \`${BASE_REF}\` (${BASE_SHA})"
  echo -n " to \`${HEAD_REF}\` (${HEAD_SHA}), but you don't appear to have"
  echo " permission to push to this repository."
else
  # Fast-forwarding is possible, but "merge" is disabled
  echo -n "It is possible to fast forward \`${BASE_REF}\` (${BASE_SHA})"
  echo -n " to \`${HEAD_REF}\` (${HEAD_SHA}). If you have write access to the"
  echo -n " target repository, you can add a comment with"
  echo -n " \`/fast-forward\` to fast forward \`${BASE_REF}\` to"
  echo " \`${HEAD_REF}\`."
  echo "EXIT_CODE=0" >> ${GITHUB_ENV}
fi
