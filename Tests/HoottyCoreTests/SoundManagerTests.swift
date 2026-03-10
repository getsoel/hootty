import Testing
import Foundation
@testable import HoottyCore

@Suite struct SoundManagerTests {
    private func tempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("hootty-test-\(UUID().uuidString)")
            .appendingPathComponent("config")
    }

    private func makeManager(fileURL: URL? = nil) -> (SoundManager, ConfigFile) {
        let url = fileURL ?? tempFileURL()
        let configFile = ConfigFile(fileURL: url)
        let manager = SoundManager(configFile: configFile)
        return (manager, configFile)
    }

    @Test func defaultSoundsAreNilWhenNoFile() {
        let (manager, _) = makeManager()
        #expect(manager.bellSound == nil)
        #expect(manager.attentionIdleSound == nil)
        #expect(manager.attentionInputSound == nil)
    }

    @Test func settingSoundPersistsToConfigFile() {
        let url = tempFileURL()
        let (manager, _) = makeManager(fileURL: url)
        manager.bellSound = "Ping"
        manager.attentionIdleSound = "Glass"
        manager.attentionInputSound = "Basso"

        // Reload from same file
        let (manager2, _) = makeManager(fileURL: url)
        #expect(manager2.bellSound == "Ping")
        #expect(manager2.attentionIdleSound == "Glass")
        #expect(manager2.attentionInputSound == "Basso")
    }

    @Test func settingNilRemovesSound() {
        let url = tempFileURL()
        let (manager1, _) = makeManager(fileURL: url)
        manager1.bellSound = "Ping"

        let (manager2, _) = makeManager(fileURL: url)
        #expect(manager2.bellSound == "Ping")

        manager2.bellSound = nil

        let (manager3, _) = makeManager(fileURL: url)
        #expect(manager3.bellSound == nil)
    }

    @Test func availableSystemSoundsReturnsNonEmpty() {
        let sounds = SoundManager.availableSystemSounds()
        #expect(!sounds.isEmpty)
    }

    @Test func availableSystemSoundsAreSorted() {
        let sounds = SoundManager.availableSystemSounds()
        #expect(sounds == sounds.sorted())
    }

    @Test func soundForTriggerReturnsCorrectValue() {
        let (manager, _) = makeManager()
        manager.bellSound = "Ping"
        manager.attentionIdleSound = "Glass"
        manager.attentionInputSound = "Basso"
        #expect(manager.sound(for: .bell) == "Ping")
        #expect(manager.sound(for: .attentionIdle) == "Glass")
        #expect(manager.sound(for: .attentionInput) == "Basso")
    }

    @Test func playCallsSoundPlayer() {
        let (manager, _) = makeManager()
        manager.bellSound = "Ping"
        var played: String?
        manager.soundPlayer = { name in played = name }
        manager.play(.bell)
        #expect(played == "Ping")
    }

    @Test func playDoesNothingWhenSoundIsNil() {
        let (manager, _) = makeManager()
        var played = false
        manager.soundPlayer = { _ in played = true }
        manager.play(.bell)
        #expect(!played)
    }
}
