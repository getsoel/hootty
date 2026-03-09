import SwiftUI
import HoottyCore
import LucideIcons

struct StatusDotView: View {
    let attentionKind: AttentionKind?
    let isRunning: Bool
    let isThinking: Bool
    let tokens: DesignTokens

    @State private var rotation: Double = 0

    var body: some View {
        if let kind = attentionKind {
            LucideIcon(Lucide.bell, size: 12)
                .foregroundStyle(Color(tokens.attentionColor(for: kind)))
        } else if isThinking {
            LucideIcon(Lucide.loaderCircle, size: 12)
                .foregroundStyle(Color(tokens.statusThinking))
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
        } else if isRunning {
            LucideIcon(Lucide.play, size: 12)
                .foregroundStyle(Color(tokens.statusSuccess))
        } else {
            Color.clear
                .frame(width: 12, height: 12)
        }
    }
}
