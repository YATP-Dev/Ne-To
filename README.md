# Ne-To

Ne-To is a small macOS menu bar app that repairs words typed in the wrong English or Russian keyboard layout. It runs locally and has no language model, network calls, API keys, correction journal, or conversation storage.

## Features

- Press **Shift twice** to convert selected text or the word immediately before the caret. The app then selects the matching EN or RU input source.
- Optional automatic repair after **Space** or **Return**. It changes a lowercase word only when the macOS spelling dictionaries reject the source and accept the converted word. Ambiguous words, technical text, mixed scripts, unavailable text fields, and secure input are skipped.
- Automatic repair is enabled by default and can be switched off in the menu bar.

The physical key map covers the standard English and Russian layouts. Manual repair requires a readable Accessibility text field. Some applications do not expose their text or reject synthesized keyboard events; Ne-To skips fields it cannot verify. Automatic repair is deliberately conservative and does not use approximate spell checking.

## Build

Requires macOS 14 or later, Xcode's Swift toolchain, and enabled English and Russian input sources in macOS.

```sh
swift test
zsh Scripts/package-app.sh
```

The package script creates `dist/Ne-To.app`. Set `NE_TO_SIGNING_IDENTITY` to a macOS code signing identity to sign it; without one the script uses ad hoc signing for local testing. Install the app in a stable location before granting **Accessibility** and **Input Monitoring** permissions in System Settings. The menu bar app never uploads typed text.

## License

The source is available under the [MIT License](LICENSE).
