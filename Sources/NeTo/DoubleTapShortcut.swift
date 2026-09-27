import AppKit

enum DoubleTapModifier: String, CaseIterable, Identifiable, Codable {
    case shift
    case control
    case option
    case command

    var id: Self { self }

    func title(in language: InterfaceLanguage) -> String {
        switch self {
        case .shift: language.text("Double Shift", "Двойной Shift")
        case .control: language.text("Double Control", "Двойной Control")
        case .option: language.text("Double Option", "Двойной Option")
        case .command: language.text("Double Command", "Двойной Command")
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .shift: .shift
        case .control: .control
        case .option: .option
        case .command: .command
        }
    }
}

struct DoubleTapDetector {
    private var held: DoubleTapModifier?
    private var lastRelease: [DoubleTapModifier: TimeInterval] = [:]

    mutating func keyPressed() {
        held = nil
        lastRelease.removeAll()
    }

    mutating func flagsChanged(_ flags: NSEvent.ModifierFlags, at time: TimeInterval) -> DoubleTapModifier? {
        let modifiers = flags.intersection([.shift, .control, .option, .command])
        if let modifier = DoubleTapModifier.allCases.first(where: { modifiers == $0.flag }) {
            held = modifier
            return nil
        }
        guard modifiers.isEmpty, let released = held else {
            held = nil
            lastRelease.removeAll()
            return nil
        }
        held = nil
        if let previous = lastRelease[released], time >= previous, time - previous < 0.42 {
            lastRelease[released] = nil
            return released
        }
        lastRelease[released] = time
        return nil
    }
}

struct KeyChord: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt64
    let keyLabel: String

    static let modifierMask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

    func display(in language: InterfaceLanguage) -> String {
        let symbols: [(CGEventFlags, String)] = [
            (.maskControl, "⌃"), (.maskAlternate, "⌥"), (.maskShift, "⇧"), (.maskCommand, "⌘")
        ]
        let label = keyLabel == "Space" ? language.text("Space", "Пробел") : keyLabel
        return symbols.filter { modifiers & $0.0.rawValue != 0 }.map(\.1).joined() + label
    }

    static func capture(_ event: NSEvent) -> KeyChord? {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !flags.isEmpty else { return nil }
        var modifiers: CGEventFlags = []
        if flags.contains(.command) { modifiers.insert(.maskCommand) }
        if flags.contains(.control) { modifiers.insert(.maskControl) }
        if flags.contains(.option) { modifiers.insert(.maskAlternate) }
        if flags.contains(.shift) { modifiers.insert(.maskShift) }
        let label: String
        switch event.keyCode {
        case 36, 76: label = "↩"
        case 48: label = "⇥"
        case 49: label = "Space"
        case 51: label = "⌫"
        case 123: label = "←"
        case 124: label = "→"
        case 125: label = "↓"
        case 126: label = "↑"
        default:
            label = event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        }
        return KeyChord(keyCode: event.keyCode, modifiers: modifiers.rawValue, keyLabel: label)
    }

    func matches(_ event: CGEvent) -> Bool {
        UInt16(event.getIntegerValueField(.keyboardEventKeycode)) == keyCode
            && event.flags.intersection(Self.modifierMask).rawValue == modifiers
    }
}

enum ManualShortcut: Codable, Equatable {
    case doubleTap(DoubleTapModifier)
    case chord(KeyChord)

    func display(in language: InterfaceLanguage) -> String {
        switch self {
        case .doubleTap(let modifier): modifier.title(in: language)
        case .chord(let chord): chord.display(in: language)
        }
    }
}

enum ManualAction: String {
    case previousWord
    case selection
}
