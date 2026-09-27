import Foundation

enum CustomDictionary {
    private static let key = "customWords"

    static var words: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func contains(_ word: String) -> Bool {
        words.contains { $0.localizedCaseInsensitiveCompare(word) == .orderedSame }
    }

    @discardableResult
    static func add(_ input: String) -> Bool {
        let word = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...40).contains(word.count), word.allSatisfy(\.isLetter), !contains(word) else { return false }
        UserDefaults.standard.set((words + [word]).sorted { $0.localizedStandardCompare($1) == .orderedAscending }, forKey: key)
        return true
    }

    static func remove(_ word: String) {
        UserDefaults.standard.set(words.filter { $0 != word }, forKey: key)
    }
}
