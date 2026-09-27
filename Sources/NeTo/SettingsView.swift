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
                    shortcutRow("Previous word", action: .previousWord)
                    shortcutRow("Selected text", action: .selection)
                    Text("Click a shortcut and press a key with any modifier. You can also double-tap a modifier. Esc cancels. Both actions default to Double Shift.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let message = model.shortcutMessage {
                        Text(message).font(.caption).foregroundStyle(.red)
                    }
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
                    ScrollView {
                        if model.customWords.isEmpty {
                            Text("No custom words yet")
                                .font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            TagFlowLayout(spacing: 8) {
                                ForEach(model.customWords, id: \.self) { word in
                                    HStack(spacing: 6) {
                                        Text(word).lineLimit(1).truncationMode(.middle)
                                        Button {
                                            model.removeCustomWord(word)
                                        } label: {
                                            Image(systemName: "xmark").font(.caption2.weight(.semibold))
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Remove \(word)")
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.quaternary, in: Capsule())
                                }
                            }
                            .padding(8)
                        }
                    }
                    .frame(height: 116)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
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
        .onDisappear { model.cancelShortcutRecording() }
    }

    private func shortcutRow(_ title: String, action: ManualAction) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button(model.recordingAction == action ? "Press shortcut…" : model.shortcut(for: action).display) {
                if model.recordingAction == action { model.cancelShortcutRecording() }
                else { model.beginShortcutRecording(action) }
            }
            .frame(minWidth: 138)
            if model.shortcut(for: action) != .doubleTap(.shift) {
                Button("Reset") { model.resetShortcut(action) }
            }
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

private struct TagFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 440
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > bounds.width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
