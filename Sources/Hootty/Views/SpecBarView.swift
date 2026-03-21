import HoottyCore
import SwiftUI

/// Compact bar showing Spec status for a pane.
/// When the pane has a claimed task group, shows: [Change] > [Task Group] [3/7]
/// Otherwise shows artifact progress dots for active changes.
struct SpecBarView: View {
    let specModel: SpecModel
    let repoRoot: String
    let paneID: UUID
    let tokens: DesignTokens

    var body: some View {
        let claim = specModel.claim(forPaneID: paneID.uuidString)
        let status = specModel.status(for: repoRoot)
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

    // MARK: - Claimed Task View

    private func claimedView(_ claim: SpecClaim) -> some View {
        let groups = specModel.taskGroups(forChange: claim.change)
        let group = groups.first { $0.name == claim.taskGroup }

        return HStack(spacing: Spacing.sm) {
            Image(systemName: "terminal")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textAccent))
                .padding(.leading, Spacing.lg)

            Text(SpecChange.formatName(claim.change))
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.5))

            Text(claim.taskGroup)
                .font(.system(size: TypeScale.smallSize, weight: .medium))
                .foregroundStyle(Color(tokens.text))
                .lineLimit(1)

            if let group {
                progressView(group)
            }
        }
    }

    private func progressView(_ group: SpecTaskGroup) -> some View {
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

    private func overviewView(_ changes: [SpecChange]) -> some View {
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

    private func changeItem(_ change: SpecChange) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(change.displayName)
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
                .lineLimit(1)

            artifactDots(change.artifacts)
        }
    }

    private func artifactDots(_ artifacts: [SpecArtifact]) -> some View {
        HStack(spacing: Spacing.xs) {
            ForEach(artifacts) { artifact in
                Circle()
                    .fill(dotColor(artifact.state))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func dotColor(_ state: SpecArtifactState) -> Color {
        switch state {
        case .done: Color(tokens.textMuted)
        case .ready: Color(tokens.textAccent)
        case .blocked: Color(tokens.textMuted).opacity(0.3)
        }
    }
}
