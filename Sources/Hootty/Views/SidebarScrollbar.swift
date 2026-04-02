import HoottyCore
import SwiftUI

struct SidebarScrollbar: View {
    let contentHeight: CGFloat
    let visibleHeight: CGFloat
    let scrollOffset: CGFloat
    let tokens: DesignTokens
    var sidebarHovered: Bool = false
    var onScroll: (CGFloat) -> Void

    @State private var isTrackHovered = false
    @State private var isDragging = false
    @GestureState private var dragDelta: CGFloat = 0

    private var hasOverflow: Bool {
        contentHeight > visibleHeight && contentHeight > 0
    }

    private var thumbHeight: CGFloat {
        guard hasOverflow else { return 0 }
        return max(24, visibleHeight * (visibleHeight / contentHeight))
    }

    private var trackSpace: CGFloat {
        visibleHeight - thumbHeight
    }

    private var scrollFraction: CGFloat {
        guard contentHeight > visibleHeight else { return 0 }
        let maxOffset = contentHeight - visibleHeight
        guard maxOffset > 0 else { return 0 }
        return min(max(scrollOffset / maxOffset, 0), 1)
    }

    private var thumbY: CGFloat {
        scrollFraction * trackSpace + dragDelta
    }

    private var thumbOpacity: Double {
        if isDragging { return 0.9 }
        if isTrackHovered { return 0.7 }
        return 0.4
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .frame(width: 8)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        isTrackHovered = true
                    case .ended:
                        isTrackHovered = false
                    }
                }
                .onTapGesture { location in
                    let ratio = min(max(location.y / visibleHeight, 0), 1)
                    onScroll(ratio)
                }

            Rectangle()
                .fill(Color(tokens.textMuted).opacity(thumbOpacity))
                .frame(width: 6, height: thumbHeight)
                .offset(y: clampedThumbY)
                .gesture(
                    DragGesture()
                        .updating($dragDelta) { value, state, _ in
                            state = value.translation.height
                        }
                        .onChanged { _ in
                            isDragging = true
                        }
                        .onEnded { value in
                            isDragging = false
                            let finalY = scrollFraction * trackSpace + value.translation.height
                            let ratio = min(max(finalY / trackSpace, 0), 1)
                            onScroll(ratio)
                        }
                )
        }
        .frame(width: hasOverflow ? 8 : 0)
        .opacity(hasOverflow && (sidebarHovered || isDragging) ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: sidebarHovered)
        .animation(.easeInOut(duration: 0.2), value: isTrackHovered)
        .animation(.easeInOut(duration: 0.1), value: isDragging)
    }

    private var clampedThumbY: CGFloat {
        min(max(thumbY, 0), trackSpace)
    }
}
