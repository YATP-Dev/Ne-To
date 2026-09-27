import AppKit

@MainActor
enum KeyboardReplacement {
    static let eventTag: Int64 = 0x4E65546F

    static func replace(backspaces: Int, with text: String) {
        guard backspaces >= 0, backspaces <= 128, text.utf16.count <= 128 else { return }
        for _ in 0..<backspaces { postKey(0x33) }
        let units = Array(text.utf16)
        units.withUnsafeBufferPointer { buffer in
            guard let pointer = buffer.baseAddress else { return }
            for down in [true, false] {
                guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down) else { continue }
                event.flags = []
                event.setIntegerValueField(.eventSourceUserData, value: eventTag)
                event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: pointer)
                event.post(tap: .cghidEventTap)
            }
        }
    }

    private static func postKey(_ code: CGKeyCode) {
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { continue }
            event.flags = []
            event.setIntegerValueField(.eventSourceUserData, value: eventTag)
            event.post(tap: .cghidEventTap)
        }
    }
}
