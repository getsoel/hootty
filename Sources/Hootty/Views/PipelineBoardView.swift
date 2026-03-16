import HoottyCore
import SwiftUI

struct PipelineBoardView: View {
    let boardData: PipelineBoardData
    let tokens: DesignTokens
    var highlightedJobSlug: String?
    var onTogglePause: (() -> Void)?
    var onMoveJob: ((_ jobSlug: String, _ fromStageIndex: Int, _ toStageIndex: Int) -> Void)?
    var onAddJob: ((_ title: String, _ stageIndex: Int) -> Void)?
    var onRemoveJob: ((_ jobSlug: String) -> Void)?
    var onClickClaimed: ((_ sessionKey: String) -> Void)?
    var onLoadJobBody: ((_ jobSlug: String) -> String?)?
    var onLoadFullContent: ((_ jobSlug: String) -> String?)?
    var onUpdateTitle: ((_ jobSlug: String, _ newTitle: String) -> Void)?
    var onAddStage: ((_ name: String, _ type: PipelineStageDef.StageType, _ afterIndex: Int?) -> Void)?
    var onRemoveStage: ((_ stageIndex: Int) -> Void)?
    var onChangeStageType: ((_ stageIndex: Int, _ newType: PipelineStageDef.StageType) -> Void)?
    var onClaimInWorktree: ((_ jobSlug: String) -> Void)?
    var onArchive: (() -> Void)?

    @State private var selectedJob: PipelineJobInfo?
    @State private var showArchive = false
    @State private var addingJobInStage: Int?
    @State private var newJobTitle: String = ""
    @State private var hoveredPauseButton = false
    @State private var hoveredArchiveButton = false
    @State private var dropTargetStage: Int?

    var body: some View {
        VStack(spacing: 0) {
            boardHeader
            boardColumns
            if !boardData.archivedJobs.isEmpty {
                archiveSection
            }
        }
        .background(Color(tokens.background))
        .sheet(item: $selectedJob) { job in
            JobDetailSheet(
                job: job,
                boardData: boardData,
                tokens: tokens,
                fullContent: onLoadFullContent?(job.slug),
                onMoveJob: onMoveJob,
                onRemoveJob: onRemoveJob,
                onClickClaimed: onClickClaimed,
                onUpdateTitle: onUpdateTitle,
                onDismiss: { selectedJob = nil }
            )
        }
    }

    // MARK: - Header

    private var boardHeader: some View {
        HStack(spacing: Spacing.md) {
            Text(boardData.displayName)
                .font(.system(size: TypeScale.bodySize, weight: .medium))
                .foregroundStyle(Color(tokens.text))

            if boardData.isPaused {
                Text("Paused")
                    .font(.system(size: TypeScale.captionSize))
                    .foregroundStyle(Color(tokens.statusWarning))
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(tokens.statusWarning).opacity(0.15))
                    )
            }

            jobCountSummary

            Spacer()

            if onArchive != nil {
                archiveButton
            }

            if onTogglePause != nil {
                pausePlayButton
            }
        }
        .padding(.horizontal, Spacing.lg)
        .frame(height: 38)
        .background(Color(tokens.surface))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    private var jobCountSummary: some View {
        let active = boardData.jobs.filter { $0.status == .active }.count
        let total = boardData.jobs.count
        return Text("\(active) active / \(total) total")
            .font(.system(size: TypeScale.captionSize))
            .foregroundStyle(Color(tokens.textMuted).opacity(0.6))
    }

    private var archiveButton: some View {
        Button {
            onArchive?()
        } label: {
            Image(systemName: "archivebox")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hoveredArchiveButton ? Color(tokens.elementHover) : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 4))
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        hoveredArchiveButton = true
                        DispatchQueue.main.async { NSCursor.pointingHand.set() }
                    case .ended:
                        hoveredArchiveButton = false
                    @unknown default: break
                    }
                }
        }
        .buttonStyle(.plain)
        .help("Archive completed jobs")
    }

    private var pausePlayButton: some View {
        Button {
            onTogglePause?()
        } label: {
            Image(systemName: boardData.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hoveredPauseButton ? Color(tokens.elementHover) : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 4))
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        hoveredPauseButton = true
                        DispatchQueue.main.async { NSCursor.pointingHand.set() }
                    case .ended:
                        hoveredPauseButton = false
                    @unknown default: break
                    }
                }
        }
        .buttonStyle(.plain)
        .help(boardData.isPaused ? "Resume pipeline" : "Pause pipeline")
    }

    // MARK: - Columns

    private var boardColumns: some View {
        let grouped = boardData.jobsByStage
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Spacing.md) {
                ForEach(Array(boardData.stages.enumerated()), id: \.offset) { index, stage in
                    stageColumn(stage: stage, jobs: grouped[safe: index] ?? [], stageIndex: index)
                }
            }
            .padding(Spacing.lg)
        }
    }

    private func stageColumn(stage: PipelineStageDef, jobs: [PipelineJobInfo], stageIndex: Int) -> some View {
        let isDropTarget = dropTargetStage == stageIndex
        return VStack(alignment: .leading, spacing: 0) {
            columnHeader(stage: stage, jobCount: jobs.count, stageIndex: stageIndex)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(jobs) { job in
                        jobCard(job: job)
                            .draggable(jobDragPayload(job: job)) {
                                jobCardDragPreview(job: job)
                            }
                            .contextMenu { jobContextMenu(job: job) }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
            }

            if stageIndex == 0 {
                addJobRow(stageIndex: stageIndex)
            }
        }
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(tokens.surfaceLow))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isDropTarget ? Color(tokens.textAccent) : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let payload = items.first,
                  let parsed = parseJobDragPayload(payload) else { return false }
            if parsed.fromStageIndex != stageIndex {
                onMoveJob?(parsed.slug, parsed.fromStageIndex, stageIndex)
            }
            return true
        } isTargeted: { targeted in
            dropTargetStage = targeted ? stageIndex : (dropTargetStage == stageIndex ? nil : dropTargetStage)
        }
    }

    private func columnHeader(stage: PipelineStageDef, jobCount: Int, stageIndex: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: stage.type == .automated ? "bolt.fill" : "hand.raised.fill")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.6))

            Text(stage.name)
                .font(.system(size: TypeScale.captionSize, weight: .medium))
                .foregroundStyle(Color(tokens.textMuted))

            Text("\(jobCount)")
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.6))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .help(stageTooltip(stage))
        .contentShape(Rectangle())
        .contextMenu { columnContextMenu(stageIndex: stageIndex, stage: stage) }
    }

    // MARK: - Column Context Menu

    @ViewBuilder
    private func columnContextMenu(stageIndex: Int, stage: PipelineStageDef) -> some View {
        if let onAddStage {
            Button("Add Stage After") {
                onAddStage("New Stage", .manual, stageIndex)
            }
        }

        if let onChangeStageType {
            let newType: PipelineStageDef.StageType = stage.type == .automated ? .manual : .automated
            Button("Change to \(newType.rawValue.capitalized)") {
                onChangeStageType(stageIndex, newType)
            }
        }

        if onRemoveStage != nil, boardData.stages.count > 1 {
            Divider()
            Button("Remove Stage", role: .destructive) {
                onRemoveStage?(stageIndex)
            }
        }
    }

    // MARK: - Job Cards

    private func jobCard(job: PipelineJobInfo) -> some View {
        let isHighlighted = highlightedJobSlug == job.slug
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(job.title)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.text))
                .lineLimit(2)

            if job.priority != nil || !job.labels.isEmpty {
                jobMetadataRow(job: job)
            }

            jobFooter(job: job)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(tokens.surface))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isHighlighted ? Color(tokens.textAccent) : Color(tokens.border), lineWidth: isHighlighted ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 4))
        .onTapGesture { selectedJob = job }
        .animation(.easeOut(duration: 0.3), value: isHighlighted)
    }

    private func jobFooter(job: PipelineJobInfo) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(jobStatusColor(job))
                .frame(width: 6, height: 6)

            Text(job.slug)
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted))

            Spacer(minLength: 0)

            if job.claimedBy != nil {
                Image(systemName: "person.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(tokens.textAccent))
            }
        }
    }

    private func jobMetadataRow(job: PipelineJobInfo) -> some View {
        HStack(spacing: Spacing.xs) {
            if let priority = job.priority {
                priorityBadge(priority)
            }
            ForEach(job.labels.prefix(3), id: \.self) { label in
                labelBadge(label)
            }
            if job.labels.count > 3 {
                Text("+\(job.labels.count - 3)")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(tokens.textMuted).opacity(0.6))
            }
        }
    }

    private func priorityBadge(_ priority: String) -> some View {
        Text(priority)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(priorityColor(priority))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(priorityColor(priority).opacity(0.15))
            )
    }

    private func labelBadge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 9))
            .foregroundStyle(Color(tokens.textMuted))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(tokens.surfaceHighlight).opacity(0.5))
            )
    }

    // MARK: - Add Job

    private func addJobRow(stageIndex: Int) -> some View {
        VStack(spacing: 0) {
            if addingJobInStage == stageIndex {
                addJobField(stageIndex: stageIndex)
            } else {
                addJobButton(stageIndex: stageIndex)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    private func addJobButton(stageIndex: Int) -> some View {
        Button {
            newJobTitle = ""
            addingJobInStage = stageIndex
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: TypeScale.smallSize))
                Text("Add job")
                    .font(.system(size: TypeScale.captionSize))
            }
            .foregroundStyle(Color(tokens.textMuted).opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.smd)
        }
        .buttonStyle(.plain)
    }

    private func addJobField(stageIndex: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            TextField("Job title", text: $newJobTitle)
                .textFieldStyle(.plain)
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.text))
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(tokens.surface))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(tokens.textAccent), lineWidth: 1)
                )
                .onSubmit { commitAddJob(stageIndex: stageIndex) }
                .onExitCommand { addingJobInStage = nil }
        }
    }

    private func commitAddJob(stageIndex: Int) {
        let trimmed = newJobTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            onAddJob?(trimmed, stageIndex)
        }
        addingJobInStage = nil
        newJobTitle = ""
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func jobContextMenu(job: PipelineJobInfo) -> some View {
        Button("View Details") { selectedJob = job }

        Divider()

        if job.stageIndex > 0 {
            let prevStage = boardData.stages[job.stageIndex - 1]
            Button("Move to \(prevStage.name)") {
                onMoveJob?(job.slug, job.stageIndex, job.stageIndex - 1)
            }
        }
        if job.stageIndex < boardData.stages.count - 1 {
            let nextStage = boardData.stages[job.stageIndex + 1]
            Button("Advance to \(nextStage.name)") {
                onMoveJob?(job.slug, job.stageIndex, job.stageIndex + 1)
            }
        }

        Menu("Move to...") {
            ForEach(Array(boardData.stages.enumerated()), id: \.offset) { index, stage in
                if index != job.stageIndex {
                    Button(stage.name) {
                        onMoveJob?(job.slug, job.stageIndex, index)
                    }
                }
            }
        }

        Divider()

        if let sessionKey = job.claimedBy {
            Button("Go to Terminal") {
                onClickClaimed?(sessionKey)
            }
        }

        if onClaimInWorktree != nil {
            Button("Claim in Worktree") {
                onClaimInWorktree?(job.slug)
            }
        }

        Divider()

        Button("Delete Job", role: .destructive) {
            onRemoveJob?(job.slug)
        }
    }

    // MARK: - Archive Section

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showArchive.toggle() }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: showArchive ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(Color(tokens.textMuted))
                    Text("Archive")
                        .font(.system(size: TypeScale.captionSize, weight: .medium))
                        .foregroundStyle(Color(tokens.textMuted))
                    Text("\(boardData.archivedJobs.count)")
                        .font(.system(size: TypeScale.smallSize))
                        .foregroundStyle(Color(tokens.textMuted).opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showArchive {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(boardData.archivedJobs) { job in
                            archivedJobCard(job: job)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.md)
                }
            }
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    private func archivedJobCard(job: PipelineJobInfo) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(job.title)
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted))
                .lineLimit(1)
            Text(job.slug)
                .font(.system(size: TypeScale.smallSize))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.5))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(tokens.surfaceHighlight).opacity(0.3))
        )
    }

    // MARK: - Drag & Drop

    private func jobDragPayload(job: PipelineJobInfo) -> String {
        "\(job.slug)|\(job.stageIndex)"
    }

    private func parseJobDragPayload(_ payload: String) -> (slug: String, fromStageIndex: Int)? {
        let parts = payload.components(separatedBy: "|")
        guard parts.count == 2, let stageIndex = Int(parts[1]) else { return nil }
        return (slug: parts[0], fromStageIndex: stageIndex)
    }

    private func jobCardDragPreview(job: PipelineJobInfo) -> some View {
        Text(job.title)
            .font(.system(size: TypeScale.captionSize))
            .foregroundStyle(Color(tokens.text))
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(tokens.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(tokens.textAccent), lineWidth: 1)
            )
    }

    // MARK: - Helpers

    private func stageTooltip(_ stage: PipelineStageDef) -> String {
        if let command = stage.command {
            return "\(stage.name): \(command)"
        }
        return stage.type == .manual ? "\(stage.name): Manual" : "\(stage.name): Uses job prompt"
    }

    private func jobStatusColor(_ job: PipelineJobInfo) -> Color {
        guard let status = job.status else {
            return Color(tokens.textMuted).opacity(0.4)
        }
        switch status {
        case .active: return Color(tokens.statusSuccess)
        case .interrupted: return Color(tokens.statusWarning)
        case .completed: return Color(tokens.textMuted)
        case .queued: return Color(tokens.textMuted).opacity(0.6)
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "critical": Color(tokens.statusError)
        case "high": Color(tokens.statusWarning)
        case "medium": Color(tokens.textAccent)
        case "low": Color(tokens.statusThinking)
        default: Color(tokens.textMuted)
        }
    }
}

// MARK: - Job Detail Sheet

private struct JobDetailSheet: View {
    let job: PipelineJobInfo
    let boardData: PipelineBoardData
    let tokens: DesignTokens
    let fullContent: String?
    var onMoveJob: ((_ jobSlug: String, _ fromStageIndex: Int, _ toStageIndex: Int) -> Void)?
    var onRemoveJob: ((_ jobSlug: String) -> Void)?
    var onClickClaimed: ((_ sessionKey: String) -> Void)?
    var onUpdateTitle: ((_ jobSlug: String, _ newTitle: String) -> Void)?
    var onDismiss: () -> Void

    @State private var isEditingTitle = false
    @State private var editedTitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            detailHeader
            ScrollView {
                detailContent
                    .padding(Spacing.lg)
            }
            detailActions
        }
        .frame(width: 520, height: 480)
        .background(Color(tokens.surface))
    }

    private var detailHeader: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if isEditingTitle {
                    titleEditField
                } else {
                    Text(job.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(tokens.text))
                        .onTapGesture(count: 2) {
                            editedTitle = job.title
                            isEditingTitle = true
                        }
                }

                HStack(spacing: Spacing.sm) {
                    Text(job.slug)
                        .font(.system(size: TypeScale.captionSize))
                        .foregroundStyle(Color(tokens.textMuted))

                    Circle()
                        .fill(stageTypeColor)
                        .frame(width: 6, height: 6)

                    Text(job.stageName)
                        .font(.system(size: TypeScale.captionSize))
                        .foregroundStyle(Color(tokens.textMuted))
                }
            }

            Spacer()

            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(tokens.textMuted))
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(Spacing.lg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    private var titleEditField: some View {
        TextField("Title", text: $editedTitle)
            .textFieldStyle(.plain)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color(tokens.text))
            .padding(Spacing.xs)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color(tokens.surfaceHighlight).opacity(0.3)))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(tokens.textAccent), lineWidth: 1))
            .onSubmit {
                let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty, trimmed != job.title {
                    onUpdateTitle?(job.slug, trimmed)
                }
                isEditingTitle = false
            }
            .onExitCommand { isEditingTitle = false }
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            metadataSection
            parsedContentSections
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let priority = job.priority {
                metadataRow(label: "Priority", value: priority.capitalized)
            }
            if !job.labels.isEmpty {
                metadataRow(label: "Labels", value: job.labels.joined(separator: ", "))
            }
            if let claimedBy = job.claimedBy {
                claimedByRow(sessionKey: claimedBy)
            }
            if let status = job.status {
                metadataRow(label: "Status", value: status.rawValue.capitalized)
            }
        }
    }

    private func claimedByRow(sessionKey: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text("Claimed by")
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted))
                .frame(width: 80, alignment: .trailing)
            Button {
                onClickClaimed?(sessionKey)
                onDismiss()
            } label: {
                Text(sessionKey)
                    .font(.system(size: TypeScale.captionSize))
                    .foregroundStyle(Color(tokens.textAccent))
            }
            .buttonStyle(.plain)
        }
    }

    /// Parse and display the full job content with ## section headers.
    @ViewBuilder
    private var parsedContentSections: some View {
        if let content = fullContent {
            let sections = parseJobSections(content)

            if let prompt = sections.prompt, !prompt.isEmpty {
                contentSection(title: "Prompt", body: prompt)
            }

            ForEach(sections.headingSections, id: \.title) { section in
                contentSection(title: section.title, body: section.body)
            }
        }
    }

    private func contentSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.system(size: TypeScale.captionSize, weight: .medium))
                .foregroundStyle(Color(tokens.textMuted))
            Text(body)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.text))
                .textSelection(.enabled)
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(label)
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted))
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.text))
        }
    }

    private var detailActions: some View {
        HStack(spacing: Spacing.md) {
            if job.stageIndex > 0 {
                let prev = boardData.stages[job.stageIndex - 1]
                Button("Move to \(prev.name)") {
                    onMoveJob?(job.slug, job.stageIndex, job.stageIndex - 1)
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted))
                .help("Move job to previous stage")
            }

            if job.stageIndex < boardData.stages.count - 1 {
                let next = boardData.stages[job.stageIndex + 1]
                Button("Advance to \(next.name)") {
                    onMoveJob?(job.slug, job.stageIndex, job.stageIndex + 1)
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: TypeScale.captionSize, weight: .medium))
                .foregroundStyle(Color(tokens.textAccent))
                .help("Advance job to next stage")
            }

            Spacer()

            Button("Delete", role: .destructive) {
                onRemoveJob?(job.slug)
                onDismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: TypeScale.captionSize))
            .foregroundStyle(Color(tokens.statusError))
            .help("Delete this job")
        }
        .padding(Spacing.lg)
        .overlay(alignment: .top) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    private var stageTypeColor: Color {
        guard job.stageIndex < boardData.stages.count else { return Color(tokens.textMuted) }
        let stage = boardData.stages[job.stageIndex]
        return stage.type == .automated ? Color(tokens.statusThinking) : Color(tokens.statusWarning)
    }

    // MARK: - Section Parsing

    private struct ParsedSections {
        let prompt: String?
        let headingSections: [HeadingSection]
    }

    private struct HeadingSection: Hashable {
        let title: String
        let body: String
    }

    private func parseJobSections(_ content: String) -> ParsedSections {
        let lines = content.components(separatedBy: .newlines)

        // Skip frontmatter
        var bodyStartIndex = 0
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
            if let endIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
                bodyStartIndex = endIndex + 1
            }
        }

        let bodyLines = Array(lines[bodyStartIndex...])
        var prompt: [String] = []
        var sections: [HeadingSection] = []
        var currentHeading: String?
        var currentBody: [String] = []

        for line in bodyLines {
            if line.hasPrefix("## ") {
                // Flush previous
                if let heading = currentHeading {
                    let body = currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    sections.append(HeadingSection(title: heading, body: body))
                }
                currentHeading = String(line.dropFirst(3))
                currentBody = []
            } else if currentHeading != nil {
                currentBody.append(line)
            } else {
                prompt.append(line)
            }
        }

        // Flush last section
        if let heading = currentHeading {
            let body = currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(HeadingSection(title: heading, body: body))
        }

        let promptText = prompt.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedSections(prompt: promptText.isEmpty ? nil : promptText, headingSections: sections)
    }
}

// MARK: - PipelineJobInfo Identifiable for sheet

extension PipelineJobInfo: Equatable {
    public static func == (lhs: PipelineJobInfo, rhs: PipelineJobInfo) -> Bool {
        lhs.id == rhs.id
    }
}

extension PipelineJobInfo: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
