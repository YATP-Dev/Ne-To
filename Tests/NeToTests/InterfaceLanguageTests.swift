import Testing
@testable import NeTo

@Test func interfaceLanguageLocalizesLabelsAndStatusWithStableLayoutCodes() {
    #expect(InterfaceLanguage.russian.text("Settings", "Настройки") == "Настройки")
    #expect(InterfaceLanguage.english.text("Settings", "Настройки") == "Settings")
    #expect(DoubleTapModifier.shift.title(in: .russian) == "Двойной Shift")
    #expect(DoubleTapModifier.shift.title(in: .english) == "Double Shift")
    #expect(AppStatus.repaired(.english, .russian).text(in: .russian) == "Исправлено EN → RU.")
    #expect(AppStatus.repaired(.english, .russian).text(in: .english) == "Repaired EN → RU.")
}
