import SwiftUI
import HoottyCore

struct PaneBar: View {
    let pane: Pane
    let isFocused: Bool
    let tokens: DesignTokens
    let onFocusPane: () -> Void
    var onSplitPane: ((SplitDirection, Bool) -> Void)?
    var onClosePane: ((UUID) -> Void)?
    var onSave: (() -> Void)?

    private enum HoveredElement: Equatable {
        case split
        case close
    }

    @State private var hovered: HoveredElement?
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""

    var body: some View {
        HStack(spacing: 0) {
            StatusDotView(attentionKind: pane.attentionKind, isThinking: pane.isThinking, tokens: tokens)
                .frame(maxHeight: .infinity)
                .padding(.leading, Spacing.md)

            Text(pane.displayName)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, Spacing.sm)

            Spacer(minLength: 0)

            if pane.branch != nil {
                branchLabel
            }

            if onSplitPane != nil || onClosePane != nil {
                actionGroup
            }
        }
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.tabBarBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
        .contentShape(Rectangle())
        .draggable(pane.id.uuidString)
        .onTapGesture {
            onFocusPane()
        }
        .contextMenu {
            Button("Rename Pane") {
                editingName = pane.displayName
                renameTargetID = pane.id
            }
        }
        .alert("Rename Pane", isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField("Pane name", text: $editingName)
            Button("OK") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
    }

    private var actionGroup: some View {
        HStack(spacing: Spacing.xs) {
            if onSplitPane != nil {
                Menu {
                    Button("Split Right") { onSplitPane?(.horizontal, false) }
                    Button("Split Down") { onSplitPane?(.vertical, false) }
                    Divider()
                    Button("Split Left") { onSplitPane?(.horizontal, true) }
                    Button("Split Up") { onSplitPane?(.vertical, true) }
                } label: {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: TypeScale.smallSize))
                        .foregroundStyle(Color(tokens.textMuted))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(RoundedRectangle(cornerRadius: 4).fill(hovered == .split ? Color(tokens.elementHover) : Color.clear))
                        .contentShape(RoundedRectangle(cornerRadius: 4))
                        .onContinuousHover { phase in
                            switch phase {
                            case .active:
                                hovered = .split
                                DispatchQueue.main.async { NSCursor.pointingHand.set() }
                            case .ended:
                                if hovered == .split { hovered = nil }
                            @unknown default: break
                            }
                        }
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .accessibilityLabel("Split pane")
            }

            if onClosePane != nil {
                Button {
                    onClosePane?(pane.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: TypeScale.smallSize))
                        .foregroundStyle(Color(tokens.textMuted))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(RoundedRectangle(cornerRadius: 4).fill(hovered == .close ? Color(tokens.elementHover) : Color.clear))
                        .contentShape(RoundedRectangle(cornerRadius: 4))
                        .onContinuousHover { phase in
                            switch phase {
                            case .active:
                                hovered = .close
                                DispatchQueue.main.async { NSCursor.pointingHand.set() }
                            case .ended:
                                if hovered == .close { hovered = nil }
                            @unknown default: break
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close pane")
            }
        }
        .padding(Spacing.smd)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color(tokens.border)).frame(width: 1)
        }
    }

    @ViewBuilder
    private var branchLabel: some View {
        if let branch = pane.branch {
            branchText(repo: pane.repoName, branch: branch)
                .font(.system(size: TypeScale.bodySize))
                .lineLimit(1)
                .truncationMode(.head)
                .padding(.trailing, Spacing.md)
        }
    }

    private func branchText(repo: String?, branch: String) -> Text {
        let branchPart = Text(branch).foregroundStyle(Color(tokens.textBranch))
        guard let repo else { return branchPart }
        let repoPart = Text(repo).foregroundStyle(Color(tokens.textRepo))
        let sep = Text("⎇").foregroundStyle(Color(tokens.textMuted).opacity(0.5))
        return repoPart + sep + branchPart
    }

    private func commitRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            pane.customName = trimmed
            onSave?()
        }
        renameTargetID = nil
    }
}
