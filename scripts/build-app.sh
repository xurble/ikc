#!/bin/sh
set -eu

if [ -z "${TEAM_ID:-}" ] || [ -z "${BUNDLE_ID:-}" ] || [ -z "${PROFILE:-}" ] || [ -z "${SIGNING_IDENTITY:-}" ]; then
    echo "Set TEAM_ID, BUNDLE_ID, PROFILE, and SIGNING_IDENTITY." >&2
    exit 2
fi

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "$PROFILE" in
    /*) ;;
    *) echo "PROFILE must be an absolute path outside this repository." >&2; exit 2 ;;
esac
case "$PROFILE" in
    "$project_dir"/*) echo "Keep the provisioning profile outside this repository." >&2; exit 2 ;;
esac

if [ ! -f "$PROFILE" ]; then
    echo "Provisioning profile not found: $PROFILE" >&2
    exit 2
fi
if [ "$SIGNING_IDENTITY" = "-" ]; then
    echo "An ad-hoc signature cannot access the iCloud Keychain access group." >&2
    exit 2
fi

profile_contents=$(mktemp)
trap 'rm -f "$profile_contents" "${entitlements:-}"' EXIT
if ! security cms -D -i "$PROFILE" -o "$profile_contents"; then
    echo "Could not decode the provisioning profile." >&2
    exit 2
fi
plutil -lint "$profile_contents" >/dev/null

cd "$project_dir"
swift build -c release --product ikc
binary_dir=$(swift build -c release --show-bin-path)
app="$project_dir/build/ikc.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$binary_dir/ikc" "$app/Contents/MacOS/ikc"
cp "$PROFILE" "$app/Contents/embedded.provisionprofile"

cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>ikc</string>
<key>CFBundleExecutable</key><string>ikc</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF

entitlements=$(mktemp)
cat > "$entitlements" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.application-identifier</key><string>$TEAM_ID.$BUNDLE_ID</string>
<key>com.apple.developer.team-identifier</key><string>$TEAM_ID</string>
<key>keychain-access-groups</key><array><string>$TEAM_ID.$BUNDLE_ID</string></array>
</dict></plist>
EOF

plutil -lint "$app/Contents/Info.plist" "$entitlements"
codesign --force --sign "$SIGNING_IDENTITY" --entitlements "$entitlements" "$app"
codesign --verify --strict --verbose=2 "$app"
echo "Signed helper: $app/Contents/MacOS/ikc"
echo "Run its probe from a logged-in macOS session before storing real secrets."
