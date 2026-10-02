# ikc

`ikc` is a small macOS command-line helper for generic passwords that sync through iCloud Keychain. It uses Apple's Security framework with `kSecAttrSynchronizable=true`. It does not access existing Apple Passwords entries or the legacy `login` keychain.

## Commands

```sh
ikc probe
printf '%s' 'example-secret' | ikc set example-service example-account
ikc get example-service example-account
```

`set` reads the entire secret from standard input. `get` writes the exact secret bytes to standard output without an added newline. Errors go to standard error; a missing item exits with status 4. Use distinct service and account names for each secret. `probe` creates, reads, and removes a disposable item.

Anyone who can run commands as your logged-in macOS user can invoke this executable to read items in its access group. Restrict access to that account and avoid printing secrets in terminal sessions or logs.

## Build and sign

Apple requires an app-like bundle with a provisioning profile for the Keychain access group entitlement. The `ikc.xcodeproj` target builds the command-line executable inside `ikc.app`, enables Keychain Sharing and hardened runtime, and uses Xcode's automatic signing. Enable iCloud Passwords & Keychain for the signed-in macOS user.

Keep your Apple Developer account password and signing private key in Xcode and Keychain. This repository commits a blank example signing config and ignores your populated local config. Never put developer credentials or profiles in GitHub Actions secrets for this project; CI only runs Swift package tests.

```sh
cp Config/Local.example.xcconfig Config/Local.xcconfig
```

Edit `Config/Local.xcconfig` locally. Set `DEVELOPMENT_TEAM` to your Team ID and `PRODUCT_BUNDLE_IDENTIFIER` to a unique bundle identifier. Sign in to your developer account in Xcode > Settings > Accounts, then open `ikc.xcodeproj` and build the `ikc` scheme. Xcode manages the development certificate and provisioning profile. The local config is ignored by Git; check `git status` before committing.

Set the Team ID in `Local.xcconfig`, not Xcode's Signing & Capabilities Team picker. The picker can write the ID into the tracked `project.pbxproj` file. If you use it, remove the `DEVELOPMENT_TEAM` overrides from that file before committing; the local config still supplies the setting.

```sh
swift test
xcodebuild -project ikc.xcodeproj -scheme ikc -configuration Release \
  -derivedDataPath build/DerivedData build
./build/DerivedData/Build/Products/Release/ikc.app/Contents/MacOS/ikc probe
```

For a shorter command, keep the signed app bundle in place and symlink its executable from a directory on your `PATH`:

```sh
mkdir -p "$HOME/.local/bin"
ln -s "$PWD/build/DerivedData/Build/Products/Release/ikc.app/Contents/MacOS/ikc" "$HOME/.local/bin/ikc"
ikc probe
```

Add `$HOME/.local/bin` to `PATH` if your shell does not already include it. The symlink is only a launcher; the app bundle and its embedded provisioning profile must stay together.

The bundle identifier must remain the same on every Mac that needs the synced items. Build and sign the same bundle identifier and access group on each Mac. Run the executable from inside its signed `.app` bundle; moving the executable out loses the provisioning profile context. Do not commit certificates, profiles, or signed builds.

To distribute the helper, use Xcode's Product > Archive, then Organizer > Distribute App > Developer ID. Xcode can submit the archive for notarization. This requires a Developer ID signing identity and a suitable distribution provisioning profile. Notarization is for distribution; the synced Keychain behavior still depends on a valid signature, profile, entitlements, and the user's iCloud Keychain settings. Test the distributed build's `probe` command before using it with real secrets.

The helper must run in a logged-in user session. An unsigned `swift run ikc` build can run the unit tests but cannot access its iCloud Keychain items. First test a harmless item on two Macs before storing important credentials.

Apple's [macOS Keychain guidance](https://developer.apple.com/documentation/Technotes/tn3137-on-mac-keychains), [Keychain Sharing setup](https://developer.apple.com/documentation/xcode/configuring-keychain-sharing), and [notarization workflow](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) explain the requirements.
