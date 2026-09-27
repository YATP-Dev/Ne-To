import Testing
@testable import NeTo

@Test func convertsPhysicalKeysInBothDirections() {
    #expect(LayoutConversion.convert("ghbdtn")?.output == "привет")
    #expect(LayoutConversion.convert("руддщ")?.output == "hello")
    #expect(LayoutConversion.convert("hello")?.output == "руддщ")
}

@MainActor
@Test func rejectsMixedScriptAndTechnicalBoundaries() {
    #expect(LayoutConversion.convert("helло") == nil)
    #expect(WordBoundary.precedingWord(in: "mail@example ", allowDelimiter: true) == nil)
    #expect(WordBoundary.precedingWord(in: "mail@example.com ", allowDelimiter: true) == nil)
    #expect(WordBoundary.precedingWord(in: "https://example.com ", allowDelimiter: true) == nil)
    #expect(WordBoundary.precedingWord(in: "ghbdtn ", allowDelimiter: true) == "ghbdtn")
    #expect(WordBoundary.precedingWord(in: "e;by ", allowDelimiter: true) == "e;by")
    #expect(WordBoundary.precedingWord(in: "k.lb", allowDelimiter: false) == "k.lb")
    #expect(AutomaticDecision.candidate(for: "e;by")?.output == "ужин")
    #expect(AutomaticDecision.candidate(for: "k.lb")?.output == "люди")
    #expect(AutomaticDecision.candidate(for: "work.") == nil)
}

@MainActor
@Test func automaticRepairNeedsDictionaryAgreement() {
    #expect(AutomaticDecision.candidate(for: "ghbdtn")?.output == "привет")
    #expect(AutomaticDecision.candidate(for: "руддщ")?.output == "hello")
    #expect(AutomaticDecision.candidate(for: "рш")?.output == "hi")
    #expect(AutomaticDecision.candidate(for: "yt")?.output == "не")
    #expect(AutomaticDecision.candidate(for: "ye")?.output == "ну")
    #expect(AutomaticDecision.candidate(for: "Ye")?.output == "Ну")
    #expect(AutomaticDecision.candidate(for: "pyf.")?.output == "знаю")
    #expect(AutomaticDecision.candidate(for: "bp") == nil)
    #expect(AutomaticDecision.candidate(for: "kb") == nil)
    #expect(AutomaticDecision.candidate(for: "vs") == nil)
    #expect(AutomaticDecision.candidate(for: "ин") == nil)
    #expect(AutomaticDecision.candidate(for: "ру") == nil)
    #expect(AutomaticDecision.candidate(for: "hi") == nil)
    #expect(AutomaticDecision.candidate(for: "не") == nil)
    #expect(AutomaticDecision.candidate(for: "ну") == nil)
    #expect(AutomaticDecision.candidate(for: "hello") == nil)
    #expect(AutomaticDecision.candidate(for: "im") == nil)
}

@MainActor
@Test func repairsStrongWrongLayoutPhraseWithoutChangingNormalText() {
    #expect(PhraseDecision.candidate(for: "Ye z yt pyf.")?.output == "Ну я не знаю")
    #expect(PhraseDecision.candidate(for: "Ye z yt pyf") == nil)
    #expect(PhraseDecision.candidate(for: "A small cafe opens near the park.") == nil)
    #expect(PhraseDecision.candidate(for: "В парке дети играют.") == nil)
}
