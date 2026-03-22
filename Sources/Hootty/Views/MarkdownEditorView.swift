import AppKit
import HoottyCore
import Neon
import SwiftTreeSitter
import SwiftUI
import TreeSitterMarkdown
import TreeSitterMarkdownInline

/// NSViewRepresentable wrapping NSTextView with tree-sitter Markdown highlighting via Neon.
struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    let theme: TerminalTheme

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView(usingTextLayoutManager: false)
        let tokens = DesignTokens.from(theme)

        // Core editor settings
        textView.font = .monospacedSystemFont(ofSize: TypeScale.bodySize, weight: .regular)
        textView.textColor = tokens.text
        textView.backgroundColor = tokens.surface
        textView.insertionPointColor = tokens.text
        textView.selectedTextAttributes = [
            .backgroundColor: theme.selectionBackground,
            .foregroundColor: theme.selectionForeground
        ]
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        // Disable smart substitutions for code editing
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false

        // Typography
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.4
        textView.defaultParagraphStyle = paragraph
        textView.typingAttributes = [
            .foregroundColor: tokens.text,
            .font: NSFont.monospacedSystemFont(ofSize: TypeScale.bodySize, weight: .regular),
            .paragraphStyle: paragraph
        ]

        // Layout: wrap lines, grow vertically
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: Spacing.lg, height: Spacing.lg)

        // Performance
        textView.layoutManager?.allowsNonContiguousLayout = true

        // Set initial text
        textView.string = text

        // Wire delegate for text change notifications
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        // Set up tree-sitter highlighting
        context.coordinator.setupHighlighter(textView: textView, theme: theme)

        // Scroll view
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        // Tell Neon about the scroll view for lazy visible-range highlighting
        context.coordinator.highlighter?.observeEnclosingScrollView()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Sync text from SwiftUI → NSTextView (skip if change originated from typing)
        if !context.coordinator.isUpdating, textView.string != text {
            context.coordinator.isUpdating = true
            textView.string = text
            context.coordinator.isUpdating = false
        }

        // Re-theme if theme changed
        if context.coordinator.currentTheme != theme {
            let tokens = DesignTokens.from(theme)
            textView.backgroundColor = tokens.surface
            textView.insertionPointColor = tokens.text
            textView.selectedTextAttributes = [
                .backgroundColor: theme.selectionBackground,
                .foregroundColor: theme.selectionForeground
            ]
            context.coordinator.setupHighlighter(textView: textView, theme: theme)
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditorView
        var isUpdating = false
        weak var textView: NSTextView?
        var highlighter: TextViewHighlighter?
        var currentTheme: TerminalTheme?

        init(parent: MarkdownEditorView) {
            self.parent = parent
        }

        func setupHighlighter(textView: NSTextView, theme: TerminalTheme) {
            currentTheme = theme
            let tokens = DesignTokens.from(theme)

            do {
                let markdownConfig = try LanguageConfiguration(
                    tree_sitter_markdown(),
                    name: "Markdown"
                )

                let inlineConfig = try LanguageConfiguration(
                    tree_sitter_markdown_inline(),
                    name: "MarkdownInline",
                    bundleName: "TreeSitterMarkdown_TreeSitterMarkdownInline"
                )

                let attributeProvider: TokenAttributeProvider = { token in
                    Self.attributes(for: token.name, tokens: tokens)
                }

                let config = TextViewHighlighter.Configuration(
                    languageConfiguration: markdownConfig,
                    attributeProvider: attributeProvider,
                    languageProvider: { name in
                        name == "markdown_inline" ? inlineConfig : nil
                    },
                    locationTransformer: { _ in nil }
                )

                highlighter = try TextViewHighlighter(
                    textView: textView,
                    configuration: config
                )
            } catch {
                highlighter = nil
            }
        }

        private static func attributes(
            for name: String,
            tokens: DesignTokens
        ) -> [NSAttributedString.Key: Any] {
            let base = NSFont.monospacedSystemFont(
                ofSize: TypeScale.bodySize, weight: .regular
            )

            switch name {
            case "text.title":
                return [
                    .foregroundColor: tokens.textAccent,
                    .font: NSFont.monospacedSystemFont(
                        ofSize: TypeScale.bodySize, weight: .bold
                    )
                ]
            case "text.emphasis":
                let italic = NSFont(
                    descriptor: base.fontDescriptor.withSymbolicTraits(.italic),
                    size: TypeScale.bodySize
                ) ?? base
                return [.foregroundColor: tokens.text, .font: italic]
            case "text.strong":
                return [
                    .foregroundColor: tokens.text,
                    .font: NSFont.monospacedSystemFont(
                        ofSize: TypeScale.bodySize, weight: .bold
                    )
                ]
            case "text.literal":
                return [.foregroundColor: tokens.textRepo]
            case "text.uri":
                return [.foregroundColor: tokens.textAccent]
            case "text.reference":
                return [.foregroundColor: tokens.textBranch]
            case "string.escape":
                return [.foregroundColor: tokens.statusWarning]
            case let s where s.hasPrefix("punctuation"):
                return [.foregroundColor: tokens.textMuted]
            default:
                return [.foregroundColor: tokens.text]
            }
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }
            isUpdating = true
            parent.text = textView.string
            isUpdating = false
        }
    }
}
