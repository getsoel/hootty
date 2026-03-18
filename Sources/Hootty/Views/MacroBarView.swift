import HoottyCore
import SwiftUI

struct MacroBarView: View {
    let progress: MacroRunner.MacroProgress
    let tokens: DesignTokens
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            macroLabel
                .padding(.leading, Spacing.md)

            Spacer(minLength: Spacing.md)

            stepDots
                .padding(.trailing, Spacing.md)

            stepLabel
                .padding(.trailing, Spacing.md)

            removeButton
        }
        .frame(height: Layout.barHeight)
        .frame(maxWidth: .infinity)
        .background(Color(tokens.surface))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(tokens.border)).frame(height: 1)
        }
    }

    // MARK: - Macro Label

    private var macroLabel: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: progress.isComplete ? "checkmark.circle.fill" : "play.circle.fill")
                .foregroundStyle(Color(progress.isComplete ? tokens.textMuted : tokens.textAccent))
                .font(.system(size: TypeScale.smallSize))

            Text(progress.macroName)
                .foregroundStyle(Color(tokens.text))

            Text("›")
                .foregroundStyle(Color(tokens.textMuted).opacity(0.5))

            Text(progress.isComplete ? "Complete" : "Step \(progress.currentStep + 1)/\(progress.totalSteps)")
                .foregroundStyle(Color(tokens.textMuted))
        }
        .font(.system(size: TypeScale.captionSize))
    }

    // MARK: - Step Dots

    private var stepDots: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0 ..< progress.totalSteps, id: \.self) { index in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: 6, height: 6)
                    .overlay {
                        if index > progress.currentStep, !progress.isComplete {
                            Circle()
                                .stroke(Color(tokens.textMuted).opacity(0.3), lineWidth: 1)
                        }
                    }
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        if progress.isComplete || index < progress.currentStep {
            Color(tokens.textMuted)
        } else if index == progress.currentStep {
            Color(tokens.textAccent)
        } else {
            .clear
        }
    }

    // MARK: - Step Label

    private var stepLabel: some View {
        Text(progress.currentStepText)
            .font(.system(size: TypeScale.captionSize))
            .foregroundStyle(Color(tokens.textMuted))
            .lineLimit(1)
            .truncationMode(.tail)
    }

    // MARK: - Remove Button

    private var removeButton: some View {
        BarIconButton(
            systemImage: "xmark",
            tokens: tokens,
            accessibilityLabel: progress.isComplete ? "Dismiss macro" : "Cancel macro",
            sizing: .fillBar,
            action: { onRemove?() }
        )
        .padding(.trailing, Spacing.smd)
    }
}
