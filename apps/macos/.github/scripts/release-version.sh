#!/usr/bin/env bash
# Prints the versions derived from a release tag such as v1.2.0 or v1.2.0-beta.1:
# VERSION_TAG keeps the whole tag for file names, APP_VERSION is the numeric part
# that the app bundles and installers declare.
set -euo pipefail
tag="${1:?A release tag such as v1.2.0 is required}"
if [[ ! "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)(-[0-9A-Za-z.]+)?$ ]]; then
  printf 'The release tag must look like v1.2.0 or v1.2.0-beta.1; got: %s\n' "$tag" >&2
  exit 1
fi
printf 'VERSION_TAG=%s\nAPP_VERSION=%s\n' "${tag#v}" "${BASH_REMATCH[1]}"
