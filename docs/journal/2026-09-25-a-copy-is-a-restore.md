# A copy is a restore, and a specialization is its space's own
Goal: `Space.copy()` answers a space holding exactly its source's rows,
generated specializations included, whatever the source compiled before the
copy and whatever either space does after it.
Constraint: a specialization is stored content, derived when the function
whose call it serves compiles; a library's equations wait until something
calls them; a lambda's name used to come from a process-wide counter.

## 2026-09-25
Found by: extensions/python/tests/ch17_concurrency_and_the_loop/test_aio.py,
which copied the process home and failed in some orders. Three causes were
separable, and the first two are the module-scoped force (every force of a
waiting function names the module it is made from).

Tried: naming a `|->` lambda by its content, so that the copy's compile of zip
would name the same specialization its source stored and adopt it. This
settled the names and left six rows only in the copy
[measured 2026-09-25T02:18:49+10:00, one process per scenario]. `copy()` added
the source's rows through the one-atom door, which compiles each equation as it
arrives. The copy therefore compiled chunk, window and group-by, which the
source had never called, and stored their unfold specializations.

Tried: the loader's program door alone, in the shape a fast restore uses. The
copy was exact for the process home and for a named space, with no warning.
But each copied specialization stayed unowned until its function compiled in
the copy. A load has the same property, and it is how the adoption defect
below reproduces.

Decided: `metta_host_copy_rows/2` restores the rows as a program and then
compiles in the copy exactly the functions its source had compiled. A
specialization exists because its caller compiled, so reproducing the compile
state reproduces the derived rows, and the adoption at the copy gives each
copied specialization the owner that retires it when its function changes.
pg_dump restores a materialized view populated only if it was populated, which
is the same rule. The seat's `copy()` became one crossing.

Found while building it, each with a user-level test that failed first:
- `ho_specialization_failed/3` had no module in its key, so a failure in one
  space kept another space from specializing the same call. It is now
  `ho_specialization_failed/4`, and every space's failures still clear on any
  function change, since a child's plan reads its parents' definitions.
- Adoption trusted a name. Rows a load brought under a generated name were
  adopted after their function was redefined. They are now compared, as
  variant multisets, with the rows this call would derive, and a stale set is
  retired and derived again. `forget_symbol/2` withdraws the name's deferral
  too; without that, the retired name translated the fresh row a second time
  and answered twice.
- The derive door asserted a specialization through a module's import link
  into an ancestor holding the same name. Content names made that frequent;
  a function argument's name always could. It now applies the compiler's
  `metta_prepare_function_predicate/3` before asserting.

Rejected: keeping the one-atom door and teaching the specializer not to derive
during a copy. That is a special case for one door, and it would still leave
the copy's compile state different from its source's.
