import AppKit
import ApplicationServices
import Carbon
import SwiftUI

@main
struct NeToApp: App {
    @StateObject private var model = NeToModel.shared

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ne-To").font(.headline)
                Text(model.status).font(.caption).fixedSize(horizontal: false, vertical: true)
                Toggle("Automatic layout repair", isOn: $model.automaticRepair)
                Text("Press Shift twice to repair selected text or the previous word.")
                    .font(.caption)
                Button("Grant Accessibility and Input Monitoring") { model.requestPermissions() }
                Divider()
                Button("Quit Ne-To") { NSApplication.shared.terminate(nil) }
            }
            .padding(14)
            .frame(width: 300)
            .onAppear { model.start() }
        } label: {
            Text(model.currentLayout?.rawValue ?? "EN/RU")
        }
        .menuBarExtraStyle(.window)
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

    private let keyboard = KeyboardLayoutService()
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var layoutTimer: Timer?
    private var lastShiftRelease: TimeInterval = 0
    private var shiftWasAlone = false
    private var revision = 0
    private var started = false

    init() {
        automaticRepair = UserDefaults.standard.object(forKey: "automaticRepair") as? Bool ?? true
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
        if !AXIsProcessTrusted() || !CGPreflightListenEventAccess() {
            status = "Accessibility and Input Monitoring access are required."
        }
    }

    func requestPermissions() {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        CGRequestListenEventAccess()
        status = "Grant access in System Settings, then restart Ne-To."
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
                repairManually()
            } else {
                lastShiftRelease = now
            }
        } else {
            shiftWasAlone = false
        }
    }

    func repairManually() {
        guard let snapshot = FocusedText.read() else {
            status = "Select text in a readable field and grant the required access."
            return
        }
        let selected = snapshot.selection.length > 0
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
