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
- SSH настроен

## Workflow

- Коммиты: `git add` + `git commit` локально
- Push/Pull: `git push` / `git pull` через SSH
- Единственный контрибьютор — конфликтов нет, можно пушить напрямую в main

## Требования к функциональности

### Основное приложение — 3 таба: Translate, History, Settings

**Translate:**
- Поле для ввода текста + кнопка старта перевода
- Ниже появляется текст перевода в отформатированном виде + кнопка копирования
- Указывается оригинальный язык текста
- Форматирование зависит от настройки "Detail Level":
  1. **Concise** — нормальная форма + род/тип, значения через запятую, контекст использования
  2. **Standard** — всё из Concise + ненумерованный список примеров (оригинал — перевод)
  3. **Detailed** — всё из Concise + нумерованный список значений, каждое с ненумерованными примерами

**History:**
- Список последних 50 переведённых слов/фраз. Более старые удаляются из базы
- В списке видно: оригинальное слово, точный перевод (без форматирования), язык перевода
- Вся остальная информация открывается по тапу

**Settings:**
- Google AI API Key
- Target Language
- Model
- Detail Level
- About

## Двухфазный перевод

Перевод выполняется в два этапа:

### Фаза 1: Streaming (Markdown)
- Модель: `streamGenerateContent?alt=sse`
- Промпт генерирует основной текст перевода в Markdown (нормальная форма, грамматика, значения)
- Примеры НЕ включаются в streaming — они приходят отдельно из JSON
- Результат отображается через `MarkdownText` (парсит блочный и inline Markdown)

### Фаза 2: JSON meta extraction
- Модель: `generateContent` с `response_mime_type: "application/json"` + `response_schema`
- Извлекает структурированные метаданные для UI и истории

**JSON Schema ответа:**
```json
{
  "sourceLanguage": "Польский (pl)",
  "shortTranslation": "ещё, всё ещё, пока",
  "examples": [
    {
      "original": "Jeszcze nie skończyłem.",
      "translation": "Я ещё не закончил."
    }
  ]
}
```

**Поля:**
- `sourceLanguage` (string, required) — язык оригинала на target language + ISO 639-1 код в скобках
- `shortTranslation` (string, required) — краткий перевод через запятую, без форматирования
- `examples` (array, required) — примеры использования:
  - Concise: пустой массив `[]`
  - Standard: 3-5 примеров
  - Detailed: 5-8 примеров
  - Каждый элемент: `{ "original": string, "translation": string }`

## Shared UI

`TranslationContentView` (TranscriptorKit) — переиспользуемая view для отображения результата перевода:
- Source language badge
- Markdown-текст перевода
- Список примеров (ExamplesView)
- Кнопка копирования с feedback "Copied!"

Используется в: TranslationView, ActionView, HistoryDetailView.

## Верификация

1. Собрать и запустить на симуляторе — основное приложение должно открыться
2. Ввести API key в Settings, проверить что сохраняется (перезапуск приложения)
3. Ввести текст в TranslationView → нажать Translate → streaming перевод
4. Проверить историю: перевод появляется в History
5. На реальном устройстве: выделить текст в Safari/Notes → Share → Transcriptor → перевод в модальном окне
6. Clipboard: скопировать текст → переключиться в Transcriptor → предложение перевести
