# Redwing

Redwing is a native macOS Webex client foundation. It uses the tagged
`webex-swift-sdk` Swift package for OAuth, Keychain-backed account storage,
realtime connection state, Spaces, Messages, and threaded message snapshots.

The current app is read-only. It provides:

- A Webex setup flow for one active account
- A native spaces-first Liquid Glass pane
- A menu bar attention feed
- A shared realtime Webex connection
- Diagnostics and status reporting for local testing

## Prerequisites

- macOS 26.4 or newer with Xcode installed
- The `redwing.xcodeproj` project in this repository
- Network access for Xcode to resolve Swift package dependencies

The SDK package is pinned to a released tag from:

```sh
https://github.com/mechaHarry/webex-swift-sdk.git
```

The current pinned SDK version is `2.5.1`.

## Versioning

Update the app version in one place:

```sh
Redwing/Config/Version.xcconfig
```

`REDWING_SEMVER` is the release version source of truth. The app and test
bundle plists consume it through Xcode build settings for both
`CFBundleShortVersionString` and `CFBundleVersion`.

Use `MAJOR.MINOR.PATCH` without a leading `v`; the release script creates the
signed git tag as `v<REDWING_SEMVER>`.

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

After authorization, the app loads Spaces into a single glass pane. Message and
thread lane code remains archived in the source tree while the client surface is
reset around Spaces.

## Notes

- Secrets are stored through the SDK-backed Keychain store.
- The app is sandboxed and has network client entitlement enabled.
- UI code is native SwiftUI/AppKit and does not call Webex REST directly.

## Releasing

Create only the local versioned zip and checksum:

```sh
./release.sh --package-only
```

Run the full release flow:

```sh
GITHUB_TOKEN=... ./release.sh
```

The script reads `REDWING_SEMVER`, builds the Release app, writes
`dist/Redwing-<version>-macos-<arch>.zip` and `.sha256`, creates and verifies a
signed tag named `v<version>`, pushes it, creates a GitHub release with generated
notes, uploads both assets, and publishes the release. By default it passes
`CODE_SIGNING_ALLOWED=NO` to Xcode; set `CODE_SIGNING_ALLOWED=YES` when the
project has a working signing team/certificate configured.
