# Transcriptor

An iOS translation app powered by the Google Gemini API. Enter a word or phrase in any language and get a rich, dictionary-style translation with normal forms, synonyms, usage examples, and source language detection — all in a single API call.

## Features

- **Translate** — type or paste text, get a formatted translation with normal form, synonyms, and usage examples. Three detail levels: Concise, Standard, and Detailed.
- **Share Extension** — select text in any app (Safari, Notes, etc.), tap Share → Transcriptor, and get an instant translation in a modal overlay.
- **Clipboard Detection** — switch to the app with copied text and get an offer to translate it immediately.
- **History** — browse your last 50 translations with quick access to full details.
- **Configurable** — choose your target language, Gemini model, detail level, and API key in Settings.

## Tech Stack

- iOS 26+, universal (iPhone + iPad)
- Pure SwiftUI + Swift Concurrency (async/await, actors)
- SwiftData for translation history
- URLSession + Gemini REST API (JSON structured output)
- Zero third-party dependencies

## Architecture

Three targets sharing code through an embedded framework:

| Target | Purpose |
|---|---|
| `Transcriptor` | Main app (Translate, History, Settings tabs) |
| `TranscriptorAction` | Action Extension for system Share sheet |
| `TranscriptorKit` | Shared framework (services, models, views, utilities) |

Targets communicate via App Groups and Keychain Sharing.

## Getting Started

1. Clone the repository
2. Open `Transcriptor.xcodeproj` in Xcode
3. Build and run on a simulator or device (iOS 26+)
4. Go to **Settings** tab and enter your [Google AI API key](https://aistudio.google.com/apikey)
5. Start translating!

## Vibe Coded

This entire application — every line of Swift, every SwiftUI view, every service, every test — was fully **vibe coded** by [Claude Code](https://claude.com/claude-code) (Anthropic's CLI coding agent). No human-written code. Just vibes and prompts.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
