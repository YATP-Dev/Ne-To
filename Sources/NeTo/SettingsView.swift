import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: NeToModel
    @State private var newWord = ""
    @State private var dictionaryMessage: String?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                if let message = model.launchAtLoginMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Automatic layout repair", isOn: $model.automaticRepair)
            }

            Section("Manual repair") {
                LabeledContent("Shortcut", value: "Double Shift")
                Text("Repairs selected text, or the previous word when nothing is selected.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Custom dictionary") {
                Text("These local words are protected from automatic replacement and can be accepted as converted words.")
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

            Section("Access") {
                LabeledContent("Accessibility", value: model.hasAccessibilityAccess ? "Granted" : "Required")
                LabeledContent("Input Monitoring", value: model.hasInputMonitoringAccess ? "Granted" : "Required")
                if !model.hasRequiredAccess {
                    Button("Grant Required Access") { model.requestPermissions() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 510, height: 520)
        .onAppear {
            model.refreshPermissions()
            model.refreshLaunchAtLogin()
        }
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
