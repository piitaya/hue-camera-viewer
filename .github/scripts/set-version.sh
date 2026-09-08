#!/usr/bin/env bash
# Writes the app version into the macOS Info.plist and the Windows project.
set -euo pipefail
version="${1:?A version such as 1.2.0 is required}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'The version must look like 1.2.0; got: %s\n' "$version" >&2
  exit 1
fi
root="$(cd "$(dirname "$0")/../.." && pwd)"
plist="$root/apps/macos/Resources/Info.plist"
csproj="$root/apps/windows/Hue.Windows/Hue.Windows.csproj"
sed -i.bak -E \
  -e "s|(<key>CFBundleShortVersionString</key><string>)[^<]*|\1$version|" \
  -e "s|(<key>CFBundleVersion</key><string>)[^<]*|\1$version|" "$plist"
sed -i.bak -E "s|(<Version>)[^<]*(</Version>)|\1$version\2|" "$csproj"
rm -f "$plist.bak" "$csproj.bak"
grep -q "<string>$version</string>" "$plist" && grep -q "<Version>$version</Version>" "$csproj"
printf 'Version %s written to Info.plist and Hue.Windows.csproj\n' "$version"
