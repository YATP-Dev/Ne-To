import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: NeToModel
    @State private var newWord = ""
    @State private var dictionaryError = false
    @State private var applicationError = false

    private var language: InterfaceLanguage { model.interfaceLanguage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsGroup(language.text("General", "Основные")) {
                    HStack {
                        Text(language.text("Interface language", "Язык интерфейса"))
                        Spacer()
                        Picker("", selection: $model.interfaceLanguage) {
                            Text("RU").tag(InterfaceLanguage.russian)
                            Text("EN").tag(InterfaceLanguage.english)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 130)
                        .accessibilityLabel(language.text("Interface language", "Язык интерфейса"))
                    }
                    Toggle(language.text("Launch at Login", "Запускать при входе"), isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    if let message = model.launchAtLoginMessage {
                        Text(message.text(in: language)).font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Toggle(language.text("Automatic layout repair", "Автоматически исправлять раскладку"),
                           isOn: $model.automaticRepair)
                }

                Divider()

                settingsGroup(language.text("Switching sound", "Звук переключения")) {
                    Toggle(language.text("Play sound after repair", "Воспроизводить звук после исправления"),
                           isOn: $model.playSound)
                    HStack {
                        Picker(language.text("Sound", "Звук"), selection: $model.switchSound) {
                            ForEach(SwitchSound.allCases) { sound in
                                Text(sound.title(in: language)).tag(sound)
                            }
                        }
                        Button(language.text("Preview", "Прослушать")) {
                            model.previewSwitchSound()
                        }
                    }
                    .disabled(!model.playSound)
                    HStack {
                        Text(language.text("Volume", "Громкость"))
                        Slider(value: $model.switchSoundVolume, in: 0...1, step: 0.01)
                        Text("\(Int((model.switchSoundVolume * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                    .disabled(!model.playSound)
                }

                Divider()

                settingsGroup(language.text("Manual repair", "Ручное исправление")) {
                    shortcutRow(language.text("Previous word", "Предыдущее слово"), action: .previousWord)
                    shortcutRow(language.text("Selected text", "Выделенный текст"), action: .selection)
                    Text(language.text(
                        "Click a shortcut and press a key with any modifier. You can also double-tap a modifier. Esc cancels. Both actions default to Double Shift.",
                        "Нажмите на сочетание и введите клавишу с модификатором или дважды нажмите модификатор. Esc отменяет запись. По умолчанию — двойной Shift."
                    ))
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    if let message = model.shortcutMessage {
                        Text(message.text(in: language)).font(.system(size: 13)).foregroundStyle(.red)
                    }
                }

                Divider()

                settingsGroup(language.text("Custom dictionary", "Свой словарь")) {
                    Text(language.text(
                        "Custom words stay on this Mac. They are protected from automatic replacement and can be accepted as converted words.",
                        "Добавленные слова хранятся только на этом Mac. Они защищены от автоматической замены и могут использоваться как результат исправления."
                    ))
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    HStack {
                        TextField(language.text("Add a word", "Добавьте слово"), text: $newWord)
                            .onSubmit(addWord)
                        Button(language.text("Add", "Добавить"), action: addWord)
                            .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if dictionaryError {
                        Text(language.text("Enter a new word of 2–40 letters.", "Введите новое слово длиной от 2 до 40 букв."))
                            .font(.system(size: 13)).foregroundStyle(.red)
                    }
                    ScrollView {
                        if model.customWords.isEmpty {
                            Text(language.text("No custom words yet", "Слов пока нет"))
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            TagFlowLayout(spacing: 8) {
                                ForEach(model.customWords, id: \.self) { word in
                                    HStack(spacing: 6) {
                                        Text(word).lineLimit(1).truncationMode(.middle)
                                        Button {
                                            model.removeCustomWord(word)
                                        } label: {
                                            Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(language.text("Remove \(word)", "Удалить \(word)"))
                                    }
                                    .font(.system(size: 13))
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

                settingsGroup(language.text("Automatic repair exceptions", "Исключения автозамены")) {
                    Text(language.text(
                        "Ne-To will not change the keyboard layout automatically in these apps. Manual repair still works.",
                        "В этих приложениях Ne-To не исправляет раскладку автоматически. Ручное исправление продолжит работать."
                    ))
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    Button(language.text("Add Application…", "Добавить приложение…"), action: chooseApplications)
                    if applicationError {
                        Text(language.text("Choose an application with a valid bundle identifier.",
                                           "Выберите приложение с корректным идентификатором."))
                            .font(.system(size: 13)).foregroundStyle(.red)
                    }
                    if model.excludedApplications.isEmpty {
                        Text(language.text("No excluded applications", "Исключений пока нет"))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(model.excludedApplications) { application in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(application.name)
                                            Text(application.bundleID)
                                                .font(.system(size: 12)).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button {
                                            model.removeExcludedApplication(application.bundleID)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(language.text("Remove \(application.name)",
                                                                           "Удалить \(application.name)"))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    if application.id != model.excludedApplications.last?.id { Divider() }
                                }
                            }
                        }
                        .frame(height: 110)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                Divider()

                settingsGroup(language.text("Access", "Доступ")) {
                    settingRow(language.text("Accessibility", "Универсальный доступ"),
                               value: model.hasAccessibilityAccess
                                   ? language.text("Granted", "Разрешён") : language.text("Required", "Требуется"))
                    settingRow(language.text("Input Monitoring", "Мониторинг ввода"),
                               value: model.hasInputMonitoringAccess
                                   ? language.text("Granted", "Разрешён") : language.text("Required", "Требуется"))
                    if !model.hasRequiredAccess {
                        Button(language.text("Grant Required Access", "Предоставить доступ")) {
                            model.requestPermissions()
                        }
                    }
                }
            }
            .font(.system(size: 14))
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 560, height: 540)
        .onAppear {
            model.refreshPermissions()
            model.refreshLaunchAtLogin()
            updateWindowTitle()
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first {
                $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window"
            }?.makeKeyAndOrderFront(nil)
        }
        .onChange(of: model.interfaceLanguage) { _, _ in updateWindowTitle() }
        .onDisappear { model.cancelShortcutRecording() }
    }

    private func shortcutRow(_ title: String, action: ManualAction) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button(model.recordingAction == action
                   ? language.text("Press shortcut…", "Нажмите сочетание…")
                   : model.shortcut(for: action).display(in: language)) {
                if model.recordingAction == action { model.cancelShortcutRecording() }
                else { model.beginShortcutRecording(action) }
            }
            .frame(minWidth: 138)
            if model.shortcut(for: action) != .doubleTap(.shift) {
                Button(language.text("Reset", "Сбросить")) { model.resetShortcut(action) }
            }
        }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 15, weight: .semibold))
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
            dictionaryError = false
        } else {
            dictionaryError = true
        }
    }

    private func chooseApplications() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = language.text("Add", "Добавить")
        guard panel.runModal() == .OK else { return }
        applicationError = !model.addExcludedApplications(panel.urls)
    }

    private func updateWindowTitle() {
        let title = language.text("Ne-To Settings", "Настройки Ne-To")
        NSApp.windows.first { $0.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" }?.title = title
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
