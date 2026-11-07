#!/usr/bin/env bash
#
# Fetch the current Factorio headless versions from the official API and
# sync them into stable/VERSION, experimental/VERSION, README.md and CHANGELOG.md.
#
# Usage: scripts/update-versions.sh
# When run inside GitHub Actions it also writes step outputs:
#   stable, experimental, changed (true|false)

set -Eeuo pipefail
cd "$(dirname "$0")/.."

API_URL="https://factorio.com/api/latest-releases"
REPO_URL="https://github.com/craftorio/factorio"
TODAY="$(date -u +%F)"

releases="$(curl -fsSL --retry 3 "$API_URL")"
stable="$(jq -er '.stable.headless' <<<"$releases")"
experimental="$(jq -er '.experimental.headless' <<<"$releases")"

for v in "$stable" "$experimental"; do
    [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Unexpected version from API: '$v'" >&2; exit 1; }
done

readme_row() {
    local channel="$1" version="$2"
    local base="$REPO_URL/blob/main/$channel"
    case "$channel" in
        stable)
            echo "| [latest, stable, $version]($base/Dockerfile)<br>[latest-alpine, stable-alpine, $version-alpine]($base/Dockerfile.alpine) | $version | Factorio headless server stable release | $TODAY | <!-- stable -->"
            ;;
        experimental)
            echo "| [experimental]($base/Dockerfile)<br>[experimental-alpine]($base/Dockerfile.alpine) | $version | Factorio headless server experimental release | $TODAY | <!-- experimental -->"
            ;;
    esac
}

changes=()
for channel in stable experimental; do
    new="${!channel}"
    current="$(tr -d '[:space:]' < "$channel/VERSION")"
    if [ "$current" != "$new" ]; then
        echo "$new" > "$channel/VERSION"
        row="$(readme_row "$channel" "$new")"
        awk -v row="$row" -v marker="<!-- $channel -->" \
            'index($0, marker) { print row; next } { print }' README.md > README.md.tmp
        mv README.md.tmp README.md
        changes+=("  * ${channel^} Factorio v${new}")
        echo "$channel: $current -> $new"
    else
        echo "$channel: $current (up to date)"
    fi
done

if [ "${#changes[@]}" -gt 0 ]; then
    {
        echo "**$TODAY**"
        printf '%s\n' "${changes[@]}"
        echo "---"
        cat CHANGELOG.md
    } > CHANGELOG.md.tmp
    mv CHANGELOG.md.tmp CHANGELOG.md
    changed=true
else
    changed=false
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "stable=$stable"
        echo "experimental=$experimental"
        echo "changed=$changed"
    } >> "$GITHUB_OUTPUT"
fi
