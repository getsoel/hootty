import HoottyCore
import SwiftUI

struct StatusDotView: View {
    let attentionKind: AttentionKind?
    let isThinking: Bool
    let isClaudeSession: Bool
    let tokens: DesignTokens

    var body: some View {
        Group {
            if attentionKind == .done {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Color(tokens.statusDone))
            } else if attentionKind == .bell {
                Image(systemName: "bell")
                    .foregroundStyle(Color(tokens.statusBell))
            } else if isThinking {
                TimelineView(.animation) { context in
                    let cycle = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 1.5) / 1.5 * 360
                    Image(systemName: "arrow.2.circlepath")
                        .foregroundStyle(Color(tokens.statusThinking))
                        .rotationEffect(.degrees(cycle))
                }
            } else if isClaudeSession {
                Image(systemName: "bubble.left")
                    .foregroundStyle(Color(tokens.textMuted))
            } else {
                Image(systemName: "apple.terminal")
                    .foregroundStyle(Color(tokens.textMuted))
            }
        }
        .font(.system(size: TypeScale.smallSize))
        .frame(width: TypeScale.iconSize)
    }
}
