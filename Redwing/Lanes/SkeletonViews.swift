import SwiftUI

struct SkeletonRowView: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .frame(width: 140, height: 10)

                RoundedRectangle(cornerRadius: 4)
                    .frame(width: 220, height: 10)
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading")
    }
}
