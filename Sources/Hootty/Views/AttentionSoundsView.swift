import HoottyCore
import SwiftUI

struct AttentionSoundsView: View {
    @Bindable var soundManager: SoundManager
    let tokens: DesignTokens
    let onDismiss: () -> Void

    private let systemSounds = SoundManager.availableSystemSounds

    var body: some View {
        ZStack {
            Color(tokens.scrim)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            panel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 60)
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            Text("Attention Sounds")
                .font(.system(size: TypeScale.bodySize, weight: .semibold))
                .foregroundStyle(Color(tokens.text))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)

            Rectangle()
                .fill(Color(tokens.border))
                .frame(height: 1)

            VStack(spacing: 0) {
                ForEach(AttentionKind.allCases, id: \.rawValue) { kind in
                    soundRow(kind)
                }
            }
            .padding(.vertical, Spacing.sm)
        }
        .frame(width: 360)
        .background(Color(tokens.surface))
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusLg))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusLg)
                .strokeBorder(Color(tokens.border), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }

    private func soundRow(_ kind: AttentionKind) -> some View {
        let hasSound = soundManager.sound(for: kind) != nil
        return HStack(spacing: Spacing.md) {
            Text(kind.displayName)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.text))
                .frame(width: 100, alignment: .leading)

            soundPicker(for: kind)

            BarIconButton(
                systemImage: "play.fill",
                tokens: tokens,
                accessibilityLabel: "Preview \(kind.displayName) sound",
                iconSize: TypeScale.smallSize,
                sizing: .fixed(24),
                action: { soundManager.play(kind) }
            )
            .opacity(hasSound ? 1 : 0.3)
            .disabled(!hasSound)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private func soundPicker(for kind: AttentionKind) -> some View {
        Picker("", selection: Binding(
            get: { soundManager.sound(for: kind) },
            set: { soundManager.setSound(for: kind, to: $0) }
        )) {
            Text("None").tag(String?.none)
            ForEach(systemSounds, id: \.self) { sound in
                Text(sound).tag(String?.some(sound))
            }
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }
}
