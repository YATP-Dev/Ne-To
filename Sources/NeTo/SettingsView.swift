import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: NeToModel
    @State private var newWord = ""
    @State private var dictionaryMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsGroup("General") {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    if let message = model.launchAtLoginMessage {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                    Toggle("Automatic layout repair", isOn: $model.automaticRepair)
                }

                Divider()

                settingsGroup("Manual repair") {
                    settingRow("Shortcut", value: "Double Shift")
                    Text("Repairs selected text, or the previous word when nothing is selected.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Divider()

                settingsGroup("Custom dictionary") {
                    Text("Custom words stay on this Mac. They are protected from automatic replacement and can be accepted as converted words.")
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

                Divider()

                settingsGroup("Access") {
                    settingRow("Accessibility", value: model.hasAccessibilityAccess ? "Granted" : "Required")
                    settingRow("Input Monitoring", value: model.hasInputMonitoringAccess ? "Granted" : "Required")
                    if !model.hasRequiredAccess {
                        Button("Grant Required Access") { model.requestPermissions() }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 520, height: 500)
        .onAppear {
            model.refreshPermissions()
            model.refreshLaunchAtLogin()
        }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private func settingRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
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
