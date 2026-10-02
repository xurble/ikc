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

Apple requires an app-like bundle with a provisioning profile for the Keychain access group entitlement. Create a macOS App ID and a matching provisioning profile in your Apple Developer team. Install an Apple Development signing identity in Keychain Access. Enable iCloud Passwords & Keychain for the signed-in macOS user.

Keep your Apple Developer account password and signing private key in Apple's own tools and Keychain. The build script only accepts a signing identity name and the path to a provisioning profile stored **outside this repository**. The resulting signed app bundle stays in the ignored `build/` directory. Never put developer credentials or profiles in GitHub Actions secrets for this project; CI only runs tests.

```sh
swift test
TEAM_ID=YOUR_TEAM_ID \
BUNDLE_ID=com.example.ikc \
PROFILE=/path/to/mac-development.provisionprofile \
SIGNING_IDENTITY='Apple Development: Your Name (YOUR_TEAM_ID)' \
./scripts/build-app.sh
./build/ikc.app/Contents/MacOS/ikc probe
```

The `BUNDLE_ID` must match the App ID in the profile and remain the same on every Mac that needs the synced items. Build and sign the same bundle identifier and access group on each Mac. Run the executable from inside its signed `.app` bundle; moving the executable out loses the provisioning profile context. Do not commit certificates, profiles, or signed builds.

The helper must run in a logged-in user session. An unsigned `swift run ikc` build can run the unit tests but cannot access its iCloud Keychain items. First test a harmless item on two Macs before storing important credentials.

Apple's [macOS Keychain guidance](https://developer.apple.com/documentation/Technotes/tn3137-on-mac-keychains) and [app-like bundle signing guidance](https://developer.apple.com/documentation/xcode/signing-a-daemon-with-a-restricted-entitlement) explain the requirements.
