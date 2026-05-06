import Foundation

enum SetupValidation {
    enum ValidationError: Error, Equatable, CustomStringConvertible {
        case missingClientID
        case missingClientSecret
        case invalidRedirectURI
        case missingRequiredScopes([String])

        var description: String {
            switch self {
            case .missingClientID:
                return "Client ID is required"
            case .missingClientSecret:
                return "Client secret is required"
            case .invalidRedirectURI:
                return "Redirect URI must be a valid URL"
            case .missingRequiredScopes(let scopes):
                return "Missing required scopes: \(scopes.joined(separator: " "))"
            }
        }
    }

    static let requiredRealtimeScopes = ["spark:all", "spark:kms"]

    static func validate(_ credentials: SetupCredentials) throws {
        guard !credentials.clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingClientID
        }

        guard !credentials.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingClientSecret
        }

        guard let url = URL(string: credentials.redirectURI),
              url.scheme != nil,
              url.host != nil else {
            throw ValidationError.invalidRedirectURI
        }

        let scopeSet = Set(credentials.scopes)
        let missingScopes = requiredRealtimeScopes.filter { !scopeSet.contains($0) }
        guard missingScopes.isEmpty else {
            throw ValidationError.missingRequiredScopes(missingScopes)
        }
    }
}
