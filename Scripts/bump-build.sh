#!/usr/bin/env bash
#
# Bump the app's build number (CURRENT_PROJECT_VERSION) before an archive.
#
# App Store Connect rejects an upload whose build number already exists for the
# current marketing version, so run this once per TestFlight upload.
#
#   Scripts/bump-build.sh          # 7 -> 8
#   Scripts/bump-build.sh 42       # set explicitly
#   Scripts/bump-build.sh --show   # print the current version without changing it
#
set -euo pipefail

PBXPROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Boardly/Boardly.xcodeproj/project.pbxproj"

current() {
    grep -m1 -E 'CURRENT_PROJECT_VERSION = [0-9]+;' "$PBXPROJ" |
        sed -E 's/.*CURRENT_PROJECT_VERSION = ([0-9]+);.*/\1/'
}

marketing() {
    grep -m1 -E 'MARKETING_VERSION = [^;]+;' "$PBXPROJ" |
        sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/'
}

old="$(current)"

if [[ "${1:-}" == "--show" ]]; then
    echo "$(marketing) ($old)"
    exit 0
fi

if [[ -n "${1:-}" ]]; then
    [[ "$1" =~ ^[0-9]+$ ]] || { echo "error: build number must be an integer, got '$1'" >&2; exit 1; }
    new="$1"
else
    new=$((old + 1))
fi

# Every configuration (app + test targets) shares one build number.
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = ${new};/g" "$PBXPROJ"

echo "build $old -> $new (version $(marketing))"
