import AppKit
import HoottyCore
import SwiftUI

/// One entry in a `BarFilterGroup`.
struct BarFilterItem {
    let filter: SidebarFilter
    let color: NSColor
    let count: Int
    let icon: AnyView

    init(
        filter: SidebarFilter,
        color: NSColor,
        count: Int,
        @ViewBuilder icon: () -> some View
    ) {
        self.filter = filter
        self.color = color
        self.count = count
        self.icon = AnyView(icon())
    }
}

/// A horizontal segmented-style group of attention filter toggles.
///
/// Two modes, switched by whether `onToggle` is provided:
///   * **Interactive** (onToggle != nil) — items are tap targets, the group
///     sits inside a shared rounded track, and hover/active states render a
///     filled pill behind each item. Used by the floating filter pill at the
///     bottom of the sidebar.
///   * **Display-only** (onToggle == nil) — items render as plain badges
///     with no track, hover, or tap handling. Used by branch section headers
///     to surface per-section status counts.
///
/// When `hidesZeroCounts` is true, items with `count == 0` are omitted
/// entirely. When false, they render muted so the group has a stable shape
/// and remains a clickable filter control even with no matches.
///
/// `size` scales the font, padding, and corner radii. Use `.regular` for
/// prominent standalone controls (the floating pill), `.compact` for inline
/// use within existing row chrome (branch section headers).
struct BarFilterGroup: View {
    enum Size {
        case compact
        case regular
    }

    let items: [BarFilterItem]
    let tokens: DesignTokens
    let activeFilters: Set<SidebarFilter>
    let hidesZeroCounts: Bool
    let size: Size
    let onToggle: ((SidebarFilter) -> Void)?

    private var isInteractive: Bool {
        onToggle != nil
    }

    private var visibleItems: [BarFilterItem] {
        hidesZeroCounts ? items.filter { $0.count > 0 } : items
    }

    var body: some View {
        let visible = visibleItems
        if visible.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: isInteractive ? 1 : Spacing.xs) {
                ForEach(visible, id: \.filter) { item in
                    BarFilterGroupItem(
                        item: item,
                        tokens: tokens,
                        isActive: activeFilters.contains(item.filter),
                        size: size,
                        onTap: onToggle.map { toggle in { toggle(item.filter) } }
                    )
                }
            }
            .modifier(BarFilterGroupTrack(tokens: tokens, enabled: isInteractive, size: size))
        }
    }
}

// MARK: - Item

private struct BarFilterGroupItem: View {
    let item: BarFilterItem
    let tokens: DesignTokens
    let isActive: Bool
    let size: BarFilterGroup.Size
    let onTap: (() -> Void)?

    @State private var isHovered = false

    private var hasCount: Bool {
        item.count > 0
    }

    private var baseColor: Color {
        Color(hasCount || isActive ? item.color : tokens.textMuted)
    }

    private var backgroundFill: Color {
        if isActive { return baseColor.opacity(0.25) }
        if isHovered { return baseColor.opacity(0.12) }
        return .clear
    }

    private var font: Font {
        switch size {
        case .compact: .system(size: TypeScale.smallSize, weight: .medium)
        case .regular: .system(size: TypeScale.bodySize, weight: .medium)
        }
    }

    private var iconTextSpacing: CGFloat {
        switch size {
        case .compact: 3
        case .regular: Spacing.sm
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .compact: Spacing.sm
        case .regular: Spacing.md
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .compact: 2
        case .regular: Spacing.smd
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .compact: Layout.cornerRadiusSm
        case .regular: Layout.cornerRadiusMd
        }
    }

    var body: some View {
        HStack(spacing: iconTextSpacing) {
            item.icon
            Text("\(item.count)")
                .monospacedDigit()
        }
        .font(font)
        .foregroundStyle(baseColor)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundFill)
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .modifier(BarFilterGroupInteraction(onTap: onTap, isHovered: $isHovered))
    }
}

// MARK: - Track

private struct BarFilterGroupTrack: ViewModifier {
    let tokens: DesignTokens
    let enabled: Bool
    let size: BarFilterGroup.Size

    private var padding: CGFloat {
        switch size {
        case .compact: Spacing.xs
        case .regular: Spacing.sm
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .compact: Layout.cornerRadiusMd
        case .regular: Layout.cornerRadiusLg
        }
    }

    func body(content: Content) -> some View {
        if enabled {
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(tokens.surfaceHighlight).opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color(tokens.border), lineWidth: 1)
                )
        } else {
            content
        }
    }
}

// MARK: - Interaction

private struct BarFilterGroupInteraction: ViewModifier {
    let onTap: (() -> Void)?
    @Binding var isHovered: Bool

    func body(content: Content) -> some View {
        if let onTap {
            content
                .onTapGesture(perform: onTap)
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        isHovered = true
                        DispatchQueue.main.async { NSCursor.pointingHand.set() }
                    case .ended:
                        isHovered = false
                    @unknown default:
                        break
                    }
                }
        } else {
            content
        }
    }
}
