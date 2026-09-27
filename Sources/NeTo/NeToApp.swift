import AppKit
import ApplicationServices
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
    @Published private(set) var customWords = CustomDictionary.words
    @Published var previousWordShortcut: DoubleTapModifier {
        didSet { UserDefaults.standard.set(previousWordShortcut.rawValue, forKey: "previousWordShortcut") }
    }
    @Published var selectionShortcut: DoubleTapModifier {
        didSet { UserDefaults.standard.set(selectionShortcut.rawValue, forKey: "selectionShortcut") }
    }

    var hasRequiredAccess: Bool { hasAccessibilityAccess && hasInputMonitoringAccess }

    private let keyboard = KeyboardLayoutService()
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var layoutTimer: Timer?
    private var accessTimer: Timer?
    private var doubleTap = DoubleTapDetector()
    private var revision = 0
    private var started = false

    init() {
        automaticRepair = UserDefaults.standard.object(forKey: "automaticRepair") as? Bool ?? true
        previousWordShortcut = DoubleTapModifier(rawValue: UserDefaults.standard.string(forKey: "previousWordShortcut") ?? "") ?? .shift
        selectionShortcut = DoubleTapModifier(rawValue: UserDefaults.standard.string(forKey: "selectionShortcut") ?? "") ?? .shift
        UserDefaults.standard.removeObject(forKey: "hotKey.1")
        UserDefaults.standard.removeObject(forKey: "hotKey.2")
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
        refreshPermissions()
        refreshLaunchAtLogin()
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
        doubleTap.keyPressed()
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
        guard let shortcut = doubleTap.flagsChanged(event.modifierFlags, at: event.timestamp),
              shortcut == previousWordShortcut || shortcut == selectionShortcut else { return }
        repairManually(triggeredBy: shortcut)
    }

    private func repairManually(triggeredBy shortcut: DoubleTapModifier) {
        guard let snapshot = FocusedText.read() else {
            status = hasRequiredAccess
                ? "Place the caret in a readable text field."
                : "Accessibility and Input Monitoring access are required."
            return
        }
        let selected = snapshot.selection.length > 0
        guard (selected && shortcut == selectionShortcut) || (!selected && shortcut == previousWordShortcut) else { return }
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
