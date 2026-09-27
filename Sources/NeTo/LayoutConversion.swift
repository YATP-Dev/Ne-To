import Foundation

enum KeyboardLanguage: String {
    case english = "EN"
    case russian = "RU"

    var opposite: Self { self == .english ? .russian : .english }
}

struct Conversion: Equatable {
    let input: String
    let output: String
    let source: KeyboardLanguage
    let target: KeyboardLanguage
}

enum LayoutConversion {
    private static let english = Array("`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./")
    private static let russian = Array("ё1234567890-=йцукенгшщзхъ\\фывапролджэячсмитьбю.")
    private static let enToRu = makeMap(english, russian)
    private static let ruToEn = makeMap(russian, english)

    static func convert(_ text: String) -> Conversion? {
        let en = text.filter { $0.isASCII && $0.isLetter }.count
        let ru = text.filter { $0.unicodeScalars.allSatisfy { (0x0400...0x052F).contains($0.value) } }.count
        guard en + ru > 0, en == 0 || ru == 0 else { return nil }
        let source: KeyboardLanguage = en > 0 ? .english : .russian
        let map = source == .english ? enToRu : ruToEn
        let output = String(text.map { map[$0] ?? $0 })
        guard output != text else { return nil }
        return Conversion(input: text, output: output, source: source, target: source.opposite)
    }

    private static func makeMap(_ source: [Character], _ target: [Character]) -> [Character: Character] {
        var result = Dictionary(uniqueKeysWithValues: zip(source, target))
        for (left, right) in zip(source, target) where left.isLetter {
            result[Character(String(left).uppercased())] = Character(String(right).uppercased())
        }
        return result
    }
}

enum WordBoundary {
    static func precedingWord(in prefix: String, allowDelimiter: Bool) -> String? {
        var characters = Array(prefix)
        if allowDelimiter {
            guard let last = characters.last, last == " " || last == "\n" else { return nil }
            characters.removeLast()
        }
        let word = String(characters.reversed().prefix { $0.isLetter }.reversed())
        guard !word.isEmpty, word.count <= 64 else { return nil }
        if characters.count > word.count {
            let before = characters[characters.count - word.count - 1]
            guard !before.isLetter, !before.isNumber, !"@._/-".contains(before) else { return nil }
        }
        return word
    }
}
