# translate moves when the ENGINE gains a predicate, not only the bench file
Goal: attribute a +360 move on `translate` and +16 on `evaluate` that appeared
with a commit adding two predicates, so the rows can be re-pinned with evidence
rather than argued about.
Constraint: the allowance is four inferences, absolute. Attribution has to be a
positive control, not a reading of the diff.

## 2026-09-04
Already known, and I should have read it first. `engine/bench-baseline.json`
documents this sensitivity in the `measures` prose of `boot` and `evaluate`:
"appending ONE INERT FACT moves boot 612598 to 612740 and evaluate 4276161 to
4276145, ten facts move boot to 612896, and removing them moves both back, so
the process's predicate set is part of what boot costs and it is
non-monotonic" [measured 2026-08-28]. The 2026-09-01 `'subtract-atom'/3` pin
records the same shape reaching `translate`: "translate 376975 to 376615
(-360) ... translate's -360 is the same shape read the other way".

What the file did NOT record, and what this thread adds: the 2026-08-28 control
used `engine/bench.pl`, and under it "the other five cases do not move at all
under the same edits, byte for byte", `translate` included. That reads as
`translate` being insensitive. It is insensitive to the BENCH file's predicate
set and sensitive to the ENGINE's, which is a different statement and the one
that matters when the change under test is an engine change.

Measured, `sh tools/check.sh engine-bench`, three identical samples every run:

    dca33c9f, pristine                    translate 380634   evaluate 559327   = baseline
    9dc6355f, pristine (two predicates)   translate 380994   evaluate 559343   +360 / +16
    9dc6355f with those two deleted       translate 380634   evaluate 559327   back to baseline
    9dc6355f + ONE inert never-called
      fact appended to
      engine/metta/interop.pl, literally
      `plunit_inert_perturbation_probe_zzz(x).`
                                          translate 380994   evaluate 559343   +360 / +16

That is the positive control the file's practice asks for, both ways: removing
the predicates returns the rows to their pins and an unrelated inert fact
reproduces the move exactly. Non-monotonic as documented: folding the same two
predicates into one gave translate 381354, HIGHER than the two-predicate
380994. An added module EXPORT is a separate cost again; removing one took
`boot` from +9 to +3, inside its allowance.

The mechanism for `translate` is visible in the code that causes it.
`engine/filereader.pl`'s `existing_predicate_arities/2` asks
`current_predicate(N/Arity)` once per MeTTa function name a load registers, and
its own comment says why that is not free: "current_predicate/1 with the arity
unbound ENUMERATES the predicate table: asking about one name costs 17.4us
against this engine's 2,845 predicates".

Tried and rejected as explanations, each by measurement: a stale `.qlf` (the
set rebuilds on every run and a second run of an identical tree gives the
identical number); load from the ten concurrent agents (inference counts are
deterministic and every sample matched); the emitted goal's name (emitting an
already-registered name instead of a new one moved translate by 84); the
`seam:engine_emitted/1` registration (removing it left translate unchanged and
moved only `boot`).

Decided, for the change that found it: the metatype shape test goes inline in a
clause of a predicate that already exists rather than into a helper of its own,
so it adds no predicate and the rows do not move for it. That is recorded in
2026-09-04-metatype-argument-guards.md as a design constraint. It is also the
smaller change, so nothing was traded for it.

Also learned, the hard way: I told ten concurrent agents these rows "measure
inventory, not work" before reading the baseline file's own prose, which would
have led them to dismiss reds they are obliged to attribute. Corrected to all
ten within the hour. Read the row's `measures` field before concluding anything
about what the row does; it is written for exactly this moment.

Open: `existing_predicate_arities/2` is O(names x predicates) where a
name-indexed lookup is O(names), on the path of every source load. Fixing it
would speed up real loads and shrink this sensitivity at the same time. Handed
to the performance track rather than taken here.
