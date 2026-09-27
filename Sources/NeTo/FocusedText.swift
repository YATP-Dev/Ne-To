import AppKit
import ApplicationServices
import Carbon

@MainActor
struct FocusedText {
    private static var enabledAccessibilityPIDs = Set<pid_t>()
    let element: AXUIElement
    let processID: pid_t
    let value: String
    let selection: CFRange

    static func read() -> Self? {
        guard AXIsProcessTrusted(), CGPreflightListenEventAccess(),
              !IsSecureEventInputEnabled(),
              let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              processID != ProcessInfo.processInfo.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(app, 0.1)
        // Electron apps often leave their accessibility tree disabled until a
        // client requests it. Other apps simply reject this optional attribute.
        if enabledAccessibilityPIDs.insert(processID).inserted {
            AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        }
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.1)
        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
           let subrole = subrole as? String,
           subrole == kAXSecureTextFieldSubrole as String { return nil }
        var value: CFTypeRef?
        var range: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
              let value = value as? String,
              AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success,
              let range, CFGetTypeID(range) == AXValueGetTypeID() else { return nil }
        var selection = CFRange(location: 0, length: 0)
        guard AXValueGetValue(range as! AXValue, .cfRange, &selection),
              selection.location >= 0, selection.length >= 0,
              selection.location + selection.length <= (value as NSString).length else { return nil }
        return Self(element: element, processID: processID, value: value, selection: selection)
    }

    func isStillCurrent() -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == processID,
              let current = Self.read() else { return false }
        return CFEqual(element, current.element)
            && selection.location == current.selection.location
            && selection.length == current.selection.length
            && value == current.value
    }

    func replaceDirectly(range: NSRange, with replacement: String) -> Bool {
        guard selection.length == 0,
              range.location >= 0, range.length > 0,
              range.location + range.length <= (value as NSString).length,
              isStillCurrent() else { return false }
        var rangeSettable = DarwinBoolean(false)
        var textSettable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &rangeSettable) == .success,
              rangeSettable.boolValue,
              AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &textSettable) == .success,
              textSettable.boolValue else { return false }
        var selectedRange = CFRange(location: range.location, length: range.length)
        guard let selectedValue = AXValueCreate(.cfRange, &selectedRange),
              AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, selectedValue) == .success else {
            return false
        }
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString,
                                                  replacement as CFString)
        let delta = (replacement as NSString).length - range.length
        var restoredCaret = CFRange(location: selection.location + (result == .success ? delta : 0), length: 0)
        if let caretValue = AXValueCreate(.cfRange, &restoredCaret) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, caretValue)
        }
        return result == .success
    }

    var prefix: String {
        (value as NSString).substring(to: selection.location)
    }

    var selectedText: String {
        (value as NSString).substring(with: NSRange(location: selection.location, length: selection.length))
    }
}
