import AppKit
import Testing
@testable import NeTo

@Test func detectsConfiguredDoubleModifierWithoutInterveningKey() {
    var detector = DoubleTapDetector()
    #expect(detector.flagsChanged(.shift, at: 1.00) == nil)
    #expect(detector.flagsChanged([], at: 1.08) == nil)
    #expect(detector.flagsChanged(.shift, at: 1.20) == nil)
    #expect(detector.flagsChanged([], at: 1.29) == .shift)

    #expect(detector.flagsChanged(.option, at: 2.00) == nil)
    #expect(detector.flagsChanged([], at: 2.05) == nil)
    #expect(detector.flagsChanged(.option, at: 2.20) == nil)
    #expect(detector.flagsChanged([], at: 2.25) == .option)
}

@Test func ignoresSlowOrInterruptedModifierTaps() {
    var detector = DoubleTapDetector()
    #expect(detector.flagsChanged(.control, at: 1.00) == nil)
    #expect(detector.flagsChanged([], at: 1.05) == nil)
    #expect(detector.flagsChanged(.control, at: 1.60) == nil)
    #expect(detector.flagsChanged([], at: 1.65) == nil)
    detector.keyPressed()
    #expect(detector.flagsChanged(.control, at: 1.75) == nil)
    #expect(detector.flagsChanged([], at: 1.80) == nil)
    #expect(detector.flagsChanged([.control, .shift], at: 2.00) == nil)
    #expect(detector.flagsChanged([], at: 2.08) == nil)
}

@Test func keyChordMatchesOnlyItsPhysicalKeyAndModifiers() throws {
    let shortcut = KeyChord(keyCode: 37, modifiers: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue,
                            keyLabel: "L")
    let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 37, keyDown: true))
    event.flags = [.maskCommand, .maskAlternate]
    #expect(shortcut.matches(event))
    event.flags = [.maskCommand]
    #expect(!shortcut.matches(event))
    event.flags = [.maskCommand, .maskAlternate]
    event.setIntegerValueField(.keyboardEventKeycode, value: 40)
    #expect(!shortcut.matches(event))

    let saved = ManualShortcut.chord(shortcut)
    let restored = try JSONDecoder().decode(ManualShortcut.self, from: JSONEncoder().encode(saved))
    #expect(restored == saved)
}
