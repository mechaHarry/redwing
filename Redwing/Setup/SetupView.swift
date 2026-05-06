import SwiftUI

struct SetupView: View {
    let onAuthorize: (SetupCredentials) -> Void

    @State private var credentials = SetupCredentials(
        clientID: "",
        clientSecret: "",
        redirectURI: "http://127.0.0.1:8282/oauth/callback",
        scopesText: "spark:all spark:kms"
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Webex Setup")
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Client ID") {
                    TextField("Client ID", text: $credentials.clientID)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Client Secret") {
                    SecureField("Client Secret", text: $credentials.clientSecret)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Redirect URI") {
                    TextField("Redirect URI", text: $credentials.redirectURI)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Scopes") {
                    TextField("Scopes", text: $credentials.scopesText)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                Spacer()
                Button("Authorize") {
                    onAuthorize(credentials)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(minWidth: 520, idealWidth: 620, maxWidth: 720, alignment: .topLeading)
    }
}
