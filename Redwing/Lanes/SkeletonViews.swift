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
        .modifier(SkeletonWaveModifier())
        .accessibilityLabel("Loading")
    }
}

struct SkeletonWaveModifier: ViewModifier {
    @State private var phase = -1.0

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.26),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(12))
                .offset(x: phase * 260)
                .blendMode(.plusLighter)
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}
