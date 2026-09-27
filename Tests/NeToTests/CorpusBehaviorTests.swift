import Testing
@testable import NeTo

private let sampleParagraphs: [(language: String, text: String)] = [
    ("EN", "On a quiet morning the city wakes and people walk to work. A small cafe opens near the park. After the rain the air feels fresh and the streets shine in the sunlight."),
    ("EN", "In the evening friends meet at home and cook dinner. They talk about books and plans for the weekend. Later they take a walk and return before dark."),
    ("EN", "A young teacher writes a short story for the class. Students ask questions, share ideas, and read the story aloud. Everyone leaves with a new book to enjoy."),
    ("RU", "Утром город просыпается и люди идут на работу. В парке дети играют, а рядом открывается небольшое кафе. После дождя воздух становится свежим, и на дорожках блестят капли воды."),
    ("RU", "Вечером друзья встречаются дома и готовят ужин. Они обсуждают книги, фильмы и планы на выходные. Потом все выходят на прогулку и возвращаются до темноты."),
    ("RU", "Молодой учитель пишет короткий рассказ для класса. Ученики задают вопросы, делятся идеями и читают рассказ вслух. Каждый уходит домой с новой книгой.")
]

@MainActor
@Test func naturalParagraphsRemainUntouched() {
    var checked = 0
    var unexpected: [String] = []
    for paragraph in sampleParagraphs {
        var prefix = ""
        for character in paragraph.text {
            prefix.append(character)
            guard character == " " || character == "\n",
                  let word = WordBoundary.precedingWord(in: prefix, allowDelimiter: true) else { continue }
            checked += 1
            if let conversion = AutomaticDecision.candidate(for: word) {
                unexpected.append("\(paragraph.language): \(word) → \(conversion.output)")
            }
        }
    }
    #expect(checked >= 150)
    #expect(unexpected.isEmpty, "Unexpected changes: \(unexpected)")
}

@MainActor
@Test func wrongLayoutWordsFromParagraphsRecover() {
    var recovered = 0
    var missed: [String] = []
    for paragraph in sampleParagraphs {
        let words = Set(paragraph.text.split(whereSeparator: { !$0.isLetter }).map(String.init)
            .filter { $0 == $0.lowercased() && $0.count >= 2 })
        for word in words {
            guard let wrongLayout = LayoutConversion.convert(word)?.output else { continue }
            let boundary = WordBoundary.precedingWord(in: wrongLayout + " ", allowDelimiter: true)
            let decision = AutomaticDecision.candidate(for: wrongLayout)?.output
            if word == "in" && paragraph.language == "EN" {
                // “шт” is also a valid Russian abbreviation, so the conservative
                // automatic mode leaves this ambiguous pair to double Shift.
                #expect(decision == nil)
            } else if boundary == wrongLayout && decision == word {
                recovered += 1
            } else {
                missed.append("\(paragraph.language): \(wrongLayout) → \(word), got \(decision ?? "none")")
            }
        }
    }
    #expect(recovered >= 110)
    #expect(missed.isEmpty, "Missed corrections: \(missed)")
}
