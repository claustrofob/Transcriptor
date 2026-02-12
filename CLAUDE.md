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
- URLSession + Gemini REST API (JSON mode)
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

## Перевод (единый JSON-запрос)

Один запрос к Gemini API через `generateContent` с `response_mime_type: "application/json"` + `response_schema`.
Возвращает все данные сразу: перевод, метаданные, примеры.

**Метод:** `GeminiService.translateFull(text:settings:) -> TranslationMeta`

**JSON Schema ответа:**
```json
{
  "normalForm": "podekscytowany",
  "synonyms": "podniecony, rozentuzjazmowany, ożywiony",
  "translatedText": "прилагательное (м.р.)\nвзволнованный, возбуждённый...",
  "sourceLanguage": "Польский (pl)",
  "shortTranslation": "взволнованный, возбуждённый",
  "examples": [
    {
      "original": "Jestem podekscytowany tą wiadomością.",
      "translation": "Я взволнован этой новостью."
    }
  ]
}
```

**Поля:**
- `normalForm` (string, required) — словарная (начальная) форма слова на языке оригинала. Существительное → им.п. ед.ч., прилагательное → им.п. ед.ч. м.р., глагол → инфинитив
- `synonyms` (string, required) — синонимы на языке оригинала через запятую. Пустая строка если нет синонимов
- `translatedText` (string, required) — полный текст перевода, plain text (нумерованные/ненумерованные списки через \n, без Markdown)
- `sourceLanguage` (string, required) — язык оригинала на target language + ISO 639-1 код в скобках
- `shortTranslation` (string, required) — краткий перевод через запятую, plain text (без Markdown)
- `examples` (array, required) — примеры использования:
  - Concise: пустой массив `[]`
  - Standard: 3-5 примеров
  - Detailed: 5-8 примеров
  - Каждый элемент: `{ "original": string, "translation": string }`

## Shared UI

`TranslationContentView` (TranscriptorKit) — переиспользуемая view для отображения контента перевода:
- Текст перевода (plain Text)
- Список примеров (ExamplesView), отделённый Divider

Используется в: TranslationView, ActionView, HistoryDetailView.
Source language badge и кнопка копирования реализуются каждым экраном отдельно (разный дизайн).

## Верификация

1. Собрать и запустить на симуляторе — основное приложение должно открыться
2. Ввести API key в Settings, проверить что сохраняется (перезапуск приложения)
3. Ввести текст в TranslationView → нажать Translate → перевод появляется целиком
4. Проверить историю: перевод появляется в History
5. На реальном устройстве: выделить текст в Safari/Notes → Share → Transcriptor → перевод в модальном окне
6. Clipboard: скопировать текст → переключиться в Transcriptor → предложение перевести
