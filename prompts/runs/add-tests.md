# Run log — `add-tests.md`

- **Date:** 2026-09-14
- **Prompt:** [`../add-tests.md`](../add-tests.md) v3
- **Target:** `app/src/quote.ts` after the fixes that came out of
  `review-module.md` and `debug-failing-test.md`.

## How it was run, including what went wrong

1. **Earlier, by the participant:** a first test-writing pass grew the suite from
   4 to 22 tests and, per the participant, exposed the workshop's seeded defect
   (`splitInstallments` losing or inventing cents via `Math.round(total / parts)`),
   which was then fixed. **That pass left no transcript and no recorded prompt, so
   it is not claimed as evidence of anything** — see "Which run found the seeded
   defect" below for the runs that do have a trace.
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

## Baseline: the weak prompt, actually run — 2026-11-15

`materials/weak-prompt.md` (`допоможи з тестами для app`) had never been run, so the
comparison with this prompt was an assumption. It was run once, verbatim, in an
isolated sandbox: `git archive da25af6 app` (the original code — 4 green tests,
`Math.round(totalCents / parts)` at `quote.ts:32`) copied outside the repo, with a
fresh sub-agent that was given only that sentence. Two additions to the bare
prompt, both needed for the trace and both worth knowing about: a note naming the
sandbox directory, and a request to end with a report of files opened, assumed
scope, "done" criterion and surprises. The sandbox had no `AGENTS.md`/`CLAUDE.md`,
so no repo guardrails applied. One run, one model — an observation, not a benchmark.

Checked afterwards against the sandbox, not taken from the agent's own report:
only `app/src/quote.test.ts` changed, `quote.ts` is byte-identical to the original,
and `npm test` shows `Tests 21 passed | 5 expected fail | 5 todo (31)` (4 → 31).

| Question | What the agent did |
|---|---|
| Scope | Guessed "tests for `app`" = the one module `quote.ts` and its one test file. Opened `quote.ts`, `quote.test.ts`, `package.json`, `tsconfig.json` and a directory listing; nothing else. Read the file comments ("tests are deliberately minimal") as permission to expand coverage. Did not touch source, deps or config — by its own reading of "tests", not because anything forbade it. |
| "Done" | Invented its own: every export has happy/boundary/edge cases, suite green, typecheck clean, bugs "recorded visibly". Stopped when the bar went green. Dropped one test of its own that passed trivially. |
| Seeded defect | **Noticed it**: `splitInstallments(100, 3)` → sum 99, `(5, 2)` → sum 6, `(1, 3)` → `[0,0,0]` — plus `formatMoney(1.5)` → `"$0.1.5"`, no `parts` validation, no `discountPercent` validation. |
| What it did with the findings | Pinned the cent-loss and the `formatMoney` bug as `it.fails` (5 of them) and the validation gaps as `it.todo` (5), so **`npm test` is green with the defects inside**. Wrote the findings in its chat report only; nothing in the repo says the code is wrong except those markers. |

Reading: the weak prompt did **not** miss the defect — the hint in
`materials/weak-prompt.md` ("the weak prompt won't find it") did not hold for this
run. What it lacked was an acceptance criterion that says what to do with a defect:
the agent chose a convention (`it.fails`) that turns "found a bug" into "suite
passes". The structured prompt's criteria close that — a test must fail on code that
has the defect it targets (13 do, below) and defects get their own section of the
report. The difference shown here is the *handling* of the finding, not the
finding.

## Which run found the seeded defect

| Run | Found it? | Trace |
|---|---|---|
| Participant's first pass (4 → 22) | claimed, **unverifiable** | none — not counted |
| Weak prompt, sandbox, 2026-11-15 | yes — as 3 `it.fails` + a chat note | this section; sandbox diff checked |
| `add-tests.md` v3 suite, run against the original code (re-verified 2026-09-15) | yes — failing tests 1–4 below | verbatim `13 failed \| 20 passed (33)` |
| Blind sub-agent run of `add-tests.md` on the pre-fix code | **never happened** — API rate limit (item 2 above) | none |

So the only prompt-driven *discovery* on record is the weak-prompt run; the
structured prompt's contribution is the reproducible *proof* that its tests fail on
defective code, not an independent find.

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

(Прогін 2026-09-15, до deny-списку. Нині `.claude/settings.json` забороняє
`Bash(npx *)`, тож той самий запуск — `cd app && npm test -- --reporter=verbose`.)

Where the 33 split on the original code (corrected 2026-11-15; earlier text said
the 20 passing tests were all pre-existing, which the numbers contradict):

| Group | Tests | On original code |
|---|---|---|
| Earlier 22 | 22 | **5 fail** (#1–5 in the table) · 17 pass |
| New 11 | 11 | **8 fail** (#6–13) · **3 pass** |
| Total | 33 | 13 fail · 20 pass = 17 earlier + 3 new |

The 3 new tests that pass on defective code are the ones that pin behaviour the
original already had and that target no defect: `приймає межові знижки 0 і 100`,
`не мутує вхідний об'єкт і не дописує знижку за замовчуванням` and
`найбільше безпечне ціле в одній частині лишається незмінним`. So "no new test
passes on code that has the defect it targets" holds — each of the 8 defect-targeting
new tests fails — but it is **not** true that every passing test is an old one. The
split was derived from the two tables in this file; it was not re-run test by test.

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
