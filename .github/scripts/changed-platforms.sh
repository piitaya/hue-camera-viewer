#!/usr/bin/env bash
set -euo pipefail

build_both() {
  printf 'macos=true\nwindows=true\n'
}

case "${GITHUB_EVENT_NAME:-}" in
  workflow_dispatch)
    build_both
    exit 0
    ;;
  pull_request)
    : "${BASE_SHA:?A pull request requires BASE_SHA}"
    : "${HEAD_SHA:?A pull request requires HEAD_SHA}"
    base=$(git merge-base "$BASE_SHA" "$HEAD_SHA")
    ;;
  push)
    if [[ -z "${BASE_SHA:-}" || "$BASE_SHA" =~ ^0+$ ]]; then
      build_both
      exit 0
    fi
    : "${HEAD_SHA:?A push requires HEAD_SHA}"
    base=$BASE_SHA
    ;;
  *)
    printf 'Unsupported GitHub event: %s\n' "${GITHUB_EVENT_NAME:-<missing>}" >&2
    exit 1
    ;;
esac

changed_files=$(mktemp "${TMPDIR:-/tmp}/girafon-changed-platforms.XXXXXX")
trap 'rm -f "$changed_files"' EXIT

# Disable rename detection so both the old and new platforms are considered.
git diff --name-only --no-renames -z "$base" "$HEAD_SHA" -- > "$changed_files"

macos=false
windows=false
while IFS= read -r -d '' path; do
  case "$path" in
    *.[mM][dD]|*.[mM][aA][rR][kK][dD][oO][wW][nN]|docs/*|apps/macos/LISEZ-MOI.txt)
      ;;
    apps/macos/*)
      macos=true
      ;;
    apps/windows/*)
      windows=true
      ;;
    *)
      macos=true
      windows=true
      ;;
  esac
done < "$changed_files"

printf 'macos=%s\nwindows=%s\n' "$macos" "$windows"
