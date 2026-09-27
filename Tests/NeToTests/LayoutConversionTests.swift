import Testing
@testable import NeTo

@Test func convertsPhysicalKeysInBothDirections() {
    #expect(LayoutConversion.convert("ghbdtn")?.output == "привет")
    #expect(LayoutConversion.convert("руддщ")?.output == "hello")
    #expect(LayoutConversion.convert("hello")?.output == "руддщ")
}

@Test func rejectsMixedScriptAndTechnicalBoundaries() {
    #expect(LayoutConversion.convert("helло") == nil)
    #expect(WordBoundary.precedingWord(in: "mail@example ", allowDelimiter: true) == nil)
    #expect(WordBoundary.precedingWord(in: "ghbdtn ", allowDelimiter: true) == "ghbdtn")
}

@MainActor
@Test func automaticRepairNeedsDictionaryAgreement() {
    #expect(AutomaticDecision.candidate(for: "ghbdtn")?.output == "привет")
    #expect(AutomaticDecision.candidate(for: "руддщ")?.output == "hello")
    #expect(AutomaticDecision.candidate(for: "hello") == nil)
    #expect(AutomaticDecision.candidate(for: "im") == nil)
}
