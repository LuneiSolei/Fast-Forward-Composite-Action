#! /bin/bash

set -e

# Ensure COMMENT value is valid
case "${COMMENT}" in
  always|on-error|never)
    printf "COMMENT=%s\n" "${COMMENT}" >> "${GITHUB_ENV}"
    ;;
  *)
    printf "::error::Invalid value '%s' for COMMENT\n" "${COMMENT}" >> "${GITHUB_STEP_SUMMARY}" >&2
    exit 1
esac

SHOULD_EXIT=false
# Ensure GITHUB_TOKEN is set
if [[ -z "${GITHUB_TOKEN}" ]]
then
  printf "::error::GITHUB_TOKEN cannot be empty" >&2
  SHOULD_EXIT=true
else
  printf "GITHUB_TOKEN=%s\n" "${GITHUB_TOKEN}" >> "${GITHUB_ENV}"
fi

# Ensure AUTO_MERGE is valid
case "${AUTO_MERGE}" in
  true|false)
    printf "AUTO_MERGE=%s\n" "${AUTO_MERGE}" >> "${GITHUB_ENV}"
    ;;
  *)
    printf "::error::Invalid value '%s' for AUTO_MERGE\n" "${AUTO_MERGE}" >> "${GITHUB_STEP_SUMMARY}" >&2
    SHOULD_EXIT=true
    ;;
esac

# Ensure we're running via GitHub Actions
if [[ -z "${GITHUB_EVENT_PATH}" ]]
then
  printf "::error::GITHUB_EVENT_PATH environment variable not set. This script is intended to be run within a GitHub
    Actions workflow." >> "${GITHUB_STEP_SUMMARY}" >&2
  SHOULD_EXIT=true
fi

# Debug output
printf "::debug::GITHUB_ENV: %s\n" "${GITHUB_ENV}"
printf "::debug::GITHUB_EVENT_PATH: %s\n" "${GITHUB_EVENT_PATH}"

if [[ "${SHOULD_EXIT}" == "true" ]]
then
  exit 1
fi

# Step summary output
printf "Pre-checks completed successfully.\n" >> "${GITHUB_STEP_SUMMARY}"