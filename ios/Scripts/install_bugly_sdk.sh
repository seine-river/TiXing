#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/TiXing/Vendor/Bugly"
VERSION="${1:-2.8.2.14}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$VENDOR"
BUGLY_URL="https://github.com/BuglyDevTeam/BuglyPro-iOS/releases/download/${VERSION}/BuglyPro-${VERSION}.zip"
# Reuse a complete archive when it was downloaded by a CI cache or a previous run.
# This avoids repeating the large GitHub asset download after a project regeneration.
CACHED_ARCHIVE="${BUGLY_SDK_ARCHIVE:-/tmp/BuglyPro-${VERSION}.zip}"
if [[ -f "$CACHED_ARCHIVE" ]] && unzip -tq "$CACHED_ARCHIVE" >/dev/null 2>&1; then
  cp "$CACHED_ARCHIVE" "$WORK/bugly.zip"
else
  if ! curl --retry 3 --retry-all-errors --connect-timeout 15 --max-time 900 -fL "$BUGLY_URL" \
    -o "$WORK/bugly.zip"; then
    # GitHub release assets can be unstable in mainland-China networks; use a public
    # HTTPS mirror as an explicit fallback. The official URL remains the first choice.
    curl --retry 8 --retry-all-errors --connect-timeout 15 --max-time 1800 -fL \
      "https://gh-proxy.com/${BUGLY_URL}" -o "$WORK/bugly.zip"
  fi
fi
unzip -q "$WORK/bugly.zip" -d "$WORK/extracted"
# The official archive also contains optional module frameworks for Bugly's
# modular CocoaPods subspecs. This project uses the full BuglyPro default
# subspec; linking both the full framework and module frameworks would duplicate
# symbols, so install only BuglyPro.xcframework.
framework="$(find "$WORK/extracted" -type d -name 'BuglyPro.xcframework' -print -quit)"
if [[ -z "$framework" ]]; then
  echo "BuglyPro.xcframework not found in archive" >&2
  exit 1
fi
rm -rf "$VENDOR"
mkdir -p "$VENDOR"
cp -R "$framework" "$VENDOR/BuglyPro.xcframework"

python3 "$ROOT/generate_project.py"
echo "Bugly XCFrameworks installed in $VENDOR"
