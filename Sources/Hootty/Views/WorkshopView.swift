import HoottyCore
import SwiftUI

struct WorkshopView: View {
    @Bindable var appModel: AppModel
    let tokens: DesignTokens

    @State private var repoFilter: String?
    /// Compound key "repoRoot|changeName" to avoid cross-repo collisions.
    @State private var expandedChangeKey: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Color(tokens.background))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            Text("Changes")
                .font(.system(size: TypeScale.captionSize, weight: .semibold))
                .foregroundStyle(Color(tokens.textMuted))
                .padding(.leading, Spacing.lg)

            Spacer()

            repoFilterPicker
                .padding(.trailing, Spacing.md)
        }
        .frame(height: Layout.barHeight)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.tabBarBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    private var repoFilterPicker: some View {
        let repos = allRepoRoots
        return Group {
            if repos.count > 1 {
                HStack(spacing: Spacing.sm) {
                    Text("Repo:")
                        .font(.system(size: TypeScale.captionSize))
                        .foregroundStyle(Color(tokens.textMuted))

                    Picker("", selection: $repoFilter) {
                        Text("All").tag(nil as String?)
                        ForEach(repos, id: \.self) { repo in
                            Text(repoDisplayName(repo))
                                .tag(repo as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 200)
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let repos = allRepoRoots
        let entries = filteredEntries(repos: repos)
        if entries.isEmpty {
            emptyState
        } else {
            let showRepoHeader = repos.count > 1
            ScrollView {
                LazyVStack(spacing: Spacing.lg) {
                    ForEach(entries, id: \.repoRoot) { entry in
                        repoSection(entry: entry, showRepoHeader: showRepoHeader)
                    }
                }
                .padding(Spacing.lg)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: TypeScale.iconSize * 2))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.4))
            Text("No active changes")
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted))
            Text("Run `hootty workshop init` in a repo to get started")
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Repo Section

    private func repoSection(entry: RepoEntry, showRepoHeader: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if showRepoHeader {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: TypeScale.smallSize))
                        .foregroundStyle(Color(tokens.textMuted))
                    Text(repoDisplayName(entry.repoRoot))
                        .font(.system(size: TypeScale.captionSize, weight: .medium))
                        .foregroundStyle(Color(tokens.text))
                    Spacer()
                }
            }

            ForEach(entry.changes) { change in
                let key = "\(entry.repoRoot)|\(change.name)"
                WorkshopChangeCard(
                    change: change,
                    tokens: tokens,
                    isExpanded: expandedChangeKey == key,
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            expandedChangeKey = expandedChangeKey == key ? nil : key
                        }
                    },
                    onReadArtifact: { artifactID in
                        appModel.workshopModel.readArtifactContent(
                            repoRoot: entry.repoRoot,
                            changeName: change.name,
                            artifactID: artifactID
                        )
                    }
                )
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusMd)
                .fill(Color(tokens.surface))
        )
    }

    // MARK: - Data

    private var allRepoRoots: [String] {
        Array(appModel.workshopModel.statusByRepo.keys).sorted()
    }

    private func filteredEntries(repos: [String]) -> [RepoEntry] {
        let filtered: [String] = if let filter = repoFilter {
            [filter]
        } else {
            repos
        }

        return filtered.compactMap { repo in
            let status = appModel.workshopModel.status(for: repo)
            guard let status, !status.changes.isEmpty else { return nil }
            return RepoEntry(repoRoot: repo, changes: status.changes)
        }
    }

    private func repoDisplayName(_ repoRoot: String) -> String {
        URL(fileURLWithPath: repoRoot).lastPathComponent
    }
}

// MARK: - Data Types

private struct RepoEntry {
    let repoRoot: String
    let changes: [WorkshopChange]
}

// MARK: - Change Card

private struct WorkshopChangeCard: View {
    let change: WorkshopChange
    let tokens: DesignTokens
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onReadArtifact: (WorkshopArtifactID) -> String?

    @State private var hoveredArtifactID: WorkshopArtifactID?
    @State private var selectedArtifact: SelectedArtifact?

    private struct SelectedArtifact: Equatable {
        let id: WorkshopArtifactID
        let content: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            if isExpanded {
                cardDetail
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusMd)
                .fill(Color(tokens.surfaceHighlight).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusMd)
                .stroke(Color(tokens.border).opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var cardHeader: some View {
        Button {
            onToggleExpand()
        } label: {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        Text(change.displayName)
                            .font(.system(size: TypeScale.bodySize, weight: .medium))
                            .foregroundStyle(Color(change.isArchived ? tokens.textMuted : tokens.text))

                        if change.isArchived {
                            Text("archived")
                                .font(.system(size: TypeScale.smallSize))
                                .foregroundStyle(Color(tokens.textMuted))
                                .padding(.horizontal, Spacing.sm)
                                .background(
                                    Capsule().fill(Color(tokens.surfaceHighlight))
                                )
                        }
                    }

                    artifactProgressDots
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(tokens.textMuted))
            }
            .padding(Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var artifactProgressDots: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(change.artifacts) { artifact in
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(artifactColor(state: artifact.state))
                        .frame(width: 6, height: 6)
                    Text(artifact.displayName)
                        .font(.system(size: TypeScale.smallSize))
                        .foregroundStyle(Color(artifact.state == .blocked ? tokens.textMuted.withAlphaComponent(0.5) : tokens.textMuted))
                }
            }
        }
    }

    private func artifactColor(state: WorkshopArtifactState) -> Color {
        switch state {
        case .done: Color(tokens.textMuted)
        case .ready: Color(tokens.textAccent)
        case .blocked: Color(tokens.textMuted).opacity(0.3)
        }
    }

    // MARK: - Detail

    private var cardDetail: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)

            artifactDAG

            if let selected = selectedArtifact {
                artifactContentPreview(content: selected.content)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - DAG Visualization

    // Layout is hardcoded to the workshop-driven schema:
    //   [Proposal] → [Specs]  → [Tasks]
    //              → [Design] ↗

    private var artifactDAG: some View {
        let proposal = change.artifacts.first { $0.id == .proposal }
        let specs = change.artifacts.first { $0.id == .specs }
        let design = change.artifacts.first { $0.id == .design }
        let tasks = change.artifacts.first { $0.id == .tasks }

        return HStack(spacing: 0) {
            if let proposal {
                artifactNode(proposal)
            }

            dagArrow

            VStack(spacing: Spacing.sm) {
                if let specs {
                    artifactNode(specs)
                }
                if let design {
                    artifactNode(design)
                }
            }

            dagArrow

            if let tasks {
                artifactNode(tasks)
            }

            Spacer()
        }
    }

    private func artifactNode(_ artifact: WorkshopArtifact) -> some View {
        let isHovered = hoveredArtifactID == artifact.id
        let isSelected = selectedArtifact?.id == artifact.id

        return Button {
            if artifact.state == .done {
                if isSelected {
                    selectedArtifact = nil
                } else if let content = onReadArtifact(artifact.id) {
                    selectedArtifact = SelectedArtifact(id: artifact.id, content: content)
                }
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                artifactStateIcon(artifact.state)
                Text(artifact.displayName)
                    .font(.system(size: TypeScale.captionSize, weight: .medium))
                    .foregroundStyle(Color(artifact.state == .blocked ? tokens.textMuted.withAlphaComponent(0.5) : tokens.text))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadiusSm)
                    .fill(nodeBackground(state: artifact.state, isHovered: isHovered, isSelected: isSelected))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadiusSm)
                    .stroke(isSelected ? Color(tokens.textAccent).opacity(0.5) : Color(tokens.border).opacity(0.3), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredArtifactID = hovering ? artifact.id : nil
        }
        .disabled(artifact.state != .done)
    }

    private func artifactStateIcon(_ state: WorkshopArtifactState) -> some View {
        Group {
            switch state {
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(tokens.textMuted))
            case .ready:
                Image(systemName: "circle.dotted")
                    .foregroundStyle(Color(tokens.textAccent))
            case .blocked:
                Image(systemName: "circle")
                    .foregroundStyle(Color(tokens.textMuted).opacity(0.3))
            }
        }
        .font(.system(size: TypeScale.captionSize))
    }

    private func nodeBackground(state: WorkshopArtifactState, isHovered: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return Color(tokens.elementSelected)
        }
        if isHovered, state == .done {
            return Color(tokens.surfaceHighlight).opacity(0.5)
        }
        return Color(tokens.surface)
    }

    private var dagArrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: TypeScale.smallSize))
            .foregroundStyle(Color(tokens.textMuted).opacity(0.3))
            .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Content Preview

    private func artifactContentPreview(content: String) -> some View {
        ScrollView {
            Text(content)
                .font(.system(size: TypeScale.captionSize, design: .monospaced))
                .foregroundStyle(Color(tokens.text))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 200)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusSm)
                .fill(Color(tokens.surface))
        )
    }
}
