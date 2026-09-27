import AppKit

@MainActor
enum AutomaticDecision {
    static func candidate(for word: String) -> Conversion? {
        guard word.count >= 2, word.count <= 40,
              word == word.lowercased(),
              let conversion = LayoutConversion.convert(word),
              conversion.output.allSatisfy(\.isLetter) else { return nil }
        let checker = NSSpellChecker.shared
        guard let source = language(for: conversion.source, available: checker.availableLanguages),
              let target = language(for: conversion.target, available: checker.availableLanguages),
              (!isCorrect(word, language: source, checker: checker)
                  || (word == "ye" && conversion.output == "ну")),
              isCorrect(conversion.output, language: target, checker: checker) else { return nil }
        return conversion
    }

    private static func language(for layout: KeyboardLanguage, available: [String]) -> String? {
        let prefix = layout == .english ? "en" : "ru"
        return available.first { $0.lowercased().hasPrefix(prefix) }
    }

    private static func isCorrect(_ word: String, language: String, checker: NSSpellChecker) -> Bool {
        checker.checkSpelling(of: word, startingAt: 0, language: language,
                              wrap: false, inSpellDocumentWithTag: 0, wordCount: nil).location == NSNotFound
    }
}
