import SwiftUI
import HoottyCore
import LucideIcons

struct StatusDotView: View {
    let attentionKind: AttentionKind?
    let isRunning: Bool
    let tokens: DesignTokens

    var body: some View {
        if let kind = attentionKind {
            LucideIcon(Lucide.bell, size: 12)
                .foregroundStyle(Color(tokens.attentionColor(for: kind)))
        } else if isRunning {
            LucideIcon(Lucide.play, size: 12)
                .foregroundStyle(Color(tokens.statusSuccess))
        } else {
            Color.clear
                .frame(width: 12, height: 12)
        }
    }
}
