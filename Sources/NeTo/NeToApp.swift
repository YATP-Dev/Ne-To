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
                Text(model.status.text(in: model.interfaceLanguage))
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
                if !model.hasRequiredAccess {
                    Text(AppStatus.accessRequired.text(in: model.interfaceLanguage))
                        .font(.caption)
                    Button(model.interfaceLanguage.text("Grant Required Access", "Предоставить доступ")) {
                        model.requestPermissions()
                    }
                }
                Button(model.interfaceLanguage.text("Settings…", "Настройки…")) { openSettings() }
                Text(model.interfaceLanguage.text("Press Shift twice to repair selected text or the previous word.",
                                                  "Дважды нажмите Shift, чтобы исправить выделенный текст или предыдущее слово."))
                    .font(.caption)
                Divider()
                Button(model.interfaceLanguage.text("Quit Ne-To", "Завершить Ne-To")) {
                    NSApplication.shared.terminate(nil)
                }
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
    @Published var interfaceLanguage: InterfaceLanguage {
        didSet { UserDefaults.standard.set(interfaceLanguage.rawValue, forKey: "interfaceLanguage") }
    }
    @Published var automaticRepair: Bool {
        didSet { UserDefaults.standard.set(automaticRepair, forKey: "automaticRepair") }
    }
    @Published var playSound: Bool {
        didSet { UserDefaults.standard.set(playSound, forKey: "playSound") }
    }
    @Published var switchSound: SwitchSound {
        didSet { UserDefaults.standard.set(switchSound.rawValue, forKey: "switchSound") }
    }
    @Published var switchSoundVolume: Double {
        didSet { UserDefaults.standard.set(switchSoundVolume, forKey: "switchSoundVolume") }
    }
    @Published private(set) var status = AppStatus.ready
    @Published private(set) var currentLayout: KeyboardLanguage?
    @Published private(set) var hasAccessibilityAccess = false
    @Published private(set) var hasInputMonitoringAccess = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var launchAtLoginMessage: LaunchAtLoginNotice?
    @Published private(set) var customWords = CustomDictionary.words
    @Published private(set) var excludedApplications = ApplicationExclusions.applications
    @Published private(set) var previousWordShortcut: ManualShortcut
    @Published private(set) var selectionShortcut: ManualShortcut
    @Published private(set) var recordingAction: ManualAction?
    @Published private(set) var shortcutMessage: ShortcutNotice?

    var hasRequiredAccess: Bool { hasAccessibilityAccess && hasInputMonitoringAccess }

    private let keyboard = KeyboardLayoutService()
    private let switchSoundPlayer = SwitchSoundPlayer()
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var layoutTimer: Timer?
    private var accessTimer: Timer?
    private var shortcutTap: ShortcutEventTap?
    private var recordingMonitor: Any?
    private var recordingDoubleTap = DoubleTapDetector()
    private var doubleTap = DoubleTapDetector()
    private var revision = 0
    private var started = false

    init() {
        interfaceLanguage = .saved
        automaticRepair = UserDefaults.standard.object(forKey: "automaticRepair") as? Bool ?? true
        playSound = UserDefaults.standard.object(forKey: "playSound") as? Bool ?? true
        switchSound = SwitchSound(rawValue: UserDefaults.standard.string(forKey: "switchSound") ?? "") ?? .shutter
        let savedVolume = UserDefaults.standard.object(forKey: "switchSoundVolume") as? Double ?? 1
        switchSoundVolume = savedVolume.isFinite ? min(1, max(0, savedVolume)) : 1
        previousWordShortcut = Self.savedShortcut(for: .previousWord)
        selectionShortcut = Self.savedShortcut(for: .selection)
        UserDefaults.standard.removeObject(forKey: "previousWordShortcut")
        UserDefaults.standard.removeObject(forKey: "selectionShortcut")
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
        shortcutTap = ShortcutEventTap { [weak self] chord in
            self?.repairManually(triggeredBy: .chord(chord))
        }
        if shortcutTap?.update(chords: configuredChords) == false {
            shortcutMessage = .tapUnavailable
        }
        refreshPermissions()
        refreshLaunchAtLogin()
    }

    private static func savedShortcut(for action: ManualAction) -> ManualShortcut {
        if let data = UserDefaults.standard.data(forKey: "manualShortcut.\(action.rawValue)"),
           let shortcut = try? JSONDecoder().decode(ManualShortcut.self, from: data) {
            return shortcut
        }
        let oldKey = action == .previousWord ? "previousWordShortcut" : "selectionShortcut"
        let modifier = DoubleTapModifier(rawValue: UserDefaults.standard.string(forKey: oldKey) ?? "") ?? .shift
        return .doubleTap(modifier)
    }

    private var configuredChords: [KeyChord] {
        [previousWordShortcut, selectionShortcut].compactMap {
            if case .chord(let chord) = $0 { return chord }
            return nil
        }
    }

    func shortcut(for action: ManualAction) -> ManualShortcut {
        action == .previousWord ? previousWordShortcut : selectionShortcut
    }

    func beginShortcutRecording(_ action: ManualAction) {
        cancelShortcutRecording()
        recordingAction = action
        recordingDoubleTap = DoubleTapDetector()
        shortcutMessage = nil
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, let action = self.recordingAction else { return event }
            if event.type == .flagsChanged {
                if let modifier = self.recordingDoubleTap.flagsChanged(event.modifierFlags, at: event.timestamp) {
                    self.setShortcut(.doubleTap(modifier), for: action)
                }
                return event
            }
            if event.keyCode == 53 {
                self.cancelShortcutRecording()
            } else if let chord = KeyChord.capture(event) {
                self.setShortcut(.chord(chord), for: action)
            } else {
                self.recordingDoubleTap.keyPressed()
                self.shortcutMessage = .recordHint
            }
            return nil
        }
    }

    func cancelShortcutRecording() {
        if let recordingMonitor { NSEvent.removeMonitor(recordingMonitor) }
        recordingMonitor = nil
        recordingAction = nil
    }

    func resetShortcut(_ action: ManualAction) {
        setShortcut(.doubleTap(.shift), for: action)
    }

    private func setShortcut(_ shortcut: ManualShortcut, for action: ManualAction) {
        let other = self.shortcut(for: action == .previousWord ? .selection : .previousWord)
        let next = [shortcut, other].compactMap { value -> KeyChord? in
            if case .chord(let chord) = value { return chord }
            return nil
        }
        guard shortcutTap?.update(chords: next) == true else {
            shortcutMessage = .activationFailed
            return
        }
        if action == .previousWord { previousWordShortcut = shortcut }
        else { selectionShortcut = shortcut }
        UserDefaults.standard.set(try? JSONEncoder().encode(shortcut), forKey: "manualShortcut.\(action.rawValue)")
        shortcutMessage = nil
        cancelShortcutRecording()
    }

    func refreshLaunchAtLogin() {
        let state = SMAppService.mainApp.status
        launchAtLogin = state == .enabled || state == .requiresApproval
        launchAtLoginMessage = state == .requiresApproval ? .approvalRequired : nil
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLaunchAtLogin()
        } catch {
            refreshLaunchAtLogin()
            launchAtLoginMessage = .error(error.localizedDescription)
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

    func previewSwitchSound() {
        playSwitchSoundIfEnabled()
    }

    private func playSwitchSoundIfEnabled() {
        guard playSound else { return }
        switchSoundPlayer.play(switchSound, volume: switchSoundVolume)
    }

    @discardableResult
    func addExcludedApplications(_ urls: [URL]) -> Bool {
        guard ApplicationExclusions.add(urls) else { return false }
        excludedApplications = ApplicationExclusions.applications
        return true
    }

    func removeExcludedApplication(_ bundleID: String) {
        ApplicationExclusions.remove(bundleID: bundleID)
        excludedApplications = ApplicationExclusions.applications
    }

    private func isAutomaticRepairExcluded(_ processID: pid_t) -> Bool {
        ApplicationExclusions.contains(bundleID: NSRunningApplication(processIdentifier: processID)?.bundleIdentifier,
                                       in: excludedApplications)
    }


    func refreshPermissions() {
        hasAccessibilityAccess = AXIsProcessTrusted()
        hasInputMonitoringAccess = CGPreflightListenEventAccess()
        if hasRequiredAccess && !configuredChords.isEmpty,
           shortcutMessage == .tapUnavailable {
            shortcutMessage = shortcutTap?.update(chords: configuredChords) == true
                ? nil
                : .tapUnavailable
        }
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
        guard automaticRepair, !event.isARepeat else { return }
        let expectedRevision = revision
        let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard expectedRevision == revision,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == processID else { return }
            guard !repairPhraseAutomatically(in: processID),
                  !repairContextualLetterAutomatically(in: processID) else { return }
            repairRecentCompletedWordAutomatically(in: processID)
        }
        guard [49, 36, 76].contains(Int(event.keyCode)) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(60))
            guard expectedRevision == revision,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == processID else { return }
            repairAutomatically(in: processID)
        }
    }

    private func handleFlags(_ event: NSEvent) {
        guard let modifier = doubleTap.flagsChanged(event.modifierFlags, at: event.timestamp) else { return }
        repairManually(triggeredBy: .doubleTap(modifier))
    }

    private func repairManually(triggeredBy shortcut: ManualShortcut) {
        guard let snapshot = FocusedText.read() else {
            status = hasRequiredAccess ? .unreadableField : .accessRequired
            return
        }
        let selected = snapshot.selection.length > 0
        guard (selected && shortcut == selectionShortcut) || (!selected && shortcut == previousWordShortcut) else { return }
        let input = selected ? snapshot.selectedText : WordBoundary.precedingWord(in: snapshot.prefix, allowDelimiter: false)
        guard let input, let conversion = LayoutConversion.convert(input), snapshot.isStillCurrent() else {
            status = .noText
            return
        }
        KeyboardReplacement.replace(backspaces: selected ? 0 : input.utf16.count, with: conversion.output)
        keyboard.select(conversion.target)
        currentLayout = keyboard.currentLayout
        status = .repaired(conversion.source, conversion.target)
        playSwitchSoundIfEnabled()
    }

    private func repairAutomatically(in processID: pid_t?) {
        guard let processID, !isAutomaticRepairExcluded(processID),
              let snapshot = FocusedText.read(), snapshot.processID == processID,
              snapshot.selection.length == 0,
              let delimiter = snapshot.prefix.last, delimiter == " " || delimiter == "\n",
              let word = WordBoundary.precedingWord(in: snapshot.prefix, allowDelimiter: true),
              let conversion = AutomaticDecision.candidate(for: word),
              snapshot.isStillCurrent() else { return }
        KeyboardReplacement.replace(backspaces: word.utf16.count + 1,
                                    with: conversion.output + String(delimiter))
        keyboard.select(conversion.target)
        currentLayout = keyboard.currentLayout
        status = .repaired(conversion.source, conversion.target)
        playSwitchSoundIfEnabled()
    }

    private func repairPhraseAutomatically(in processID: pid_t?) -> Bool {
        guard CGEventSource.flagsState(.combinedSessionState).intersection(KeyChord.modifierMask).isEmpty,
              let processID, !isAutomaticRepairExcluded(processID),
              let snapshot = FocusedText.read(), snapshot.processID == processID,
              snapshot.selection.length == 0,
              let line = snapshot.prefix.split(separator: "\n", omittingEmptySubsequences: false).last,
              let conversion = PhraseDecision.candidate(for: String(line)),
              snapshot.isStillCurrent() else { return false }
        KeyboardReplacement.replace(backspaces: line.utf16.count, with: conversion.output)
        keyboard.select(conversion.target)
        currentLayout = keyboard.currentLayout
        status = .repaired(conversion.source, conversion.target)
        playSwitchSoundIfEnabled()
        return true
    }

    private func repairContextualLetterAutomatically(in processID: pid_t?) -> Bool {
        guard let processID, !isAutomaticRepairExcluded(processID),
              let snapshot = FocusedText.read(), snapshot.processID == processID,
              let candidate = ContextualLetterDecision.candidate(in: snapshot.prefix),
              snapshot.replaceDirectly(range: candidate.range, with: candidate.replacement) else { return false }
        status = .repaired(.english, .russian)
        playSwitchSoundIfEnabled()
        return true
    }

    private func repairRecentCompletedWordAutomatically(in processID: pid_t?) {
        guard let processID, !isAutomaticRepairExcluded(processID),
              let snapshot = FocusedText.read(), snapshot.processID == processID,
              snapshot.selection.length == 0 else { return }
        for candidate in WordBoundary.recentCompletedWords(in: snapshot.prefix) {
            guard let conversion = AutomaticDecision.candidate(for: candidate.word) else { continue }
            let location = snapshot.selection.location
                - candidate.trailing.utf16.count - candidate.word.utf16.count
            guard location >= 0,
                  snapshot.replaceDirectly(
                    range: NSRange(location: location, length: candidate.word.utf16.count),
                    with: conversion.output
                  ) else { return }
            if candidate.trailing.dropFirst().allSatisfy({ !$0.isLetter }),
               keyboard.currentLayout == conversion.source {
                keyboard.select(conversion.target)
            }
            currentLayout = keyboard.currentLayout
            status = .repaired(conversion.source, conversion.target)
            playSwitchSoundIfEnabled()
            return
        }
    }
}
