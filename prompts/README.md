# Prompt cookbook

Бібліотека перевірених промптів команди. Кожен промпт — окремий файл за
структурою [`_template.md`](./_template.md), перевірений на реальній задачі
(ціль за замовчуванням — `app/`).

## Індекс

| Промпт | Напрям | Що робить | Перевірено на | Слід запуску |
|---|---|---|---|---|
| [`review-pr.md`](./review-pr.md) | рев'ю | Рев'ю дифу перед мержем (приклад-планка від авторів) | `app/src/quote.ts`: діф PR #20, 4 знахідки, жодної помилки коректності | [`runs/review-pr.md`](./runs/review-pr.md) |
| [`add-tests.md`](./add-tests.md) v3 | тести | Вичерпні unit-тести за 11 вимірами + звіт про дефекти без їх виправлення | `app/src/quote.ts`: 22 → 33 тести (нині 40 після рев'ю CodeRabbit); на вихідному коді падають 13 | [`runs/add-tests.md`](./runs/add-tests.md) |
| [`review-module.md`](./review-module.md) | рев'ю | Аудит цілого модуля проти його JSDoc-контракту (не дифу) | `app/src/quote.ts`: 7 порушень контракту | [`runs/review-module.md`](./runs/review-module.md) |
| [`write-docs.md`](./write-docs.md) | документація | API-документація, де кожен приклад перевірено запуском | `app/README.md`: 10 перевірених прикладів | [`runs/write-docs.md`](./runs/write-docs.md) |
| [`refactor-safely.md`](./refactor-safely.md) | рефакторинг | План рефакторингу з тестами як страховкою; «нічого не робити» — повноцінна відповідь | `app/src/quote.ts`: «no refactor worth doing» | [`runs/refactor-safely.md`](./runs/refactor-safely.md) |
| [`debug-failing-test.md`](./debug-failing-test.md) | дебаг · **markdown + XML** | Відтворення → root cause на `file:line` → мінімальний фікс, без застосування | `formatMoney(0.5)` → `"$0.0.5"`: обидва діалекти знайшли `quote.ts:49` | [`runs/debug-failing-test.md`](./runs/debug-failing-test.md) |
| [`scope-client-request.md`](./scope-client-request.md) v2 | задача агенції | Вхідний запит клієнта → бриф зі скоупом, критеріями, оцінкою й відкритими питаннями | синтетичний запит із 6 пастками | [`runs/scope-client-request.md`](./runs/scope-client-request.md) |

> Кожен промпт перед першим запуском покращено окремим sub-agent'ом
> (meta-prompting), а потім виконано агентом, який отримав лише сам артефакт —
> без підказок про те, що шукати (виняток — `add-tests.md`: sub-agent-запуск
> обірвався на ліміті API, тож його виконано в основній сесії; деталі в
> run log). Результати, включно з тим, що довелось виправити, збережено в
> [`runs/`](./runs/).

## Slash-команди (Task D)

| Команда | Що робить | Слід запуску |
|---|---|---|
| [`/sanitize-check <file>...`](../.claude/commands/sanitize-check.md) | Локальний скан на секрети, PII та приховані інструкції. Друкує лише категорії й номери рядків, значень не показує | [`runs/slash-commands.md`](./runs/slash-commands.md) |
| [`/scope-client-request <path> [rate-cents]`](../.claude/commands/scope-client-request.md) | Pre-flight-скан → бриф за `scope-client-request.md` v2 | [`runs/slash-commands.md`](./runs/slash-commands.md) |

## Правила цієї бібліотеки

1. Один промпт — одна задача. Якщо в описі є «і ще», це два промпти.
2. Кожен промпт має **acceptance criteria**, які можна перевірити «так/ні».
3. Кожен промпт має **stop-правило** — де агент зупиняється.
4. Промпт без перевірки на реальній задачі у бібліотеку не потрапляє.
5. Змінюєте промпт — піднімайте `version` і пишіть, що саме змінилось.
