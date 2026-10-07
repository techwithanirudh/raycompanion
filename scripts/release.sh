#!/bin/zsh
set -euo pipefail
repo_dir=${0:A:h:h}
cd "$repo_dir"
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--publish" ) ]]; then
    print -u2 'Usage: scripts/release.sh [--publish]'
    exit 1
fi
account=com.anirudh.raycompanion.updates
sparkle_dir="$repo_dir/.build/artifacts/sparkle/Sparkle/bin"
./scripts/check.sh
./scripts/build-app.sh release
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
public_key=$("$sparkle_dir/generate_keys" --account "$account" -p)
bundle_key=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' build/RayCompanion.app/Contents/Info.plist)
[[ "$public_key" == "$bundle_key" ]] || { print -u2 'The release signing key does not match the app.'; exit 1; }
codesign --verify --deep --strict build/RayCompanion.app
codesign -dvvv build/RayCompanion.app 2>&1 | grep -q 'Authority=' || { print -u2 'Releases need a stable signing identity.'; exit 1; }
release_dir="$repo_dir/build/releases/v$version"
mkdir -p "$release_dir"
ditto -c -k --sequesterRsrc --keepParent build/RayCompanion.app "$release_dir/RayCompanion.zip"
cp Resources/ReleaseNotes.html "$release_dir/RayCompanion.html"
"$sparkle_dir/generate_appcast" --account "$account" --maximum-deltas 0 --embed-release-notes --download-url-prefix "https://github.com/techwithanirudh/raycompanion/releases/download/v$version/" --link 'https://github.com/techwithanirudh/raycompanion' "$release_dir"
"$sparkle_dir/sign_update" --account "$account" --verify "$release_dir/appcast.xml"
if [[ ${1:-} == --publish ]]; then
    [[ -z $(git status --porcelain) ]] || { print -u2 'Commit the verified source before publishing a release.'; exit 1; }
    gh release create "v$version" "$release_dir/RayCompanion.zip" "$release_dir/appcast.xml" --repo techwithanirudh/raycompanion --target "$(git rev-parse HEAD)" --title "RayCompanion $version" --notes-file Resources/ReleaseNotes.md
fi
print "$release_dir"
