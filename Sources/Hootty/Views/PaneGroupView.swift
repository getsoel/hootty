import HoottyCore
import SwiftUI
import UniformTypeIdentifiers

struct PaneContentView: View {
    var pane: Pane
    let isFocused: Bool
    let tokens: DesignTokens
    var pipelineModel: PipelineModel
    let onFocusPane: () -> Void
    var onSplitPane: ((SplitDirection, Bool) -> Void)?
    var onClosePane: ((UUID) -> Void)?
    var onSwapPanes: ((UUID, UUID) -> Void)?
    let onSave: () -> Void
    var onSwitchToBoard: ((String?) -> Void)?
    var onPipelineRefresh: ((String) -> Void)?
    @State private var isDropTarget = false
    @Environment(\.sidebarHasFocus) private var sidebarHasFocus
    @Environment(\.sidebarCursorPaneID) private var sidebarCursorPaneID

    private var terminalHasFocus: Bool {
        isFocused && !sidebarHasFocus
    }

    var body: some View {
        VStack(spacing: 0) {
            PaneBar(
                pane: pane,
                isFocused: terminalHasFocus,
                tokens: tokens,
                onFocusPane: onFocusPane,
                onSplitPane: onSplitPane,
                onClosePane: onClosePane,
                onSave: onSave
            )

            if let claim = pipelineModel.claimInfo(for: pane.id) {
                PipelineBarView(
                    claimInfo: claim,
                    tokens: tokens,
                    onTogglePause: {
                        guard let repoRoot = pane.repoRoot else { return }
                        if pipelineModel.togglePause(repoRoot: repoRoot, pipelineName: claim.pipelineName) {
                            onPipelineRefresh?(repoRoot)
                        }
                    },
                    onClickPipelineName: {
                        onSwitchToBoard?(claim.pipelineName)
                    },
                    onAdvance: {
                        guard let repoRoot = pane.repoRoot else { return }
                        let nextIndex = claim.currentStageIndex + 1
                        if pipelineModel.moveJob(repoRoot: repoRoot, pipelineName: claim.pipelineName, jobSlug: claim.jobSlug, fromStageIndex: claim.currentStageIndex, toStageIndex: nextIndex, stages: claim.stages) {
                            onPipelineRefresh?(repoRoot)
                        }
                    },
                    onLoadJobBody: { slug in
                        guard let repoRoot = pane.repoRoot else { return nil }
                        return PipelineReader.readJobBody(repoRoot: repoRoot, pipelineName: claim.pipelineName, stages: claim.stages, jobSlug: slug)
                    }
                )
            }

            TerminalPaneView(pane: pane, isFocused: isFocused, onFocusPane: onFocusPane)
        }
        .overlay {
            if !terminalHasFocus {
                Color(tokens.unfocusedDimColor)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if let kind = pane.attentionKind, !terminalHasFocus {
                Color.clear
                    .glowBorder(
                        shape: Rectangle(),
                        color: Color(tokens.attentionColor(for: kind)),
                        lineWidth: 2,
                        glowRadius: 6
                    )
            } else if terminalHasFocus {
                Rectangle()
                    .stroke(Color(tokens.borderFocused), lineWidth: 2)
                    .allowsHitTesting(false)
            } else if sidebarHasFocus, sidebarCursorPaneID == pane.id {
                VStack(spacing: 0) {
                    Text("Press Enter to focus")
                        .font(.system(size: TypeScale.bodySize, weight: .medium))
                        .foregroundStyle(Color(tokens.text))
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(tokens.surface))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(tokens.borderFocused).opacity(0.5), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
        .overlay {
            if isDropTarget {
                Rectangle()
                    .stroke(Color(tokens.textAccent), lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onFocusPane()
        }
        .onDrop(of: [.utf8PlainText], isTargeted: $isDropTarget) { providers in
            let targetID = pane.id
            let swap = onSwapPanes
            guard let item = providers.first else { return false }
            item.loadItem(forTypeIdentifier: UTType.utf8PlainText.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let str = String(data: data, encoding: .utf8),
                      let sourceID = UUID(uuidString: str) else { return }
                DispatchQueue.main.async {
                    swap?(sourceID, targetID)
                }
            }
            return true
        }
    }
}
