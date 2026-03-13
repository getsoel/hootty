import Foundation

public enum FocusDirection: String, CaseIterable, Sendable {
    case up, down, left, right
}

public struct SidebarSection: Identifiable {
    public var id: String {
        guard let branch else { return "__ungrouped__" }
        return "\(repoRoot ?? "__norepo__")|\(branch)"
    }
    public let repoRoot: String?
    public let repoDisplayName: String?
    public let branch: String?
    public let isHead: Bool
    public let panes: [Pane]

    public var displayLabel: String? {
        guard let branch else { return nil }
        if let repoDisplayName { return "\(repoDisplayName)/\(branch)" }
        return branch
    }
}

@Observable
public final class Workspace: Identifiable {
    public let id: UUID
    public var name: String
    public var repoPath: String?
    public var headBranches: [String: String] = [:]
    public var rootNode: SplitNode
    public var focusedPaneID: UUID?
    private var paneCounter = 0

    public var focusedPane: Pane? {
        guard let focusedPaneID else { return rootNode.firstPane() }
        return rootNode.findPane(id: focusedPaneID) ?? rootNode.firstPane()
    }

    public var allPanes: [Pane] {
        rootNode.allPanes()
    }

    public var isRunning: Bool {
        allPanes.contains { $0.isRunning }
    }

    public var hasThinkingPane: Bool {
        allPanes.contains { $0.isThinking }
    }

    public var hasAttention: Bool {
        attentionKind != nil
    }

    /// Returns the attention kind if any unfocused pane has attention.
    public var attentionKind: AttentionKind? {
        for pane in allPanes where pane.id != focusedPaneID {
            if let kind = pane.attentionKind {
                return kind
            }
        }
        return nil
    }

    // MARK: - Sidebar Sections

    /// Backward-compat: returns first head branch value for branch picker.
    public var headBranch: String? {
        headBranches.values.first
    }

    public var hasBranchSections: Bool {
        allPanes.contains { $0.branch != nil }
    }

    public var sidebarSections: [SidebarSection] {
        let (grouped, keyOrder) = groupPanesByBranch()
        let (headSections, worktreeSectionsByRepo, otherSections, ungroupedPanes) = classifySections(grouped: grouped, keyOrder: keyOrder)
        return assembleSections(headSections: headSections, worktreeSectionsByRepo: worktreeSectionsByRepo, otherSections: otherSections, ungroupedPanes: ungroupedPanes)
    }

    private struct BranchGroupKey: Hashable {
        let repoRoot: String?
        let branch: String?
    }

    /// Group panes by (repoRoot, branch), preserving insertion order.
    private func groupPanesByBranch() -> (grouped: [BranchGroupKey: [Pane]], keyOrder: [BranchGroupKey]) {
        let panes = allPanes
        var grouped: [BranchGroupKey: [Pane]] = [:]
        var keyOrder: [BranchGroupKey] = []
        for pane in panes {
            let key = BranchGroupKey(repoRoot: pane.repoRoot, branch: pane.branch)
            if grouped[key] == nil {
                keyOrder.append(key)
            }
            grouped[key, default: []].append(pane)
        }
        return (grouped, keyOrder)
    }

    /// Classify groups into HEAD sections, worktree sections (keyed by repo), other sections, and ungrouped panes.
    private func classifySections(
        grouped: [BranchGroupKey: [Pane]], keyOrder: [BranchGroupKey]
    ) -> (head: [SidebarSection], worktreesByRepo: [String: [SidebarSection]], other: [SidebarSection], ungrouped: [Pane]) {
        var headSections: [SidebarSection] = []
        var worktreeSectionsByRepo: [String: [SidebarSection]] = [:]
        var otherSections: [SidebarSection] = []
        var ungroupedPanes: [Pane] = []

        for key in keyOrder {
            let groupPanes = grouped[key]!

            guard let branch = key.branch else {
                ungroupedPanes.append(contentsOf: groupPanes)
                continue
            }

            let repoRoot = key.repoRoot
            let repoDisplayName = repoRoot.map { URL(fileURLWithPath: $0).lastPathComponent }
            let isHead = repoRoot.map { headBranches[$0] == branch } ?? false

            let section = SidebarSection(
                repoRoot: repoRoot,
                repoDisplayName: repoDisplayName,
                branch: branch,
                isHead: isHead,
                panes: groupPanes
            )

            let isWorktree = groupPanes.contains { $0.worktreePath != nil }

            if isHead {
                headSections.append(section)
            } else if isWorktree, let root = repoRoot {
                worktreeSectionsByRepo[root, default: []].append(section)
            } else {
                otherSections.append(section)
            }
        }

        return (headSections, worktreeSectionsByRepo, otherSections, ungroupedPanes)
    }

    /// Assemble final section list: HEAD sections with nested worktrees, then other, then ungrouped.
    private func assembleSections(
        headSections: [SidebarSection],
        worktreeSectionsByRepo: [String: [SidebarSection]],
        otherSections: [SidebarSection],
        ungroupedPanes: [Pane]
    ) -> [SidebarSection] {
        var result: [SidebarSection] = []
        for headSection in headSections {
            result.append(headSection)
            if let root = headSection.repoRoot,
               let worktrees = worktreeSectionsByRepo[root] {
                result.append(contentsOf: worktrees)
            }
        }
        result.append(contentsOf: otherSections)
        if !ungroupedPanes.isEmpty {
            result.append(SidebarSection(repoRoot: nil, repoDisplayName: nil, branch: nil, isHead: false, panes: ungroupedPanes))
        }
        return result
    }

    // MARK: - Initializers

    public init(name: String) {
        self.id = UUID()
        self.name = name
        self.paneCounter = 1
        let pane = Pane(name: "Pane 1")
        self.rootNode = SplitNode(pane: pane)
        self.focusedPaneID = pane.id
    }

    /// Restoration initializer.
    public init(id: UUID, name: String, repoPath: String? = nil,
                headBranches: [String: String] = [:],
                rootNode: SplitNode, focusedPaneID: UUID?) {
        self.id = id
        self.name = name
        self.repoPath = repoPath
        self.headBranches = headBranches
        self.rootNode = rootNode
        self.focusedPaneID = focusedPaneID
        self.paneCounter = rootNode.allPanes().count
    }

    // MARK: - Branches

    /// Returns local branches (enriched with pane cross-references) plus
    /// remote-only branches appended. Returns empty for non-git workspaces.
    public func listBranches() -> [BranchRef] {
        guard let repoPath else { return [] }
        let (locals, remotes, _) = GitWorktreeManager.listBranches(repoPath: repoPath)

        var panesByBranchName: [String: [UUID]] = [:]
        for pane in allPanes {
            if let branch = pane.branch {
                panesByBranchName[branch, default: []].append(pane.id)
            }
        }

        var result = locals.map { ref -> BranchRef in
            var branch = ref
            if let paneIDs = panesByBranchName[ref.name] {
                branch.hasPanes = true
                branch.paneIDs = paneIDs
            }
            return branch
        }

        let localNames = Set(locals.map(\.name))
        result += remotes.filter { !localNames.contains($0.name) }
        return result
    }

    // MARK: - Splitting

    @discardableResult
    public func splitFocusedPane(direction: SplitDirection, placeBefore: Bool = false, workingDirectory: String? = nil) -> Pane? {
        guard let focused = focusedPane else { return nil }
        paneCounter += 1
        let newPane = Pane(
            name: "Pane \(paneCounter)",
            shell: focused.shell,
            workingDirectory: workingDirectory ?? focused.workingDirectory
        )
        if rootNode.splitPane(paneID: focused.id, direction: direction, newPane: newPane, placeBefore: placeBefore) {
            focusedPaneID = newPane.id
            equalizeChainContaining(paneID: newPane.id, direction: direction)
            return newPane
        }
        return nil
    }

    // MARK: - Equalize

    public func equalizeSplits() {
        rootNode.equalizeSplits()
    }

    // MARK: - Directional Focus

    public func focusPaneInDirection(_ direction: FocusDirection) {
        guard let currentID = focusedPaneID else { return }
        let rects = rootNode.paneRects()
        guard let focusedRect = rects[currentID] else { return }

        let epsilon = 0.001
        var bestID: UUID?
        var bestPrimary = Double.infinity
        var bestPerp = Double.infinity

        for (candidateID, candidateRect) in rects where candidateID != currentID {
            let adj = adjacency(from: focusedRect, to: candidateRect, direction: direction, epsilon: epsilon)
            guard adj.isAdjacent && adj.hasOverlap else { continue }
            if adj.primaryDist < bestPrimary - epsilon
                || (abs(adj.primaryDist - bestPrimary) < epsilon && adj.perpendicularDist < bestPerp) {
                bestPrimary = adj.primaryDist
                bestPerp = adj.perpendicularDist
                bestID = candidateID
            }
        }

        if let bestID {
            focusPane(id: bestID)
        }
    }

    private func adjacency(
        from src: CGRect, to dst: CGRect, direction: FocusDirection, epsilon: Double
    ) -> (isAdjacent: Bool, primaryDist: Double, hasOverlap: Bool, perpendicularDist: Double) {
        let isAdj: Bool
        let primaryDist: Double
        let hasOverlap: Bool
        let perpDist: Double

        switch direction {
        case .right:
            isAdj = dst.minX >= src.maxX - epsilon
            primaryDist = dst.minX - src.maxX
            hasOverlap = dst.maxY > src.minY + epsilon && dst.minY < src.maxY - epsilon
            perpDist = abs(dst.midY - src.midY)
        case .left:
            isAdj = dst.maxX <= src.minX + epsilon
            primaryDist = src.minX - dst.maxX
            hasOverlap = dst.maxY > src.minY + epsilon && dst.minY < src.maxY - epsilon
            perpDist = abs(dst.midY - src.midY)
        case .down:
            isAdj = dst.minY >= src.maxY - epsilon
            primaryDist = dst.minY - src.maxY
            hasOverlap = dst.maxX > src.minX + epsilon && dst.minX < src.maxX - epsilon
            perpDist = abs(dst.midX - src.midX)
        case .up:
            isAdj = dst.maxY <= src.minY + epsilon
            primaryDist = src.minY - dst.maxY
            hasOverlap = dst.maxX > src.minX + epsilon && dst.minX < src.maxX - epsilon
            perpDist = abs(dst.midX - src.midX)
        }

        return (isAdj, primaryDist, hasOverlap, perpDist)
    }

    // MARK: - Chain Equalization (i3-style)

    private func equalizeChainContaining(paneID: UUID, direction: SplitDirection) {
        let chain = rootNode.ancestorChain(for: paneID)
        var highestSameDir: SplitNode?
        for entry in chain.reversed() {
            if case .split(let dir, _, _) = entry.node.content, dir == direction {
                highestSameDir = entry.node
            } else {
                break
            }
        }
        highestSameDir?.equalizeSameDirectionChain(direction: direction)
    }

    // MARK: - Pane Management

    public func removePane(id: UUID) {
        if !rootNode.removePane(id: id) {
            paneCounter += 1
            let newPane = Pane(name: "Pane \(paneCounter)")
            rootNode.content = .leaf(newPane)
            focusedPaneID = newPane.id
            return
        }
        if focusedPaneID == id {
            focusedPaneID = rootNode.firstPane()?.id
        }
    }

    public func focusPane(id: UUID) {
        guard let pane = rootNode.findPane(id: id) else { return }
        focusedPaneID = id
        pane.attentionKind = nil
    }

    public func findPane(id: UUID) -> Pane? {
        rootNode.findPane(id: id)
    }

    @discardableResult
    public func swapPanes(_ id1: UUID, _ id2: UUID) -> Bool {
        rootNode.swapPanes(id1, id2)
    }

    public func focusNextPane() {
        let panes = allPanes
        guard panes.count > 1,
              let currentID = focusedPaneID,
              let idx = panes.firstIndex(where: { $0.id == currentID }) else { return }
        let nextIdx = (idx + 1) % panes.count
        focusPane(id: panes[nextIdx].id)
    }

    public func focusPreviousPane() {
        let panes = allPanes
        guard panes.count > 1,
              let currentID = focusedPaneID,
              let idx = panes.firstIndex(where: { $0.id == currentID }) else { return }
        let prevIdx = (idx - 1 + panes.count) % panes.count
        focusPane(id: panes[prevIdx].id)
    }
}

extension Workspace: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, repoPath, headBranch, headBranches, rootNode, focusedPaneID
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Migration: try new headBranches dict first, fall back to old headBranch string
        let branches: [String: String]
        if let dict = try container.decodeIfPresent([String: String].self, forKey: .headBranches) {
            branches = dict
        } else if let oldBranch = try container.decodeIfPresent(String.self, forKey: .headBranch),
                  let repoPath = try container.decodeIfPresent(String.self, forKey: .repoPath) {
            branches = [repoPath: oldBranch]
        } else {
            branches = [:]
        }

        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            repoPath: try container.decodeIfPresent(String.self, forKey: .repoPath),
            headBranches: branches,
            rootNode: try container.decode(SplitNode.self, forKey: .rootNode),
            focusedPaneID: try container.decodeIfPresent(UUID.self, forKey: .focusedPaneID)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(repoPath, forKey: .repoPath)
        if !headBranches.isEmpty {
            try container.encode(headBranches, forKey: .headBranches)
        }
        try container.encode(rootNode, forKey: .rootNode)
        try container.encodeIfPresent(focusedPaneID, forKey: .focusedPaneID)
    }
}
