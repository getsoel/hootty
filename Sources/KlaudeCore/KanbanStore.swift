import Foundation
import os

@Observable
public final class KanbanStore {
    private static let logger = Logger(subsystem: "com.soel.klaude", category: "kanban")

    public var board: KanbanBoard

    private let fileURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Klaude", isDirectory: true)
        self.fileURL = dir.appendingPathComponent("kanban.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.board = Self.load(from: self.fileURL)
    }

    private static func load(from url: URL) -> KanbanBoard {
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("No kanban file found, creating default board")
            return KanbanBoard.defaultBoard()
        }
        do {
            let data = try Data(contentsOf: url)
            let board = try JSONDecoder().decode(KanbanBoard.self, from: data)
            logger.info("Loaded kanban board with \(board.lanes.count) lanes, \(board.cards.count) cards")
            return board
        } catch {
            logger.error("Failed to load kanban: \(error.localizedDescription)")
            return KanbanBoard.defaultBoard()
        }
    }

    public func save() {
        do {
            let data = try JSONEncoder().encode(board)
            try data.write(to: fileURL, options: .atomic)
            Self.logger.debug("Saved kanban board")
        } catch {
            Self.logger.error("Failed to save kanban: \(error.localizedDescription)")
        }
    }
}
