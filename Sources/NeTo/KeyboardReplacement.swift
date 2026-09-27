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

    private static func postKey(_ code: CGKeyCode, flags: CGEventFlags = []) {
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { continue }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: eventTag)
            event.post(tap: .cghidEventTap)
        }
    }

    static func selectPreviousCharacters(trailing: Int, length: Int) -> Bool {
        guard trailing == 1, (1...64).contains(length) else { return false }
        postKey(0x7B)
        for _ in 0..<length { postKey(0x7B, flags: .maskShift) }
        return true
    }

    static func moveRight() {
        postKey(0x7C)
    }

    static func paste(_ text: String) -> ClipboardRestore? {
        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems?.compactMap { original -> NSPasteboardItem? in
            let copy = NSPasteboardItem()
            for type in original.types {
                if let data = original.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy.types.isEmpty ? nil : copy
        } ?? []
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            pasteboard.clearContents()
            if !savedItems.isEmpty { pasteboard.writeObjects(savedItems) }
            return nil
        }
        let changeCount = pasteboard.changeCount
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: down) else {
                return ClipboardRestore(items: savedItems, changeCount: changeCount)
            }
            event.flags = .maskCommand
            event.setIntegerValueField(.eventSourceUserData, value: eventTag)
            event.post(tap: .cgAnnotatedSessionEventTap)
        }
        return ClipboardRestore(items: savedItems, changeCount: changeCount)
    }
}

struct ClipboardRestore {
    let items: [NSPasteboardItem]
    let changeCount: Int

    func restoreIfUnchanged() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == changeCount else { return }
        pasteboard.clearContents()
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }
}
