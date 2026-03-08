import SwiftUI
import HoottyCore

struct PaneGroupView: View {
    @Bindable var group: PaneGroup
    let isFocused: Bool
    let tokens: DesignTokens
    let onFocusPaneGroup: (UUID) -> Void
    let onAddPane: () -> Void
    let onRemovePane: (UUID) -> Void
    var onSplitPane: ((SplitDirection, Bool) -> Void)?
    var onResumeClaudeSession: ((UUID) -> Void)?
    let onSave: () -> Void

    @State private var selectedTabGlobalFrame: CGRect?
    @State private var paneGroupGlobalFrame: CGRect = .zero
    @State private var scrollAreaGlobalFrame: CGRect = .zero

    var body: some View {
        VStack(spacing: 0) {
            PaneGroupTabBar(
                group: group,
                isFocused: isFocused,
                tokens: tokens,
                onFocusPaneGroup: { onFocusPaneGroup(group.id) },
                onAddPane: onAddPane,
                onRemovePane: onRemovePane,
                onSplitPane: onSplitPane,
                onResumeClaudeSession: onResumeClaudeSession,
                onSave: onSave,
                unifiedBorderPaneID: showUnifiedBorder ? group.selectedPaneID : nil,
                onSelectedTabFrameChange: { selectedTabGlobalFrame = $0 }
            )

            ZStack {
                ForEach(group.panes) { pane in
                    TerminalPaneView(pane: pane, isFocused: isFocused && pane.id == group.selectedPaneID)
                        .opacity(pane.id == group.selectedPaneID ? 1 : 0)
                        .allowsHitTesting(pane.id == group.selectedPaneID)
                }
            }
            .overlay {
                if showFallbackPaneBorder {
                    Color.clear
                        .animatedBorderSegment(shape: Rectangle(), color: Color(tokens.statusWarning), lineWidth: 2)
                }
            }
        }
        .overlay {
            if selectedPaneNeedsAttention, let tabLocalRect = selectedTabLocalRect {
                Color.clear
                    .animatedBorderSegment(shape: TabConnectedShape(tabRect: tabLocalRect), color: Color(tokens.statusWarning), lineWidth: 2)
            }
        }
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: PaneGroupFrameKey.self, value: geo.frame(in: .global))
            }
        }
        .onPreferenceChange(PaneGroupFrameKey.self) { paneGroupGlobalFrame = $0 }
        .onPreferenceChange(ScrollAreaFrameKey.self) { scrollAreaGlobalFrame = $0 }
        .contentShape(Rectangle())
        .onTapGesture {
            onFocusPaneGroup(group.id)
        }
    }

    private var selectedPaneNeedsAttention: Bool {
        group.selectedPane?.needsAttention ?? false
    }

    private var selectedTabLocalRect: CGRect? {
        guard let tabGlobal = selectedTabGlobalFrame,
              paneGroupGlobalFrame.width > 0,
              scrollAreaGlobalFrame.width > 0,
              tabGlobal.width > 0 else { return nil }

        // Clip tab frame to visible scroll area
        let clipped = tabGlobal.intersection(scrollAreaGlobalFrame)
        guard !clipped.isNull, clipped.width > 2 else { return nil }

        // Convert to VStack-local coordinates
        return CGRect(
            x: clipped.minX - paneGroupGlobalFrame.minX,
            y: clipped.minY - paneGroupGlobalFrame.minY,
            width: clipped.width,
            height: clipped.height
        )
    }

    private var showUnifiedBorder: Bool {
        selectedPaneNeedsAttention && selectedTabLocalRect != nil
    }

    private var showFallbackPaneBorder: Bool {
        selectedPaneNeedsAttention && selectedTabLocalRect == nil
    }
}
