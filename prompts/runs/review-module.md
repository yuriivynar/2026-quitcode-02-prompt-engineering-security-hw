# Run log — `review-module.md`

- **Date:** 2026-09-14
- **Prompt:** [`../review-module.md`](../review-module.md) v1
- **Target:** `app/src/quote.ts` (working tree, suite green at 22/22)
- **Runner:** Claude Code sub-agent given *only* the artifact — no hints about
  what to find, no mention of any known defect.
- **Result:** 7 contract violations, all reproduced in a REPL. Scope held:
  read-only, `git status --porcelain` byte-identical before and after.

## Audited

| symbol | verdict |
|---|---|
| `QuoteInput` (quote.ts:10–17) | Contract only, never enforced — the `0..100` clause on `discountPercent` is a comment; nothing rejects `-50` or `150`. |
| `estimateTotalCents` (quote.ts:20–25) | 3 findings — F1, F2 (MONEY), F5 (CRASH). |
| `splitInstallments` (quote.ts:33–42) | 2 findings — F3 (MONEY), F6 (CRASH). `parts` validation is sound: `0`, `-3`, `2.5`, `NaN`, `Infinity` all rejected. |
| `formatMoney` (quote.ts:45–51) | 2 findings — F4, F7 (CRASH). Integers, zero, negatives, grouping all correct. |

Input classes reported even when clean: zero — clean; negative — clean;
non-integer — broken (F3, F4); `NaN`/`Infinity` — broken (F5, F6, F7);
out-of-documented-range — broken (F1, F2); rounding remainders — **clean**,
backed by an exhaustive scan of hours 1–40 × rateCents 1–4000 × discount 1–99
finding zero disagreements with exact half-up arithmetic; input mutation —
clean, and **no test asserts it**.

## Findings

`SEVERITY | file:line | input | expected | actual | contradicted doc | consequence | covered?`

- **F1** `MONEY | quote.ts:23 | estimateTotalCents({hours:10, rateCents:5000, discountPercent:150}) | a price in cents | -25000 | line 15 "Знижка у відсотках, 0..100" | a 150%-off typo turns the invoice into a negative amount a refund pipeline will pay out | not covered`
  gross `50000`, discount `75000`, `Math.round(50000 - 75000) = -25000`.
- **F2** `MONEY | quote.ts:23 | estimateTotalCents({hours:10, rateCents:5000, discountPercent:-50}) | ≤ gross (50000) | 75000 | line 15 | a negative discount silently becomes a 50% surcharge — overbilled client, chargeback | not covered`
- **F3** `MONEY | quote.ts:40 | splitInstallments(100.5, 3) | parts summing to exactly 100.5 | [34,34,33] (sum 101) | line 29 "сума якого ТОЧНО дорівнює totalCents" | the schedule invents a cent the client never agreed to; the ledger never reconciles | not covered`
  `base = trunc(33.5) = 33`, `remainder = 1.5`, so both `i=0` and `i=1` satisfy `i < 1.5`.
- **F4** `CRASH | quote.ts:49 | formatMoney(1234.5) | "$12.35"-shaped string | "$12.34.5" | line 44 | a client-facing invoice line with two decimal points | not covered`
  `String(1234.5 % 100) = "34.5"` is already 3 chars, so `padStart(2,"0")` pads nothing.
- **F5** `CRASH | quote.ts:24 | estimateTotalCents({hours:NaN, rateCents:5000}) | a number of cents | NaN | line 19 + the declared `number` return | an empty hours field becomes a NaN quote that propagates instead of failing loudly | not covered`
  Also `hours: Infinity` → `NaN`, because `Infinity * 0` is `NaN` even at the default discount.
- **F6** `CRASH | quote.ts:41 | splitInstallments(NaN, 3) | parts summing to the total | [NaN,NaN,NaN] | line 29 | NaN installments written to the billing schedule; every charge silently fails | not covered`
  `i < NaN` is false for every `i`. Nearest test `it("сума платежів завжди дорівнює загальній сумі")` only covers seven finite integer pairs.
- **F7** `CRASH | quote.ts:48 | formatMoney(NaN) | "$1,234.50"-shaped string | "$NaN.NaN" | line 44 | the F5 NaN reaches the client on the quote PDF | not covered`

**Verdict:** *No* — this module cannot be trusted to bill clients until F1–F3 are closed.

## Candidates the prompt made it *drop* (anti-padding rule working)

Not reported, because no documented clause is contradicted: negative `hours`;
non-integer `rateCents` rounding to an integer output; precision loss above
`MAX_SAFE_INTEGER`; `formatMoney(-0.5)` (same defect as F4); `-0` results;
`splitInstallments(100, 4294967296)` → `RangeError: Invalid array length`.

## Independent verification by the operator

I re-derived F3 and F4 myself before accepting them:
`splitInstallments(100.5,3)` → `[34,34,33]`, sum `101`; `formatMoney(0.5)` →
`"$0.0.5"`; `formatMoney(NaN)` → `"$NaN.NaN"`. Confirmed.

## What had to be corrected

The agent's first REPL pass printed the `NaN` arrays through `JSON.stringify`,
which renders `NaN` as `null`; it caught this itself, re-ran raw, and disclosed
the correction in its self-check rather than shipping the wrong output.
