import AppKit

@MainActor
enum PhraseDecision {
    static func candidate(for line: String) -> Conversion? {
        guard line.count <= 128,
              let last = line.last,
              last == " " || "`[];',./".contains(last),
              !line.contains(where: { $0.isNumber || "@/_\\".contains($0) }),
              let conversion = LayoutConversion.convert(line),
              conversion.output.allSatisfy({ $0.isLetter || $0 == " " }) else { return nil }
        let words = line.split(separator: " ").map(String.init)
        guard (3...12).contains(words.count) else { return nil }
        let supported = words.filter { AutomaticDecision.candidate(for: $0) != nil }.count
        guard supported >= 2, supported * 3 >= words.count * 2 else { return nil }
        return conversion
    }
}
