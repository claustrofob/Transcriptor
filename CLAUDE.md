# Transcriptor

## О проекте

iOS-приложение для перевода текста через Google Gemini API или Anthropic Claude API. Пользователь настраивает API-ключ и параметры перевода один раз, затем может переводить текст из любого приложения через Share-меню (Action Extension) или через буфер обмена.

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
- URLSession + Gemini REST API (JSON mode) / Claude Messages API (structured outputs)
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

### Основное приложение — экран Translate; History (кнопка слева вверху) и Settings (справа вверху) открываются через sheet

**Translate:**
- Вверху экрана — блок ввода (`TranslationInputBox`, карточка в стиле блока Translation): поле, кнопка очистки, меню Detail Level, кнопка отправки. Он стоит на месте блока Original; при отправке текст остаётся в поле. Новая отправка отменяет текущий запрос; отменённый запрос не попадает в историю
- Под ним — строка языков (Source → Target); Target Language выбирается там (видна и до первого перевода, source = «Auto-detect»). Значения сохраняются в `SettingsManager`
- Тот же лейаут в ActionView: поле предзаполнено расшареным текстом, его можно отредактировать и перевести заново
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
- Provider: Google или Anthropic (активен один)
- Для активного провайдера: API Key и Model. У каждого провайдера свои ключ (Keychain) и модель, при переключении они не сбрасываются
- About

## Перевод (единый JSON-запрос)

Один запрос к Gemini API через `generateContent` с `response_mime_type: "application/json"` + `response_schema`.
Возвращает все данные сразу: перевод, метаданные, примеры.

**Метод:** `GeminiService.translateFull(...)` / `ClaudeService.translateFull(...) -> TranslationMeta`. Выбор провайдера — в `TranslationHelper` по `settings.provider`.

Схема ответа общая — `TranslationSchema` (в диалекте Gemini); для Claude она конвертируется через `JSONSchema.standardized()` (lowercase-типы + `additionalProperties: false`).

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

`TranslationSession` (TranscriptorKit, `@Observable`) — состояние и логика перевода на экране: новый запрос отменяет текущий, отменённый не сохраняется в историю; смена source/target языка перезапускает перевод. Повторный запрос с теми же параметрами (текст, source, target, Detail Level, провайдер, модель) не отправляется, если результат уже показан или запрос в пути; после ошибки повтор разрешён. Используется в TranslationView и ActionView.

`TranslationInputBox(text:isFocused:onSubmit:)` (TranscriptorKit) — блок ввода: поле, очистка, Detail Level, отправка. Используется в TranslationView и ActionView над `TranslationResultView`.

`TranslationResultView(session:)` (TranscriptorKit) — строка языков (Source ⇅ → Target ⇅; «Auto-detect» до первого запроса, «Detecting» пока язык не определён) → Translation. Используется в TranslationView и ActionView.

`dismissesKeyboardOnTap()` (TranscriptorKit) — закрытие клавиатуры тапом вне текстового поля (распознаватель на окне, активен только при открытой клавиатуре).

Строительные блоки (TranscriptorKit, `TranslationResultView.swift`): `OriginalTextBox` (только в HistoryDetailView), `TranslationBox` (ошибка / загрузка / контент), `LanguagePair` (две равные половины, стрелка по центру), `LanguageChip`. HistoryDetailView собирает из них тот же лейаут, только с текстом вместо кнопок языков.

`TranslationContentView` (TranscriptorKit) — переиспользуемая view для отображения контента перевода:
- Source language badge (опционально)
- Нормальная форма + синонимы
- Текст перевода (plain Text)
- Список примеров (ExamplesView), отделённый Divider

`CopyTranslationButton` (TranscriptorKit) — кнопка копирования с анимацией "Copied!":
- Параметры: text, label (default "Copy"), fullWidth (default false)
- fullWidth: true — bordered стиль на всю ширину, зелёный tint при копировании
- fullWidth: false — компактная кнопка для toolbar

Обе view используются в: TranslationView, ActionView, HistoryDetailView.

## Верификация

1. Собрать и запустить на симуляторе — основное приложение должно открыться
2. Ввести API key в Settings, проверить что сохраняется (перезапуск приложения)
3. Ввести текст в TranslationView → нажать Translate → перевод появляется целиком
4. Проверить историю: перевод появляется в History
5. На реальном устройстве: выделить текст в Safari/Notes → Share → Transcriptor → перевод в модальном окне
6. Clipboard: скопировать текст → переключиться в Transcriptor → предложение перевести
