# Run log — `add-tests.md`

- **Date:** 2026-09-14
- **Prompt:** [`../add-tests.md`](../add-tests.md) v3
- **Target:** `app/src/quote.ts` after the fixes that came out of
  `review-module.md` and `debug-failing-test.md`.

## How it was run, including what went wrong

1. **Earlier, by the participant:** a first test-writing pass grew the suite from
   4 to 22 tests and exposed the workshop's seeded defect (`splitInstallments`
   losing or inventing cents via `Math.round(total / parts)`), which was then fixed.
2. **Planned blind re-run on the pre-fix code** in an isolated sandbox (HEAD copy,
   4 green tests, defect hidden): **failed** — the sub-agent hit an API session
   rate limit before writing anything. Nothing from that run is claimed here.
3. **Sub-agent run on the repo:** stopped by the operator before it wrote anything,
   to finish Task A in the main session instead.
4. **The run recorded below** was executed in the main Claude Code session,
   following this artifact literally.

## Result

| Check | Outcome |
|---|---|
| Tests before → after | 22 → **33** (11 added, purely additive) |
| `cd app && npm test` | exit 0 — **33 passed (33)**, 0 skipped, 0 todo |
| `cd app && npm run typecheck` | exit 0 — `tsc --noEmit`, no diagnostics |
| `app/src/quote.ts` changed by the run | no — byte-identical to a pre-run copy |
| Lines removed from `quote.test.ts` | 0 |
| `.only` / `.skip` / `.todo` | none |

## Coverage added, per dimension

| Function | Dimension | New test |
|---|---|---|
| `estimateTotalCents` | boundaries | `приймає межові знижки 0 і 100` |
| `estimateTotalCents` | invalid input, documented range | `відхиляє знижку поза документованими межами 0..100` (`150`, `100.5`, `-10`, `-0.5`, `NaN`) |
| `estimateTotalCents` | invalid input, non-finite | `відхиляє нескінченні або NaN години й ставку замість тихого NaN` |
| `estimateTotalCents` | purity | `не мутує вхідний об'єкт і не дописує знижку за замовчуванням` |
| `splitInstallments` | invariants, non-integer total | `відхиляє дробову суму, яка ламала інваріант точної суми` |
| `splitInstallments` | invalid input | `відхиляє NaN та нескінченну суму` |
| `splitInstallments` | boundaries | `найбільше безпечне ціле в одній частині лишається незмінним` |
| `formatMoney` | rounding, output shape | `округлює дробові центи, тож у рядку завжди одна крапка` |
| `formatMoney` | rounding carry | `переносить округлення в долари, а не лише в центи` (`99.6` → `"$1.00"`) |
| `formatMoney` | invalid input | `відхиляє NaN і нескінченність замість рядка $NaN.NaN` |
| all three | composition | `платежі сумуються назад до кошторису і форматуються коректно` |

N/A with reason: `QuoteInput` is type-only (covered by `tsc`). The `-0` result of
`estimateTotalCents` and `"-$0.00"` for sub-half-cent negatives were deliberately
**not** asserted — pinning them would lock in behaviour no doc comment defines.

Expected values are hand-derived literals, never recomputed with the module's own
formula — e.g. the composition test states `87500 × 0.85 = 74375`, then
`74375 / 3 = 24791 r 2` → `[24792, 24792, 24791]`.

## Proof the tests can fail

The finished 33-test suite was run against the **original HEAD code** in the
isolated sandbox:

```
Tests  13 failed | 20 passed (33)
```

Re-verified on 2026-09-15 by running the finished suite against
`git show da25af6:app/src/quote.ts` in a sandbox outside the repo. Every one of
the 13 is listed below with the defect it proves — the criterion is per test, not
per defect group:

| # | Failing test | Defect it proves |
|---|---|---|
| 1 | `splitInstallments` › `не втрачає центи, коли сума не ділиться націло` | seeded: `Math.round(total / parts)` loses cents |
| 2 | `splitInstallments` › `не створює зайвих центів при округленні вгору` | seeded: the same rounding invents cents |
| 3 | `splitInstallments` › `сума платежів завжди дорівнює загальній сумі` | seeded: the exact-sum invariant is broken outright |
| 4 | `splitInstallments` › `від'ємна сума (повернення) ділиться так само коректно` | seeded: refunds are split by the same broken rounding |
| 5 | `splitInstallments` › `відхиляє некоректну кількість платежів` | no `parts` validation at all — `0` and `-3` returned `[]`, `2.5` a fractional length |
| 6 | `estimateTotalCents — межі контракту` › `відхиляє знижку поза документованими межами 0..100` | `discountPercent: 150` accepted → `-25000`, a negative invoice |
| 7 | `estimateTotalCents — межі контракту` › `відхиляє нескінченні або NaN години й ставку замість тихого NaN` | `NaN`/`Infinity` flowed through to a `NaN` total |
| 8 | `splitInstallments — межі контракту` › `відхиляє дробову суму, яка ламала інваріант точної суми` | non-integer `totalCents` accepted — `100.5` summed to `101` |
| 9 | `splitInstallments — межі контракту` › `відхиляє NaN та нескінченну суму` | `NaN`/`Infinity` total accepted |
| 10 | `formatMoney — межі контракту` › `округлює дробові центи, тож у рядку завжди одна крапка` | `formatMoney(0.5)` → `"$0.0.5"`, two decimal points |
| 11 | `formatMoney — межі контракту` › `переносить округлення в долари, а не лише в центи` | the line-local fix candidate: `99.6` → `"$0.100"` |
| 12 | `formatMoney — межі контракту` › `відхиляє NaN і нескінченність замість рядка $NaN.NaN` | `NaN` cents rendered as `"$NaN.NaN"` on a client document |
| 13 | `композиція estimate → split → format` › `платежі сумуються назад до кошторису і форматуються коректно` | the three defects compose: the chain does not round-trip |

Command and verbatim tail:

```
$ npx vitest run --reporter=verbose
 ⎯⎯⎯⎯⎯⎯ Failed Tests 13 ⎯⎯⎯⎯⎯⎯⎯
 Test Files  1 failed (1)
      Tests  13 failed | 20 passed (33)
```

No new test passes on code that has the defect it targets, and the 20 that pass
are the pre-existing green cases the run was required not to disturb.

## Defects

Proven by the suite on the original code and now fixed in `app/src/quote.ts`:
`discountPercent` outside `0..100` accepted (`150` → `-25000`); a non-integer
`totalCents` breaking the exact-sum promise (`100.5` → sum `101`);
`formatMoney(0.5)` → `"$0.0.5"`; `NaN`/`Infinity` flowing through all three
functions.

On the current code: **No defects found.** One cosmetic, out-of-contract behaviour
is recorded, not fixed: `formatMoney(-0.4)` → `"-$0.00"`.

## Addendum — 2026-09-15, after CodeRabbit review of PR #20

Two further defects were reported on `app/src/quote.ts` by review, not by this
suite, and both were real — this run's 11 new tests did not cover them:

1. `estimateTotalCents` returned `NaN` when finite inputs overflowed the
   intermediate product (`{ hours: Number.MAX_VALUE, rateCents: 2,
   discountPercent: 100 }`). Guarded now with `Number.isSafeInteger` on the
   computed total.
2. `splitInstallments` accepted `parts: 4_294_967_295` — a positive integer, so
   it passed the guard — and then asked `Array.from` for four billion elements.
   Bounded now by the exported `MAX_INSTALLMENTS` (`120`).

Five regression tests were added for these (suite **33 → 38**, `npm test` exit 0,
`38 passed (38)`; `npm run typecheck` exit 0). The lesson for the prompt: the
11-dimension checklist in `add-tests.md` asks for boundaries per *argument* but
never for the boundaries of a *computed result* or of an *allocation size*. Both
gaps sat in dimension 2 and neither was caught.
