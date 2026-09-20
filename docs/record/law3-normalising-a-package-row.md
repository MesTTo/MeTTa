# Law 3: normalising a package row

approach, done, on i24.

## What this had to establish

A universal with two cases, and the whole difficulty was finding where the
cases divide. Every package row must be performed, and every row that is
COMPUTED must have its computation charged against law 3's `reads` ceiling and
its inference budget. Two earlier attempts put the division in the wrong place
and refused every shipped row; the third measurement said why neither could
have worked.

## Three attempts, and what separated them

**Charge the question.** Plan the effect of `(package requires)` and refuse if
it exceeds the ceiling. Refused every `requires` row, because planning a HEAD
walks every equation for it, so asking about `requires` drags in the backing
row's body.

**Charge the row.** Plan the effect of the payload. Refused every backing row,
because `(prolog F (heads))` reads as a call to a known operation and prices
`oracleIO`.

Both are recorded against a31.6. The third measurement shows the second could
never have worked whatever it charged:

    metta_host_goal_effect_plan(M, [prolog, "x.pl", [a_head]], O, E)
      E = oracleIO,  O = [['[|]', oracleIO]]
    metta_host_goal_effect_plan(M, [+, 1, 2], O, E)
      E = oracleIO,  O = [['[|]', oracleIO]]

That planner answers about a compiled Prolog BODY, so it prices any list
`oracleIO`, including `(+ 1 2)`. Its source-level sibling answers about MeTTa
source:

    metta_host_source_effect_plan(M, [prolog, "x.pl", [a_head]], O, E)
      E = pureStructural,  O = []
    metta_host_source_effect_plan(M, [+, 1, 2], O, E)
      E = pureStructural,  O = [[+, pureStructural]]

A literal row prices `pureStructural` with no operations at all, which is the
split the law describes: normalisation evaluates the question, and a row
written as a literal is already the answer.

## Where the division actually is

Law 4 keeps the registry that answers it. A claim is the equation
`(= (perform (<token> ...)) ...)` a seat, library or program adds to `&metta`,
so a token some claim answers is a row the loader performs as written. Anything
else is a term.

The claims are enumerated and the token tested rather than matched with
`[Token|_]` in the pattern: measured 2026-09-20, the partial pattern answered
nothing through the space's index while the full shape `(= (perform $pattern) $_)`
answered `[prolog,_,_]`. There are as many claims as attached seats, so
enumerating them is the small side of the join.

## The ceiling is not a rank

Law 3 allows "space reads and runtime facts" and excludes the filesystem and
host calls. The engine's lattice does not divide there:

| term | class |
|---|---|
| a literal row | `pureStructural` |
| `(match &self a a)` | `writesState` |
| `(add-atom &self a)` | `writesState` |
| `(get-property lib version)` | `oracleIO` |
| `(py-call m f)` | `oracleIO`, through the seat's `seam:extension_builtin/2` |

Law 2 makes `get-property` the way a package reads the runtime facts law 3
allows, and the engine classifies it `oracleIO`. So a ceiling at any single
rank either refuses the one read the design provides or admits the filesystem.
It is written the way the law writes it: the classes below `oracleIO`, plus the
operations named as reads of the runtime.

The refusal names the OPERATIONS rather than the class, because "it reads too
much" says nothing a writer can act on where `exists_file` names the line to
move.

## The budget

`package-budget`, defaulting to law 3's 1,000,000. It is not `max-inferences`:
that bounds a runnable the program wrote, and this bounds the loader
normalising a row while the file is still being read, where no runnable is in
flight. `pragma!`'s registry is closed, so the key had to be added to it.

The engine's bound raises `metta_control_signal(inference_limit, N)`, which
names the limit and not which budget, so the refusal renames it.

## Two silent paths, found by reading it back

`metta_package_refuse_above_ceiling/2` opened with a bare conjunction of goals
that can each fail, and either would have failed the predicate, the forall, and
the whole load with no message. A row nothing could plan is refused now.

`metta_package_reduce/4` had the same shape around `eval`. A term with no
answer is a row that did not reduce, which law 3 calls a row nobody claims; the
written term passes through and the perform leaves it unreduced, which is what
happened before normalisation existed. Refusing it by name waits on law 6,
which decides when an unclaimed backing is SKIPPED because its heads are
covered rather than refused.

The first version of the culprit branch also passed while checking nothing: it
ended in a `; true` arm and the branch above it failed on `pairs_keys/2`
reading `[Name, Class]` lists as pairs, so every row was allowed. The arm is
gone.

## The cases

| case | what it asserts |
|---|---|
| `a_computed_row_normalises_and_then_performs` | a payload no claim answers reduces and the artifact loads |
| `a_row_reaching_the_filesystem_refuses_by_name` | the refusal names `exists_file` |
| `a_row_reading_the_runtime_is_allowed` | `get-property` is admitted, which a bare rank would refuse |
| `a_row_that_will_not_reduce_refuses_past_its_budget` | the file's own `!(pragma! package-budget 2000)` bounds it |
| `a_row_that_answers_nothing_leaves_the_load_standing` | no silent failure |

Twenty-one cases in the suite, 0 failures, in a verified battery snapshot.
