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
- Форматирование зависит от настройки "Detail Level":
  1. **Concise** — только точные переводы через запятую
  2. **Standard** — слово/фраза в нормальной форме с указанием числа и рода. Описание значения
  3. **Detailed** — то же, что Standard, в более развёрнутом виде
- Если включена опция "Include examples" — добавить примеры использования в разных контекстах

**History:**
- Список последних 50 переведённых слов/фраз. Более старые удаляются из базы
- В списке видно: оригинальное слово, точный перевод (без форматирования), язык перевода
- Вся остальная информация открывается по тапу

**Settings:**
- Google AI API Key
- Target Language
- Model
- Detail Level
- Include Examples
- About

## Верификация

1. Собрать и запустить на симуляторе — основное приложение должно открыться
2. Ввести API key в Settings, проверить что сохраняется (перезапуск приложения)
3. Ввести текст в TranslationView → нажать Translate → streaming перевод
4. Проверить историю: перевод появляется в History
5. На реальном устройстве: выделить текст в Safari/Notes → Share → Transcriptor → перевод в модальном окне
6. Clipboard: скопировать текст → переключиться в Transcriptor → предложение перевести
