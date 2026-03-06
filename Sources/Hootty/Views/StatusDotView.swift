import SwiftUI
import HoottyCore
import LucideIcons

struct StatusDotView: View {
    let needsAttention: Bool
    let isRunning: Bool
    let tokens: DesignTokens

    var body: some View {
        if needsAttention {
            LucideIcon(Lucide.bell, size: 10)
                .foregroundStyle(Color(tokens.statusWarning))
                .modifier(PulseModifier())
        } else if isRunning {
            LucideIcon(Lucide.play, size: 10)
                .foregroundStyle(Color(tokens.statusSuccess))
        } else {
            Color.clear
                .frame(width: 10, height: 10)
        }
    }
}
