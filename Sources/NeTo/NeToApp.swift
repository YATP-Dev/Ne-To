import AppKit
import ApplicationServices
import Carbon
import ServiceManagement
import SwiftUI

@main
struct NeToApp: App {
    @StateObject private var model = NeToModel.shared
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ne-To").font(.headline)
                Text(model.status).font(.caption).fixedSize(horizontal: false, vertical: true)
                if !model.hasRequiredAccess {
                    Text("Accessibility and Input Monitoring access are required.")
                        .font(.caption)
                    Button("Grant Required Access") { model.requestPermissions() }
                }
                Button("Settings…") { openSettings() }
                Text("Press Shift twice to repair selected text or the previous word.")
                    .font(.caption)
                Divider()
                Button("Quit Ne-To") { NSApplication.shared.terminate(nil) }
            }
            .padding(14)
            .frame(width: 300)
            .onAppear { model.start(); model.refreshPermissions() }
        } label: {
            Text(model.currentLayout?.rawValue ?? "EN/RU")
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView(model: model)
        }
    }
}

@MainActor
final class NeToModel: ObservableObject {
    static let shared = NeToModel()
    @Published var automaticRepair: Bool {
        didSet { UserDefaults.standard.set(automaticRepair, forKey: "automaticRepair") }
    }
    @Published private(set) var status = "Ready. Press Shift twice to repair text."
    @Published private(set) var currentLayout: KeyboardLanguage?
    @Published private(set) var hasAccessibilityAccess = false
    @Published private(set) var hasInputMonitoringAccess = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var launchAtLoginMessage: String?
    @Published private(set) var previousWordHotKey: HotKey
    @Published private(set) var selectionHotKey: HotKey
    @Published private(set) var recordingAction: RepairAction?
    @Published private(set) var hotKeyMessage: String?
    @Published private(set) var customWords = CustomDictionary.words

    var hasRequiredAccess: Bool { hasAccessibilityAccess && hasInputMonitoringAccess }

    private let keyboard = KeyboardLayoutService()
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var layoutTimer: Timer?
    private var accessTimer: Timer?
    private var hotKeys: GlobalHotKeys?
    private var recordingMonitor: Any?
    private var lastShiftRelease: TimeInterval = 0
    private var shiftWasAlone = false
    private var revision = 0
    private var started = false

    init() {
        automaticRepair = UserDefaults.standard.object(forKey: "automaticRepair") as? Bool ?? true
        previousWordHotKey = Self.savedHotKey(for: .previousWord) ?? .defaultPreviousWord
        selectionHotKey = Self.savedHotKey(for: .selection) ?? .defaultSelection
        currentLayout = keyboard.currentLayout
        Task { @MainActor [weak self] in self?.start() }
    }

    func start() {
        guard !started else { return }
        started = true
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.handleKey(event) }
        }
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlags(event) }
        }
        layoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.currentLayout = self.keyboard.currentLayout
            }
        }
        accessTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }
        hotKeys = GlobalHotKeys { [weak self] action in self?.repairManually(scope: action) }
        let wordRegistered = hotKeys?.register(previousWordHotKey, for: .previousWord) == true
        let selectionRegistered = hotKeys?.register(selectionHotKey, for: .selection) == true
        if !wordRegistered || !selectionRegistered {
            hotKeyMessage = "A shortcut is already used by macOS or another app. Change it in Settings."
        }
        refreshPermissions()
        refreshLaunchAtLogin()
    }

    private static func savedHotKey(for action: RepairAction) -> HotKey? {
        guard let data = UserDefaults.standard.data(forKey: "hotKey.\(action.rawValue)") else { return nil }
        return try? JSONDecoder().decode(HotKey.self, from: data)
    }

    func refreshLaunchAtLogin() {
        let state = SMAppService.mainApp.status
        launchAtLogin = state == .enabled || state == .requiresApproval
        launchAtLoginMessage = state == .requiresApproval
            ? "Approve Ne-To in System Settings → General → Login Items."
            : nil
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLaunchAtLogin()
        } catch {
            refreshLaunchAtLogin()
            launchAtLoginMessage = error.localizedDescription
        }
    }

    func addCustomWord(_ word: String) -> Bool {
        guard CustomDictionary.add(word) else { return false }
        customWords = CustomDictionary.words
        return true
    }

    func removeCustomWord(_ word: String) {
        CustomDictionary.remove(word)
        customWords = CustomDictionary.words
    }

    func hotKey(for action: RepairAction) -> HotKey {
        action == .previousWord ? previousWordHotKey : selectionHotKey
    }

    func beginRecording(_ action: RepairAction) {
        cancelRecording()
        recordingAction = action
        hotKeyMessage = nil
        hotKeys?.register(nil, for: action)
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let action = self.recordingAction else { return event }
            if event.keyCode == 53 {
                self.cancelRecording()
            } else if let candidate = HotKey.capture(event) {
                self.saveHotKey(candidate, for: action)
            } else {
                self.hotKeyMessage = "Press a letter or number with at least two of ⌃, ⌥, ⌘. Esc cancels."
            }
            return nil
        }
    }

    func cancelRecording() {
        guard let action = recordingAction else { return }
        if let recordingMonitor { NSEvent.removeMonitor(recordingMonitor) }
        recordingMonitor = nil
        recordingAction = nil
        hotKeys?.register(hotKey(for: action), for: action)
    }

    private func saveHotKey(_ candidate: HotKey, for action: RepairAction) {
        let other: RepairAction = action == .previousWord ? .selection : .previousWord
        guard candidate.keyCode != hotKey(for: other).keyCode || candidate.modifiers != hotKey(for: other).modifiers else {
            hotKeyMessage = "The two actions need different shortcuts."
            return
        }
        guard hotKeys?.register(candidate, for: action) == true else {
            hotKeyMessage = "This shortcut is already used by macOS or another app."
            return
        }
        if let recordingMonitor { NSEvent.removeMonitor(recordingMonitor) }
        recordingMonitor = nil
        recordingAction = nil
        if action == .previousWord { previousWordHotKey = candidate }
        else { selectionHotKey = candidate }
        UserDefaults.standard.set(try? JSONEncoder().encode(candidate), forKey: "hotKey.\(action.rawValue)")
        hotKeyMessage = nil
    }

    func refreshPermissions() {
        hasAccessibilityAccess = AXIsProcessTrusted()
        hasInputMonitoringAccess = CGPreflightListenEventAccess()
    }

    func requestPermissions() {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        CGRequestListenEventAccess()
        refreshPermissions()
    }

    private func handleKey(_ event: NSEvent) {
        if event.cgEvent?.getIntegerValueField(.eventSourceUserData) == KeyboardReplacement.eventTag { return }
        revision &+= 1
        shiftWasAlone = false
        guard automaticRepair, !event.isARepeat,
              [49, 36, 76].contains(Int(event.keyCode)) else { return }
        let expectedRevision = revision
        let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            guard expectedRevision == revision,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == processID else { return }
            repairAutomatically(in: processID)
        }
    }

    private func handleFlags(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.shift, .control, .option, .command])
        let now = ProcessInfo.processInfo.systemUptime
        if flags == .shift {
            shiftWasAlone = true
        } else if flags.isEmpty && shiftWasAlone {
            shiftWasAlone = false
            if now - lastShiftRelease < 0.42 {
                lastShiftRelease = 0
                repairManually(scope: nil)
            } else {
                lastShiftRelease = now
            }
        } else {
            shiftWasAlone = false
        }
    }

    func repairManually(scope: RepairAction?) {
        guard let snapshot = FocusedText.read() else {
            status = hasRequiredAccess
                ? "Place the caret in a readable text field."
                : "Accessibility and Input Monitoring access are required."
            return
        }
        let selected = snapshot.selection.length > 0
        if scope == .selection && !selected {
            status = "Select text to repair."
            return
        }
        if scope == .previousWord && selected {
            status = "Place the caret after a word to repair it."
            return
        }
        let input = selected ? snapshot.selectedText : WordBoundary.precedingWord(in: snapshot.prefix, allowDelimiter: false)
        guard let input, let conversion = LayoutConversion.convert(input), snapshot.isStillCurrent() else {
            status = "No EN/RU text to repair."
            return
        }
        KeyboardReplacement.replace(backspaces: selected ? 0 : input.utf16.count, with: conversion.output)
        keyboard.select(conversion.target)
        currentLayout = keyboard.currentLayout
        status = "Repaired \(conversion.source.rawValue) → \(conversion.target.rawValue)."
    }

    private func repairAutomatically(in processID: pid_t?) {
        guard let processID, let snapshot = FocusedText.read(), snapshot.processID == processID,
              snapshot.selection.length == 0,
              snapshot.selection.location == (snapshot.value as NSString).length,
              let delimiter = snapshot.prefix.last, delimiter == " " || delimiter == "\n",
              let word = WordBoundary.precedingWord(in: snapshot.prefix, allowDelimiter: true),
              let conversion = AutomaticDecision.candidate(for: word),
              snapshot.isStillCurrent() else { return }
        KeyboardReplacement.replace(backspaces: word.utf16.count + 1,
                                    with: conversion.output + String(delimiter))
        keyboard.select(conversion.target)
        currentLayout = keyboard.currentLayout
        status = "Repaired \(conversion.source.rawValue) → \(conversion.target.rawValue)."
    }
}
