import AppKit

enum DoubleTapModifier: String, CaseIterable, Identifiable {
    case shift
    case control
    case option
    case command

    var id: Self { self }

    var title: String {
        switch self {
        case .shift: "Double Shift"
        case .control: "Double Control"
        case .option: "Double Option"
        case .command: "Double Command"
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
