import HoottyCore
import SwiftUI

struct PipelineBoardView: View {
    let boardData: PipelineBoardData
    let tokens: DesignTokens

    var body: some View {
        VStack(spacing: 0) {
            boardHeader
            boardColumns
        }
        .background(Color(tokens.background))
    }

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

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .frame(height: 38)
        .background(Color(tokens.surface))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

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

    private func stageColumn(stage: PipelineStageDef, jobs: [PipelineJobInfo], stageIndex _: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            HStack(spacing: Spacing.sm) {
                Image(systemName: stage.type == .automated ? "bolt.fill" : "hand.raised.fill")
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(tokens.textMuted).opacity(0.6))

                Text(stage.name)
                    .font(.system(size: TypeScale.captionSize, weight: .medium))
                    .foregroundStyle(Color(tokens.textMuted))

                Text("\(jobs.count)")
                    .font(.system(size: TypeScale.smallSize))
                    .foregroundStyle(Color(tokens.textMuted).opacity(0.6))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .help(stageTooltip(stage))

            // Job cards
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(jobs) { job in
                        jobCard(job: job)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
            }
        }
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(tokens.surfaceLow))
        )
    }

    private func jobCard(job: PipelineJobInfo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(job.title)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.text))
                .lineLimit(2)

            HStack(spacing: Spacing.sm) {
                // Status dot
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
    }

    private func stageTooltip(_ stage: PipelineStageDef) -> String {
        if let command = stage.command {
            return "\(stage.name): \(command)"
        }
        return stage.type == .manual ? "\(stage.name): Manual" : "\(stage.name): Uses job prompt"
    }

    private func jobStatusColor(_ job: PipelineJobInfo) -> Color {
        guard let status = job.status else {
            return Color(tokens.textMuted).opacity(0.4) // unclaimed
        }
        switch status {
        case .active: return Color(tokens.statusSuccess)
        case .interrupted: return Color(tokens.statusWarning)
        case .completed: return Color(tokens.textMuted)
        }
    }
}
