# Ne-To

Ne-To is a small macOS menu bar app that repairs words typed in the wrong English or Russian keyboard layout. It runs locally and has no language model, network calls, API keys, correction journal, or conversation storage.

## Features

- Press **Shift twice** to convert selected text or the word immediately before the caret. The app then selects the matching EN or RU input source.
- Optional automatic repair after **Space** or **Return**, including two-letter words such as `рш` → `hi`, `yt` → `не`, and `ye` → `ну`. It changes a lowercase word when the macOS spelling dictionaries reject the source and accept the converted word. When both words are accepted, a small offline frequency table permits correction only if the converted word is in the top 200, the source is in the top 3,000, and the source rank is at least 20 times the target rank. Consonant-only abbreviations and other ambiguous words are skipped. Technical text, mixed scripts, unavailable text fields, and secure input are also skipped.
- Automatic repair is enabled by default and can be switched off in **Settings…** in the menu bar. Settings also shows the current Accessibility and Input Monitoring access states.

The physical key map covers the standard English and Russian layouts, including punctuation keys that produce Russian letters in the wrong layout (`e;by` → `ужин`). Manual repair requires a readable Accessibility text field. Some applications do not expose their text or reject synthesized keyboard events; Ne-To skips fields it cannot verify. Automatic repair is deliberately conservative and does not use approximate spell checking. The frequency ranks are bundled locally; see [data sources and licenses](THIRD_PARTY_DATA.md).

## Build

Requires macOS 14 or later, Xcode's Swift toolchain, and enabled English and Russian input sources in macOS.

```sh
swift test
zsh Scripts/package-app.sh
```

The package script creates `dist/Ne-To.app` using the sole available Apple Development signing identity. If there is more than one identity, set `NE_TO_SIGNING_IDENTITY` explicitly. Install the app in a stable location before granting **Accessibility** and **Input Monitoring** permissions in System Settings. Keeping the same signing identity across builds helps macOS retain those permissions. The menu bar app never uploads typed text.

## License

The source is available under the [MIT License](LICENSE).
