import AppKit
import HoottyCore
import SwiftUI

struct BranchSectionHeader: View {
    let section: SidebarSection
    let tokens: DesignTokens

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
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
