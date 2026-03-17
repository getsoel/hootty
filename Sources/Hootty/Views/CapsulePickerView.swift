import HoottyCore
import SwiftUI

struct CapsulePickerView<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let tokens: DesignTokens
    let label: (Value) -> String
    var badge: ((Value) -> Int?)?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                optionLabel(option: option, isActive: selection == option)
            }
        }
        .padding(2)
        .background(
            Capsule()
                .fill(Color(tokens.surfaceHighlight).opacity(0.3))
        )
    }

    private func optionLabel(option: Value, isActive: Bool) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(label(option))
                .font(.system(size: TypeScale.captionSize, weight: isActive ? .medium : .regular))
                .foregroundStyle(Color(isActive ? tokens.text : tokens.textMuted))

            if let badge, let count = badge(option), count > 0, !isActive {
                Text("\(count)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(tokens.statusWarning))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color(tokens.statusWarning).opacity(0.2)))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs + 1)
        .background(
            Capsule()
                .fill(isActive ? Color(tokens.elementSelected) : Color.clear)
        )
        .contentShape(Capsule())
        .onTapGesture { selection = option }
    }
}
