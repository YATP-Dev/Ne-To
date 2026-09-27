import Foundation

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case english = "en"

    var id: String { rawValue }

    static var saved: Self {
        if let value = UserDefaults.standard.string(forKey: "interfaceLanguage"),
           let language = Self(rawValue: value) { return language }
        return Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") == true ? .russian : .english
    }

    func text(_ english: String, _ russian: String) -> String {
        self == .russian ? russian : english
    }
}

enum AppStatus {
    case ready
    case unreadableField
    case accessRequired
    case noText
    case repaired(KeyboardLanguage, KeyboardLanguage)

    func text(in language: InterfaceLanguage) -> String {
        switch self {
        case .ready:
            language.text("Ready. Press Shift twice to repair text.", "Готово. Дважды нажмите Shift, чтобы исправить текст.")
        case .unreadableField:
            language.text("Place the caret in a readable text field.", "Поместите курсор в доступное текстовое поле.")
        case .accessRequired:
            language.text("Accessibility and Input Monitoring access are required.", "Нужен доступ к Универсальному доступу и мониторингу ввода.")
        case .noText:
            language.text("No EN/RU text to repair.", "Нет текста EN/RU для исправления.")
        case .repaired(let source, let target):
            language.text("Repaired \(source.rawValue) → \(target.rawValue).",
                          "Исправлено \(source.rawValue) → \(target.rawValue).")
        }
    }
}

enum ShortcutNotice: Equatable {
    case tapUnavailable
    case recordHint
    case activationFailed

    func text(in language: InterfaceLanguage) -> String {
        switch self {
        case .tapUnavailable:
            language.text("The global shortcut could not start. Check Accessibility and Input Monitoring access.",
                          "Глобальное сочетание не запустилось. Проверьте доступ к Универсальному доступу и мониторингу ввода.")
        case .recordHint:
            language.text("Press a key with a modifier, or double-tap a modifier. Esc cancels.",
                          "Нажмите клавишу с модификатором или дважды нажмите модификатор. Esc отменяет запись.")
        case .activationFailed:
            language.text("Could not activate this shortcut. Check Accessibility and Input Monitoring access.",
                          "Не удалось включить сочетание. Проверьте доступ к Универсальному доступу и мониторингу ввода.")
        }
    }
}

enum LaunchAtLoginNotice {
    case approvalRequired
    case error(String)

    func text(in language: InterfaceLanguage) -> String {
        switch self {
        case .approvalRequired:
            language.text("Approve Ne-To in System Settings → General → Login Items.",
                          "Разрешите Ne-To в Системных настройках → Основные → Объекты входа.")
        case .error(let message):
            language.text("Could not change Launch at Login: \(message)",
                          "Не удалось изменить автозапуск: \(message)")
        }
    }
}
