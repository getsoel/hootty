import HoottyCore
import SwiftUI

struct FlagNoteInputView: View {
    let tokens: DesignTokens
    let onSubmit: (String) -> Void
    let onDismiss: () -> Void

    @State private var note = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color(tokens.scrim)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(Color(tokens.statusFlag))
                        .font(.system(size: TypeScale.bodySize))

                    TextField("Add a note (optional)", text: $note)
                        .textFieldStyle(.plain)
                        .font(.system(size: TypeScale.bodySize))
                        .foregroundColor(Color(tokens.text))
                        .focused($isFocused)
                }
                .padding(Spacing.md)
            }
            .frame(width: 360)
            .background(Color(tokens.surface))
            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusLg))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadiusLg)
                    .strokeBorder(Color(tokens.border), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 60)
        }
        .onAppear {
            NSApp.keyWindow?.makeFirstResponder(nil)
            DispatchQueue.main.async {
                isFocused = true
            }
        }
        .onKeyPress(.return) {
            onSubmit(note)
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }
}
