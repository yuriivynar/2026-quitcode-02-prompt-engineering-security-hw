# Run log — `write-docs.md`

- **Date:** 2026-09-14
- **Prompt:** [`../write-docs.md`](../write-docs.md) v1
- **Target:** `app/src/quote.ts` → creates `app/README.md`
- **Runner:** Claude Code sub-agent given only the artifact.

## Result of the run

- Created `app/README.md`, the only file it wrote. One section per exported symbol
  (`QuoteInput`, `estimateTotalCents`, `splitInstallments`, `formatMoney`), the
  integer-cents rule stated before the first example, and a "Known gaps" section
  listing four unguarded input classes instead of hiding them.
- **10 examples, 10 verification-log entries**, each a `node` command executed from
  `app/` with its exact output. The agent then extracted every command from the
  *finished* file and re-ran it; all 10 matched character for character.
- Signatures checked mechanically: each of the 7 signature and field lines appears
  exactly once in both `quote.ts` and the README (`grep -cxF`).
- All 9 quoted `it("…")` names diffed against `quote.test.ts`: zero differences.
- **Refused to document** concrete outputs of undefined inputs (a `150`% discount,
  fractional totals, `NaN`), because printing them would present an accident of
  the arithmetic as a contract.
- Honesty under a messy tree: it reported that `prompts/runs/` appeared during its
  run and was not its own, and disclosed two throwaway files it wrote *outside* the
  repo and then deleted.

## What had to be corrected afterwards

The run documented the code as it was at that moment, and was right about it.
Minutes later the defects found by `review-module.md` and `debug-failing-test.md`
were fixed, which made three statements stale: "Throws — nothing" for
`estimateTotalCents` and `formatMoney`, "`totalCents` is not validated", and the
whole Known gaps section.

The operator updated those statements by hand under the prompt's own rules: every
new claim cites a passing test (`33 passed (33)`), Known gaps became an **Input
validation** table, and a script re-checked that every `it("…")` name quoted in the
README exists verbatim in the suite. The 10 original examples use only valid
inputs, so the fixes do not change their outputs; they were not re-executed after
the change.

**Lesson recorded:** generated docs are a snapshot. Run the docs prompt *after*
behaviour changes land, not in parallel with them.
