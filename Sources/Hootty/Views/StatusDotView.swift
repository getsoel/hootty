import SwiftUI
import HoottyCore

struct StatusDotView: View {
    let attentionKind: AttentionKind?
    let isThinking: Bool
    let tokens: DesignTokens

    @State private var rotation: Double = 0

    var body: some View {
        Group {
            if attentionKind != nil {
                Image(systemName: "bell")
                    .foregroundStyle(Color(tokens.statusBell))
            } else if isThinking {
                Image(systemName: "arrow.2.circlepath")
                    .foregroundStyle(Color(tokens.statusThinking))
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
            } else {
                Image(systemName: "apple.terminal")
                    .foregroundStyle(Color(tokens.textMuted))
            }
        }
        .font(.system(size: TypeScale.smallSize))
        .frame(width: TypeScale.iconSize)
    }
}
