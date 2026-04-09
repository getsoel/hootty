import Foundation
import os

@MainActor
@Observable
public final class SoundManager {
    private var configFile: ConfigFile

    public init(configFile: ConfigFile) {
        self.configFile = configFile
    }

    public func updateConfigFile(_ newConfigFile: ConfigFile) {
        configFile = newConfigFile
    }

    // MARK: - Sound Config

    private func configKey(for kind: AttentionKind) -> String {
        "hootty-\(kind.rawValue)-sound"
    }

    public func sound(for kind: AttentionKind) -> String? {
        configFile.get(configKey(for: kind))
    }

    public func setSound(for kind: AttentionKind, to value: String?) {
        configFile.set(configKey(for: kind), value: value)
        configFile.save()
    }

    // MARK: - Playback

    public func play(_ kind: AttentionKind) {
        guard let name = sound(for: kind) else { return }
        soundPlayer?(name)
    }

    /// Set by the app layer to provide actual sound playback (NSSound).
    /// HoottyCore cannot import AppKit, so this bridges the gap.
    public var soundPlayer: ((String) -> Void)?

    public nonisolated static let availableSystemSounds: [String] = {
        let soundsDir = "/System/Library/Sounds"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: soundsDir) else {
            return []
        }
        return files
            .filter { $0.hasSuffix(".aiff") }
            .map { ($0 as NSString).deletingPathExtension }
            .sorted()
    }()
}
