# Run log — `debug-failing-test.md` (markdown vs XML, same symptom)

- **Date:** 2026-09-14
- **Prompt:** [`../debug-failing-test.md`](../debug-failing-test.md) v1, both dialects
- **Symptom handed in:** `formatMoney(0.5)` returns `"$0.0.5"`. A money formatter
  must never return a string with two decimal points.
- **Method:** two sub-agents, run separately, each given exactly one dialect and
  the identical symptom, neither told anything about the cause and neither aware
  of the other. The dialects were served from copies outside the repo so that
  neither agent could see the other version.
- **Baseline:** tree dirty (`quote.ts`, `quote.test.ts` uncommitted), suite 22/22 green.

## Result: identical diagnosis, identical fix

| | markdown | XML |
|---|---|---|
| Reproduced the symptom | yes | yes |
| Root cause | `quote.ts:49` | `quote.ts:49` |
| Expression blamed | `String(abs % 100).padStart(2, "0")` | same |
| Fix proposed | `quote.ts:47` → `Math.round(Math.abs(cents))` | same |
| Rejected the line-49-local fix | yes, `99.6` → `"$0.100"` | yes, `99.6` → `"$0.100"` |
| Existing tests affected | none (`Math.round` is identity on integers) | none |
| Applied anything | no | no |
| Flagged the concurrent `prompts/runs/` as not its own | yes | yes |

## Reproduction, verbatim

The two sub-agent sessions of 2026-09-14 were not transcribed, so the table above
is a summary of their reports and the commands below are **not** quoted from them.
The prompt requires verbatim evidence, so the reproduction was re-executed on
2026-09-15 against the same pre-fix source, `git show da25af6:app/src/quote.ts`,
copied into a sandbox outside the repo. Every block below is real output.

**1 — the symptom, on the original code:**

```
$ node repro.mjs
"$0.0.5"
"$0.99.6"
$ echo $?
0
```

(`formatMoney(0.5)` and `formatMoney(99.6)`, JSON-quoted so the stray `.` is
unambiguous. `repro.mjs` is two `console.log` lines importing `./src/quote.ts`;
the `--input-type=module -e` one-liner the original runs used is now blocked by
`.claude/settings.json`, which denies `Bash(node -e*)`.)

**2 — why the fix goes on the `abs` line, not the `frac` line.** Both candidates
applied to a copy of the original body:

```
$ node repro2.mjs
local(0.5)      = "$0.01"
normalised(0.5) = "$0.01"
local(99.6)      = "$0.100"
normalised(99.6) = "$1.00"
$ echo $?
0
```

The line-local candidate passes the reported symptom and still produces two
decimal points one input over. This is the datum both dialects reported, and it
reproduces exactly.

**3 — the tree before the diagnosis.** `git diff --stat -- app/src` was **not**
empty: the 2026-09-14 baseline note above records `quote.ts` and `quote.test.ts`
as uncommitted, which is why both agents were told to diagnose the working copy
rather than `HEAD`.

**4 — applied nothing.** Both runs stopped at a proposed diff. The sandbox used
for this re-verification is outside the repository, so it cannot appear in
`git status --porcelain`; on 2026-09-15 that command shows only the files edited
by the CodeRabbit follow-up, and no file created by a debugging run:

```
$ git diff --stat -- app/src
 app/src/quote.test.ts | 40 +++++++++++++++++++++++++++++++++++++++-
 app/src/quote.ts      | 30 ++++++++++++++++++++++++------
 2 files changed, 63 insertions(+), 7 deletions(-)
```

**What this run log cannot show.** The per-agent command logs the prompt asks for
are gone — they existed only in two sub-agent sessions that were not saved. The
evidence above proves the *findings* reproduce; it does not prove what either
agent typed. The fix for next time is procedural, and it is now the first line of
the lesson below: capture the transcript, not the conclusion.

**The mechanism both found:** for `cents = 0.5`, `abs % 100` is `0.5`, so
`String(...)` gives `"0.5"` — already 3 characters, so `padStart(2, "0")` pads
nothing and the fractional field arrives carrying its own decimal point. Line 50
then interpolates it after its own `.`, producing `"$0.0.5"`.

**Why the fix goes on line 47, not 49:** lines 48 and 49 both read `abs`, so
rounding inside `frac` alone loses the carry. Both runs demonstrated it:
`99.6` → `"$0.100"` (two points *and* wrong by a dollar) versus `"$1.00"` when
`abs` is normalised once.

## Where the two dialects actually diverged

- **XML went wider:** additionally ran `npm run typecheck`, grepped for real
  callers of `formatMoney` (found none outside the test file), and reported the
  *other* live defect — `splitInstallments(100.5, 2)` → `[51, 50]`, sum 101 —
  under "found while debugging, untouched".
- **Markdown went deeper:** swept 20 000 random non-integer inputs to show the
  fix never emits two decimal points, and disclosed a subtlety XML stated more
  flatly — the doc comment pins the output *shape* but never gives a value for
  fractional input, so the expected `"$0.01"` is derived from the module's
  integer-cents rule rather than quoted.
- **Neither** obeyed the "fix it while you're there" temptation; both stopped at
  a proposed diff, as the Stop rule requires.

## Honest conclusion for Task A step 6

The dialect made **no difference to the outcome**. The acceptance criteria did
the work. **The process lesson, learned the hard way:** this log recorded outcomes in a
yes/no table and threw away the transcripts, so the prompt's own "verbatim
output" criterion could not be met afterwards at any price. A run log is
evidence or it is nothing. Capture stdout as it happens.

The one structural observation worth keeping: prose constraints carry
their *reason* ("no speculation: name the expression, the inputs, and the value
it produces"), and collapsing that into `<never>speculate</never>` loses the
reason — XML compensated with more enumeration. Reach for XML when a prompt is
shared across models or when sections grow long enough that markdown headings
stop being visually distinct, not as a quality upgrade in itself.

## What the operator did with the result

The fix was **accepted and applied** (see `runs/add-tests.md` and the
`app/src/quote.ts` diff), together with regression coverage. Both agents were
right to refuse to apply it themselves — that decision belongs to a human.
