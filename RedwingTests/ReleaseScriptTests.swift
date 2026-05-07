import XCTest

final class ReleaseScriptTests: XCTestCase {
    func testVersionConfigIsTheSingleSemverSourceOfTruth() throws {
        let rootURL = repositoryRootURL()
        let versionConfigURL = rootURL.appendingPathComponent("Redwing/Config/Version.xcconfig")
        let versionConfig = try String(contentsOf: versionConfigURL, encoding: .utf8)
        let semver = try XCTUnwrap(
            versionConfig.firstMatch(for: #"(?m)^REDWING_SEMVER\s*=\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$"#)
        )

        XCTAssertFalse(semver.hasPrefix("v"))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("VERSION").path),
            "Release version should stay centralized in Redwing/Config/Version.xcconfig."
        )

        let infoPlist = try String(
            contentsOf: rootURL.appendingPathComponent("Redwing/Resources/Info.plist"),
            encoding: .utf8
        )
        XCTAssertTrue(infoPlist.contains("<key>CFBundleShortVersionString</key>\n  <string>$(REDWING_SEMVER)</string>"))
        XCTAssertTrue(infoPlist.contains("<key>CFBundleVersion</key>\n  <string>$(REDWING_SEMVER)</string>"))

        let releaseScript = try String(
            contentsOf: rootURL.appendingPathComponent("release.sh"),
            encoding: .utf8
        )
        XCTAssertTrue(releaseScript.contains("VERSION_CONFIG=\"${ROOT_DIR}/Redwing/Config/Version.xcconfig\""))
        XCTAssertTrue(releaseScript.contains("REDWING_SEMVER"))
        XCTAssertTrue(releaseScript.contains("TAG_NAME=\"v${VERSION}\""))
    }

    func testReleaseScriptBuildsVersionedZipSignedTagAndGithubRelease() throws {
        let releaseScript = try String(
            contentsOf: repositoryRootURL().appendingPathComponent("release.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(releaseScript.contains("xcodebuild build"))
        XCTAssertTrue(releaseScript.contains("-configuration Release"))
        XCTAssertTrue(releaseScript.contains("git tag -s"))
        XCTAssertTrue(releaseScript.contains("git tag -v"))
        XCTAssertTrue(releaseScript.contains("git push \"${REMOTE}\" \"${TAG_NAME}\""))
        XCTAssertTrue(releaseScript.contains("${APP_NAME}-${VERSION}-macos-${ARCH_LABEL}.zip"))
        XCTAssertTrue(releaseScript.contains("ditto -c -k --norsrc --noextattr --keepParent"))
        XCTAssertTrue(releaseScript.contains("shasum -a 256"))
        XCTAssertTrue(releaseScript.contains("generate_release_notes"))
        XCTAssertTrue(releaseScript.contains("upload_asset \"${ZIP_PATH}\" \"application/zip\""))
        XCTAssertTrue(releaseScript.contains("upload_asset \"${SHA_PATH}\" \"text/plain\""))
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private extension String {
    func firstMatch(for pattern: String) throws -> String? {
        let expression = try NSRegularExpression(pattern: pattern)
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = expression.firstMatch(in: self, range: range),
              let captureRange = Range(match.range(at: 1), in: self) else {
            return nil
        }

        return String(self[captureRange])
    }
}
