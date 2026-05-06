import Foundation

struct SetupCredentials: Equatable {
    var clientID: String
    var clientSecret: String
    var redirectURI: String
    var scopesText: String

    var scopes: [String] {
        scopesText
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map(String.init)
    }
}
