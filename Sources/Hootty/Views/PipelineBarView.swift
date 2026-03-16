import HoottyCore
import SwiftUI

struct PipelineBarView: View {
    let claimInfo: PipelineClaimInfo
    let tokens: DesignTokens
    var onRelease: (() -> Void)?

    @State private var closeHovered = false

    var body: some View {
        HStack(spacing: 0) {
            pipelineLabel
                .padding(.leading, Spacing.md)

            Spacer(minLength: Spacing.md)

            stageDots
                .padding(.trailing, Spacing.md)

            stageNameLabel
                .padding(.trailing, Spacing.md)

            if onRelease != nil {
                releaseButton
            }
        }
        .frame(height: 28)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.surface))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    private var pipelineLabel: some View {
        HStack(spacing: Spacing.sm) {
            Text(claimInfo.pipelineName)
                .foregroundStyle(Color(tokens.textMuted))
            Text("›")
                .foregroundStyle(Color(tokens.textMuted).opacity(0.5))
            Text(claimInfo.jobTitle)
                .foregroundStyle(Color(tokens.text))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.system(size: TypeScale.captionSize))
    }

    private var stageDots: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(Array(claimInfo.stages.enumerated()), id: \.offset) { index, stage in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: 6, height: 6)
                    .overlay {
                        if index > claimInfo.currentStageIndex {
                            Circle()
                                .stroke(Color(tokens.textMuted).opacity(0.3), lineWidth: 1)
                        }
                    }
                    .help("\(stage.name) (\(stage.type.rawValue))")
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        if index < claimInfo.currentStageIndex {
            // Completed stage
            Color(tokens.textMuted)
        } else if index == claimInfo.currentStageIndex {
            // Current stage
            if claimInfo.status == .interrupted {
                Color(tokens.statusWarning)
            } else {
                Color(tokens.textAccent)
            }
        } else {
            // Future stage — outline only, fill transparent
            .clear
        }
    }

    private var stageNameLabel: some View {
        let stage = claimInfo.stages[safe: claimInfo.currentStageIndex]
        return Text(stage?.name ?? "")
            .font(.system(size: TypeScale.captionSize))
            .foregroundStyle(Color(tokens.textMuted))
            .help(stage?.command ?? "")
    }

    private var releaseButton: some View {
        Button {
            onRelease?()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9))
                .foregroundStyle(Color(tokens.textMuted))
                .frame(width: 20, height: 20)
                .background(RoundedRectangle(cornerRadius: 4).fill(closeHovered ? Color(tokens.elementHover) : Color.clear))
                .contentShape(RoundedRectangle(cornerRadius: 4))
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        closeHovered = true
                        DispatchQueue.main.async { NSCursor.pointingHand.set() }
                    case .ended:
                        closeHovered = false
                    @unknown default: break
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Release pipeline claim")
        .padding(.trailing, Spacing.smd)
    }
}
