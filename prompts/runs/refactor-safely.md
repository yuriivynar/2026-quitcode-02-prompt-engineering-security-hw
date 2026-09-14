# Run log — `refactor-safely.md`

- **Date:** 2026-09-14
- **Prompt:** [`../refactor-safely.md`](../refactor-safely.md) v1
- **Target:** `app/src/quote.ts` (51 lines, 3 functions + `QuoteInput`)
- **Runner:** Claude Code sub-agent given only the artifact.
- **Result:** **`no refactor worth doing`** — 0 lines proposed, nothing applied.
  This is the outcome the prompt is built to make easy, and the reason it exists.

## Coverage check it produced (abridged)

Per symbol: what the 22-test suite *pins*, by test name, versus what is *open*.

- `estimateTotalCents` — pinned: 8 tests incl. "округлює залишок центів, а не
  відкидає його" (pins `Math.round`, not truncation). Open: negative `hours`,
  `discountPercent` outside `0..100`, non-integer `rateCents`, the `-0` return,
  exact `.5` ties, `NaN`/`Infinity`.
- `splitInstallments` — pinned: 9 tests incl. front-loaded remainder order and
  the negative-refund path. Open: the `RangeError` **message text** (only the
  type is asserted, at `quote.test.ts:101-103`), non-integer `totalCents`,
  `NaN`/`Infinity`.
- `formatMoney` — pinned: 5 tests incl. sign-before-`$` and `padStart`. Open:
  non-integer input (`0.5` → `"$0.0.5"`), `-0`, the hard-coded `"en-US"`.
- `QuoteInput` — no runtime test can pin a type; signature drift is caught only
  by `tsc --noEmit`, never by vitest.

## Why the answer was "nothing"

A mechanical duplication sweep of lines 10–51 found no statement repeated even
once. The only recurring tokens are `Math.abs` at `:40` and `:47` (unrelated
quantities), the literal `100` at `:23`/`:48`/`:49` (naming it is explicitly
forbidden by the prompt), and a sign-ternary *shape* at `:39`/`:46` with
different operand and return types.

**Considered and rejected — recorded so the analysis is visible:**

- `:38` `totalCents - base * parts` → `totalCents % parts`. Probed across 7 input
  pairs incl. `MAX_SAFE_INTEGER`: **0 divergences**, so likely behaviour-
  preserving — rejected anyway because it cites no symptom, which the prompt's
  constraints reject outright.
- `:41` `Array.from` → `for` loop — named cosmetic churn.
- A named constant for `100` — forbidden, and the three sites mean two different
  things.

**Routed elsewhere instead of fixed here** (the "report the bug, don't fix it"
constraint working): the `formatMoney` non-integer defect → `debug-failing-test.md`;
the unenforced `discountPercent` range → a finding, since a guard is a behaviour
change, not a refactor; the open column above → the backlog for `add-tests.md`.

## Scope discipline

`git status --porcelain` captured before and after. The agent reported the two
outputs as **not** a literal byte-match: one extra line, `?? prompts/runs/`,
created at 21:03 by a different agent running concurrently, before its own first
command at 21:04. It flagged the delta rather than presenting the outputs as
identical, and confirmed `app/src/quote.ts` unchanged by md5. Both safety nets
green: 22/22 tests, `tsc --noEmit` exit 0.
