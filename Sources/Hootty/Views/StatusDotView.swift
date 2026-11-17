import HoottyCore
import SwiftUI

struct StatusDotView: View {
    let attentionKind: AttentionKind?
    let isThinking: Bool
    let isAgentSession: Bool
    /// Known completion (0–100) while thinking: drawn as a ring instead of the spinner.
    var progress: Int?
    let tokens: DesignTokens

    var body: some View {
        Group {
            if attentionKind == .blocked {
                Image(systemName: "hand.raised")
                    .foregroundStyle(Color(tokens.statusBlocked))
            } else if attentionKind == .error {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Color(tokens.statusError))
            } else if attentionKind == .done {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Color(tokens.statusDone))
            } else if attentionKind == .bell {
                Image(systemName: "bell")
                    .foregroundStyle(Color(tokens.statusBell))
            } else if isThinking, let progress {
                ZStack {
                    Circle().stroke(Color(tokens.statusThinking).opacity(0.25), lineWidth: 1.5)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress) / 100)
                        .stroke(Color(tokens.statusThinking), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .padding(2)
                .accessibilityLabel("Working \(progress) percent")
            } else if isThinking {
                TimelineView(.animation) { context in
                    let cycle = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 1.5) / 1.5 * 360
                    Image(systemName: "arrow.2.circlepath")
                        .foregroundStyle(Color(tokens.statusThinking))
                        .rotationEffect(.degrees(cycle))
                }
            } else if isAgentSession {
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
