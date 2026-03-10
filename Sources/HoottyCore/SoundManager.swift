import Foundation
import os

public enum SoundTrigger: String, CaseIterable, Sendable {
    case bell
    case attentionIdle
    case attentionInput
}

@Observable
public final class SoundManager {
    private let configFile: ConfigFile

    public var bellSound: String? {
        get { configFile.get("hootty-bell-sound") }
        set { configFile.set("hootty-bell-sound", value: newValue); configFile.save() }
    }

    public var attentionIdleSound: String? {
        get { configFile.get("hootty-attention-idle-sound") }
        set { configFile.set("hootty-attention-idle-sound", value: newValue); configFile.save() }
    }

    public var attentionInputSound: String? {
        get { configFile.get("hootty-attention-input-sound") }
        set { configFile.set("hootty-attention-input-sound", value: newValue); configFile.save() }
    }

    public init(configFile: ConfigFile) {
        self.configFile = configFile
    }

    // MARK: - Playback

    public func sound(for trigger: SoundTrigger) -> String? {
        switch trigger {
        case .bell: return bellSound
        case .attentionIdle: return attentionIdleSound
        case .attentionInput: return attentionInputSound
        }
    }

    public func play(_ trigger: SoundTrigger) {
        guard let name = sound(for: trigger) else { return }
        soundPlayer?(name)
    }

    /// Set by the app layer to provide actual sound playback (NSSound).
    /// HoottyCore cannot import AppKit, so this bridges the gap.
    public var soundPlayer: ((String) -> Void)?

    public static func availableSystemSounds() -> [String] {
        let soundsDir = "/System/Library/Sounds"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: soundsDir) else {
            return []
        }
        return files
            .filter { $0.hasSuffix(".aiff") }
            .map { ($0 as NSString).deletingPathExtension }
            .sorted()
    }
}
