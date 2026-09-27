import Foundation
import Testing
@testable import NeTo

@MainActor
@Test func customWordsProtectSourceAndAcceptTarget() {
    let previous = CustomDictionary.words
    defer { UserDefaults.standard.set(previous, forKey: "customWords") }

    #expect(CustomDictionary.add("ФЫВАПР"))
    #expect(CustomDictionary.contains("фывапр"))
    #expect(AutomaticDecision.candidate(for: "asdfgh")?.output == "фывапр")
    #expect(CustomDictionary.add("ASDFGH"))
    #expect(AutomaticDecision.candidate(for: "asdfgh") == nil)
    #expect(!CustomDictionary.add("asdfgh"))
    #expect(!CustomDictionary.add("two words"))

    CustomDictionary.remove("ASDFGH")
    #expect(AutomaticDecision.candidate(for: "asdfgh")?.output == "фывапр")

    #expect(CustomDictionary.add("nebrand"))
    #expect(CustomDictionary.contains("NEBRAND"))
}
