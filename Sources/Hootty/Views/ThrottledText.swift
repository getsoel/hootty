import SwiftUI

/// A `Text` that shows a changing string at most a few times a second.
/// Agents can rewrite their status on every tool call; redrawing that fast
/// reads as flicker. The first change shows immediately, later ones within
/// the interval collapse into the latest value.
struct ThrottledText: View {
    let text: String
    var interval: Duration = .milliseconds(400)

    @State private var shown: String?
    @State private var lastShown = ContinuousClock.now
    @State private var pending: Task<Void, Never>?

    var body: some View {
        Text(shown ?? text)
            .onChange(of: text) { _, newValue in
                pending?.cancel()
                let wait = lastShown + interval - ContinuousClock.now
                guard wait > .zero else {
                    show(newValue)
                    return
                }
                pending = Task { @MainActor in
                    try? await Task.sleep(for: wait)
                    guard !Task.isCancelled else { return }
                    show(newValue)
                }
            }
            .onDisappear { pending?.cancel() }
    }

    private func show(_ value: String) {
        shown = value
        lastShown = .now
    }
}
