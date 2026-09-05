# Two doors that already agreed
Goal: settle the backlog row asking that `why()` and `lint()` share their
unknown-head and arity analysis so the two diagnoses cannot drift.
Constraint: do not refactor two working analyses together on a guess.

## 2026-09-05

Tried: the same head through both doors, before and after defining it.

    (= (calls-it $x) (mystery-head $x))
    lint -> possibly-undefined-reference on mystery-head
    why  -> "nothing here is headed by mystery-head, and no function has that name"

    (= (mystery-head $x) ok)
    lint -> no finding
    why  -> "mystery-head is a function, so its answers come from evaluation"

They FLIP TOGETHER, in both directions. So the row's premise does not hold on
this tree: the diagnoses agree today, and a refactor to share the analysis would
be motion without a defect behind it.

A first probe seemed to show a disagreement and did not: it asked `why` about a
query pattern and `lint` about a rule body, which are different questions over
different inputs. `why` reads a pattern against the stored program; `lint` reads
the program. The comparison only means something when both are asked about the
SAME head.

Decided: pin the agreement rather than merge the implementations. What was
missing was never a shared analysis, it was a lane that fails if either door
learns about a head the other has not. Both directions are asserted, because a
check that only sees the undefined case passes trivially the moment a door stops
reporting anything at all.

The risk is real even though the behaviour is right. A head has meaning through
`fun/1` OR through the translator, and this repository has already paid for
asking that only one way: 723 false lint findings. Nothing pinned the two doors
to each other afterwards.

Proven to discriminate by renaming lint's `possibly-undefined-reference` kind:
the test fails naming both spellings, and passes on restore.

Evidence: 3,013 Python tests pass, against 3,012 before.
