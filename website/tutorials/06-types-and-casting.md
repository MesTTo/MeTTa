<!--
Purpose: explain MeTTa declarations, annotation-derived arrows,
effect-classified operations, transparent aliases, cardinality auditing, and checked casts.
Guarantees: operation examples use the canonical Space.op decorator with
required EffectClass metadata.
[tested: npm run docs:build and
test_every_effect_rank_registers_and_reflects;
commit=3cfbe0d7417b1c453c2dc12d47e2e47e7de461f7]
-->

# 06. Types and casting

Types are optional atoms. A declaration such as `(: Ann Person)` gives a
value a type. A function declaration such as `(: age (-> Person Number))`
says that `age` accepts a `Person` and answers a `Number`.

![Value and function type declarations beside a get-type
query](/visuals/06-types-and-casting.svg)

Python annotations can create function declarations at registration time:

```python
def test_annotations_declare_types(metta):
    from metta.vocabularies import EffectClass

    name = unique("typed")

    @metta.op(name=name, effect=EffectClass.pureStructural)
    def typed_op(x: int) -> int:
        return x

    assert metta.run(f"!(get-type ({name} 1))") == [[S.Number]]
```

`get-type` asks what type the current space can derive. The arrow's final
atom is the result type; preceding atoms are input types. A typed call that
refuses an argument can disappear as an empty branch during nondeterministic
evaluation.

A function's type has to be an arrow, and a source that gets this wrong is
refused rather than accepted quietly. `(: inc Number)` beside `(= (inc $x) (+ $x 1))` types the symbol `inc`, not a call to it. So every `(inc ...)`
compiles with no check, and a wrong argument surfaces wherever it finally
breaks, deep inside `+` rather than at `inc` itself. Writing `(: inc (-> Number Number))` is what puts the check on the call. The engine refuses the
first form when it loads the source:

```
(: inc Number) is not an arrow, so it types the symbol inc and not a call to
it: every (inc ...) compiles with no check at all, and a wrong argument
surfaces wherever it finally breaks instead of here. Write (: inc (-> ...)),
or (: inc %Undefined%) to say inc is deliberately untyped.
```

Three things pass. A name may carry several declarations, MeTTa's ad-hoc
polymorphism, and one arrow among them is enough. `%Undefined%` says the
function is deliberately untyped. And a declaration for a name nothing
defines is data, not a defect, which is what lets `(: nars-belief (--> Cat Animal))` mean inheritance rather than a mistyped arrow.

Name a reusable type expression with `Alias`:

```metta
(: Count (Alias Number))
(: Row (Alias (Count String)))
(: Identity (Alias (-> Row Row)))
(: row-id Identity)
(= (row-id $row) $row)
!(row-id (7 "seven")) ; (7 "seven")
!(get-type row-id)     ; (-> (Number String) (Number String))
```

An alias substitutes its right-hand side wherever a type is expected. `Count`
accepts numbers and rejects strings. A positional `Row` checks each field.
An alias of `Atom` also keeps arguments unevaluated and marks its result as
final, just as writing `Atom` directly does. Aliases name complete type
expressions; they do not introduce a new distinct type or take type arguments.

A local alias shadows an inherited declaration. Names inside an inherited
alias keep their meaning in the space where that alias was declared. Declare
an alias before the function annotation that uses it. Repeated variables in
one alias expansion remain related; separate occurrences receive fresh
variables.

Adding or removing an alias updates already compiled callers. Repeating the
same definition is harmless. A different definition for the same alias in the
same space raises a conflict; remove the old declaration before replacing it.
Direct and indirect cycles raise an error with the expansion path. Failed
transactions restore the previous declarations and compiled behavior.
Compound changes still need the [caller lock described in the thread guide](../guide/threads.md#state-cells-and-compound-updates);
a transaction does not substitute for that lock.

`get-type` reports expanded types, while matching stored `(: ...)` atoms and
exporting source retain the written alias. A type error retains that spelling
and adds `TypeExpansion` when substitution changed the declaration.

You can put a cardinality and an effect class in a function arrow:

```metta
(: w (-[det,writesState]-> Number Number))
(= (w $x) $x)
```

The written type stays visible through `get-type`. Its effect publishes
`(effect w writesState)` in `&metta`, so `space.effect_plan(S.w(1))` reports
`writesState`. A world covering only `pureStructural` refuses the call, even
though this example's body is an identity.
Removing the declaration removes its owned effect row. Effects join by name
across the catalog, including declarations in other spaces; one declaration
cannot weaken another or the effects found in a body.
Removing an owned effect row directly is refused. Clearing `&metta` is also
refused while declarations in other spaces still own effect rows there;
remove those declarations first.

`nondet` joins its class with `nondeterministicReadOnly`. For example,
`(-[nondet,pureStructural]-> Number Number)` has that joined class. Omitting
the class, as in `(-[det]-> Number Number)`, uses `oracleIO`.

An effect annotation reaches effect planning and world admission. It does not
reach `lib_memo`: a written `!(memoize w)` is honoured over an annotated body,
and an annotation added afterwards lands beside the live cache rather than
withdrawing it. Whether a cache belongs on a function is the program's own
decision.

Cardinality is an author assertion. By default it is trusted and does not
prune answers. Enable auditing when you want execution to check it:

```metta
(: two (-[det]-> Number Number))
(= (two $x) $x)
(= (two $x) (+ $x 1))
!(pragma! verify-cardinality true)
!(two 1) ; raises: annotated call succeeded with a choicepoint
```

The check follows [SWI's `det/1` rule](https://www.swi-prolog.org/pldoc/man?predicate=det/1):
`det` must succeed without a choicepoint; `semidet` may fail but must leave no
choicepoint on success. `nondet` permits any number of answers. A choicepoint
raises before another equation runs, including when the alternatives would
produce equal answers or eventually fail. The body is executed once, so
auditing does not replay its effects. An `Empty` result is not an answer.
A call with an already constrained output checks only the upper bound,
because that constraint can legitimately remove the result.

The mode is optional because this operational check is stricter than counting
completed answers and adds work to annotated calls. It observes each executed
call; it does not prove unexecuted branches. Use
`!(pragma! verify-cardinality none)` to disable it, or scope it with
`with-pragma!`. Plain `->` calls retain their ordinary compiled goals in either
mode.

A foreign space must declare transactional writes before storing an annotated
arrow. An undeclared or `best-effort` provider is refused because a partial
write could separate the type from its catalog effect. Plain arrows retain
their existing storage behavior.

An annotation must name an ordinary function and use a concrete product.
Product variables such as `-[$effect]->`, annotations nested in parameter or
result types, and annotations on translated special forms or translator rules
are refused at load with the unsupported claim named. Put a contract on an
ordinary wrapper when a translated form needs one. An annotated function can
still be passed to an ordinary higher-order parameter such as
`(-> (-> Number Number) Number Number)`.

At a Python boundary, use `m.cast` when refusal must raise instead:

```python
def test_declared_symbols_cast_by_their_declarations(m):
    m.run("(: Ann Person)")
    assert m.cast(S.Ann, "Person") is S.Ann
    with pytest.raises(CastError) as caught:
        m.cast(S.Ann, "Robot")
    assert "Person" in str(caught.value)
```

Aliases work through the same Python cast door: after
`m.run("(: Count (Alias Number))")`, `m.cast(7, "Count")` returns `7` and
`m.cast("seven", "Count")` raises `CastError`. Casting requires a type witness:
an unknown symbol cannot establish `Count`. Ordinary typed calls and MeTTa's
`type-cast` retain their gradual acceptance of an unknown actual type.

The successful cast returns the same symbol. The failed cast names the type
the space knows. Declarations are space-relative, so another space can carry
a different type environment.

See [`metta.convert`](../reference/metta-convert) for structural targets,
protocol types, and Python type spellings. Next, inspect execution and
support in [07. Seeing your program](./07-seeing-your-program).
