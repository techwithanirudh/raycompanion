#!/bin/zsh
set -euo pipefail
repo_dir=${0:A:h:h}
cd "$repo_dir"
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--publish" ) ]]; then
    print -u2 'Usage: scripts/release.sh [--publish]'
    exit 1
fi
account=com.anirudh.raycompanion.updates
identity=${CODESIGN_IDENTITY:-Remotely Self Signed}
sparkle_dir="$repo_dir/.build/artifacts/sparkle/Sparkle/bin"
if [[ ${1:-} == --publish ]]; then
    [[ -z $(git status --porcelain) ]] || { print -u2 'Commit the verified source before publishing a release.'; exit 1; }
    git fetch -q origin
    [[ -n $(git branch -r --contains HEAD) ]] || { print -u2 'Push HEAD before publishing; the release tag points at it.'; exit 1; }
fi
./scripts/check.sh
./scripts/build-app.sh release
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
public_key=$("$sparkle_dir/generate_keys" --account "$account" -p)
bundle_key=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' build/RayCompanion.app/Contents/Info.plist)
[[ "$public_key" == "$bundle_key" ]] || { print -u2 'The release signing key does not match the app.'; exit 1; }
codesign --verify --deep --strict build/RayCompanion.app
signature=$(codesign -dvvv build/RayCompanion.app 2>&1)
[[ "$signature" == *Authority=* ]] || { print -u2 'Releases need a stable signing identity.'; exit 1; }
requirement=$(codesign -d -r- build/RayCompanion.app 2>&1 | sed -n 's/^designated => //p')
[[ "$requirement" == "$(<Resources/DesignatedRequirement.txt)" ]] || {
    print -u2 "The signed app's designated requirement changed, so users would lose permissions:"
    print -u2 "  built:    $requirement"
    print -u2 "  expected: $(<Resources/DesignatedRequirement.txt)"
    exit 1
}
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)
feed=$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' Resources/Info.plist)
published=$(curl -fsSL "$feed" 2>/dev/null | sed -n 's:.*<sparkle\:version>\([0-9][0-9]*\)</sparkle\:version>.*:\1:p' | sort -n | tail -1)
[[ -z "$published" || "$build" -gt "$published" ]] || { print -u2 "CFBundleVersion $build must be greater than the published build $published."; exit 1; }
release_dir="$repo_dir/build/releases/v$version"
rm -rf "$release_dir"
mkdir -p "$release_dir"
ditto -c -k --sequesterRsrc --keepParent build/RayCompanion.app "$release_dir/RayCompanion.zip"
cp Resources/ReleaseNotes.html "$release_dir/RayCompanion.html"
"$sparkle_dir/generate_appcast" --account "$account" --maximum-deltas 0 --embed-release-notes --download-url-prefix "https://github.com/techwithanirudh/raycompanion/releases/download/v$version/" --link 'https://github.com/techwithanirudh/raycompanion' "$release_dir"
"$sparkle_dir/sign_update" --account "$account" --verify "$release_dir/appcast.xml"
# After the appcast, so generate_appcast never lists the disk image as a second archive.
staging=$(mktemp -d)
ditto build/RayCompanion.app "$staging/RayCompanion.app"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname RayCompanion -srcfolder "$staging" -ov -format UDZO "$release_dir/RayCompanion.dmg"
rm -rf "$staging"
codesign --force --sign "$identity" "$release_dir/RayCompanion.dmg"
codesign --verify "$release_dir/RayCompanion.dmg"
if [[ ${1:-} == --publish ]]; then
    gh release create "v$version" "$release_dir/RayCompanion.dmg" "$release_dir/RayCompanion.zip" "$release_dir/appcast.xml" --repo techwithanirudh/raycompanion --target "$(git rev-parse HEAD)" --title "RayCompanion $version" --notes-file Resources/ReleaseNotes.md
fi
print "$release_dir"
