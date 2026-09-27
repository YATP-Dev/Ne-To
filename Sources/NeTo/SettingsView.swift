import SwiftUI

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case shortcuts = "Keyboard Shortcuts"
    case dictionary = "Custom Dictionary"

    var id: Self { self }
    var icon: String {
        switch self {
        case .general: "gearshape"
        case .shortcuts: "keyboard"
        case .dictionary: "character.book.closed"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: NeToModel
    @State private var selection: SettingsPane? = .general
    @State private var newWord = ""
    @State private var dictionaryMessage: String?

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.rawValue, systemImage: pane.icon).tag(pane)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 175, ideal: 190)
        } detail: {
            Group {
                switch selection ?? .general {
                case .general: generalPane
                case .shortcuts: shortcutsPane
                case .dictionary: dictionaryPane
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle((selection ?? .general).rawValue)
        }
        .frame(minWidth: 660, minHeight: 420)
        .onAppear {
            model.refreshPermissions()
            model.refreshLaunchAtLogin()
        }
        .onDisappear { model.cancelRecording() }
    }

    private var generalPane: some View {
        Form {
            Toggle("Launch at Login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            if let message = model.launchAtLoginMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            Toggle("Automatic layout repair", isOn: $model.automaticRepair)
            LabeledContent("Accessibility", value: model.hasAccessibilityAccess ? "Granted" : "Required")
            LabeledContent("Input Monitoring", value: model.hasInputMonitoringAccess ? "Granted" : "Required")
            if !model.hasRequiredAccess {
                Button("Grant Required Access") { model.requestPermissions() }
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutsPane: some View {
        Form {
            shortcutRow("Previous word", action: .previousWord)
            shortcutRow("Selected text", action: .selection)
            Text("Double Shift also repairs selected text, or the previous word when nothing is selected.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Click a shortcut, then press a letter or number with at least two of Control, Option, and Command. Esc cancels.")
                .font(.caption).foregroundStyle(.secondary)
            if let message = model.hotKeyMessage {
                Text(message).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }

    private func shortcutRow(_ title: String, action: RepairAction) -> some View {
        LabeledContent(title) {
            Button(model.recordingAction == action ? "Press shortcut…" : model.hotKey(for: action).display) {
                if model.recordingAction == action { model.cancelRecording() }
                else { model.beginRecording(action) }
            }
            .frame(minWidth: 130)
        }
    }

    private var dictionaryPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Words in this local dictionary are protected from automatic replacement. A converted word in the dictionary can also be accepted as a correction.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("Add a word or brand", text: $newWord)
                    .onSubmit(addWord)
                Button("Add", action: addWord)
                    .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let dictionaryMessage {
                Text(dictionaryMessage).font(.caption).foregroundStyle(.red)
            }
            List {
                ForEach(model.customWords, id: \.self) { word in
                    HStack {
                        Text(word)
                        Spacer()
                        Button("Remove", systemImage: "minus.circle") { model.removeCustomWord(word) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(word)")
                    }
                }
            }
            .overlay {
                if model.customWords.isEmpty {
                    ContentUnavailableView("No custom words", systemImage: "character.book.closed",
                                           description: Text("Add a word above to protect it."))
                }
            }
        }
        .padding(20)
    }

    private func addWord() {
        if model.addCustomWord(newWord) {
            newWord = ""
            dictionaryMessage = nil
        } else {
            dictionaryMessage = "Enter a new word of 2–40 letters."
        }
    }
}
