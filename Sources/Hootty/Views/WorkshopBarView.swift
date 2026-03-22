import HoottyCore
import SwiftUI

/// Compact bar showing Workshop status for a pane's repo:
/// - Claimed with task group: [Change] > [Task Group] [3/7]
/// - Claimed change only: [Change] + artifact pills
/// - No claim: [wrench] + claim menu to pick a change
/// Hidden when the repo has no active workshop changes.
struct WorkshopBarView: View {
    let workshopModel: WorkshopModel
    let repoRoot: String
    let paneID: UUID
    let tokens: DesignTokens
    var onEditArtifact: ((String, WorkshopArtifactID) -> Void)?

    var body: some View {
        let claim = workshopModel.claim(forPaneID: paneID.uuidString)
        let status = workshopModel.status(for: repoRoot)
        let activeChanges = status?.changes.filter { !$0.isArchived } ?? []

        if claim != nil || !activeChanges.isEmpty {
            HStack(spacing: 0) {
                if let claim {
                    claimedView(claim, activeChanges: activeChanges)
                } else {
                    unclaimedView(activeChanges)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: Layout.barHeight)
            .frame(maxWidth: .infinity)
            .background(Color(tokens.tabBarBackground))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(tokens.border)).frame(height: 1)
            }
        }
    }

    // MARK: - Claimed View

    private func claimedView(_ claim: WorkshopClaim, activeChanges: [WorkshopChange]) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textAccent))
                .padding(.leading, Spacing.lg)

            changeMenu(currentClaim: claim, activeChanges: activeChanges)

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
            }

            Spacer(minLength: 0)

            // Artifact pills aligned right
            let status = workshopModel.status(for: repoRoot)
            if let change = status?.changes.first(where: { $0.name == claim.change }) {
                artifactLabels(change.artifacts, changeName: change.name)
                    .padding(.trailing, Spacing.md)
            }
        }
    }

    /// Menu on the change name that allows switching or releasing the claim.
    private func changeMenu(currentClaim: WorkshopClaim, activeChanges: [WorkshopChange]) -> some View {
        Menu {
            ForEach(activeChanges) { change in
                Button {
                    workshopModel.writeClaim(repoRoot: repoRoot, paneID: paneID.uuidString, change: change.name)
                } label: {
                    HStack {
                        Text(change.displayName)
                        if change.name == currentClaim.change {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button("Release") {
                workshopModel.removeClaim(repoRoot: repoRoot, paneID: paneID.uuidString)
            }
        } label: {
            Text(WorkshopChange.formatName(currentClaim.change))
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Unclaimed View

    private func unclaimedView(_ activeChanges: [WorkshopChange]) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
                .padding(.leading, Spacing.lg)

            Menu {
                ForEach(activeChanges) { change in
                    Button(change.displayName) {
                        workshopModel.writeClaim(repoRoot: repoRoot, paneID: paneID.uuidString, change: change.name)
                    }
                }
            } label: {
                Text("Claim\u{2026}")
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(tokens.textMuted))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: - Progress

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

    // MARK: - Artifact Labels

    private func artifactLabels(_ artifacts: [WorkshopArtifact], changeName: String) -> some View {
        HStack(spacing: Spacing.xs) {
            ForEach(artifacts) { artifact in
                let isStale = workshopModel.isStale(changeName: changeName, artifactID: artifact.id)
                let color = isStale ? Color(tokens.statusWarning) : labelColor(artifact.state)

                if artifact.state == .done, onEditArtifact != nil {
                    Button {
                        onEditArtifact?(changeName, artifact.id)
                    } label: {
                        artifactPill(label: artifact.displayName, color: color)
                    }
                    .buttonStyle(.plain)
                } else {
                    artifactPill(label: artifact.displayName, color: color)
                }
            }
        }
    }

    private func artifactPill(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: TypeScale.captionSize, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
            .contentShape(Capsule())
    }

    private func labelColor(_ state: WorkshopArtifactState) -> Color {
        switch state {
        case .done: Color(tokens.textMuted)
        case .ready: Color(tokens.textAccent)
        case .blocked: Color(tokens.textMuted).opacity(0.3)
        }
    }
}
