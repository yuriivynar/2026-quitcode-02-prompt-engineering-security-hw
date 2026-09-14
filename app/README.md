# `quote.ts` — API reference

`app/src/quote.ts` estimates the price of a project, splits that price into
installments, and formats an amount for display. It exports exactly four
symbols, all documented here:

- [`QuoteInput`](#quoteinput) — the input object of the estimate
- [`estimateTotalCents`](#estimatetotalcents) — price of the project
- [`splitInstallments`](#splitinstallments) — price into N payments
- [`formatMoney`](#formatmoney) — cents into a display string

There is no default export and no configuration.

## Amounts are integer cents, never dollars

Every amount this module accepts and returns is a whole number of cents.
`5000` is $50.00, and $50.00 passed as `50` is fifty cents. Convert dollars to
cents before you call anything here: no function in the module takes or returns
a dollar amount. This is the rule that costs money at 2am if you miss it.

## Running the examples

Every example below is a command that was executed from the `app/` directory
with Node v24.12.0, followed by the exact output it printed.

`app/package.json` declares no `main` and no `exports` field, so there is no
package-name import for this module: the examples import the source file by
relative path, `./src/quote.ts`. `app/tsconfig.json` includes only `src`, so
nothing typechecks the snippets in this file — they are verified by having been
run, not by the compiler.

Each example has the shape:

```bash
node --input-type=module -e "<snippet>"
```

## `QuoteInput`

The input object of `estimateTotalCents`. Declaration, from `quote.ts`:

```ts
export interface QuoteInput {
  hours: number;
  rateCents: number;
  discountPercent?: number;
}
```

| Field | Required | Unit | Notes |
| --- | --- | --- | --- |
| `hours` | yes | hours | Work estimate. Fractional values work: the test `it("дробові години дають цілі центи")` passes `2.5`. |
| `rateCents` | yes | cents per hour | `5000` means $50.00 per hour. |
| `discountPercent` | no | percent | The source documents the range `0..100`. Omitted, it defaults to `0`. Values outside `0..100` (and `NaN`) throw `RangeError` — see [Input validation](#input-validation). |

Omitting `discountPercent` and passing `discountPercent: 0` give the same
result, asserted by `it("явний discountPercent: 0 дорівнює відсутності знижки")`.

Example — build an input with a discount and price it:

```bash
node --input-type=module -e "import { estimateTotalCents } from './src/quote.ts'; const input = { hours: 10, rateCents: 5000, discountPercent: 10 }; console.log(estimateTotalCents(input));"
```

```
45000
```

## `estimateTotalCents`

```ts
export function estimateTotalCents(input: QuoteInput): number {
```

**Returns** the price of the project in cents after the discount, as a whole
number: the function applies `Math.round` to the discounted amount, so a cent
fraction is rounded rather than dropped. `it("завжди повертає ціле число центів")`
asserts the integer result for three further inputs.

**Units** — in: hours and cents per hour, through `QuoteInput`; out: cents.

**Computation**, as written in the source: `gross = hours * rateCents`,
`discount = (gross * discountPercent) / 100`, result `Math.round(gross - discount)`.

**Throws** `RangeError` when `hours` or `rateCents` is not finite, or when `discountPercent` is outside `0..100` or `NaN` — asserted by `it("відхиляє знижку поза документованими межами 0..100")` and `it("відхиляє нескінченні або NaN години й ставку замість тихого NaN")`. `0` and `100` are accepted: `it("приймає межові знижки 0 і 100")`.

Example — ten hours at $50.00 per hour, no discount:

```bash
node --input-type=module -e "import { estimateTotalCents } from './src/quote.ts'; console.log(estimateTotalCents({ hours: 10, rateCents: 5000 }));"
```

```
50000
```

Example — the rounding step, where the discount lands on a fraction of a cent
(`gross = 333`, 10% of it is `33.3`, and `333 - 33.3 = 299.7`):

```bash
node --input-type=module -e "import { estimateTotalCents } from './src/quote.ts'; console.log(estimateTotalCents({ hours: 1, rateCents: 333, discountPercent: 10 }));"
```

```
300
```

## `splitInstallments`

```ts
export function splitInstallments(totalCents: number, parts: number): number[] {
```

**Returns** an array of exactly `parts` numbers, each a whole number of cents,
summing to `totalCents` exactly: the division remainder is spread one cent at a
time over the first payments, so two payments differ by at most one cent. The
sum property is asserted by `it("сума платежів завжди дорівнює загальній сумі")`
over seven cases, the one-cent spread by
`it("платежі відрізняються не більше ніж на 1 цент")`, and the integer result by
`it("усі платежі — цілі центи")`.

**Units** — in: cents and a count of payments; out: cents.

**Negative totals** (refunds) are split the same way, the extra cent going to
the first payments: `it("від'ємна сума (повернення) ділиться так само коректно")`.

**Throws** `RangeError` when `parts` is not a positive integer — that is, when
`Number.isInteger(parts)` is false or `parts < 1`. The message is built as
`parts must be a positive integer, got ${parts}`. It also throws `RangeError` when
`totalCents` is not an integer (including `NaN`/`±Infinity`), because a fractional total cannot be split into whole cents that sum back exactly. `it("відхиляє некоректну кількість платежів")` covers `parts` of `0`, `-3` and
`2.5`; `it("відхиляє дробову суму, яка ламала інваріант точної суми")` and `it("відхиляє NaN та нескінченну суму")` cover `totalCents`.

Example — a total that divides evenly:

```bash
node --input-type=module -e "import { splitInstallments } from './src/quote.ts'; console.log(splitInstallments(90000, 3));"
```

```
[ 30000, 30000, 30000 ]
```

Example — a total that does not divide evenly: four payments absorb the
remainder and the array still sums to 100:

```bash
node --input-type=module -e "import { splitInstallments } from './src/quote.ts'; console.log(splitInstallments(100, 6));"
```

```
[ 17, 17, 17, 17, 16, 16 ]
```

Example — a refund:

```bash
node --input-type=module -e "import { splitInstallments } from './src/quote.ts'; console.log(splitInstallments(-100, 3));"
```

```
[ -34, -33, -33 ]
```

Example — the `RangeError`:

```bash
node --input-type=module -e "import { splitInstallments } from './src/quote.ts'; try { splitInstallments(100, 0); } catch (err) { console.log(err.name + ': ' + err.message); }"
```

```
RangeError: parts must be a positive integer, got 0
```

## `formatMoney`

```ts
export function formatMoney(cents: number): string {
```

**Returns** a display string built as: a minus sign when `cents` is negative,
then `$`, then the whole-dollar part grouped by `toLocaleString("en-US")`, then
`.`, then the remaining cents (after rounding to a whole cent) padded to two digits. The sign comes before the
currency symbol, asserted by `it("ставить знак мінус перед символом валюти")`.
The locale `en-US` and the `$` symbol are hard-coded and the function takes no
options.

**Units** — in: cents; out: a string.

**Throws** `RangeError` for `NaN` and `±Infinity`: `it("відхиляє NaN і нескінченність замість рядка $NaN.NaN")`. A fractional amount is rounded to the nearest cent *before* splitting into dollars and cents, so the string always has exactly one `.` and the rounding carries into the dollars: `it("округлює дробові центи, тож у рядку завжди одна крапка")`, `it("переносить округлення в долари, а не лише в центи")`.

Example — cents to dollars, with thousands grouping:

```bash
node --input-type=module -e "import { formatMoney } from './src/quote.ts'; console.log(formatMoney(123450));"
```

```
$1,234.50
```

Example — under a dollar, zero, and a negative amount:

```bash
node --input-type=module -e "import { formatMoney } from './src/quote.ts'; console.log(formatMoney(5)); console.log(formatMoney(0)); console.log(formatMoney(-123450));"
```

```
$0.05
$0.00
-$1,234.50
```

## The three functions together

Price seven hours at $125.00 per hour with a 15% discount, split the total into
three payments, and format each one:

```bash
node --input-type=module -e "import { estimateTotalCents, splitInstallments, formatMoney } from './src/quote.ts'; const total = estimateTotalCents({ hours: 7, rateCents: 12500, discountPercent: 15 }); console.log(total); console.log(splitInstallments(total, 3).map(formatMoney));"
```

```
74375
[ '$247.92', '$247.92', '$247.91' ]
```

## Input validation

Every function rejects input outside its documented contract with `RangeError`
instead of returning a wrong amount. Summary of the guards:

| Function | Rejected input | Why it is rejected |
| --- | --- | --- |
| `estimateTotalCents` | `discountPercent` outside `0..100` or `NaN` | `150` would produce a negative invoice, `-50` a silent surcharge |
| `estimateTotalCents` | non-finite `hours` or `rateCents` | would produce a `NaN` total that propagates downstream |
| `splitInstallments` | `parts` not a positive integer | an array of that length cannot exist |
| `splitInstallments` | `totalCents` not an integer | a fractional total cannot sum back exactly (`100.5` gave a sum of `101`) |
| `formatMoney` | `NaN`, `±Infinity` | would print `"$NaN.NaN"` on a client document |

Still accepted and **not** a contract: negative `hours` (the doc comment sets no
range), and a sub-half-cent negative amount in `formatMoney`, which renders as
`"-$0.00"`. Do not build on either.

`estimateTotalCents` rounds the final total only, not the intermediate
arithmetic, and `formatMoney` is the display end of the pipeline — it is not a
parser, and the module has no inverse of it.

## Tests and typecheck

```bash
cd app && npm test
cd app && npm run typecheck
```

In this checkout `npm test` (vitest v5.0.0) reported **Test Files 1 passed (1)**
and **Tests 33 passed (33)**, all from `app/src/quote.test.ts`.
`npm run typecheck` (`tsc --noEmit`) reported no errors.

The test names are Ukrainian. They are quoted verbatim throughout this document
and never translated, so that searching for a quoted name finds the assertion it
refers to.
