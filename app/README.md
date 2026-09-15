# `quote.ts` — API reference

`app/src/quote.ts` estimates the price of a project, splits that price into
installments, and formats an amount for display. It exports exactly five
symbols, all documented here:

- [`QuoteInput`](#quoteinput) — the input object of the estimate
- [`MAX_INSTALLMENTS`](#max_installments) — upper bound on the number of payments
- [`estimateTotalCents`](#estimatetotalcents) — price of the project
- [`splitInstallments`](#splitinstallments) — price into N payments
- [`formatMoney`](#formatmoney) — cents into a display string

There is no default export and no configuration.

## Amounts are cents, never dollars

Every amount this module accepts and returns is in cents. `5000` is $50.00, and
$50.00 passed as `50` is fifty cents. Convert dollars to cents before you call
anything here: no function in the module takes or returns a dollar amount. This
is the rule that costs money at 2am if you miss it.

Whether *fractional* cents are allowed differs per function, so read this row
before you pass a computed value:

| Function | Accepts | Returns |
| --- | --- | --- |
| `estimateTotalCents` | `hours` and `rateCents` may be fractional; both must be finite | an integer number of cents, and a `RangeError` rather than a total outside the safe-integer range |
| `splitInstallments` | `totalCents` **must be a safe integer**; a fractional or unsafe total throws | an array of integer cents summing exactly to `totalCents` |
| `formatMoney` | **any** finite number of cents, fractional included | a display string; fractional cents are rounded to the nearest cent, so `formatMoney(0.5)` is `"$0.01"` |

So "integer cents" is a hard precondition only for `splitInstallments`, and a
guaranteed postcondition of `estimateTotalCents`. `formatMoney` is deliberately
lenient because it is the display end of the pipeline.

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

## `MAX_INSTALLMENTS`

```ts
export const MAX_INSTALLMENTS = 120;
```

The largest number of payments `splitInstallments` will produce — ten years of
monthly instalments. It is exported so a caller can validate a user-supplied
payment count *before* calling, and so a test can assert the boundary without
hard-coding `120`.

This is a business limit doing double duty as a safety limit: `parts` is an
allocation size, so an unbounded "positive integer" check would let
`splitInstallments(100000, 4_294_967_295)` reach `Array.from` and exhaust
memory. Asserted by `it("відхиляє кількість платежів понад документовану межу до
виділення масиву")` and `it("приймає рівно MAX_INSTALLMENTS платежів")`.

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
`discount = (gross * discountPercent) / 100`, result `Math.round(gross - discount)`,
which is then checked with `Number.isSafeInteger` before it is returned.

**Throws** `RangeError` when `hours` or `rateCents` is not finite, or when `discountPercent` is outside `0..100` or `NaN` — asserted by `it("відхиляє знижку поза документованими межами 0..100")` and `it("відхиляє нескінченні або NaN години й ставку замість тихого NaN")`. `0` and `100` are accepted: `it("приймає межові знижки 0 і 100")`.

It **also** throws `RangeError` when the computed total is not a safe integer.
Finite inputs are not enough: `hours * rateCents` can overflow to `Infinity`,
and `Infinity - Infinity` is `NaN`, so
`{ hours: Number.MAX_VALUE, rateCents: 2, discountPercent: 100 }` returned `NaN`
before this guard. Now:

```
RangeError: total must be a safe integer number of cents, got NaN
```

Asserted by `it("відхиляє переповнення у проміжному добутку замість тихого NaN")`,
`it("відхиляє суму поза межами безпечного цілого")` and
`it("приймає найбільшу суму, яка ще є безпечним цілим")`.

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

**Throws** `RangeError` when `parts` is not an integer in `1..MAX_INSTALLMENTS`
— that is, when `Number.isInteger(parts)` is false, `parts < 1`, or
`parts > MAX_INSTALLMENTS`. The message is built as
`parts must be a positive integer within 1..${MAX_INSTALLMENTS}, got ${parts}`.
`MAX_INSTALLMENTS` is exported and is `120` — ten years of monthly payments.
The upper bound exists because `parts` is an allocation size: without it,
`splitInstallments(100000, 4_294_967_295)` passes the "positive integer" check
and then asks `Array.from` for four billion elements, hanging the process or
exhausting memory. It also throws `RangeError` when
`totalCents` is not a **safe** integer (including `NaN`/`±Infinity`), because a fractional total cannot be split into whole cents that sum back exactly, and above `Number.MAX_SAFE_INTEGER` integer arithmetic is no longer exact — `base * parts` and the remainder would drift silently, breaking the very invariant this function exists to hold. `it("відхиляє некоректну кількість платежів")` covers `parts` of `0`, `-3` and
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
RangeError: parts must be a positive integer within 1..120, got 0
```

Example — the upper bound:

```bash
node --input-type=module -e "import { splitInstallments } from './src/quote.ts'; try { splitInstallments(100, 121); } catch (err) { console.log(err.name + ': ' + err.message); }"
```

```
RangeError: parts must be a positive integer within 1..120, got 121
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
| `splitInstallments` | `parts` not an integer in `1..MAX_INSTALLMENTS` | below `1`, an array of that length cannot exist; above `MAX_INSTALLMENTS`, the allocation would exhaust memory |
| `estimateTotalCents` | a computed total outside the safe-integer range | finite inputs can still overflow in `hours * rateCents`; `{ hours: Number.MAX_VALUE, rateCents: 2, discountPercent: 100 }` used to return `NaN` |
| `splitInstallments` | `totalCents` not a safe integer | a fractional total cannot sum back exactly (`100.5` gave a sum of `101`); above `Number.MAX_SAFE_INTEGER` the split arithmetic silently loses precision |
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
and **Tests 40 passed (40)**, all from `app/src/quote.test.ts`, and exited `0`.
`npm run typecheck` (`tsc --noEmit`) reported no errors and exited `0`.

The test names are Ukrainian. They are quoted verbatim throughout this document
and never translated, so that searching for a quoted name finds the assertion it
refers to.
