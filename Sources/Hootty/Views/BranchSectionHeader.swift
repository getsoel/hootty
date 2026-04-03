import AppKit
import HoottyCore
import SwiftUI

struct BranchSectionHeader: View {
    let section: SidebarSection
    let isSelected: Bool
    let focusedPaneID: UUID?
    let tokens: DesignTokens

    private var sectionCounts: AttentionCounts {
        AttentionCounts(panes: section.panes, focusedPaneID: focusedPaneID)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(isSelected ? tokens.text : tokens.textMuted))
                .frame(width: TreeLayout.columnWidth)

            if let displayLabel = section.displayLabel {
                let isWorktree = section.panes.contains { $0.worktreePath != nil }
                branchLabelView(displayLabel, repoDisplayName: section.repoDisplayName, isWorktree: isWorktree)
            } else {
                Text("No Branch")
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(tokens.textMuted).opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            sectionAttentionBadges
        }
        .padding(.vertical, Spacing.smd)
        .padding(.trailing, Spacing.md)
        .padding(.leading, Spacing.md + TreeLayout.columnWidth)
        .background(TreeLinesBackground(depth: 1, tokens: tokens))
        .contextMenu {
            if !section.isHead, let branch = section.branch,
               let worktreePath = section.panes.compactMap(\.worktreePath).first {
                Button("Copy merge prompt") {
                    let prompt = "Merge branch '\(branch)' into the main branch. The worktree is at \(worktreePath). Remove the worktree when done."
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(prompt, forType: .string)
                }
            }
        }
    }

    private var iconName: String {
        if section.branch == nil { return "cube.transparent" }
        return section.isHead ? "cube.fill" : "cube"
    }

    @ViewBuilder
    private var sectionAttentionBadges: some View {
        let counts = sectionCounts
        HStack(spacing: Spacing.xs) {
            if counts.thinking > 0 {
                sectionBadge(icon: "arrow.2.circlepath", count: counts.thinking, color: tokens.statusThinking)
            }
            if counts.done > 0 {
                sectionBadge(icon: "checkmark.circle", count: counts.done, color: tokens.statusDone)
            }
            if counts.bell > 0 {
                sectionBadge(icon: "bell", count: counts.bell, color: tokens.statusBell)
            }
        }
    }

    private func sectionBadge(icon: String, count: Int, color: NSColor) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            if count > 1 {
                Text("\(count)")
            }
        }
        .font(.system(size: TypeScale.smallSize, weight: .medium))
        .foregroundStyle(Color(color))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color(color).opacity(0.15))
        )
    }

    @ViewBuilder
    private func branchLabelView(_ displayLabel: String, repoDisplayName: String?, isWorktree: Bool = false) -> some View {
        let treeSuffix = isWorktree
            ? Text("@").foregroundStyle(Color(tokens.textMuted).opacity(0.5)) + Text("tree").foregroundStyle(Color(tokens.textTree))
            : Text("")
        if let repoName = repoDisplayName, let slashRange = displayLabel.range(of: "/") {
            let branchPart = String(displayLabel[slashRange.upperBound...])
            (Text(repoName).foregroundStyle(Color(tokens.textRepo))
                + Text("⎇").foregroundStyle(Color(tokens.textMuted).opacity(0.5))
                + Text(branchPart).foregroundStyle(Color(tokens.textBranch))
                + treeSuffix)
                .font(.system(size: TypeScale.bodySize))
                .lineLimit(1)
        } else {
            (Text(displayLabel).foregroundStyle(Color(tokens.textBranch))
                + treeSuffix)
                .font(.system(size: TypeScale.bodySize))
                .lineLimit(1)
        }
    }
}
