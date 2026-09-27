import AppKit

enum SwitchSound: String, CaseIterable, Identifiable {
    case shutter
    case drop
    case keys

    var id: String { rawValue }

    func title(in language: InterfaceLanguage) -> String {
        switch self {
        case .shutter: language.text("Shutter Click", "Щелчок затвора")
        case .drop: language.text("Water Drop", "Капля воды")
        case .keys: language.text("Keyboard Key", "Клавиша")
        }
    }

    var resourceName: String {
        switch self {
        case .shutter: "switch-shutter"
        case .drop: "switch-drop"
        case .keys: "switch-keys"
        }
    }
}

@MainActor
final class SwitchSoundPlayer {
    private var currentSound: NSSound?

    func play(_ selection: SwitchSound, volume: Double) {
        currentSound?.stop()
        currentSound = nil
        let level = volume.isFinite ? min(1, max(0, volume)) : 1
        guard level > 0,
              let url = Bundle.main.url(forResource: selection.resourceName,
                                        withExtension: "wav", subdirectory: "Sounds"),
              let sound = NSSound(contentsOf: url, byReference: true) else { return }
        sound.volume = Float(level)
        currentSound = sound
        sound.play()
    }
}
