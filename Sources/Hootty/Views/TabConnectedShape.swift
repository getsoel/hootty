import SwiftUI

// MARK: - Preference Keys

/// Reports the scroll area's global frame for clipping tab visibility.
struct ScrollAreaFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// Reports the PaneGroupView VStack's global frame for coordinate conversion.
struct PaneGroupFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - TabConnectedShape

/// A notched rectangle that traces a continuous path around both a tab and the pane content area.
///
/// ```
///              +----------+
///    ----------+   Tab    +--------
///    |                            |
///    |       Pane content         |
///    |                            |
///    +----------------------------+
/// ```
struct TabConnectedShape: InsettableShape {
    var tabRect: CGRect
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let d = insetAmount

        // Pane area outer bounds (inset)
        let pLeft = rect.minX + d
        let pRight = rect.maxX - d
        let pBottom = rect.maxY - d

        // Divider: where the tab bottom meets the pane content top
        let divider = tabRect.maxY

        // Tab bounds (inset from sides and top)
        let tLeft = tabRect.minX + d
        let tRight = tabRect.maxX - d
        let tTop = tabRect.minY + d

        var path = Path()
        path.move(to: CGPoint(x: pLeft, y: pBottom))
        path.addLine(to: CGPoint(x: pLeft, y: divider))      // up left side
        path.addLine(to: CGPoint(x: tLeft, y: divider))      // right to tab left
        path.addLine(to: CGPoint(x: tLeft, y: tTop))         // up tab left side
        path.addLine(to: CGPoint(x: tRight, y: tTop))        // across tab top
        path.addLine(to: CGPoint(x: tRight, y: divider))     // down tab right side
        path.addLine(to: CGPoint(x: pRight, y: divider))     // right to pane right
        path.addLine(to: CGPoint(x: pRight, y: pBottom))     // down right side
        path.closeSubpath()                                   // across bottom
        return path
    }

    func inset(by amount: CGFloat) -> TabConnectedShape {
        TabConnectedShape(tabRect: tabRect, insetAmount: insetAmount + amount)
    }
}
