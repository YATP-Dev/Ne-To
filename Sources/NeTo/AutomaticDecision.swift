import AppKit

@MainActor
enum AutomaticDecision {
    static func candidate(for word: String) -> Conversion? {
        let lower = word.lowercased()
        let titlecased = String(word.prefix(1)).uppercased() + String(word.dropFirst()).lowercased()
        guard word.count >= 2, word.count <= 40,
              word == lower || word == titlecased,
              !CustomDictionary.contains(word),
              let conversion = LayoutConversion.convert(word),
              conversion.output.allSatisfy(\.isLetter),
              let lowerConversion = LayoutConversion.convert(lower) else { return nil }
        let checker = NSSpellChecker.shared
        guard let source = language(for: conversion.source, available: checker.availableLanguages),
              let target = language(for: conversion.target, available: checker.availableLanguages),
              (!isCorrect(lower, language: source, checker: checker)
                  || word.contains(where: { !$0.isLetter })
                  || ShortWordFrequency.stronglyFavors(lowerConversion)),
              (CustomDictionary.contains(conversion.output)
                  || isCorrect(conversion.output.lowercased(), language: target, checker: checker)) else { return nil }
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
