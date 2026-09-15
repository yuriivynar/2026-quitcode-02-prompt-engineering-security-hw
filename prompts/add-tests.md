---
name: add-tests
purpose: Generate an exhaustive unit-test suite for one module, then report the defects those tests expose instead of silently fixing them.
tested-on: `app/src/quote.ts` — run 2026-09-14: suite 22 → 33, all green; the same suite fails 13 tests on the original code, including the seeded `splitInstallments` defect; trace in `runs/add-tests.md`
version: 3
---

# Add exhaustive unit tests for a module

> **Reuse:** swap four things — the module `app/src/quote.ts`, its suite
> `app/src/quote.test.ts`, the command `cd app && npm test`, and the domain
> invariants in Context.

## Role (Роль)

Senior TypeScript engineer specialising in test design. You hunt for inputs that
break the code, not for proof that it works. A test that cannot fail is worthless.

## Goal (Мета)

Write unit tests for the three functions exported by `app/src/quote.ts` —
`estimateTotalCents`, `splitInstallments`, `formatMoney` — then report each
defect the suite exposes. For each function **every dimension below is covered
by a test or explicitly marked N/A with a one-line reason**; silence is not
coverage. `QuoteInput` is type-only — it is covered by `npm run typecheck`.

1. **Happy path** — the documented, ordinary case.
2. **Boundaries** — `0`, `1`, `-1`, single element, `Number.MAX_SAFE_INTEGER`.
3. **Sign** — negative inputs and negative results (refunds), and `-0`.
4. **Rounding and remainder** — values that do not divide evenly; anything where
   `Math.round` / `trunc` / `floor` differ, negative halves included
   (`Math.round(-2.5) === -2`).
5. **Precision** — float inputs producing integer outputs; money never drifts.
6. **Optional parameters** — `discountPercent` omitted, passed as its default
   `0`, and passed as a non-default value. Assert omitted === explicit default.
7. **Invalid input** — wrong type, `NaN`, `Infinity`, non-integer where an
   integer is required, and values outside the documented range
   (`discountPercent` is documented `0..100`; try `150` and `-10`).
8. **Invariants** — the domain rules below, checked over a table of inputs.
9. **Composition** — `estimateTotalCents` → `splitInstallments` → `formatMoney`:
   assert the chain still sums back to the estimate.
10. **Purity** — the input object is not mutated; calling twice with the same
    input returns the same result.
11. **Output shape** — length, ordering, element type; for `formatMoney`: sign
    placement, two-digit fraction, thousands separators.

**Undocumented behaviour (dimension 7):** all three functions validate their
input today and throw `RangeError` — `estimateTotalCents` on non-finite
`hours`/`rateCents`, on `discountPercent` outside `0..100`, and on a computed
total that is not a safe integer; `splitInstallments` on `parts` outside
`1..MAX_INSTALLMENTS` and on a `totalCents` that is not a safe integer; `formatMoney` on
non-finite `cents`. Those throws are documented in the JSDoc, so asserting them
is pinning a spec, not inventing one.

What is *not* documented is where the gaps remain: negative `hours`, the `-0`
that `Math.round` can return, `"-$0.00"` for a sub-half-cent negative, and the
hard-coded `"en-US"` grouping. For those, assert what the code *actually* does
only if you also record that it is out of contract — and never assert a `throw`
the JSDoc does not promise, because that invents a spec.

`formatMoney` accepting fractional cents and rounding them is **contract, not a
defect**: `formatMoney(0.5)` is `"$0.01"`. Do not write a test that demands it
throw.

## Context (Контекст)

Read all of these before writing a single line:

- `app/src/quote.ts` — three exported functions, the `QuoteInput` interface and
  the `MAX_INSTALLMENTS` constant.
  **The Ukrainian doc comments and the types are the spec.** Where the code
  contradicts them the spec wins, and the gap is a defect, not a test to relax.
- `app/src/quote.test.ts` — the existing suite: vitest `describe` / `it` /
  `expect` imported from `"vitest"`, module imported as `"./quote.js"`, test
  names in Ukrainian. Match that; do not duplicate a case already there.
- `app/package.json` — `npm test` is `vitest run`, `npm run typecheck` is
  `tsc --noEmit`. `app/tsconfig.json` is `strict` + `NodeNext`: relative imports
  keep the `.js` extension, and deliberately bad inputs need an explicit cast
  (`as unknown as number`) to compile.
- `AGENTS.md` — project conventions and guardrails.
- Domain invariants here: all amounts are **integer cents**; a split sums back to
  *exactly* the original total; installments differ by at most 1 cent; no
  operation may invent or lose a cent.

## Constraints (Обмеження)

- **Do not modify production code.** `app/src/quote.test.ts` is the only file
  you write to — no new test files, fixtures or config. A test that proves a
  defect gets reported; fixing it is a separate request.
- Your change to that file must be **purely additive**. Never delete, rename,
  skip or weaken an existing test to reach a green run: editing an assertion to
  match buggy output is the failure mode this prompt exists to prevent.
- No new dependencies. No `it.only`, `describe.only`, `it.skip`, `it.todo`.
- Deterministic only: no network, filesystem, timers, `Date.now()`, unseeded
  randomness. No snapshots. No mocks for pure functions.
- Every expected value is a literal you derived by hand from the spec — never
  produced by running the function under test, never recomputed with the
  implementation's own formula (that passes for any bug). Invariant tests
  (dimension 8) may compute over the returned output.
- One rule per test; the test name states that rule. Prefer one table-driven
  test over ten near-identical blocks.

## Acceptance criteria

- [ ] Before editing, copy `app/src/quote.ts` and `app/src/quote.test.ts` aside.
      At the end the `quote.ts` copy is byte-identical to the file, and diffing
      the `quote.test.ts` copy against the file shows **only added lines**.
- [ ] `git status --porcelain -- app` contains no `??` (untracked) line.
- [ ] `estimateTotalCents`, `splitInstallments` and `formatMoney` each gain at
      least one new test; `QuoteInput` is listed as N/A (type-only).
- [ ] Every dimension 1–11 is covered per function, or marked N/A with a reason.
- [ ] `cd app && npm test` was actually run; the report quotes its real summary
      line and exit code, and the run shows **0 skipped / 0 todo**.
- [ ] The test count after the run is higher than before it; both are stated.
- [ ] `cd app && npm run typecheck` exits 0.
- [ ] Every failing test appears in the defect list with the defect it proves,
      and the failing-test count in the run output equals the number of defects
      marked as proven by a failing test.
- [ ] Each coverage-table row answers "breaks if" with a concrete change to
      `app/src/quote.ts` that would make that test fail; a row with no answer is
      a tautological test — delete it.
- [ ] Each defect cites the `app/src/quote.ts` line whose doc comment or type it
      contradicts; a complaint with no contradicted spec line is not a defect.
- [ ] The defect list is present, or the sentence "No defects found." is stated
      explicitly — never left implied.

## Response format (Формат відповіді)

Four blocks, in this order, no prose around them:

1. **Coverage table** — `function | dimension | covered / N-A + reason | breaks if`.
2. **Diff** for `app/src/quote.test.ts` only.
3. **Run log** — for `npm test` and `npm run typecheck`: command, exit code, and
   the real summary line (files, passed, failed, skipped).
4. **Defects** — one line each, most severe first:
   `SEVERITY | quote.ts:line | input | expected per spec | actual | test proving it`
   …or `No defects found.`

## Stop (Stop)

Stop after the defect list. Do not fix production code, refactor, add features
or create extra test files — wait for a separate request.

If a function has no documented behaviour for an input and more than one
expectation is reasonable, stop before guessing: list the options and ask. An
invented spec produces tests that lock in the wrong behaviour.

---

## Run log (слід запуску)

**2026-09-14 — `app/src/quote.ts`.** Full trace: [`runs/add-tests.md`](./runs/add-tests.md).

- **Result:** 22 → 33 tests, 33/33 green, `tsc --noEmit` exit 0, `quote.ts`
  byte-identical to a pre-run copy, zero lines removed, no `.only`/`.skip`.
- **Proof the tests can fail:** the finished suite run against the original HEAD
  code gives `13 failed | 20 passed` — every new contract test fails there, and so
  do the tests for the seeded `splitInstallments` cent-loss defect.
- **What went wrong:** the planned blind sub-agent run on the pre-fix sandbox died
  on an API rate limit before writing anything, and the repo sub-agent run was
  stopped unfinished. The run above was executed in the main session instead;
  nothing from the failed runs is claimed.
- **Judgement the dimensions forced:** `-0` and `"-$0.00"` were marked N/A rather
  than asserted, because no doc comment defines them and a test would lock them in.
- **Version history:** v1 used slot placeholders → v2 replaced them with real paths
  (the rubric deducts for unfilled placeholders) plus a Reuse note → v3 after a
  meta-prompting sub-agent (hand-derived expected values, the `.only` ban, the
  baseline-copy criterion, `QuoteInput` marked type-only N/A).
