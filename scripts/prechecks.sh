#! /bin/bash

set -e

# Ensure COMMENT value is valid
case "${COMMENT}" in
  always|on-error|never) 
    printf 'COMMENT=%s\n' "${COMMENT}" >> "${GITHUB_ENV}"
    ;;
  *)
    printf '::error::Invalid value \'%s\' for COMMENT\n' "${COMMENT}" >&2
    exit 1
    ;;
esac

# Ensure GITHUB_TOKEN is set
if [[ -z "${GITHUB_TOKEN}" ]]
then
  printf '::error::GITHUB_TOKEN cannot be empty' >&2
  exit 1
else
  printf 'GITHUB_TOKEN=%s\n' "${GITHUB_TOKEN}" >> "${GITHUB_ENV}"
fi

# Ensure AUTO_MERGE is valid
case "${AUTO_MERGE}" in
  true|false) 
    printf 'AUTO_MERGE=%s\n' "${AUTO_MERGE}" >> "${GITHUB_ENV}"
    ;;
  *)
    printf '::error::Invalid value for \'%s\' for AUTO_MERGE\n' "${AUTO_MERGE}" >&2
    exit 1
    ;;
esac

# Ensure we're running via GitHub Actions
if [[ -z "${GITHUB_EVENT_PATH}" ]]
then
  printf '::error::GITHUB_EVENTPATH environment variable must be set' >&2
  exit 1
fi

echo "::debug::env"
echo "::debug::GITHUB_ENV: ${GITHUB_ENV}"
echo "::debug::${GITHUB_ENV}"
echo "::debug::GITHUB_EVENT_PATH: ${GITHUB_EVENT_PATH}"
echo "::debug::${GITHUB_EVENT_PATH}"
