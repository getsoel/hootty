import HoottyCore
import SwiftUI

struct PipelineBoardView: View {
    let boardData: PipelineBoardData
    let tokens: DesignTokens
    var onTogglePause: (() -> Void)?
    var onMoveJob: ((_ jobSlug: String, _ fromStageIndex: Int, _ toStageIndex: Int) -> Void)?
    var onAddJob: ((_ title: String, _ stageIndex: Int) -> Void)?
    var onRemoveJob: ((_ jobSlug: String) -> Void)?
    var onClickClaimed: ((_ sessionKey: String) -> Void)?
    var onLoadJobBody: ((_ jobSlug: String) -> String?)?

    @State private var selectedJob: PipelineJobInfo?
    @State private var addingJobInStage: Int?
    @State private var newJobTitle: String = ""
    @State private var hoveredPauseButton = false
    @State private var dropTargetStage: Int?

    var body: some View {
        VStack(spacing: 0) {
            boardHeader
            boardColumns
        }
        .background(Color(tokens.background))
        .sheet(item: $selectedJob) { job in
            JobDetailSheet(
                job: job,
                boardData: boardData,
                tokens: tokens,
                jobBody: onLoadJobBody?(job.slug),
                onMoveJob: onMoveJob,
                onRemoveJob: onRemoveJob,
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
            columnHeader(stage: stage, jobCount: jobs.count)

            // Job cards
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

            // Add job button (shown in first stage)
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

    private func columnHeader(stage: PipelineStageDef, jobCount: Int) -> some View {
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
    }

    // MARK: - Job Cards

    private func jobCard(job: PipelineJobInfo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(job.title)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.text))
                .lineLimit(2)

            // Priority + labels row
            if job.priority != nil || !job.labels.isEmpty {
                jobMetadataRow(job: job)
            }

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
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(tokens.surface))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(tokens.border), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 4))
        .onTapGesture { selectedJob = job }
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

        // Move forward / backward
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

        // Move to any stage submenu
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

        Divider()

        Button("Delete Job", role: .destructive) {
            onRemoveJob?(job.slug)
        }
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
    let jobBody: String?
    var onMoveJob: ((_ jobSlug: String, _ fromStageIndex: Int, _ toStageIndex: Int) -> Void)?
    var onRemoveJob: ((_ jobSlug: String) -> Void)?
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            detailHeader
            ScrollView {
                detailContent
                    .padding(Spacing.lg)
            }
            detailActions
        }
        .frame(width: 480, height: 400)
        .background(Color(tokens.surface))
    }

    private var detailHeader: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(job.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(tokens.text))

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
        }
        .padding(Spacing.lg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Metadata
            metadataSection

            // Body / prompt
            if let body = jobBody {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Prompt")
                        .font(.system(size: TypeScale.captionSize, weight: .medium))
                        .foregroundStyle(Color(tokens.textMuted))
                    Text(body)
                        .font(.system(size: TypeScale.bodySize))
                        .foregroundStyle(Color(tokens.text))
                        .textSelection(.enabled)
                }
            }
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
                metadataRow(label: "Claimed by", value: claimedBy)
            }
            if let status = job.status {
                metadataRow(label: "Status", value: status.rawValue.capitalized)
            }
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
            // Move backward
            if job.stageIndex > 0 {
                let prev = boardData.stages[job.stageIndex - 1]
                Button("Move to \(prev.name)") {
                    onMoveJob?(job.slug, job.stageIndex, job.stageIndex - 1)
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted))
            }

            // Advance
            if job.stageIndex < boardData.stages.count - 1 {
                let next = boardData.stages[job.stageIndex + 1]
                Button("Advance to \(next.name)") {
                    onMoveJob?(job.slug, job.stageIndex, job.stageIndex + 1)
                    onDismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: TypeScale.captionSize, weight: .medium))
                .foregroundStyle(Color(tokens.textAccent))
            }

            Spacer()

            Button("Delete", role: .destructive) {
                onRemoveJob?(job.slug)
                onDismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: TypeScale.captionSize))
            .foregroundStyle(Color(tokens.statusError))
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
