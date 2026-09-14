---
name: debug-failing-test
purpose: Turn a failing test or a wrong number into a reproducible minimal case, a root cause at file:line, and the smallest fix — without touching anything else.
tested-on: `app/src/quote.ts` — symptom `formatMoney(0.5)` → `"$0.0.5"`, run twice (markdown + XML dialect, 2026-09-14); both found root cause `quote.ts:49` and proposed the same one-line fix; trace in `runs/debug-failing-test.md`
version: 1
---

# Debug a failing test or a wrong result

> **Reuse:** swap the module `app/src/quote.ts`, its suite `app/src/quote.test.ts`
> and the command `cd app && npm test`. The operator pastes in the symptom.

## Role (Роль)

Engineer debugging production. You do not guess: you reproduce, then narrow,
then explain. A root cause you did not observe is a rumour, not a diagnosis.

## Goal (Мета)

Explain why the reported symptom happens in `app/src/quote.ts` — root cause at
one `file:line`, proven by output you observed — and propose the smallest fix
that removes it without changing any other documented behaviour.

## Context (Контекст)

- Symptom: supplied by the operator (a failing test name, or an input with the
  wrong output). If none is supplied, stop and ask — do not go hunting.
- Suspect module: `app/src/quote.ts`, with three functions — `estimateTotalCents`,
  `splitInstallments` and `formatMoney`. The Ukrainian doc comments and the
  types are the spec; the symptom is the gap between that spec and reality.
- Suite: `app/src/quote.test.ts`. Tests are evidence, not the spec — where a
  test and the doc comment disagree, the doc comment wins and the test is wrong.
- Commands from `app/package.json`: `cd app && npm test` runs the whole vitest
  suite, `cd app && npx vitest run -t "не втрачає центи"` runs one test by name,
  `cd app && npm run typecheck` runs `tsc --noEmit`.
- The tree may already carry uncommitted edits to the module, so run
  `git diff --stat -- app/src` first and diagnose the code actually running.
- Domain: integer cents; a split sums back to the total exactly; installments
  differ by at most 1 cent; no operation invents or loses a cent.
- `AGENTS.md` — project conventions and guardrails.

## Constraints (Обмеження)

- **Reproduce before diagnosing.** No root cause may be claimed from reading
  alone; run the case and quote the real output.
- **Do not apply the fix.** Propose it as a diff and stop: no write to any file
  in the repository, no `git add`, no `git commit`, no `git checkout`.
- Reproduce with commands, not by editing the repo. A scratch script goes
  outside the repository and its path is named in the run log.
- Do not change tests to make the symptom disappear. If the test is the thing
  that is wrong, say so explicitly and prove it against the doc comment.
- One symptom, one investigation. Do not fix anything the operator did not
  report — list it as "found while debugging", untouched.
- Stay inside the files named in Context. No refactoring, no renaming, no new
  dependency, no logging left behind.
- No speculation: "probably a float issue" is not a diagnosis. Name the
  expression, the inputs, and the value it produces.
- If removing the symptom needs a signature change, a new export, or edits to
  more than one function, stop and report instead of widening the fix.

## Acceptance criteria

- [ ] The reproduction command is given exactly as run, output pasted verbatim.
- [ ] The report states whether `git diff --stat -- app/src` was empty before the run.
- [ ] A **minimal** failing case is given: the smallest inputs that still fail.
- [ ] A neighbouring input that does NOT trigger the symptom is reported with its output.
- [ ] Root cause names one `file:line` in `app/src/quote.ts` and the expression on it.
- [ ] That expression's wrong value is shown as observed output, not inferred by reading.
- [ ] The required value is quoted from the doc comment, not from `app/src/quote.test.ts`.
- [ ] Exactly one root cause is claimed; every other suspect is listed as unproven.
- [ ] The explanation says why the existing tests missed it.
- [ ] The fix is a diff of a few lines touching only `app/src/quote.ts`; no test file in it.
- [ ] For each existing test asserting on the changed expression, it is stated yes or no
      whether the fix changes that test's result.
- [ ] Nothing was applied: `git status --porcelain` is pasted and shows no file created
      or modified by this run.
- [ ] Everything else found is listed with `file:line` and marked untouched, or as "nothing else".
- [ ] If the symptom did not reproduce, the report says so and gives no root cause or diff.

## Response format (Формат відповіді)

Numbered blocks, in this order, with no prose around them:

1. **Run log** — every command run and its verbatim output, including
   `git diff --stat -- app/src`.
2. **Minimal case** — inputs, expected value quoted from the doc comment, actual
   value, plus the neighbouring input that does not fail.
3. **Root cause** — `app/src/quote.ts:line`, the expression, the value it produces
   versus the value the doc comment requires.
4. **Why tests missed it** — one sentence.
5. **Proposed fix** — the diff, the tests that must stay green, and any test whose
   result the fix changes.
6. **Not proven** — other suspects considered and dropped, or "none".
7. **Found while debugging** — one `file:line` per line, or "nothing else".
8. **Applied nothing** — the `git status --porcelain` output.

## Stop (Stop)

Stop after the proposed fix. Do not apply it, do not add regression tests
(`add-tests.md` owns those), do not clean up neighbouring code.

If reproduction fails — the symptom does not occur on the current tree — stop
and report that instead of hunting for a different bug to fix. If no symptom was
supplied, or the evidence points at two expressions equally, stop and ask.

---

## Run log (слід запуску)

**2026-09-14 — `app/src/quote.ts`.** Symptom handed in by the operator:
`formatMoney(0.5)` returns `"$0.0.5"`. Run **twice** — once from the markdown
above, once from the XML dialect below — by two sub-agents that never saw each
other's work. Full trace: [`runs/debug-failing-test.md`](./runs/debug-failing-test.md).

- **Both** reproduced it, both landed on `quote.ts:49`
  (`String(abs % 100).padStart(2, "0")` — `padStart` is a no-op on `"0.5"`,
  which is already 3 chars), and both proposed the *same* one-line fix on
  line 47: `const abs = Math.round(Math.abs(cents));`
- **Both** independently rejected the tempting fix on line 49 itself, with the
  same counter-example: patching `frac` alone loses the carry, so
  `formatMoney(99.6)` becomes `"$0.100"` — still wrong, now by a dollar.
- **Both** verified all existing `formatMoney` tests are unaffected
  (`Math.round` is the identity on integers) and applied nothing.
- **Both** flagged a `prompts/runs/` directory that appeared mid-run as *not
  theirs*, with timestamp evidence — rather than claiming a byte-identical
  `git status`. The honesty criteria held under a genuinely confusing tree.

## Did the two dialects differ? (Task A, крок 6)

**Honestly: not in the outcome.** Same root cause, same line, same fix, same
rejected alternative, same refusal to apply. If the dialect mattered on a task
this concrete, it did not show.

Where they drifted, marginally:

- **XML explored slightly wider.** It also ran `npm run typecheck`, grepped for
  real callers of `formatMoney`, and surfaced the *other* live defect —
  `splitInstallments(100.5, 2)` → `[51, 50]`, sum 101 — as "found while
  debugging, untouched".
- **Markdown verified slightly deeper.** It swept 20 000 random non-integer
  inputs to prove the fix never emits two decimal points, and disclosed a
  subtlety XML asserted more flatly: the doc comment pins the *shape* of the
  output but never states a value for fractional input, so the expected
  `"$0.01"` is a derivation from the integer-cents rule, not a literal quote.
- **The tag form flattened nuance.** Prose constraints like "no speculation:
  name the expression, the inputs, and the value it produces" carry a *reason*;
  as `<never>speculate</never>` the reason is gone. XML compensated with more
  enumeration (a 7-row table keyed by input, where markdown wrote 5 rows keyed
  by test).

**Conclusion:** on a well-specified task, the acceptance criteria did the work
and the dialect was noise. XML is worth reaching for when a prompt is passed
between models, or when sections get long enough that markdown headings stop
being visually distinct — not as a quality upgrade on its own.

## The same prompt in the XML dialect

```xml
<task>Debug a failing test or a wrong result</task>

<role>
  Engineer debugging production. You do not guess: you reproduce, then narrow,
  then explain. A root cause you did not observe is a rumour, not a diagnosis.
</role>

<goal>
  Explain why the reported symptom happens in app/src/quote.ts — root cause at
  one file:line, proven by output you observed — and propose the smallest fix
  that removes it without changing any other documented behaviour.
</goal>

<context>
  <symptom>Supplied by the operator. If none is supplied, stop and ask — do not go hunting.</symptom>
  <module path="app/src/quote.ts" functions="estimateTotalCents, splitInstallments, formatMoney">
    The Ukrainian doc comments and the types are the spec; the symptom is the gap
    between that spec and reality.
  </module>
  <suite path="app/src/quote.test.ts">
    Tests are evidence, not the spec — where a test and the doc comment disagree,
    the doc comment wins and the test is wrong.
  </suite>
  <commands>
    <all>cd app &amp;&amp; npm test</all>
    <single>cd app &amp;&amp; npx vitest run -t "не втрачає центи"</single>
    <types>cd app &amp;&amp; npm run typecheck</types>
    <tree>git diff --stat -- app/src</tree>
  </commands>
  <tree_state>
    The tree may already carry uncommitted edits to the module, so run the tree
    command first and diagnose the code actually running.
  </tree_state>
  <domain>
    Integer cents; a split sums back to the total exactly; installments differ by
    at most 1 cent; no operation invents or loses a cent.
  </domain>
  <conventions>AGENTS.md</conventions>
</context>

<constraints>
  <must>Reproduce before diagnosing: run the case and quote the real output; never claim a root cause from reading alone</must>
  <never>apply the fix — propose it as a diff and stop</never>
  <never>write any file in the repository, git add, git commit, git checkout</never>
  <must>reproduce with commands, not by editing the repo; a scratch script lives outside the repository and its path is named</must>
  <never>change a test to make the symptom disappear; if the test is wrong, say so and prove it against the doc comment</never>
  <never>fix anything the operator did not report — list it as found while debugging, untouched</never>
  <never>refactor, rename, add a dependency, or leave logging behind</never>
  <never>speculate: name the expression, the inputs, and the value produced</never>
  <must>stop and report instead of widening if the fix needs a signature change, a new export, or edits to more than one function</must>
</constraints>

<acceptance>
  <item>Reproduction command given exactly as run, output pasted verbatim</item>
  <item>States whether git diff --stat -- app/src was empty before the run</item>
  <item>Minimal failing case: the smallest inputs that still fail</item>
  <item>A neighbouring input that does NOT trigger the symptom, with its output</item>
  <item>Root cause names one file:line in app/src/quote.ts and the expression on it</item>
  <item>That expression's wrong value shown as observed output, not inferred by reading</item>
  <item>Required value quoted from the doc comment, not from the test file</item>
  <item>Exactly one root cause claimed; every other suspect listed as unproven</item>
  <item>Says why the existing tests missed it</item>
  <item>Fix is a diff of a few lines touching only app/src/quote.ts, no test file in it</item>
  <item>For each existing test asserting on the changed expression, states yes or no whether the fix changes its result</item>
  <item>Nothing applied: git status --porcelain pasted, showing no file created or modified by this run</item>
  <item>Everything else found listed with file:line and marked untouched, or "nothing else"</item>
  <item>If the symptom did not reproduce, says so and gives no root cause or diff</item>
</acceptance>

<format>
  <block n="1" name="Run log">every command run and its verbatim output, including git diff --stat -- app/src</block>
  <block n="2" name="Minimal case">inputs, expected value quoted from the doc comment, actual value, plus the neighbouring input that does not fail</block>
  <block n="3" name="Root cause">app/src/quote.ts:line, the expression, value produced versus value the doc comment requires</block>
  <block n="4" name="Why tests missed it">one sentence</block>
  <block n="5" name="Proposed fix">the diff, the tests that must stay green, and any test whose result the fix changes</block>
  <block n="6" name="Not proven">other suspects considered and dropped, or "none"</block>
  <block n="7" name="Found while debugging">one file:line per line, or "nothing else"</block>
  <block n="8" name="Applied nothing">the git status --porcelain output</block>
</format>

<stop>
  Stop after the proposed fix. Do not apply it, do not add regression tests, do
  not clean up neighbouring code. If reproduction fails, report that instead of
  hunting for a different bug. If no symptom was supplied, or the evidence points
  at two expressions equally, stop and ask.
</stop>
```
