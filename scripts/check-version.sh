#!/usr/bin/env bash
# Fails when the committed app versions do not match the version given as argument.
set -euo pipefail
expected="${1:?A version such as 1.2.0 is required}"
root="$(cd "$(dirname "$0")/.." && pwd)"
plist_version="$(sed -nE 's|.*<key>CFBundleShortVersionString</key><string>([^<]*)</string>.*|\1|p' "$root/apps/macos/Resources/Info.plist")"
csproj_version="$(sed -nE 's|.*<Version>([^<]*)</Version>.*|\1|p' "$root/apps/windows/Hue.Windows/Hue.Windows.csproj")"
status=0
if [[ "$plist_version" != "$expected" ]]; then
  printf 'Info.plist declares %s, the release tag says %s. Run scripts/set-version.sh %s and commit before tagging.\n' "$plist_version" "$expected" "$expected" >&2
  status=1
fi
if [[ "$csproj_version" != "$expected" ]]; then
  printf 'Hue.Windows.csproj declares %s, the release tag says %s. Run scripts/set-version.sh %s and commit before tagging.\n' "$csproj_version" "$expected" "$expected" >&2
  status=1
fi
exit "$status"
