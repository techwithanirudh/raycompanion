#!/bin/zsh
set -euo pipefail
repo_dir=${0:A:h:h}
configuration=${1:-debug}
cd "$repo_dir"
swift build -c "$configuration" --product RayCompanion
swift build -c "$configuration" --product DictationHelper
binary_dir=$(swift build -c "$configuration" --show-bin-path)
app_dir="$repo_dir/build/RayCompanion.app"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/RayCompanion" "$app_dir/Contents/MacOS/RayCompanion"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp LICENSE "$app_dir/Contents/Resources/LICENSE"
cp docs/TINYCAST.md "$app_dir/Contents/Resources/TINYCAST.md"
cp docs/licenses/Tinycast.txt "$app_dir/Contents/Resources/Tinycast-LICENSE.txt"
cp docs/licenses/Tinycast-NOTICE.md "$app_dir/Contents/Resources/Tinycast-NOTICE.md"
cp docs/licenses/Remotely.txt "$app_dir/Contents/Resources/Remotely-LICENSE.txt"
cp docs/licenses/Sparkle.txt "$app_dir/Contents/Resources/Sparkle-LICENSE.txt"
cp docs/licenses/PermissionFlow.txt "$app_dir/Contents/Resources/PermissionFlow-LICENSE.txt"
cp docs/licenses/LaunchAtLogin.txt "$app_dir/Contents/Resources/LaunchAtLogin-LICENSE.txt"
mkdir -p "$app_dir/Contents/Frameworks"
rm -rf "$app_dir/Contents/Frameworks/Sparkle.framework"
ditto "$binary_dir/Sparkle.framework" "$app_dir/Contents/Frameworks/Sparkle.framework"
xcrun actool Sources/TinycastKit/Assets.xcassets --compile "$app_dir/Contents/Resources" --platform macosx --minimum-deployment-target 26.0 --target-device mac --output-partial-info-plist build/assets-info.plist > build/assets.log
cp Resources/RayCompanion.icns "$app_dir/Contents/Resources/RayCompanion.icns"
cp Resources/RayCompanionMark.png "$app_dir/Contents/Resources/RayCompanionMark.png"
cp Sources/TinycastKit/Resources/RaycastRuntime.generated.js "$app_dir/Contents/Resources/RaycastRuntime.generated.js"
for resource in "$binary_dir"/*.bundle(N); do
    ditto "$resource" "$app_dir/Contents/Resources/${resource:t}"
done
helper_name="RayCompanion Dictation"
if [[ "$configuration" == debug ]]; then helper_name="RayCompanion Dev Dictation"; fi
helper_dir="$app_dir/Contents/Helpers/$helper_name.app"
mkdir -p "$helper_dir/Contents/MacOS"
mkdir -p "$helper_dir/Contents/Resources"
cp Resources/RayCompanion.icns "$helper_dir/Contents/Resources/RayCompanion.icns"
cp "$binary_dir/DictationHelper" "$helper_dir/Contents/MacOS/$helper_name"
cp Resources/DictationInfo.plist "$helper_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string RayCompanion" "$helper_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.anirudh.quickchat.dictation" "$helper_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $helper_name" "$helper_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $helper_name" "$helper_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion en" "$helper_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $helper_name" "$helper_dir/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $helper_name" "$helper_dir/Contents/Info.plist"
identity=${CODESIGN_IDENTITY:-Remotely Self Signed}
if ! security find-identity -p codesigning 2>/dev/null | grep -qF "$identity"; then
    identity="-"
fi
if [[ -n "${RAYCOMPANION_UPDATE_FEED:-}" || -n "${RAYCOMPANION_UPDATE_PUBLIC_KEY:-}" ]]; then
    python3 - "$app_dir/Contents/Info.plist" <<'PYFEED'
import base64, os, plistlib, sys
from urllib.parse import urlparse
feed = os.environ.get('RAYCOMPANION_UPDATE_FEED', '')
key = os.environ.get('RAYCOMPANION_UPDATE_PUBLIC_KEY', '')
assert urlparse(feed).scheme == 'https' and urlparse(feed).hostname, 'Set an HTTPS update feed URL.'
assert len(base64.b64decode(key, validate=True)) == 32, 'Set the Sparkle Ed25519 public key.'
with open(sys.argv[1], 'rb') as f: info = plistlib.load(f)
info.update(SUFeedURL=feed, SUPublicEDKey=key)
with open(sys.argv[1], 'wb') as f: plistlib.dump(info, f, sort_keys=False)
PYFEED
fi
codesign --force --sign "$identity" "$app_dir/Contents/Frameworks/Sparkle.framework"
codesign --force --sign "$identity" "$helper_dir"
codesign --force --sign "$identity" "$app_dir"
print "$app_dir"
