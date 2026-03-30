import CGhostty
import HoottyCore
import SwiftUI

// MARK: - Data Types

struct MemorySample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let memoryMB: Int
    let paneCount: Int
    let surfaceCount: Int

    var deltaMB: Int?
}

// MARK: - Activity Monitor

struct ActivityMonitorView: View {
    let tokens: DesignTokens
    let samples: [MemorySample]
    let appModel: AppModel
    let onDismiss: () -> Void

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case panes = "Panes"
        case log = "Log"
    }

    @State private var selectedTab: Tab = .overview

    var body: some View {
        ZStack {
            Color(tokens.scrim)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                header
                divider
                statsBar
                divider
                tabPicker
                divider
                tabContent
            }
            .frame(width: 520)
            .frame(maxHeight: 480)
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
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private var divider: some View {
        Rectangle().fill(Color(tokens.border)).frame(height: 1)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Activity Monitor")
                .font(.system(size: TypeScale.bodySize, weight: .semibold))
                .foregroundStyle(Color(tokens.text))
            Spacer()
            if let latest = samples.last {
                Text("\(latest.memoryMB) MB")
                    .font(.system(size: TypeScale.captionSize).monospacedDigit())
                    .foregroundStyle(Color(tokens.textMuted))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: Spacing.xl) {
            statItem(label: "Memory", value: "\(samples.last?.memoryMB ?? 0) MB", color: tokens.text)
            statItem(label: "Panes", value: "\(allPanes.count)", color: tokens.textMuted)
            statItem(label: "Surfaces", value: "\(TerminalSurfaceView.liveCount)", color: surfaceCountColor)
            statItem(label: "Delta/min", value: deltaPerMinuteText, color: deltaPerMinuteColor)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private func statItem(label: String, value: String, color: NSColor) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.6))
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: TypeScale.bodySize, weight: .medium, design: .monospaced).monospacedDigit())
                .foregroundStyle(Color(color))
        }
    }

    private var surfaceCountColor: NSColor {
        TerminalSurfaceView.liveCount > allPanes.count ? tokens.statusWarning : tokens.textMuted
    }

    private var deltaPerMinuteText: String {
        guard samples.count >= 10 else { return "--" }
        let recent = Array(samples.suffix(60))
        guard let first = recent.first, let last = recent.last else { return "--" }
        let elapsed = last.timestamp.timeIntervalSince(first.timestamp)
        guard elapsed > 5 else { return "--" }
        let delta = Double(last.memoryMB - first.memoryMB) / elapsed * 60
        let rounded = Int(delta.rounded())
        if rounded == 0 { return "0" }
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    private var deltaPerMinuteColor: NSColor {
        guard samples.count >= 10 else { return tokens.textMuted }
        let recent = Array(samples.suffix(60))
        guard let first = recent.first, let last = recent.last else { return tokens.textMuted }
        let elapsed = last.timestamp.timeIntervalSince(first.timestamp)
        guard elapsed > 5 else { return tokens.textMuted }
        let delta = Double(last.memoryMB - first.memoryMB) / elapsed * 60
        if delta > 5 { return tokens.statusWarning }
        if delta < -5 { return tokens.statusSuccess }
        return tokens.textMuted
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack {
            CapsulePickerView(
                options: Tab.allCases,
                selection: $selectedTab,
                tokens: tokens,
                label: { $0.rawValue }
            )
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.smd)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewTab
        case .panes:
            panesTab
        case .log:
            logTab
        }
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                sparklineSection
                memoryStatsSection
                healthSection
            }
            .padding(Spacing.lg)
        }
    }

    private var sparklineSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Memory Trend")
            MemorySparkline(
                samples: Array(samples.suffix(120)),
                lineColor: Color(tokens.textAccent),
                fillColor: Color(tokens.textAccent).opacity(0.15),
                gridColor: Color(tokens.border)
            )
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusSm))
        }
    }

    private var memoryStatsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Memory")
            HStack(spacing: Spacing.xl) {
                inlineStatItem("Current", "\(samples.last?.memoryMB ?? 0) MB")
                inlineStatItem("Peak", "\(peakMB) MB")
                inlineStatItem("Min", "\(minMB) MB")
                Spacer()
            }
        }
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Health")
            VStack(alignment: .leading, spacing: Spacing.sm) {
                healthRow(
                    label: "Surface balance",
                    ok: TerminalSurfaceView.liveCount <= allPanes.count,
                    detail: "\(TerminalSurfaceView.liveCount) surfaces / \(allPanes.count) panes"
                )
                healthRow(
                    label: "Memory trend",
                    ok: !isMemoryGrowing,
                    detail: isMemoryGrowing ? "Growing steadily" : "Stable"
                )
            }
        }
    }

    private func healthRow(label: String, ok: Bool, detail: String) -> some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(Color(ok ? tokens.statusSuccess : tokens.statusWarning))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.text))
            Spacer()
            Text(detail)
                .font(.system(size: TypeScale.captionSize, design: .monospaced))
                .foregroundStyle(Color(tokens.textMuted))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Color(tokens.textMuted).opacity(0.6))
            .textCase(.uppercase)
    }

    private func inlineStatItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted))
            Text(value)
                .font(.system(size: TypeScale.captionSize, design: .monospaced).monospacedDigit())
                .foregroundStyle(Color(tokens.text))
        }
    }

    // MARK: - Panes Tab

    private var panesTab: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                paneColumnHeaders
                ForEach(allPanes) { pane in
                    paneRow(pane)
                }
            }
            .padding(.vertical, Spacing.sm)
        }
    }

    private var paneColumnHeaders: some View {
        HStack(spacing: Spacing.md) {
            Text("Name")
                .frame(width: 120, alignment: .leading)
            Text("Shell")
                .frame(width: 60, alignment: .leading)
            Text("Size")
                .frame(width: 60, alignment: .trailing)
            Text("Branch")
                .frame(width: 80, alignment: .leading)
            Text("Status")
                .frame(width: 60, alignment: .center)
            Spacer()
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(Color(tokens.textMuted).opacity(0.6))
        .textCase(.uppercase)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private func paneRow(_ pane: Pane) -> some View {
        let size = surfaceSize(for: pane.id)
        return HStack(spacing: Spacing.md) {
            Text(pane.displayName)
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.text))
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            Text(URL(fileURLWithPath: pane.shell).lastPathComponent)
                .font(.system(size: TypeScale.captionSize, design: .monospaced))
                .foregroundStyle(Color(tokens.textMuted))
                .frame(width: 60, alignment: .leading)

            Group {
                if let size {
                    Text("\(size.cols)x\(size.rows)")
                } else {
                    Text("--")
                }
            }
            .font(.system(size: TypeScale.captionSize, design: .monospaced))
            .foregroundStyle(Color(tokens.textMuted))
            .frame(width: 60, alignment: .trailing)

            Text(pane.branch ?? "--")
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(pane.branch != nil ? tokens.textBranch : tokens.textMuted))
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)

            paneStatusIndicator(pane)
                .frame(width: 60, alignment: .center)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs + 1)
    }

    private func paneStatusIndicator(_ pane: Pane) -> some View {
        HStack(spacing: Spacing.sm) {
            if pane.isThinking {
                Circle().fill(Color(tokens.statusThinking)).frame(width: 6, height: 6)
                Text("think")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(tokens.statusThinking))
            } else if pane.isRunning {
                Circle().fill(Color(tokens.statusSuccess)).frame(width: 6, height: 6)
                Text("run")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(tokens.statusSuccess))
            } else {
                Circle().fill(Color(tokens.statusInactive)).frame(width: 6, height: 6)
                Text("exit")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(tokens.statusInactive))
            }
        }
    }

    private func surfaceSize(for paneID: UUID) -> (cols: Int, rows: Int)? {
        guard let view = GhosttyApp.shared.cachedSurfaceView(for: paneID),
              let surface = view.surface else { return nil }
        let size = ghostty_surface_size(surface)
        guard size.columns > 0 else { return nil }
        return (cols: Int(size.columns), rows: Int(size.rows))
    }

    // MARK: - Log Tab

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var logTab: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    logColumnHeaders
                    ForEach(samples) { sample in
                        logRow(sample)
                            .id(sample.id)
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
            .onAppear {
                if let last = samples.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: samples.count) {
                if let last = samples.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var logColumnHeaders: some View {
        HStack(spacing: Spacing.md) {
            Text("Time")
                .frame(width: 64, alignment: .leading)
            Text("Memory")
                .frame(width: 64, alignment: .trailing)
            Text("Delta")
                .frame(width: 56, alignment: .trailing)
            Text("Panes")
                .frame(width: 40, alignment: .trailing)
            Text("Surf")
                .frame(width: 40, alignment: .trailing)
            Spacer()
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(Color(tokens.textMuted).opacity(0.6))
        .textCase(.uppercase)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private func logRow(_ sample: MemorySample) -> some View {
        HStack(spacing: Spacing.md) {
            Text(Self.timeFormatter.string(from: sample.timestamp))
                .frame(width: 64, alignment: .leading)

            Text("\(sample.memoryMB)")
                .foregroundStyle(Color(tokens.text))
                .frame(width: 64, alignment: .trailing)

            deltaLabel(sample.deltaMB)
                .frame(width: 56, alignment: .trailing)

            Text("\(sample.paneCount)")
                .frame(width: 40, alignment: .trailing)

            Text("\(sample.surfaceCount)")
                .foregroundStyle(logSurfaceColor(sample))
                .frame(width: 40, alignment: .trailing)

            Spacer()
        }
        .font(.system(size: TypeScale.captionSize, design: .monospaced).monospacedDigit())
        .foregroundStyle(Color(tokens.textMuted))
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
    }

    private func deltaLabel(_ delta: Int?) -> some View {
        Group {
            if let delta, delta != 0 {
                Text(delta > 0 ? "+\(delta)" : "\(delta)")
                    .foregroundStyle(Color(delta > 0 ? tokens.statusWarning : tokens.statusSuccess))
            } else {
                Text("")
            }
        }
    }

    private func logSurfaceColor(_ sample: MemorySample) -> Color {
        sample.surfaceCount > sample.paneCount
            ? Color(tokens.statusWarning)
            : Color(tokens.textMuted)
    }

    // MARK: - Computed Helpers

    private var allPanes: [Pane] {
        appModel.workspaces.flatMap(\.allPanes)
    }

    private var peakMB: Int {
        samples.map(\.memoryMB).max() ?? 0
    }

    private var minMB: Int {
        samples.map(\.memoryMB).min() ?? 0
    }

    private var isMemoryGrowing: Bool {
        guard samples.count >= 60 else { return false }
        let recent = Array(samples.suffix(60))
        guard let first = recent.first, let last = recent.last else { return false }
        let elapsed = last.timestamp.timeIntervalSince(first.timestamp)
        guard elapsed > 10 else { return false }
        let rate = Double(last.memoryMB - first.memoryMB) / elapsed * 60
        return rate > 10
    }
}

// MARK: - Memory Sparkline

private struct MemorySparkline: View {
    let samples: [MemorySample]
    let lineColor: Color
    let fillColor: Color
    let gridColor: Color

    var body: some View {
        Canvas { context, size in
            guard samples.count >= 2 else { return }

            let values = samples.map { CGFloat($0.memoryMB) }
            let minVal = (values.min() ?? 0) * 0.95
            let maxVal = (values.max() ?? 1) * 1.05
            let range = max(maxVal - minVal, 1)

            // Grid lines
            for i in 0 ... 3 {
                let y = size.height * CGFloat(i) / 3
                let gridPath = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(gridPath, with: .color(gridColor.opacity(0.3)), lineWidth: 0.5)
            }

            // Build line path
            let stepX = size.width / CGFloat(values.count - 1)
            var linePath = Path()
            for (i, val) in values.enumerated() {
                let x = stepX * CGFloat(i)
                let y = size.height - (val - minVal) / range * size.height
                if i == 0 {
                    linePath.move(to: CGPoint(x: x, y: y))
                } else {
                    linePath.addLine(to: CGPoint(x: x, y: y))
                }
            }

            // Fill under line
            var fillPath = linePath
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(fillColor))

            // Stroke line
            context.stroke(linePath, with: .color(lineColor), lineWidth: 1.5)

            // Current value dot
            if let last = values.last {
                let x = size.width
                let y = size.height - (last - minVal) / range * size.height
                let dot = Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
                context.fill(dot, with: .color(lineColor))
            }
        }
    }
}
