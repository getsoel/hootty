import HoottyCore
import SwiftUI

/// Compact bar showing Workshop status for a pane. Three display modes:
/// - Claimed with task group: [Change] > [Task Group] [3/7]
/// - Claimed change only: [Change] + artifact dots
/// - No claim: overview of all active changes with artifact dots
struct WorkshopBarView: View {
    let workshopModel: WorkshopModel
    let repoRoot: String
    let paneID: UUID
    let tokens: DesignTokens

    var body: some View {
        let claim = workshopModel.claim(forPaneID: paneID.uuidString)
        let status = workshopModel.status(for: repoRoot)
        let activeChanges = status?.changes.filter { !$0.isArchived } ?? []

        if claim != nil || !activeChanges.isEmpty {
            HStack(spacing: 0) {
                if let claim {
                    claimedView(claim)
                } else {
                    overviewView(activeChanges)
                }

                Spacer(minLength: 0)
            }
            .frame(height: Layout.barHeight)
            .frame(maxWidth: .infinity)
            .background(Color(tokens.surface))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(tokens.border)).frame(height: 1)
            }
        }
    }

    // MARK: - Claimed View

    private func claimedView(_ claim: WorkshopClaim) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "terminal")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textAccent))
                .padding(.leading, Spacing.lg)

            Text(WorkshopChange.formatName(claim.change))
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
                .lineLimit(1)

            if let taskGroup = claim.taskGroup {
                Image(systemName: "chevron.right")
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(tokens.textMuted).opacity(0.5))

                Text(taskGroup)
                    .font(.system(size: TypeScale.smallSize, weight: .medium))
                    .foregroundStyle(Color(tokens.text))
                    .lineLimit(1)

                let groups = workshopModel.taskGroups(forChange: claim.change)
                if let group = groups.first(where: { $0.name == taskGroup }) {
                    progressView(group)
                }
            } else {
                // Change-only claim — show artifact dots
                let status = workshopModel.status(for: repoRoot)
                if let change = status?.changes.first(where: { $0.name == claim.change }) {
                    artifactDots(change.artifacts)
                }
            }
        }
    }

    private func progressView(_ group: WorkshopTaskGroup) -> some View {
        Text("\(group.completed)/\(group.total)")
            .font(.system(size: TypeScale.smallSize, design: .monospaced))
            .foregroundStyle(Color(group.completed == group.total ? tokens.textMuted : tokens.textAccent))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(Color(tokens.surfaceHighlight).opacity(0.5))
            )
    }

    // MARK: - Overview (no claim)

    private func overviewView(_ changes: [WorkshopChange]) -> some View {
        HStack(spacing: 0) {
            Image(systemName: "doc.text")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
                .padding(.leading, Spacing.lg)

            HStack(spacing: Spacing.lg) {
                ForEach(Array(changes.prefix(3)), id: \.id) { change in
                    changeItem(change)
                }

                if changes.count > 3 {
                    Text("+\(changes.count - 3)")
                        .font(.system(size: TypeScale.smallSize))
                        .foregroundStyle(Color(tokens.textMuted))
                }
            }
            .padding(.leading, Spacing.md)
        }
    }

    private func changeItem(_ change: WorkshopChange) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(change.displayName)
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
                .lineLimit(1)

            artifactDots(change.artifacts)
        }
    }

    private func artifactDots(_ artifacts: [WorkshopArtifact]) -> some View {
        HStack(spacing: Spacing.xs) {
            ForEach(artifacts) { artifact in
                Circle()
                    .fill(dotColor(artifact.state))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func dotColor(_ state: WorkshopArtifactState) -> Color {
        switch state {
        case .done: Color(tokens.textMuted)
        case .ready: Color(tokens.textAccent)
        case .blocked: Color(tokens.textMuted).opacity(0.3)
        }
    }
}
