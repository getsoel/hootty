import SwiftUI
import HoottyCore
import LucideIcons

struct StatusDotView: View {
    let needsAttention: Bool
    let isRunning: Bool
    let tokens: DesignTokens

    var body: some View {
        if needsAttention {
            LucideIcon(Lucide.bell, size: 12)
                .foregroundStyle(Color(tokens.statusWarning))
        } else if isRunning {
            LucideIcon(Lucide.play, size: 12)
                .foregroundStyle(Color(tokens.statusSuccess))
        } else {
            Color.clear
                .frame(width: 12, height: 12)
        }
    }
}
