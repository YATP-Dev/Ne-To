import Foundation

enum ContextualLetterDecision {
    static func candidate(in prefix: String) -> (range: NSRange, replacement: String)? {
        let line = String(prefix.split(separator: "\n", omittingEmptySubsequences: false).last ?? "")
        let characters = Array(line)
        guard !characters.isEmpty else { return nil }
        let lineStart = (prefix as NSString).length - (line as NSString).length

        for index in characters.indices.reversed() {
            let replacement: String
            switch characters[index] {
            case "Z": replacement = "Я"
            case "F": replacement = "А"
            case "J": replacement = "О"
            default: continue
            }
            guard index == 0 || characters[index - 1] == " ",
                  index + 1 < characters.count,
                  characters[index + 1] == " " || characters[index + 1] == "!" else { continue }

            let after = String(characters[(index + 1)...].prefix(32))
            let hasRussianContext = containsRussianWord(after)
            guard hasRussianContext || (index == 0 && after == "!") else { continue }

            let offset = String(characters[..<index]).utf16.count
            return (NSRange(location: lineStart + offset, length: 1), replacement)
        }
        return nil
    }

    private static func containsRussianWord(_ text: String) -> Bool {
        text.split(whereSeparator: { !$0.isLetter }).contains { word in
            word.count >= 2 && word.unicodeScalars.allSatisfy { (0x0400...0x052F).contains($0.value) }
        }
    }
}
