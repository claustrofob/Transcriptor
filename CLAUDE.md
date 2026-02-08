# Transcriptor

## О проекте

iOS-приложение для перевода текста через Google Gemini API. Пользователь настраивает API-ключ и параметры перевода один раз, затем может переводить текст из любого приложения через Share-меню (Action Extension) или через буфер обмена.

## Архитектура

3 таргета:
- **Transcriptor** — основное приложение (настройки, ручной перевод, история)
- **TranscriptorAction** — Action Extension для перевода из любого приложения через Share
- **TranscriptorKit** — shared framework (сервисы, модели, утилиты)

Связь: App Groups + Keychain Sharing + embedded framework.

## Стек

- iOS 26+, universal (iPhone + iPad)
- SwiftUI, Swift Concurrency (async/await, actors)
- SwiftData (история переводов)
- URLSession SSE streaming (Google Gemini API)
- Ноль сторонних зависимостей

## Ключевые идентификаторы

- Bundle ID: `com.claustrofob.Transcriptor`
- Extension Bundle ID: `com.claustrofob.Transcriptor.Action`
- App Group: `group.com.claustrofob.Transcriptor`

## Репозиторий

- GitHub: `claustrofob/Transcriptor` (private)
- SSH не настроен

## Workflow

- Коммиты: `git add` + `git commit` локально
- Push: `git push` через MCP GitHub (не через SSH/HTTPS)
- Единственный контрибьютор — конфликтов нет, можно пушить напрямую в main
