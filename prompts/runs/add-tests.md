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
| `cd app && npm test` | **33 passed (33)**, 0 skipped, 0 todo |
| `cd app && npm run typecheck` | exit 0 |
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

The 13 failures include every new contract test *and* the pre-existing tests for
the seeded `splitInstallments` defect (`не втрачає центи, коли сума не ділиться
націло`, `не створює зайвих центів при округленні вгору`, and three more). No new
test passes on code that has the defect it targets.

## Defects

Proven by the suite on the original code and now fixed in `app/src/quote.ts`:
`discountPercent` outside `0..100` accepted (`150` → `-25000`); a non-integer
`totalCents` breaking the exact-sum promise (`100.5` → sum `101`);
`formatMoney(0.5)` → `"$0.0.5"`; `NaN`/`Infinity` flowing through all three
functions.

On the current code: **No defects found.** One cosmetic, out-of-contract behaviour
is recorded, not fixed: `formatMoney(-0.4)` → `"-$0.00"`.
