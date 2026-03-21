import HoottyCore
import SwiftUI

/// Sizing mode for bar icon buttons.
enum BarIconSizing {
    /// Expand to fill the bar height, keeping a square aspect ratio.
    case fillBar
    /// Fixed width/height square.
    case fixed(CGFloat)
}

/// A square icon button used in horizontal bars (sidebar header, tab bar, board header, Spec bar).
/// Owns its own hover state, shows a rounded hover background, and sets the pointing-hand cursor.
struct BarIconButton: View {
    let systemImage: String
    let tokens: DesignTokens
    let accessibilityLabel: String
    var help: String?
    var iconSize: CGFloat = TypeScale.smallSize
    var sizing: BarIconSizing = .fillBar
    var iconColor: NSColor?
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            BarIconLabel(
                systemImage: systemImage,
                tokens: tokens,
                iconSize: iconSize,
                sizing: sizing,
                iconColor: iconColor,
                isHovered: $isHovered
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .help(help ?? accessibilityLabel)
    }
}

/// A square icon menu used in horizontal bars. Same visual treatment as `BarIconButton` but wraps a `Menu`.
struct BarIconMenu<MenuContent: View>: View {
    let systemImage: String
    let tokens: DesignTokens
    let accessibilityLabel: String
    var help: String?
    var iconSize: CGFloat = TypeScale.smallSize
    var sizing: BarIconSizing = .fillBar
    var iconColor: NSColor?
    @ViewBuilder var menuContent: () -> MenuContent

    @State private var isHovered = false

    var body: some View {
        Menu {
            menuContent()
        } label: {
            BarIconLabel(
                systemImage: systemImage,
                tokens: tokens,
                iconSize: iconSize,
                sizing: sizing,
                iconColor: iconColor,
                isHovered: $isHovered
            )
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityLabel(accessibilityLabel)
        .help(help ?? accessibilityLabel)
    }
}

// MARK: - Shared Label

private struct BarIconLabel: View {
    let systemImage: String
    let tokens: DesignTokens
    var iconSize: CGFloat
    var sizing: BarIconSizing
    var iconColor: NSColor?
    @Binding var isHovered: Bool

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize))
            .foregroundStyle(Color(iconColor ?? tokens.textMuted))
            .modifier(SizingModifier(sizing: sizing))
            .background(RoundedRectangle(cornerRadius: Layout.cornerRadiusSm).fill(isHovered ? Color(tokens.elementHover) : Color.clear))
            .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusSm))
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovered = true
                    DispatchQueue.main.async { NSCursor.pointingHand.set() }
                case .ended:
                    isHovered = false
                @unknown default: break
                }
            }
    }
}

// MARK: - Sizing Modifier

private struct SizingModifier: ViewModifier {
    let sizing: BarIconSizing

    func body(content: Content) -> some View {
        switch sizing {
        case .fillBar:
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
        case let .fixed(size):
            content
                .frame(width: size, height: size)
        }
    }
}
