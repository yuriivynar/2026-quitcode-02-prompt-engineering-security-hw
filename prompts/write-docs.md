---
name: write-docs
purpose: Document a module's public API for the developer who has to use it, from the code itself — every example output verified by a real run, no invented behaviour.
tested-on: `app/src/quote.ts` → `app/README.md` — run 2026-09-14: 10 examples, each executed and re-run from the finished file; docs updated by hand after the defect fixes; trace in `runs/write-docs.md`
version: 1
---

# Document a module's public API

> **Reuse:** swap the target `app/src/quote.ts`, the output path `app/README.md`
> and the one-liner in Context. Everything else is generic.

## Role (Роль)

Engineer writing docs for the next developer who has to call this code at 2am.
You document what the code *does*, never what you assume it should do, and never
write down a value you have not watched a program print.

## Goal (Мета)

Write `app/README.md` documenting the four exported symbols of `app/src/quote.ts`
— `QuoteInput`, `estimateTotalCents`, `splitInstallments`, `formatMoney` — so a
developer can call them correctly without opening the source.

## Context (Контекст)

- Source of truth: `app/src/quote.ts`. Signatures are copied from it verbatim;
  every statement must be traceable to a line there or to a passing test.
- Verified examples: `app/src/quote.test.ts` (22 passing cases today). Its
  `it(...)` names are Ukrainian — quote them verbatim, never translate them.
- For a value no test asserts, run it. This works from `app/` (Node 22 also
  needs `--experimental-strip-types`):
  `node --input-type=module -e "import { formatMoney } from './src/quote.ts'; console.log(formatMoney(5));"`
- Commands in `app/package.json`: `cd app && npm test`, `cd app && npm run typecheck`.
- Nothing typechecks README snippets (`app/tsconfig.json` covers only `src`) and
  `app/package.json` has no `main`/`exports`: use only import paths you executed.
- `splitInstallments` is the only function that throws (`RangeError`, when
  `parts` is not a positive integer). Nothing else validates its input.
- Audience: a TypeScript developer who knows the language but not this domain.
  They need to know that amounts are integer cents *before* they pass dollars.
- `AGENTS.md` allows Ukrainian or English docs; this prompt fixes English for
  `app/README.md`, with quoted test names left in Ukrainian.

## Constraints (Обмеження)

- **Only `app/README.md` is created** — it does not exist yet: create, never
  append. No other file is written, moved or deleted: no scratch script, no fix.
- Document only exported symbols. Private helpers are not part of the contract.
- Every expected output comes from exactly one of two sources: an assertion in
  `app/src/quote.test.ts`, cited by its `it(...)` name, or a command you ran and
  whose exact output you paste into the Verification log. There is no third
  source. An example you cannot verify is deleted, not approximated.
- No hedged values: no `≈`, no "about", no "roughly", no `...`, no "may vary".
- Do not invent behaviour: no "throws on invalid input" where no `throw` exists,
  no invented parameters, no performance claims, no roadmap, no "coming soon".
- Where behaviour is undefined (non-integer amounts, out-of-range discount,
  `NaN`/`Infinity`), say it is **undefined/unguarded** — do not paper over it
  and do not present it as a feature.
- No marketing tone, no emoji, no "simply", no "just".

## Acceptance criteria

- [ ] Each of `QuoteInput`, `estimateTotalCents`, `splitInstallments`,
      `formatMoney` has its own section, and no section documents a symbol that
      `app/src/quote.ts` does not export.
- [ ] Every signature in the README is character-for-character identical to the
      one in `app/src/quote.ts`, including optional markers and return types.
- [ ] Each function section states signature, return value, units, and at least
      one runnable example with its exact expected output.
- [ ] Every README example has a Verification log entry and every log entry has
      an example, and the two outputs match character for character.
- [ ] `cd app && npm test` was actually run in this session and its real file
      and test counts are reported.
- [ ] Every import line used in an example is one that was actually executed.
- [ ] The integer-cents rule is stated once, above the first example.
- [ ] A "Known gaps" section marks as undefined/unguarded at least these four:
      `discountPercent` outside 0..100, non-integer `totalCents` in
      `splitInstallments`, non-integer cents in `formatMoney`, `NaN`/`Infinity`.
- [ ] The `RangeError` of `splitInstallments` is documented with its trigger,
      and no other function is described as validating or throwing.
- [ ] The README is in English apart from test names quoted verbatim.
- [ ] `git status --porcelain` after the run shows `?? app/README.md` and no
      entry that was not already present before the run.

## Response format (Формат відповіді)

1. The full `app/README.md` content.
2. **Verification log** — one line per example:
   `example → it("…")` or `example → command + the exact output it printed`.
3. **Traceability list** — for every claim that is not an example:
   `claim → quote.ts:line or test name`.
4. Anything you refused to document because the code does not define it.

## Stop (Stop)

Stop when the file is written and every example is verified. Do not fix the code
or the gaps you found, do not add tests, do not document other modules. Document
ambiguity instead of resolving it by guessing; drop any example that resists
verification and say which one.

---

## Run log (слід запуску)

**2026-09-14 — `app/src/quote.ts` → `app/README.md`.** Full trace: [`runs/write-docs.md`](./runs/write-docs.md).

- **Produced:** `app/README.md`, the only file written; 4 symbol sections; 10
  examples, each executed and then re-run by extracting it from the finished file;
  signatures checked with `grep -cxF`; quoted test names diffed against the suite.
- **Refused:** to print outputs for undefined inputs, listing them as unguarded
  instead — correct at the time of the run.
- **What had to be corrected:** the module was fixed minutes after the run, so three
  "no validation" statements went stale. They were updated by hand to cite the new
  passing tests. Lesson: run this prompt *after* behaviour changes land.
- **v1 history:** drafted by hand → improved by a meta-prompting sub-agent (the
  two-sources rule, the verification log, banned hedges, and a replacement for a
  `git diff --name-only` criterion that could never see a new untracked file) → run.
