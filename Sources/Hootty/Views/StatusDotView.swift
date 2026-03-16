import HoottyCore
import SwiftUI

struct StatusDotView: View {
    let attentionKind: AttentionKind?
    let isThinking: Bool
    let tokens: DesignTokens

    var body: some View {
        Group {
            if attentionKind != nil {
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
            } else {
                Image(systemName: "apple.terminal")
                    .foregroundStyle(Color(tokens.textMuted))
            }
        }
        .font(.system(size: TypeScale.smallSize))
        .frame(width: TypeScale.iconSize)
    }
}
