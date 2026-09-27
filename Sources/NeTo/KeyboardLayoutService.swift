import Carbon
import Foundation

final class KeyboardLayoutService {
    var currentLayout: KeyboardLanguage? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return layout(for: source)
    }

    func select(_ target: KeyboardLanguage) {
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource],
              let source = sources.first(where: { layout(for: $0) == target }) else { return }
        TISSelectInputSource(source)
    }

    private func layout(for source: TISInputSource) -> KeyboardLanguage? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return nil }
        let languages = Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue() as? [String] ?? []
        if languages.contains(where: { $0.lowercased().hasPrefix("ru") }) { return .russian }
        if languages.contains(where: { $0.lowercased().hasPrefix("en") }) { return .english }
        return nil
    }
}
