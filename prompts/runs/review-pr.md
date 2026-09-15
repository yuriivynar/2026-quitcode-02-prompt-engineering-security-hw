# Run log — `review-pr.md`

- **Date:** 2026-09-15
- **Prompt:** [`../review-pr.md`](../review-pr.md) v1, markdown dialect
- **Diff reviewed:** `git diff main...HEAD -- app/src/quote.ts` plus the
  uncommitted working-tree change to the same file — i.e. every change this PR
  makes to the module, including the two rounds of CodeRabbit follow-up.
- **Why this log exists:** `review-pr.md` shipped with `tested-on:` filled in and
  no trace, so the index row read `—` under «Слід запуску». CodeRabbit flagged
  the gap on PR #20. A `tested-on` claim with no run log is an unfalsifiable
  claim; this file is the trace.

## How it was run

In the main Claude Code session, following the artifact literally: the diff
above as input, edge cases probed by execution rather than by reading, and the
Stop rule observed — the findings below were written before anything was changed
in response to them, and nothing in this run was fixed.

Edge-case probe, one throwaway `app/_probe.mjs`, deleted after the run:

```
--- 0 / negative / remainder / rounding ---
estimateTotalCents({h:0,r:0})                       => 0
estimateTotalCents({h:-1,r:1,d:50})  (-0?)          => "-0"
estimateTotalCents({h:-10,r:5000})                  => -50000
splitInstallments(0, 3)                             => [0,0,0]
splitInstallments(-100, 3) sum                      => -100
splitInstallments(100, 6) sum                       => 100
splitInstallments(1, 120) sum                       => 1
splitInstallments(-1, 120) sum                      => -1
splitInstallments(MAX_SAFE, 120) sum ok?            => true
splitInstallments(7, 3) spread<=1                   => 1
splitInstallments(-7, 3) spread<=1                  => 1
--- guard boundaries ---
splitInstallments(100, 120)                         => 120
splitInstallments(100, 121)                         => RangeError: parts must be a positive integer within 1..120, got 121
splitInstallments(100, 1.0)                         => 1
estimateTotalCents({h:MAX_SAFE,r:1})                => 9007199254740991
estimateTotalCents({h:MAX_SAFE,r:1,d:0.0000001})    => 9007199245733792
formatMoney(-0.4)                                   => "-$0.00"
formatMoney(-0)                                     => "$0.00"
```

Suite at review time: `cd app && npm test` → exit 0, `40 passed (40)`.

## Знахідки

Чотири. Жодна не є помилкою коректності в дифі — зупинковий інваріант
(«сума платежів ТОЧНО дорівнює `totalCents`») тримається на нулі, на від'ємних,
на залишку і на межі безпечного цілого, що й показує проба вище.

`СЕРЙОЗНІСТЬ | файл:рядок | дефект | приклад входу | що зламається`

**СЕРЕДНЯ | `app/src/quote.ts:16` | значення `MAX_INSTALLMENTS` не виведене з
жодної записаної вимоги | `120` | ліміт подано як «10 років щомісячних внесків»,
але такої вимоги немає ані в JSDoc модуля, ані в `AGENTS.md`, ані в завданні.
Це рішення рев'ю, вбудоване в публічний контракт: клієнт із планом на 180
платежів отримає `RangeError` через число, яке ніхто не погоджував. Технічна
частина (обмежити розмір алокації) обов'язкова; конкретно `120` — ні.**
Тести покривають межу (`приймає рівно MAX_INSTALLMENTS платежів`), але тест не
може підтвердити, що саме це число правильне. Потрібне рішення продукту, не код.

**НИЗЬКА | `app/src/quote.ts:90` | знак нуля непослідовний між двома шляхами |
`formatMoney(-0)` → `"$0.00"`, `formatMoney(-0.4)` → `"-$0.00"` | те саме
відображуване значення («нуль доларів») друкується то з мінусом, то без, залежно
від того, чи вхід був точним `-0`, чи округлився до нуля. На клієнтському
документі це видно.** Наявні тести це **не** покривають і покривати не повинні:
поведінка за межами контракту, `runs/add-tests.md` фіксує її свідомо не
запінену. Дефект передує цьому дифу.

**НИЗЬКА | `app/src/quote.ts:45` | `estimateTotalCents` може повернути `-0` |
`{ hours: -1, rateCents: 1, discountPercent: 50 }` → `-0` | `-0` проходить
`Number.isSafeInteger`, тож новий guard його не ловить; далі `splitInstallments(-0, 3)`
дає `[0, 0, 0]`, і знак губиться мовчки.** Не покрито тестами, свідомо
(`runs/add-tests.md`). Передує цьому дифу; новий guard його не вводить і не
усуває. Записано, не виправлено — виправлення змінює поведінку.

**НИЗЬКА | `app/README.md:49` | документація радить команду, яку конфіг репозиторію
блокує | `node --input-type=module -e "<snippet>"` | `.claude/settings.json`
тепер містить `Bash(node -e*)` у `deny`, тож агент у цьому репозиторії не може
виконати жоден із десяти прикладів README дослівно. Людина може — заборона
стосується агента, — але приклад, який не відтворює той, хто його читає в
Claude Code, перестає бути перевіреним прикладом.** Тестами не покривається за
визначенням. `prompts/write-docs.md` тепер називає обхід (той самий імпорт у
тимчасовому `.mjs`); сам README ще ні.

## Крайові випадки, перевірені явно

| Випадок | Результат |
|---|---|
| Нуль | `estimateTotalCents({h:0,r:0})` → `0`; `splitInstallments(0,3)` → `[0,0,0]` |
| Від'ємні | `splitInstallments(-100,3)` сумується в `-100`; розкид `1` цент |
| Залишок від ділення | `splitInstallments(100,6)` сумується в `100`, розкид `1` |
| Округлення | `estimateTotalCents` округлює лише фінальну суму; `formatMoney` округлює дробові центи з переносом у долари |
| Межа алокації | `parts: 120` → масив; `parts: 121` → `RangeError` |
| Межа точності | `splitInstallments(MAX_SAFE_INTEGER, 120)` сумується назад точно |

## Чи покривають наявні тести знайдене

Знахідка 1 — частково (межа затестована, значення обґрунтувати тестом не можна).
Знахідки 2 і 3 — ні, свідомо: це поведінка поза контрактом, і запінити її
означало б зафіксувати те, чого JSDoc не обіцяє. Знахідка 4 — поза охопленням
тестів.

## Оцінка самого промпту

Обмеження «максимум 7 знахідок, відсортованих за серйозністю» зробило роботу:
спокуса дописати п'яту-шосту дрібницю була, і ліміт її не знімав — знімала
вимога «конкретний вхід, що ламає». Дрібниці не мали такого входу і відпали самі.

Чого промпту бракує, видно саме на цьому дифі: він просить «чи покривають наявні
тести знайдене», але не просить **запустити** їх — модель може відповісти з
читання. Тут тести були запущені (`40 passed (40)`), проте це рішення виконавця,
а не вимога артефакту. Для v2: додати до acceptance criteria рядок про
дослівний вивід `npm test` з exit code — рівно те, чого CodeRabbit вимагав від
`runs/add-tests.md` на цьому ж PR.
