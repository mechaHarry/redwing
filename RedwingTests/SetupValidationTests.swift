import XCTest
@testable import Redwing

final class SetupValidationTests: XCTestCase {
    func testValidCredentialsPass() {
        let credentials = SetupCredentials(
            clientID: "client-id",
            clientSecret: "secret",
            redirectURI: "http://127.0.0.1:8282/oauth/callback",
            scopesText: "spark:all spark:kms"
        )

        XCTAssertNoThrow(try SetupValidation.validate(credentials))
    }

    func testMissingSecretFailsWithoutEchoingSecretValue() {
        let credentials = SetupCredentials(
            clientID: "client-id",
            clientSecret: "   ",
            redirectURI: "http://127.0.0.1:8282/oauth/callback",
            scopesText: "spark:all spark:kms"
        )

        XCTAssertThrowsError(try SetupValidation.validate(credentials)) { error in
            XCTAssertEqual(error as? SetupValidation.ValidationError, .missingClientSecret)
            XCTAssertEqual(String(describing: error), "Client secret is required")
        }
    }

    func testRealtimeScopesAreRequired() {
        let credentials = SetupCredentials(
            clientID: "client-id",
            clientSecret: "secret",
            redirectURI: "http://127.0.0.1:8282/oauth/callback",
            scopesText: "spark:messages_read"
        )

        XCTAssertThrowsError(try SetupValidation.validate(credentials)) { error in
            XCTAssertEqual(error as? SetupValidation.ValidationError, .missingRequiredScopes(["spark:all", "spark:kms"]))
        }
    }

    func testInvalidRedirectURIFails() {
        let credentials = SetupCredentials(
            clientID: "client-id",
            clientSecret: "secret",
            redirectURI: "not a url",
            scopesText: "spark:all spark:kms"
        )

        XCTAssertThrowsError(try SetupValidation.validate(credentials)) { error in
            XCTAssertEqual(error as? SetupValidation.ValidationError, .invalidRedirectURI)
        }
    }

    func testValidationErrorsDoNotEchoSubmittedSecretValue() {
        let submittedSecret = "submitted-client-secret-value"
        let credentials = SetupCredentials(
            clientID: "client-id",
            clientSecret: submittedSecret,
            redirectURI: "not a url",
            scopesText: "spark:all spark:kms"
        )

        XCTAssertThrowsError(try SetupValidation.validate(credentials)) { error in
            XCTAssertFalse(String(describing: error).contains(submittedSecret))
        }
    }
}
