import HoottyCore
import SwiftUI

struct PaneNoteEditor: View {
    @Bindable var pane: Pane
    let tokens: DesignTokens
    let onDismiss: () -> Void

    @State private var note: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "square.text.square")
                    .foregroundStyle(Color(tokens.statusNote))
                    .font(.system(size: TypeScale.smallSize))
                    .padding(.leading, Spacing.md)

                Text("Note")
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(tokens.textMuted))
                    .padding(.leading, Spacing.sm)

                Spacer(minLength: 0)

                BarIconButton(
                    systemImage: "xmark",
                    tokens: tokens,
                    accessibilityLabel: "Close",
                    help: "Close (Esc)",
                    sizing: .fixed(24),
                    action: { onDismiss() }
                )
                .padding(.trailing, Spacing.smd)
            }
            .frame(height: Layout.barHeight)
            .background(Color(tokens.tabBarBackground))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(tokens.border)).frame(height: 1)
            }

            NoteTextEditor(text: $note, tokens: tokens, onSubmit: { commitNote() })
                .frame(minHeight: 80, maxHeight: 160)

            HStack(spacing: Spacing.sm) {
                if pane.hasNote {
                    Button {
                        pane.setNote(nil)
                        onDismiss()
                    } label: {
                        Text("Delete")
                            .font(.system(size: TypeScale.bodySize))
                            .foregroundStyle(Color(tokens.statusError))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color(tokens.statusError).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusSm))
                    .onContinuousHover { phase in
                        DispatchQueue.main.async {
                            switch phase {
                            case .active: NSCursor.pointingHand.set()
                            case .ended: NSCursor.arrow.set()
                            }
                        }
                    }
                }

                Button {
                    commitNote()
                } label: {
                    Text("Save")
                        .font(.system(size: TypeScale.bodySize))
                        .foregroundStyle(Color(tokens.text))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color(tokens.elementSelected))
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusSm))
                .onContinuousHover { phase in
                    DispatchQueue.main.async {
                        switch phase {
                        case .active: NSCursor.pointingHand.set()
                        case .ended: NSCursor.arrow.set()
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .overlay(alignment: .top) {
                Rectangle().fill(Color(tokens.border)).frame(height: 1)
            }
        }
        .frame(width: 360)
        .background(Color(tokens.surface))
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusLg))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusLg)
                .strokeBorder(Color(tokens.border), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .onAppear {
            note = pane.note ?? ""
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private func commitNote() {
        pane.setNote(note)
        onDismiss()
    }
}

// MARK: - NSTextView-backed editor for reliable focus

private struct NoteTextEditor: NSViewRepresentable {
    @Binding var text: String
    let tokens: DesignTokens
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: TypeScale.bodySize)
        textView.textColor = tokens.text
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: Spacing.sm, height: Spacing.sm)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextEditor
        init(_ parent: NoteTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                } else {
                    parent.onSubmit()
                }
                return true
            }
            if selector == #selector(NSResponder.insertTab(_:)) {
                textView.window?.selectNextKeyView(nil)
                return true
            }
            if selector == #selector(NSResponder.insertBacktab(_:)) {
                textView.window?.selectPreviousKeyView(nil)
                return true
            }
            return false
        }
    }
}
