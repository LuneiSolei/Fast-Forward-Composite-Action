#!/usr/bin bash

set -e

# Ensure COMMENT value is valid
case "${COMMENT}" in
    always|on-error|never) ;;
    *)
        echo "::error::Invalid value '${COMMENT}' for COMMENT." >&2
        exit 1
        ;;
esac

# Ensure DEBUG value is valid
case "${DEBUG}" in
    true|false) ;;
    *) echo "::error::Invalid value '${DEBUG}' for DEBUG." >&2
    exit 1
    ;;
esac

# Ensure GITHUB_TOKEN is set
if [[ -z "${GITHUB_TOKEN}" ]]
then
    echo "::error::Invalid value '${GITHUB_TOKEN}' for GITHUB_TOKEN." >&2
    exit 1
fi

# Ensure AUTO_MERGE is valid
case "${AUTO_MERGE}" in
    true|false) ;;
    *)
        echo "::error::Invalid value '${AUTO_MERGE}' for AUTO_MERGE." >&2
        exit 1
        ;;
esac


# Ensure we're running via GitHub Actions
if [[ -z "${GITHUB_EVENT_PATH}" ]]
then
    echo "::error::GITHUB_EVENT_PATH environment variable must be set."
    exit 1
fi

# Do some logging if DEBUG is enabled
if [[ "${DEBUG}" == "true" ]]
then
    {
        echo "env"
        env
        echo "GITHUB_ENV: ${GITHUB_ENV}"
        cat "${GITHUB_ENV}"
        echo "GITHUB_EVENT_PATH: ${GITHUB_EVENT_PATH}"
        cat "${GITHUB_EVENT_PATH}"
    } >&2
fi
