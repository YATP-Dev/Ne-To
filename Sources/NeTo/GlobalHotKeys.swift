import AppKit
import Carbon

enum RepairAction: UInt32, CaseIterable {
    case previousWord = 1
    case selection = 2
}

struct HotKey: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let label: String

    static let defaultPreviousWord = HotKey(keyCode: 37, modifiers: UInt32(cmdKey | optionKey | controlKey), label: "L")
    static let defaultSelection = HotKey(keyCode: 1, modifiers: UInt32(cmdKey | optionKey | controlKey), label: "S")

    var display: String {
        let symbols = [
            (UInt32(controlKey), "⌃"),
            (UInt32(optionKey), "⌥"),
            (UInt32(shiftKey), "⇧"),
            (UInt32(cmdKey), "⌘")
        ]
        return symbols.filter { modifiers & $0.0 != 0 }.map(\.1).joined() + label
    }

    static func capture(_ event: NSEvent) -> Self? {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let modifierCount = [NSEvent.ModifierFlags.command, .option, .control]
            .filter { flags.contains($0) }.count
        guard modifierCount >= 2,
              let label = event.charactersIgnoringModifiers?.uppercased(),
              label.count == 1,
              label.unicodeScalars.allSatisfy({ CharacterSet.letters.union(.decimalDigits).contains($0) }) else { return nil }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        return Self(keyCode: UInt32(event.keyCode), modifiers: modifiers, label: label)
    }
}

@MainActor
final class GlobalHotKeys {
    private var handler: EventHandlerRef?
    private var registrations: [RepairAction: EventHotKeyRef] = [:]
    private let onPress: @MainActor (RepairAction) -> Void

    init(onPress: @escaping @MainActor (RepairAction) -> Void) {
        self.onPress = onPress
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, let action = RepairAction(rawValue: id.id) else { return noErr }
            let manager = Unmanaged<GlobalHotKeys>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in manager.onPress(action) }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    @discardableResult
    func register(_ hotKey: HotKey?, for action: RepairAction) -> Bool {
        if let old = registrations.removeValue(forKey: action) { UnregisterEventHotKey(old) }
        guard let hotKey else { return true }
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: 0x4E65546F, id: action.rawValue)
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers, id,
                                        GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        registrations[action] = ref
        return true
    }
}
