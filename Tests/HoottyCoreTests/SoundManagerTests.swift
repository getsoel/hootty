import Foundation
import Testing
@testable import HoottyCore

@MainActor
struct SoundManagerTests {
    private func makeManager(fileURL: URL? = nil) -> (SoundManager, ConfigFile) {
        let url = fileURL ?? TestHelpers.tempFileURL()
        let configFile = ConfigFile(fileURL: url)
        let manager = SoundManager(configFile: configFile)
        return (manager, configFile)
    }

    @Test func defaultSoundsAreNilWhenNoFile() {
        let (manager, _) = makeManager()
        #expect(manager.sound(for: .bell) == nil)
        #expect(manager.sound(for: .done) == nil)
    }

    @Test func settingBellSoundPersistsToConfigFile() {
        let url = TestHelpers.tempFileURL()
        let (manager, _) = makeManager(fileURL: url)
        manager.setSound(for: .bell, to: "Ping")

        let (manager2, _) = makeManager(fileURL: url)
        #expect(manager2.sound(for: .bell) == "Ping")
    }

    @Test func settingDoneSoundPersistsToConfigFile() {
        let url = TestHelpers.tempFileURL()
        let (manager, _) = makeManager(fileURL: url)
        manager.setSound(for: .done, to: "Glass")

        let (manager2, _) = makeManager(fileURL: url)
        #expect(manager2.sound(for: .done) == "Glass")
    }

    @Test func settingNilRemovesSound() {
        let url = TestHelpers.tempFileURL()
        let (manager1, _) = makeManager(fileURL: url)
        manager1.setSound(for: .bell, to: "Ping")

        let (manager2, _) = makeManager(fileURL: url)
        #expect(manager2.sound(for: .bell) == "Ping")

        manager2.setSound(for: .bell, to: nil)

        let (manager3, _) = makeManager(fileURL: url)
        #expect(manager3.sound(for: .bell) == nil)
    }

    @Test func availableSystemSoundsReturnsNonEmpty() {
        let sounds = SoundManager.availableSystemSounds
        #expect(!sounds.isEmpty)
    }

    @Test func availableSystemSoundsAreSorted() {
        let sounds = SoundManager.availableSystemSounds
        #expect(sounds == sounds.sorted())
    }

    @Test func soundForBellReturnsCorrectValue() {
        let (manager, _) = makeManager()
        manager.setSound(for: .bell, to: "Ping")
        #expect(manager.sound(for: .bell) == "Ping")
    }

    @Test func soundForDoneReturnsCorrectValue() {
        let (manager, _) = makeManager()
        manager.setSound(for: .done, to: "Submarine")
        #expect(manager.sound(for: .done) == "Submarine")
    }

    @Test func playBellCallsSoundPlayer() {
        let (manager, _) = makeManager()
        manager.setSound(for: .bell, to: "Ping")
        var played: String?
        manager.soundPlayer = { name in played = name }
        manager.play(.bell)
        #expect(played == "Ping")
    }

    @Test func playDoneCallsSoundPlayer() {
        let (manager, _) = makeManager()
        manager.setSound(for: .done, to: "Glass")
        var played: String?
        manager.soundPlayer = { name in played = name }
        manager.play(.done)
        #expect(played == "Glass")
    }

    @Test func playDoesNothingWhenBellSoundIsNil() {
        let (manager, _) = makeManager()
        var played = false
        manager.soundPlayer = { _ in played = true }
        manager.play(.bell)
        #expect(!played)
    }

    @Test func playDoesNothingWhenDoneSoundIsNil() {
        let (manager, _) = makeManager()
        var played = false
        manager.soundPlayer = { _ in played = true }
        manager.play(.done)
        #expect(!played)
    }
}
