# The warning nobody could read
Goal: `discharge_audit:an_audited_compile_wraps_the_intrinsic_discharge` is red
at HEAD; make it green for the right reason.
Constraint: the same term leaves the engine by two doors and both have to say
the same thing.

## 2026-09-05

Found while running the translator suite for the `|->` parameter guard
(`2026-09-05-the-lambda-that-took-no-parameters.md`). It reproduces at HEAD with
that change reverted, so it is not that change's doing. The failure is
`Unknown message: metta_duplicate_declaration(...)`.

Tried: the survey rather than the one term. Two terms reach `print_message/2`
bare across `engine/` and `lib/`, and `metta_duplicate_declaration` is the only
one without a `prolog:message//1` clause. It declares `prolog:error_message//1`,
which answers only the thrown `error(Formal, Context)` form, and
`metta_add_atom/3` keeps the first declaration and warns with the bare term, so
that route printed the term itself.

Decided: a `prolog:message//1` clause delegating to the error one, so the two
routes cannot drift into two texts.

Tried: the test again, still red, now reading `Generated unexpected warning or
error ... the declaration (: plunit-audit-n (-> Number Number)) is a duplicate
in &self`. So the rendering was one of two defects.
`audit_translation/2` declares `plunit-audit-n` into `&self`, both tests in the
unit call it, and plunit fails any test that emits an unexpected warning: the
second test was failing on the first's residue rather than on anything it
measures.

Decided: the helper withdraws what it declares. Equations first, because
removing the declaration announces the change to every call site and there is
no reason to recompile a body that is about to leave.

Open: the rendering fix is now untested by the test that found it, since that
test no longer provokes the warning. `catalog_self_description:both_doors_render
_a_duplicate_declaration` covers it directly, through `message_to_string/2`
rather than `phrase/2` on the clause. The defect was never that the text was
wrong; it was that SWI's dispatch never reached a clause for the bare form, and
only rendering through the door `print_message/2` uses can see that.

Evidence: 288 plunit units pass and 2,993 Python tests pass. The rendering was
proven to discriminate by removing the `message//1` clause: the bare-term case
fails and the wrapped-error case still passes, which is exactly the door that
was missing.
