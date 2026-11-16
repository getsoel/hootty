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

    /// Sounds that play when the config doesn't set one. Only `blocked` is on
    /// by default: it's the one state where work stops until the user acts.
    /// The others fire often (every agent turn, any program's bell) and stay opt-in.
    public nonisolated static let defaultSounds: [AttentionKind: String] = [.blocked: "Submarine"]

    /// Config value that turns off a kind that has a default sound. Removing
    /// the key would bring the default back.
    public nonisolated static let noSound = "none"

    private func configKey(for kind: AttentionKind) -> String {
        "hootty-\(kind.rawValue)-sound"
    }

    public func sound(for kind: AttentionKind) -> String? {
        guard let value = configFile.get(configKey(for: kind)) else {
            return Self.defaultSounds[kind]
        }
        return value == Self.noSound ? nil : value
    }

    /// Set the sound for `kind`; nil means no sound. Choosing the default
    /// removes the key so the config stays minimal.
    public func setSound(for kind: AttentionKind, to value: String?) {
        let defaultSound = Self.defaultSounds[kind]
        let stored: String? = switch value {
        case nil: defaultSound == nil ? nil : Self.noSound
        case defaultSound: nil
        default: value
        }
        configFile.set(configKey(for: kind), value: stored)
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
