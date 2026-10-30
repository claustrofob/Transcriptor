# Transcriptor

## О проекте

iOS-приложение для перевода текста через Google Gemini API, Anthropic Claude API или on-device модель Apple Intelligence (Foundation Models). Пользователь настраивает API-ключ и параметры перевода один раз, затем может переводить текст из любого приложения через Share-меню (Action Extension) или через буфер обмена.

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

### Основное приложение — экран Translate с историей под результатом; Settings (справа вверху) открывается через sheet

**Translate:**
- Вверху экрана — блок ввода (`TranslationInputBox`, карточка в стиле блока Translation): поле, кнопка очистки и кнопка действия на всю ширину внизу блока. Он стоит на месте блока Original; при отправке текст остаётся в поле. Кнопка по состоянию: **Translate** (ввод) → **Stop** (идёт загрузка: поле заблокировано, блока перевода нет; Stop отменяет запрос, возвращает к вводу и фокусирует поле) → **Edit** (результат показан, поле заблокировано; Edit скрывает перевод, фокусирует поле и открывает клавиатуру). Отменённый запрос не попадает в историю
- Под ним — строка языков (Source → Target); Target Language выбирается там (видна и до первого перевода, source = «Auto-detect»). Значения сохраняются в `SettingsManager`. Языки хранятся ISO 639-кодами (`targetLanguage = "ru"`, в истории тоже коды); в промпт и схему уходит английское название (`targetLanguageName`, «Russian»), в UI — название на первом предпочитаемом языке системы (`TranslationSettings.displayName(forCode:)`, «Русский»). Исходные языки (`sourceLanguages`) — все языки из `Locale.availableIdentifiers` с английским названием; языки перевода (`supportedLanguages`) — курированный список из 20 кодов. Миграции старых настроек/истории с названиями нет — приложение переустанавливается
- Тот же лейаут в ActionView: поле предзаполнено расшареным текстом, перевод автоматически не запускается — пользователь нажимает Translate (текст можно сначала отредактировать)
- Ниже появляется текст перевода в отформатированном виде + кнопка копирования
- Указывается оригинальный язык текста
- Формат результата для слов и выражений один (настройки Detail Level нет): нормальная форма + род/тип, значения через запятую, контекст использования, нумерованный список значений + 5–8 примеров (оригинал — перевод). Свободный текст — просто перевод

**History** (отдельного экрана нет — список на экране Translate и в ActionView, `HistoryList` в TranscriptorKit):
- Карточки последних 50 переводов под результатом (или сразу под строкой языков, если результата нет). Более старые удаляются из базы
- В карточке: оригинальное слово, точный перевод (без форматирования), языки. Тап — `HistoryDetailView` (вся информация; кнопка Delete в nav bar — удаляет после закрытия экрана; кнопка Repeat справа от оригинального текста в `OriginalTextBox` — возвращает на главный экран и делает то же, что свайп Repeat). Экран Translate и ActionView — `List` (`.plain`, строки-карточки через `cardRow()`), поэтому на карточках системные `swipeActions`: влево — Delete, вправо — Repeat (полный свайп выполняет действие; оба пункта есть и в контекстном меню). Repeat подставляет текст записи в поле и фокусирует его (`TranslationSession.beginEditing()` останавливает запрос / скрывает результат), перевод запускает пользователь — через `TranslationResultView(session:onRepeat:)`
- Результат сразу пишется в историю, но пока он показан, его карточка скрыта (`TranslationSession.visibleResultID`). Когда результат уходит (Edit, Stop, новый запрос, смена языка), блок результата сворачивается вверх (`.reveal`), а его карточка появляется в истории. `matchedGeometryEffect` не используется: между строками `List` он не работает и навязывал блоку чужую рамку (зазор над результатом, обрезанный текст). `List` анимирует вставку/удаление строк только в анимированной транзакции, поэтому `TranslationSession` меняет фазу внутри `withAnimation` (неявные `.animation(value:)` в `List` не работают)

**Settings:**
- Provider: Google, Anthropic или On-device (активен один). On-device — модель Apple Intelligence через Foundation Models, без ключа; вместо ключа и модели показывается статус доступности
- Для активного провайдера: API Key и Model. У каждого провайдера свои ключ (Keychain) и модель, при переключении они не сбрасываются
- About

## Перевод (единый JSON-запрос)

Один запрос к Gemini API через `generateContent` с `response_mime_type: "application/json"` + `response_schema`.
Возвращает все данные сразу: класс текста, перевод, метаданные, примеры. Локального классификатора нет: облачная модель по промпту сначала классифицирует ввод (`word` / `expression` / `freeText`), затем отдаёт словарный результат для слов и выражений или просто перевод для свободного текста (словарные поля пустые; `TranslationHelper` превращает их в nil). Класс сохраняется в историю.

**Метод:** `GeminiService.translateFull(...)` / `ClaudeService.translateFull(...) -> TranslationMeta`. `OnDeviceTranslationService.translate(...)` — on-device (Apple Intelligence): только точный перевод (`PromptBuilder.plainTranslationPrompt`, без классификации, анализа и примеров), guided generation (`@Generable`) вместо JSON-схемы. Он же — fallback в `TranslationHelper`: если у выбранного облачного провайдера нет API-ключа или запрос упал из-за сети (URLError: нет соединения, таймаут и т.п.; не ошибки API и не отмена) и on-device модель доступна — переводит она; в результате показывается пометка, в историю пишется `apple-on-device`, повторная отправка снова пробует облако. Выбор провайдера — в `TranslationHelper` по `settings.provider`.

Схема ответа общая — `TranslationSchema` (в диалекте Gemini); для Claude она конвертируется через `JSONSchema.standardized()` (lowercase-типы + `additionalProperties: false`). Порядок генерации полей задан явно (`textType` первым): для Gemini — `propertyOrdering`, для Claude — порядок ключей в `properties`. `JSONEncoder` порядок ключей не сохраняет, поэтому схема для Claude сериализуется через `JSONSchema.orderedJSONString()` и подставляется в тело запроса в `ClaudeRequest.encodedBody()`. Ответ с пустым `translatedText` считается ошибкой (`emptyResponse`, Retry) и в историю не пишется.

**JSON Schema ответа:**
```json
{
  "textType": "word",
  "normalForm": "podekscytowany",
  "synonyms": "podniecony, rozentuzjazmowany, ożywiony",
  "translatedText": "прилагательное (м.р.)\nвзволнованный, возбуждённый...",
  "sourceLanguage": "pl",
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
- `textType` (string enum, required) — класс ввода, который модель определяет до перевода: `word` (слово, в т.ч. с артиклем/частицей/отрицанием), `expression` (идиома, устойчивое выражение), `freeText` (предложение или текст). Для `freeText` остальные словарные поля — пустые строки / пустой массив
- `normalForm` (string, required) — словарная (начальная) форма слова на языке оригинала. Существительное → им.п. ед.ч., прилагательное → им.п. ед.ч. м.р., глагол → инфинитив
- `synonyms` (string, required) — синонимы на языке оригинала через запятую. Пустая строка если нет синонимов
- `translatedText` (string, required) — полный текст перевода, plain text (нумерованные/ненумерованные списки через \n, без Markdown)
- `sourceLanguage` (string, required) — ISO 639-1 код языка оригинала, две строчные буквы (`pl`); `TranslationHelper` нормализует его (trim + lowercase) перед сохранением, `TranslationSettings.sourceLanguage(forCode:)` находит язык по коду
- `shortTranslation` (string, required) — краткий перевод через запятую, plain text (без Markdown)
- `examples` (array, required) — примеры использования:
  - 5-8 примеров (для свободного текста — пустой массив)
  - Каждый элемент: `{ "original": string, "translation": string }`

## Shared UI

`TranslationSession` (TranscriptorKit, `@Observable`) — состояние и логика перевода на экране. `phase`: `.editing` → `.translating` → `.result`; `stop()` / `edit()` возвращают в `.editing`. В `.editing` меню языков только меняют настройки (source = «Auto-detect»), запрос шлёт Translate. новый запрос отменяет текущий, отменённый не сохраняется в историю; смена source/target языка перезапускает перевод. Кнопка Translate всегда отправляет новый запрос и сбрасывает source язык в Auto-detect. В меню языков повторный выбор текущего языка (те же текст, source, target, провайдер, модель) запрос не отправляет, если результат уже показан или запрос в пути; после ошибки или fallback — отправляет. Используется в `TranslationScreen`.

`TranslationScreen(initialText:)` (TranscriptorKit) — общий экран перевода: `List` с `TranslationInputBox` и `TranslationResultView`, отправка, Repeat (прокрутка к полю и фокус). TranslationView и ActionView только оборачивают его в `NavigationStack` со своим тулбаром (Settings / Done); ActionView передаёт расшаренный текст в `initialText`.

`TranslationInputBox(text:isFocused:phase:onTranslate:onStop:onEdit:)` (TranscriptorKit) — блок ввода: поле, очистка, кнопка Translate / Stop / Edit на всю ширину. Используется в `TranslationScreen` над `TranslationResultView`.

`TranslationResultView(session:onRepeat:)` (TranscriptorKit) — строка языков (Source ⇅ → Target ⇅; «Auto-detect» до первого запроса, «Detecting» пока язык не определён) → Translation (только в `.result`) → `HistoryList`. Используется в `TranslationScreen`.

`dismissesKeyboardOnTap()` (TranscriptorKit) — закрытие клавиатуры тапом вне текстового поля (распознаватель на окне, активен только при открытой клавиатуре).

Строительные блоки (TranscriptorKit, `TranslationResultView.swift`): `OriginalTextBox` (только в `HistoryDetailView`, `HistoryList.swift`), `TranslationBox` (ошибка с необязательной кнопкой Retry / загрузка / контент), `LanguagePair` (две равные половины, стрелка по центру), `LanguageChip`. HistoryDetailView собирает из них тот же лейаут, только с текстом вместо кнопок языков.

`TranslationContentView` (TranscriptorKit) — переиспользуемая view для отображения контента перевода:
- Нормальная форма + синонимы
- Текст перевода (plain Text)
- Список примеров (ExamplesView), отделённый Divider
- Кнопка копирования (иконка) в правом верхнем углу: копирует весь результат — нормальную форму, синонимы, перевод и примеры («оригинал — перевод»). Так она есть везде: в основном приложении, ActionView и истории (в nav bar кнопки копирования нет)

`CopyTranslationButton(text)` (TranscriptorKit) — кнопка-иконка копирования в правом верхнем углу `TranslationContentView`; на 2 секунды превращается в зелёную галочку «Copied!».

Сеть: `GeminiService` / `ClaudeService` (enum со static-методами) ходят через общий `APIClient` (ключ из Keychain, POST JSON, разбор ошибки `{"error":{"message"}}` в `TranslationError.apiError`). Ключ Gemini — в заголовке `x-goog-api-key`, не в URL.

Обе view используются в: TranslationView, ActionView, HistoryDetailView.

## Верификация

1. Собрать и запустить на симуляторе — основное приложение должно открыться
2. Ввести API key в Settings, проверить что сохраняется (перезапуск приложения)
3. Ввести текст в TranslationView → нажать Translate → перевод появляется целиком
4. Проверить историю: после Edit результат сворачивается, а его карточка появляется в истории под строкой языков
5. На реальном устройстве: выделить текст в Safari/Notes → Share → Transcriptor → текст в поле модального окна → Translate → перевод
6. Clipboard: приложение само буфер не читает (никаких алертов); вставка — через системную подсказку клавиатуры «Paste from …» или Paste
