---
name: refactor-safely
purpose: Plan a behaviour-preserving refactor with the test suite as the safety net — and prove the refactor is worth doing before any code moves.
tested-on: `app/src/quote.ts` — run 2026-09-14 returned "no refactor worth doing" (0 lines changed) with the coverage gaps routed to other prompts; trace in `runs/refactor-safely.md`
version: 1
---

# Refactor without changing behaviour

> **Reuse:** swap the target `app/src/quote.ts`, its suite `app/src/quote.test.ts` and the two safety-net commands.

## Role (Роль)

Engineer who has been burned by a "pure cleanup" that changed a rounding rule.
You treat every refactor as guilty until a named test proves it innocent, and you
are rewarded for saying "nothing here is worth touching" — never for volume.

## Goal (Мета)

Decide whether `app/src/quote.ts` needs any behaviour-preserving change at all, and
if it does, propose at most three — smallest first, each with the test that would
catch it breaking. "No refactor is worth doing" is a complete answer.

## Context (Контекст)

- Target: `app/src/quote.ts` — 51 lines. Public API: `estimateTotalCents`,
  `splitInstallments`, `formatMoney`, and the exported interface `QuoteInput`.
- Safety net: `app/src/quote.test.ts` — 22 `it` cases in 3 `describe` blocks, run with
  `cd app && npm test` (vitest). Second net: `cd app && npm run typecheck`
  (`tsc --noEmit`, strict) catches signature drift the suite would miss.
- Sole in-repo consumer: `app/src/quote.test.ts`. `app/README.md` does not exist yet —
  `prompts/write-docs.md` generates it from these signatures, so a rename desyncs a doc you cannot see.
- Domain: integer cents, exact sums, no cent invented or lost.
- **Live wires — real behaviour that no test pins**, so none of it may change:
  - `estimateTotalCents`: negative `hours`, negative or above-100 `discountPercent`,
    non-integer `rateCents`, and the `-0` that `Math.round` returns
    (`{ hours: -1, rateCents: 1, discountPercent: 50 }` gives `-0`, not `0`).
  - `splitInstallments`: the `RangeError` message text — only the error *type* is
    asserted, at `app/src/quote.test.ts:100`.
  - `formatMoney`: non-integer input (`formatMoney(0.5)` is `"$0.0.5"`),
    `formatMoney(-0)` is `"$0.00"`, and grouping is hard-coded `"en-US"`.
- Conventions: `AGENTS.md`. Source comments are Ukrainian — keep them Ukrainian.

## Constraints (Обмеження)

- **Behaviour must not change.** Not return values, not error types or messages, not
  rounding, not `-0` signs, not exported signatures.
- Change no file: this prompt produces a plan only. `app/src/quote.test.ts` stays
  untouched here and in the follow-up — tests belong to `prompts/add-tests.md`.
- No new dependencies, files, abstraction layers or patterns "for future flexibility";
  no helper extracted for a single call site; no named constant for `100`.
- Do not rename exports, reorder parameters, or make an optional parameter required.
- Adding validation, guard clauses or error handling is a **behaviour change**, not a
  refactor: report it as a finding, never propose it here.
- Do not mix a bug fix into a refactor — report the bug and stop
  (`prompts/debug-failing-test.md` owns fixes, `prompts/review-module.md` audits).
- Cosmetic churn is not a refactor and must not appear: formatting, import order, comment
  rewording or translation, `function` → arrow, `Array.from` ↔ loop, JSDoc, inferred types.
- Every proposal must cite a symptom at `app/src/quote.ts:line` — an expression duplicated
  at two or more numbered lines, or a construct that already caused a defect. A principle
  (DRY, SRP, "readability") is not a symptom and is rejected.
- Maximum 3 proposals. The module is 51 lines and the suite is green, so the expected
  default answer is "no refactor worth doing"; proposing nothing costs you nothing.
- A change not covered by an existing test is **unsafe-to-apply** until a test is added.

## Acceptance criteria

- [ ] The coverage check lists, per exported symbol, which behaviours
      `app/src/quote.test.ts` pins — by test name — and which it leaves open.
- [ ] Each proposal cites `app/src/quote.ts:line` ranges for every line it would move.
- [ ] Each proposal gives one concrete input and the exact wrong output that would
      appear if the change were made incorrectly, plus the name of the test that
      catches it. "The tests cover this" with no named test is rejected.
- [ ] Each proposal is labelled **safe-to-apply** or **unsafe-to-apply**, with named tests as evidence.
- [ ] Each proposal names which live wire from Context it touches, or says "none".
- [ ] Each proposal has a one-line cost/benefit verdict, and proposals that do not pay
      for themselves are marked **do not do**.
- [ ] The plan states the total number of lines it would change. If that number exceeds
      51 — the size of the module — the plan is rejected by its own rule.
- [ ] There are at most 3 proposals, and none is justified only by a principle.
- [ ] Nothing was applied: `git status --porcelain` prints exactly what it printed
      before the run, and both outputs are shown.
- [ ] If nothing is worth changing, the answer is "no refactor worth doing" plus the
      reason — not an invented cleanup produced to fill the format.

## Response format (Формат відповіді)

1. **Coverage check** — one line per exported symbol: `symbol | pinned by | open`.
2. **Plan** — at most 3 numbered proposals, one line each:
   `N | quote.ts:lines | what moves | symptom | breaks-if input → wrong output |
   safe/unsafe + test | lines changed | verdict`
   — or the single line `no refactor worth doing` plus one sentence of why.
3. **Recommendation** — which numbers to apply, in which order, what to run between.

## Stop (Stop)

Stop after the recommendation. **Apply nothing** until a human names the numbers. When they
do: one proposal at a time, then `cd app && npm test` and `cd app && npm run typecheck`; if
either goes red, revert that proposal rather than fixing forward, and do not start the next
number without a fresh go-ahead.

## Run log (слід запуску)

**2026-09-14 — `app/src/quote.ts`.** Full trace: [`runs/refactor-safely.md`](./runs/refactor-safely.md).

- **Recommended:** nothing. `no refactor worth doing`, 0 lines, on a module whose
  suite is green — reached by a duplication sweep that found no statement
  repeated even once, not by declining to look.
- **Applied by a human:** nothing. Both safety nets still green (22/22,
  `tsc --noEmit` exit 0).
- **What the constraints actually bought:** three plausible cleanups were
  rejected *with reasons* rather than shipped — including `totalCents % parts`,
  which the agent probed across 7 input pairs and found equivalent, then
  rejected anyway because it cited no symptom. The anti-busywork rule held
  against a candidate that would have passed a normal review.
- **Side benefit:** the "report the bug and stop" constraint routed two real
  defects out to `debug-failing-test.md` and `review-module.md` instead of
  smuggling fixes into a "cleanup" diff.
- **v1 history:** drafted by hand → improved by a meta-prompting sub-agent
  (which corrected three false claims in my draft, including a reference to
  `app/README.md`, a file that did not exist) → run unchanged, as above.
