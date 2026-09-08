#!/usr/bin/env bash
# Prints APP_VERSION, the numeric version an app declares, from a release tag
# such as v1.2.0 or v1.2.0-beta.1.
set -euo pipefail
tag="${1:?A release tag such as v1.2.0 is required}"
if [[ ! "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)(-[0-9A-Za-z.]+)?$ ]]; then
  printf 'The release tag must look like v1.2.0 or v1.2.0-beta.1; got: %s\n' "$tag" >&2
  exit 1
fi
printf 'APP_VERSION=%s\n' "${BASH_REMATCH[1]}"
