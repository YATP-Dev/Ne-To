#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
signing_identity="${NE_TO_SIGNING_IDENTITY:-}"
if [[ -z "$signing_identity" ]]; then
    candidates="$(security find-identity -v -p codesigning \
        | sed -nE 's/^ *[0-9]+\) [0-9A-F]+ "(Apple Development: [^"]+)"$/\1/p' | sort -u)"
    candidate_count="$(printf '%s\n' "$candidates" | awk 'NF { count++ } END { print count+0 }')"
    if [[ "$candidate_count" -ne 1 ]]; then
        echo "Set NE_TO_SIGNING_IDENTITY to one stable Apple Development signing identity." >&2
        exit 1
    fi
    signing_identity="$candidates"
fi
cd "$root"
swift build -c release
binary="$(swift build -c release --show-bin-path)/NeTo"
app="$root/dist/Ne-To.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/NeTo"
cp "$root/LICENSE" "$root/THIRD_PARTY_DATA.md" "$app/Contents/Resources/"
xcrun actool --compile "$app/Contents/Resources" --platform macosx \
    --minimum-deployment-target 14.0 --app-icon AppIcon \
    --output-partial-info-plist "$root/.build/AppIcon-Info.plist" \
    "$root/Resources/Assets.xcassets"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleDisplayName</key><string>Ne-To</string>
    <key>CFBundleExecutable</key><string>NeTo</string>
    <key>CFBundleIdentifier</key><string>dev.yatp.ne-to</string>
    <key>CFBundleName</key><string>Ne-To</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign "$signing_identity" "$app"
echo "Created $app"
