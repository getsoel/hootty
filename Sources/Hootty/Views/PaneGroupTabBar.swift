import SwiftUI
import HoottyCore
import LucideIcons

struct PaneGroupTabBar: View {
    let group: PaneGroup
    let isFocused: Bool
    let tokens: DesignTokens
    var onFocusPaneGroup: () -> Void
    var onAddPane: () -> Void
    var onRemovePane: (UUID) -> Void
    var onSplitPane: ((SplitDirection) -> Void)?
    var onSave: (() -> Void)?

    private enum HoveredElement: Equatable {
        case navLeft, navRight, add, split, close(UUID), tab(UUID)
    }

    @State private var hovered: HoveredElement?
    @State private var renameTargetID: UUID?
    @State private var editingName: String = ""
    @State private var draggingPaneID: UUID?
    @State private var tabsScrolledToEnd: Bool = true
    @State private var tabsOverflow: Bool = false


    var body: some View {
        HStack(spacing: 0) {
            // Left nav arrows
            navButtons

            // Scrollable tab strip
            HorizontalScrollWrapper(isAtEnd: $tabsScrolledToEnd, isOverflowing: $tabsOverflow) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(group.panes) { pane in
                                paneTab(pane)
                                    .id(pane.id)
                                    .opacity(draggingPaneID == pane.id ? 0.4 : 1.0)
                                    .onDrag {
                                        draggingPaneID = pane.id
                                        return NSItemProvider(object: pane.id.uuidString as NSString)
                                    }
                                    .onDrop(of: [.text], delegate: PaneTabDropDelegate(
                                        paneID: pane.id,
                                        group: group,
                                        draggingPaneID: $draggingPaneID,
                                        onSave: onSave
                                    ))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: group.selectedPaneID) { _, newID in
                        if let id = newID, draggingPaneID == nil {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }

            // Right action buttons
            actionButtons
        }
        .frame(height: 38)
        .padding(.bottom, -1)
        .background(
            VStack(spacing: 0) {
                Color(tokens.tabBarBackground)
                Rectangle().fill(Color(tokens.border)).frame(height: 1)
            }
        )
        .alert("Rename Tab", isPresented: Binding(
            get: { renameTargetID != nil },
            set: { if !$0 { renameTargetID = nil } }
        )) {
            TextField("Tab name", text: $editingName)
            Button("OK") { commitRename() }
            Button("Cancel", role: .cancel) { renameTargetID = nil }
        }
    }

    private var selectedPaneIndex: Int? {
        guard let id = group.selectedPaneID else { return nil }
        return group.panes.firstIndex(where: { $0.id == id })
    }

    private var canGoBack: Bool { (selectedPaneIndex ?? 0) > 0 }
    private var canGoForward: Bool {
        guard let i = selectedPaneIndex else { return false }
        return i < group.panes.count - 1
    }

    private var navButtons: some View {
        HStack(spacing: 0) {
            iconButton(.navLeft, icon: Lucide.arrowLeft, accessibilityLabel: "Previous tab") {
                group.selectPreviousPane()
                onFocusPaneGroup()
            }
            .opacity(canGoBack ? 1.0 : 0.3)
            .disabled(!canGoBack)

            iconButton(.navRight, icon: Lucide.arrowRight, accessibilityLabel: "Next tab") {
                group.selectNextPane()
                onFocusPaneGroup()
            }
            .opacity(canGoForward ? 1.0 : 0.3)
            .disabled(!canGoForward)
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color(tokens.border)).frame(width: 1)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 0) {
            iconButton(.add, icon: Lucide.plus, accessibilityLabel: "New tab", action: onAddPane)

            if onSplitPane != nil {
                iconMenu(.split, icon: Lucide.columns2, accessibilityLabel: "Split pane") {
                    Button("Split Right") { onSplitPane?(.horizontal) }
                    Button("Split Down") { onSplitPane?(.vertical) }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .leading) {
            if !tabsOverflow || !tabsScrolledToEnd {
                Rectangle().fill(Color(tokens.border)).frame(width: 1)
            }
        }
    }

    private func iconButtonLabel(_ element: HoveredElement, icon: NSImage) -> some View {
        LucideIcon(icon, size: 12)
            .foregroundStyle(Color(tokens.textMuted))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(hovered == element ? Color(tokens.elementHover) : Color.clear)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    hovered = element
                    DispatchQueue.main.async { NSCursor.pointingHand.set() }
                case .ended:
                    if hovered == element { hovered = nil }
                @unknown default: break
                }
            }
    }

    private func iconButton(_ element: HoveredElement, icon: NSImage, accessibilityLabel label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            iconButtonLabel(element, icon: icon)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func iconMenu<Content: View>(_ element: HoveredElement, icon: NSImage, accessibilityLabel label: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            iconButtonLabel(element, icon: icon)
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityLabel(label)
    }

    private func commitRename() {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let target = group.panes.first(where: { $0.id == renameTargetID }) {
            target.customName = trimmed
            onSave?()
        }
        renameTargetID = nil
    }

    private func paneStatusDot(_ pane: Pane) -> some View {
        StatusDotView(needsAttention: pane.needsAttention, isRunning: pane.isRunning, tokens: tokens)
    }

    private func paneTab(_ pane: Pane) -> some View {
        let isSelected = pane.id == group.selectedPaneID
        let isHovered = hovered == .tab(pane.id)

        return HStack(spacing: 5) {
            paneStatusDot(pane)
                .padding(Spacing.sm)

            Text(pane.displayName)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted))
                .lineLimit(1)
                .truncationMode(.tail)
                .offset(y: -1)

            Button {
                onRemovePane(pane.id)
            } label: {
                LucideIcon(Lucide.x, size: 12)
                    .foregroundStyle(Color(tokens.textMuted))
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.sm)
                            .fill(hovered == .close(pane.id) ? Color(tokens.elementHover) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active: hovered = .close(pane.id)
                        case .ended: if hovered == .close(pane.id) { hovered = nil }
                        @unknown default: break
                        }
                    }
            }
            .buttonStyle(.plain)
            .opacity(isHovered || hovered == .close(pane.id) ? 1 : 0)
        }
        .padding(.leading, Spacing.sm)
        .padding(.trailing, Spacing.sm)
        .frame(maxWidth: 200, maxHeight: .infinity)
        .background(isSelected ? Color(tokens.tabActive) : Color.clear)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color(tokens.border)).frame(width: 1)
        }
        .overlay(alignment: .top) {
            if isSelected && isFocused {
                Rectangle()
                    .fill(Color(tokens.borderFocused))
                    .frame(height: 1)
            }
        }
        .overlay {
            if pane.needsAttention {
                Color.clear
                    .animatedBorderSegment(shape: Rectangle(), color: Color(tokens.statusWarning), lineWidth: 1)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                if hovered != .tab(pane.id) && hovered != .close(pane.id) { hovered = .tab(pane.id) }
                DispatchQueue.main.async { NSCursor.pointingHand.set() }
            case .ended:
                if hovered == .tab(pane.id) { hovered = nil }
            @unknown default: break
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            group.selectPane(id: pane.id)
            onFocusPaneGroup()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(pane.displayName)
        .contextMenu {
            Button("Rename Tab") {
                editingName = pane.displayName
                renameTargetID = pane.id
            }
        }
    }
}

private struct PaneTabDropDelegate: DropDelegate {
    let paneID: UUID
    let group: PaneGroup
    @Binding var draggingPaneID: UUID?
    var onSave: (() -> Void)?

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingPaneID, dragging != paneID else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            group.movePane(fromID: dragging, toID: paneID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingPaneID = nil
        onSave?()
        return true
    }

    func dropExited(info: DropInfo) {}
}

private struct HorizontalScrollWrapper<Content: View>: NSViewRepresentable {
    let content: Content
    @Binding var isAtEnd: Bool
    @Binding var isOverflowing: Bool

    init(isAtEnd: Binding<Bool>, isOverflowing: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.content = content()
        self._isAtEnd = isAtEnd
        self._isOverflowing = isOverflowing
    }

    func makeNSView(context: Context) -> ScrollInterceptView {
        let hostingView = NSHostingView(rootView: content)
        let wrapper = ScrollInterceptView()
        wrapper.onScrollPositionChanged = { atEnd, overflows in
            self.isAtEnd = atEnd
            self.isOverflowing = overflows
        }
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
        ])
        return wrapper
    }

    func updateNSView(_ nsView: ScrollInterceptView, context: Context) {
        if let hostingView = nsView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

private final class ScrollInterceptView: NSView {
    private var monitor: Any?
    private var scrollObserver: NSObjectProtocol?
    private weak var cachedScrollView: NSScrollView?
    var onScrollPositionChanged: ((_ atEnd: Bool, _ overflows: Bool) -> Void)?

    private var scrollView: NSScrollView? {
        if let cached = cachedScrollView { return cached }
        var queue = Array(subviews)
        while !queue.isEmpty {
            let view = queue.removeFirst()
            if let sv = view as? NSScrollView { cachedScrollView = sv; return sv }
            queue.append(contentsOf: view.subviews)
        }
        return nil
    }

    private func checkScrollPosition() {
        guard let scrollView else {
            onScrollPositionChanged?(true, false)
            return
        }
        let clipView = scrollView.contentView
        let contentWidth = scrollView.documentView?.frame.width ?? 0
        let visibleWidth = clipView.bounds.width
        let offsetX = clipView.bounds.origin.x
        let overflows = contentWidth > visibleWidth
        let atEnd = !overflows || offsetX + visibleWidth >= contentWidth - 1
        onScrollPositionChanged?(atEnd, overflows)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, event.deltaX == 0, event.deltaY != 0 else { return event }
                let location = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(location), let scrollView = self.scrollView else { return event }
                guard let cg = event.cgEvent else { return event }
                cg.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: cg.getDoubleValueField(.scrollWheelEventDeltaAxis1))
                cg.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: 0)
                if let converted = NSEvent(cgEvent: cg) {
                    scrollView.scrollWheel(with: converted)
                }
                return nil
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, let scrollView = self.scrollView else { return }
                scrollView.contentView.postsBoundsChangedNotifications = true
                self.scrollObserver = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: scrollView.contentView,
                    queue: .main
                ) { [weak self] _ in
                    self?.checkScrollPosition()
                }
                self.checkScrollPosition()
            }
        } else if window == nil {
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver); self.scrollObserver = nil }
            cachedScrollView = nil
        }
    }

    override func layout() {
        super.layout()
        checkScrollPosition()
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
    }
}
