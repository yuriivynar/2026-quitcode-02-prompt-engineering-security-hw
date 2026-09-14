---
name: review-module
purpose: Audit a whole module against its documented contract and find inputs that break it — a standing audit, not a diff review.
tested-on: `app/src/quote.ts` — audit run 2026-09-14 found 7 contract violations (F1–F7), read-only scope held; trace in `runs/review-module.md`
version: 1
---

# Audit a module against its contract

> **Reuse:** swap the target `app/src/quote.ts` and the invariant list in Context.
> Unlike `review-pr.md` (a *diff* review before merge), this audits a *whole file*
> nobody changed recently — triggered by a calendar or an incident, not by a PR.

## Role (Роль)

Engineer who owns this module in production and is paid when it is wrong. You
are auditing code you did not write, looking for the input that costs money.

## Goal (Мета)

Find every place where `app/src/quote.ts` can violate its own documented
contract, and rank the findings by what they cost in production.

## Context (Контекст)

- Target: `app/src/quote.ts`. It has exactly four exports — audit all four:
  `QuoteInput`, `estimateTotalCents`, `splitInstallments`, `formatMoney`.
- The contract is the JSDoc above each symbol plus its TypeScript types.
  Where code and doc disagree, **the doc is the contract** and the code is wrong.
  Two clauses to audit against verbatim: `discountPercent` is documented as
  `0..100`, and `splitInstallments` is documented to return `parts` values whose
  sum is EXACTLY `totalCents`, differing by at most 1 cent.
- The module validates `parts` and nothing else: no export checks that an amount
  is an integer, is finite, or is inside its documented range.
- Existing coverage: `app/src/quote.test.ts` — 22 tests, green today
  (`cd app && npm test`; `cd app && npm run typecheck` also exists). Green is the
  baseline, so every finding is by definition something these tests fail to assert.
- Domain: amounts are integer cents; a split must sum to exactly the total;
  installments differ by at most 1 cent; no cent is invented or lost.
- `AGENTS.md` — project conventions and guardrails.

## Constraints (Обмеження)

- **Read-only.** Do not edit any file, do not write tests, do not create scratch
  files, do not fix anything. Trace the arithmetic by hand and show it.
- A standing audit, not a diff review: do not run `git diff` / `git log`, and never
  let "not changed recently" narrow the surface. Every export is in scope, always.
- Do not comment on formatting, naming or style — a linter owns those.
- Do not propose architecture changes or new abstractions.
- No finding without a concrete input that triggers it. "Could overflow" is not a
  finding; `splitInstallments(100.5, 3)` returning `[34, 34, 33]` — a sum of 101
  where the doc promises exactly 100.5 — is.
- If the module accepts an input without throwing, that input is in scope.
  "The caller should not pass that" is a defense only when the code actually
  rejects it.
- Severity is exactly one of: `MONEY` (a wrong amount can be billed, paid or
  refunded), `CRASH` (throws, or returns `NaN` / a malformed string where the doc
  promises a value), `DOC` (code and doc disagree, no wrong amount reachable).
- At most 7 findings, most expensive first. There is no minimum: zero findings is
  a valid result, and padding the list with remarks that contradict no documented
  clause is a failed audit, not a thorough one.

## Acceptance criteria

- [ ] All four exports appear in the Audited table, including the ones with no findings.
- [ ] Each finding has: `file:line` pointing at the current contents of
      `app/src/quote.ts`, the exact input, expected vs actual, and the business
      consequence in one clause (who loses money or trust).
- [ ] Each finding's input is a complete call expression with literal arguments,
      pasteable into a REPL as-is — not a variable, a range, or "a large value".
- [ ] Each finding states the value the code actually returns, verbatim, plus the
      one-line arithmetic that produces it.
- [ ] Each finding quotes the JSDoc sentence or type it contradicts. If no
      documented clause is contradicted, it is not reported as a finding.
- [ ] Each finding carries exactly one severity label — `MONEY`, `CRASH` or `DOC`.
- [ ] Each finding says whether `app/src/quote.test.ts` covers it, by quoting the
      `it(...)` title that covers it or writing "not covered".
- [ ] These classes are explicitly checked and reported even when clean: zero,
      negative, non-integer, `NaN`/`Infinity`, out-of-documented-range values,
      rounding remainders, mutation of the input.
- [ ] No file in the repo was modified — `git status --porcelain` shows the same
      output as before the audit.
- [ ] If there are no findings, the report says "No contract violations found."
      rather than inventing filler remarks.

## Response format (Формат відповіді)

1. **Audited** — one line per export: `symbol | verdict`.
2. **Findings** — most expensive first:
   `SEVERITY | file:line | input | expected | actual | contradicted doc text | consequence | covered by tests?`
3. **One-line verdict** — is this module safe to keep billing clients with?

## Stop (Stop)

Stop after the verdict. Do not fix, do not write tests, do not open files outside
the ones named in Context. Fixes and tests are separate requests with their own
prompts (`debug-failing-test.md`, `add-tests.md`).

---

## Run log (слід запуску)

**2026-09-14 — `app/src/quote.ts`, suite green at 22/22.** Executed by a
sub-agent that was given this artifact and nothing else — no hint that the
module had any known defect. Full trace: [`runs/review-module.md`](./runs/review-module.md).

- **Found:** 7 contract violations. 3 MONEY (`discountPercent: 150` → `-25000`;
  `discountPercent: -50` → a 50% surcharge; `splitInstallments(100.5, 3)` →
  sum 101 against a doc that promises the sum is *exactly* the total) and
  4 CRASH (`NaN`/non-integer reaching `formatMoney` as `"$NaN.NaN"`, `"$12.34.5"`).
- **Scope held:** read-only as instructed; `git status --porcelain` byte-identical
  before and after; verification done through `node -e`, no scratch files.
- **What the acceptance criteria actually bought:** the "quote the contradicted
  doc clause or it is not a finding" rule made the agent *discard* six plausible
  remarks (negative `hours`, `-0`, precision above `MAX_SAFE_INTEGER`) instead of
  padding the list to the 7-finding cap.
- **What had to be corrected:** its first REPL pass printed `NaN` arrays through
  `JSON.stringify` (which shows `null`); it re-ran raw and disclosed the fix
  itself rather than shipping the wrong value.
- **v1 history:** drafted by hand → improved by a meta-prompting sub-agent
  (added the severity scale, the "audit is not triggered by a diff" boundary
  against `review-pr.md`, and the doc-clause gate) → run unchanged, as above.
