# Transcriptor

An iOS translation app powered by Google Gemini, Anthropic Claude, or Apple's on-device model. Enter a word, an expression, or a whole text in any language: the model recognizes what it is and returns either a rich, dictionary-style entry (normal form, synonyms, meanings, usage examples) or a clean translation — in a single API call.

## Features

- **Smart translation** — the model classifies the input before translating it:
  - **Word** or **expression** — dictionary-style result: normal form, synonyms, part of speech, numbered meanings, and 5–8 usage examples.
  - **Free text** — a plain, natural translation.
- **Three providers** — Google Gemini, Anthropic Claude, or Apple Intelligence on-device (no API key, works offline; plain translation only). Each cloud provider keeps its own API key (Keychain) and model.
- **On-device fallback** — if the cloud provider has no API key or the network is down, the on-device model translates instead, and the result says so.
- **Language bar** — source → target under the input. The source language is auto-detected (and can be corrected, which re-translates); the target language is picked right there, with your most-used languages on top.
- **Translate / Stop / Edit** — the input locks while translating and during review; Stop cancels the request, Edit brings the keyboard back. Errors come with a Retry button. Cancelled or empty responses never reach history.
- **Action Extension** — select text in any app (Safari, Notes, …), tap Share → Translate, and get the same screen in a sheet, with the shared text in the input, ready to edit and translate.
- **Copy everything** — one tap copies the whole result, examples included.
- **History** — the last 50 translations right under the result, on the Translate screen and in the Share extension. When a result is dismissed, it flows into its history card. Tap a card for the full entry: source → target languages, the model used, the recognized text type, and response time.
- **Polish** — a rainbow glow around the input while translating, animated result reveal, springy button transitions, SF Symbols effects.

## Tech Stack

- iOS 26+, universal (iPhone + iPad)
- Pure SwiftUI + Swift Concurrency (async/await, actors, `@Observable`)
- SwiftData for translation history
- URLSession + Gemini REST API (JSON mode with a response schema) / Claude Messages API (structured outputs)
- Foundation Models (guided generation) for on-device translation
- Swift Testing for unit tests
- Zero third-party dependencies

## Architecture

Three targets sharing code through an embedded framework:

| Target | Purpose |
|---|---|
| `Transcriptor` | Main app: Translate screen with history, Settings sheet |
| `TranscriptorAction` | Action Extension for the system Share sheet |
| `TranscriptorKit` | Shared framework: services, models, translation session, shared views |

Targets communicate via App Groups and Keychain Sharing. The Translate screen and the Action Extension are built from the same pieces: `TranslationSession` (request state, cancellation, re-translation) and the shared `TranslationInputBox` / `TranslationResultView`.

The Xcode project is described in `project.yml` ([XcodeGen](https://github.com/yonaskolb/XcodeGen)).

## Getting Started

1. Clone the repository
2. Open `Transcriptor.xcodeproj` in Xcode
3. Build and run on a simulator or device (iOS 26+)
4. Open **Settings** (top right) and pick a provider:
   - **Google** — enter your [Gemini API key](https://aistudio.google.com/apikey)
   - **Anthropic** — enter your [Claude API key](https://platform.claude.com/settings/keys)
   - **On-device** — no key needed; requires an Apple Intelligence–capable device with Apple Intelligence turned on
5. Start translating!

Run the tests with the `TranscriptorKit` scheme.

## Vibe Coded

This entire application — every line of Swift, every SwiftUI view, every service, every test — was fully **vibe coded** by [Claude Code](https://claude.com/claude-code) (Anthropic's CLI coding agent). No human-written code. Just vibes and prompts.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
