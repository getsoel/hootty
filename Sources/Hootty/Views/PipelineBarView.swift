import HoottyCore
import SwiftUI

struct PipelineBarView: View {
    let claimInfo: PipelineClaimInfo
    let tokens: DesignTokens
    var onRelease: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onClickPipelineName: (() -> Void)?
    var onAdvance: (() -> Void)?
    var onLoadJobBody: ((String) -> String?)?

    @State private var closeHovered = false
    @State private var pauseHovered = false
    @State private var pipelineNameHovered = false
    @State private var titleHovered = false
    @State private var showJobPopover = false
    @State private var loadedJobBody: String?

    var body: some View {
        HStack(spacing: 0) {
            pipelineLabel
                .padding(.leading, Spacing.md)

            Spacer(minLength: Spacing.md)

            stageDots
                .padding(.trailing, Spacing.md)

            stageNameLabel
                .padding(.trailing, Spacing.md)

            if onTogglePause != nil {
                pausePlayButton
            }

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
        .help(barTooltip)
    }

    // MARK: - Pipeline Label

    private var pipelineLabel: some View {
        HStack(spacing: Spacing.sm) {
            Text(claimInfo.pipelineDisplayName)
                .foregroundStyle(Color(pipelineNameHovered ? tokens.textAccent : tokens.textMuted))
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        pipelineNameHovered = true
                        DispatchQueue.main.async { NSCursor.pointingHand.set() }
                    case .ended:
                        pipelineNameHovered = false
                    @unknown default: break
                    }
                }
                .onTapGesture { onClickPipelineName?() }

            Text("›")
                .foregroundStyle(Color(tokens.textMuted).opacity(0.5))

            Text(claimInfo.jobTitle)
                .foregroundStyle(Color(titleHovered ? tokens.textAccent : tokens.text))
                .lineLimit(1)
                .truncationMode(.tail)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        titleHovered = true
                        DispatchQueue.main.async { NSCursor.pointingHand.set() }
                    case .ended:
                        titleHovered = false
                    @unknown default: break
                    }
                }
                .onTapGesture {
                    loadedJobBody = onLoadJobBody?(claimInfo.jobSlug)
                    showJobPopover = true
                }
                .popover(isPresented: $showJobPopover) {
                    jobBodyPopover
                }
        }
        .font(.system(size: TypeScale.captionSize))
    }

    // MARK: - Job Body Popover

    private var jobBodyPopover: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(claimInfo.jobTitle)
                    .font(.system(size: TypeScale.bodySize, weight: .medium))
                    .foregroundStyle(Color(tokens.text))
                Spacer()
                Text(claimInfo.jobSlug)
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(tokens.textMuted))
            }

            if let body = loadedJobBody, !body.isEmpty {
                Rectangle().fill(Color(tokens.border)).frame(height: 1)

                ScrollView {
                    Text(body)
                        .font(.system(size: TypeScale.captionSize))
                        .foregroundStyle(Color(tokens.text))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            } else {
                Text("No prompt body")
                    .font(.system(size: TypeScale.captionSize))
                    .foregroundStyle(Color(tokens.textMuted))
            }
        }
        .padding(Spacing.md)
        .frame(width: 340)
        .background(Color(tokens.surface))
    }

    // MARK: - Stage Dots

    private var stageDots: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(Array(claimInfo.stages.enumerated()), id: \.offset) { index, stage in
                stageDot(index: index, stage: stage)
            }
        }
    }

    private func stageDot(index: Int, stage: PipelineStageDef) -> some View {
        let canAdvance = index == claimInfo.currentStageIndex + 1
            && claimInfo.status == .interrupted
            && onAdvance != nil

        return Circle()
            .fill(dotColor(for: index))
            .frame(width: 6, height: 6)
            .overlay {
                if index > claimInfo.currentStageIndex {
                    Circle()
                        .stroke(Color(tokens.textMuted).opacity(0.3), lineWidth: 1)
                }
            }
            .help("\(stage.name) (\(stage.type.rawValue))")
            .contentShape(Circle().scale(2))
            .onTapGesture {
                if canAdvance { onAdvance?() }
            }
    }

    private func dotColor(for index: Int) -> Color {
        if index < claimInfo.currentStageIndex {
            Color(tokens.textMuted)
        } else if index == claimInfo.currentStageIndex {
            if claimInfo.status == .interrupted {
                Color(tokens.statusWarning)
            } else {
                Color(tokens.textAccent)
            }
        } else {
            .clear
        }
    }

    // MARK: - Stage Name

    private var stageNameLabel: some View {
        let stage = claimInfo.stages[safe: claimInfo.currentStageIndex]
        return Text(stage?.name ?? "")
            .font(.system(size: TypeScale.captionSize))
            .foregroundStyle(Color(tokens.textMuted))
            .help(stage?.command ?? "")
    }

    // MARK: - Pause/Play Button

    private var pausePlayButton: some View {
        Button {
            onTogglePause?()
        } label: {
            Image(systemName: claimInfo.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color(tokens.textMuted))
                .frame(width: 20, height: 20)
                .background(RoundedRectangle(cornerRadius: 4).fill(pauseHovered ? Color(tokens.elementHover) : Color.clear))
                .contentShape(RoundedRectangle(cornerRadius: 4))
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        pauseHovered = true
                        DispatchQueue.main.async { NSCursor.pointingHand.set() }
                    case .ended:
                        pauseHovered = false
                    @unknown default: break
                    }
                }
        }
        .buttonStyle(.plain)
        .help(claimInfo.isPaused ? "Resume pipeline" : "Pause pipeline")
    }

    // MARK: - Release Button

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
        .help("Release pipeline claim")
        .padding(.trailing, Spacing.smd)
    }

    // MARK: - Helpers

    private var barTooltip: String {
        let stage = claimInfo.stages[safe: claimInfo.currentStageIndex]
        var parts = [
            "\(claimInfo.pipelineDisplayName) › \(claimInfo.jobTitle)",
            "Stage: \(stage?.name ?? "unknown") (\(claimInfo.status.rawValue))"
        ]
        if claimInfo.isPaused { parts.append("Pipeline is paused") }
        return parts.joined(separator: "\n")
    }
}
