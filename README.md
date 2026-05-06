# Redwing

Redwing is a native macOS Webex client foundation. It uses the local
`webex-swift-sdk` package for OAuth, Keychain-backed account storage, realtime
connection state, Spaces, Messages, and threaded message snapshots.

The current app is read-only. It provides:

- A Webex setup flow for one active account
- A native Spaces -> Messages -> Threads lane surface
- A menu bar attention feed
- A shared realtime Webex connection
- Diagnostics and status reporting for local testing

## Prerequisites

- macOS with Xcode installed
- The `redwing.xcodeproj` project in this repository
- The local SDK checkout at:

```sh
/Users/harriche/gits/github.com/mechaHarry/webex-swift-sdk
```

The SDK remote is:

```sh
git@github.com:mechaHarry/webex-swift-sdk.git
```

If Xcode cannot resolve `webex-swift-sdk`, make sure that local checkout exists
at the path above or update the package reference in Xcode.

## Building

List the available schemes:

```sh
xcodebuild -list -project redwing.xcodeproj
```

Build the app locally:

```sh
xcodebuild build \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/redwing-local \
  CODE_SIGNING_ALLOWED=NO
```

Run the test suite:

```sh
xcodebuild test \
  -project redwing.xcodeproj \
  -scheme Redwing \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/redwing-local-tests \
  CODE_SIGNING_ALLOWED=NO
```

## Opening Locally For Testing

Open the project in Xcode:

```sh
open redwing.xcodeproj
```

Select the `Redwing` scheme, then run the app with `Product > Run`.

To open a command-line build directly, first run the build command above, then:

```sh
open /private/tmp/redwing-local/Build/Products/Debug/Redwing.app
```

On first launch, Redwing shows Webex setup. Enter:

- Client ID
- Client secret
- Redirect URI, defaulting to `http://127.0.0.1:8282/oauth/callback`
- Scopes including `spark:all spark:kms`

After authorization, the app loads Spaces, Messages, thread details when a
threaded message is selected, and attention items in the menu bar.

## Notes

- Secrets are stored through the SDK-backed Keychain store.
- The app is sandboxed and has network client entitlement enabled.
- UI code is native SwiftUI/AppKit and does not call Webex REST directly.
