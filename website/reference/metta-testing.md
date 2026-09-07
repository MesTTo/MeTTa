# `metta.testing`

Source: `extensions/python/metta/testing.py`.

> Hypothesis strategies for property-testing code built on this
> library, the pandas.testing reading: the exact generators the library's own
> suite fuzzes itself with, exported, so user operations, translators and
> spaces get tested against atoms the engine actually reads back. The
> filters encode engine truths worth not rediscovering: which characters the
> tokeniser reads back whole, that true/false ARE the boolean atoms so their
> symbol spellings canonicalize, and that `_` is the anonymous variable,
> fresh at every occurrence.
>
> The conformance surfaces live here too, one layer per audience:
> check_space_provider and check_codec run in process against an author's own
> object, SpaceComplianceSuite and GatewayComplianceSuite are pytest classes
> that run the engine's own expectations against a provider or a URL.
> .
>   - check_twin compares encoded atoms, preserving integer, float, and boolean
>     grounded species
>   - minted-space conformance recognizes decoded Space handles in provider
>     answers
>   - numpy_scalars generates non-primitive scalar objects whose identity and
>     numeric dispatch survive an engine round trip
>   - from_pattern generates ground substitutions, preserving repeated named
>     variables while drawing anonymous occurrences independently
>   - the module names both compliance suites in __dir__ and carries the asked
>     name on a refusal, without resolving either import
>   - cases(head) draws every argument from the head's annotations through
>     Hypothesis's from_type, refinements included, runs the head over them and
>     reports an Error answer, a return value outside the declared refinement,
>     or an observed effect above the declared class, with the MeTTa call form
>     in the failing example
>   - laws(algebra, space) generates one property test per declared law row
>     under the ghostwriter's names, passing for the boolean semiring and
>     failing with the counterexample for a carrier that breaks a law
>
>   - assert_answers and assert_includes hand both bags to the engine's own two
>     assertion doors rather than computing a difference here, so the relation is
>     subtraction-atom's, the failure carries the same .missing and .excess, and
>     the report below the first line of the message is the engine's own text
>
>   - one answer handed over as itself is refused with the sequence spelling
>     shown, a str included
>   - SpaceMachine resolves behind PEP 562 like the two suites, so importing this
>     module for the strategies needs neither pytest nor hypothesis

The entries below reproduce the source signatures and docstrings.

## `names`

```python
def names():
```

> Symbol and variable names MeTTa's tokeniser reads back whole: no
> whitespace, parens or quotes, none of the characters that mean
> something else at the front, and never the boolean spellings (the
> engine holds its booleans as those very atoms, so True and true are
> one term there and a round trip canonicalizes) or the anonymous `_`
> (fresh at every occurrence by contract, so it never shares).

## `symbols`

```python
def symbols():
```

> Symbol atoms with engine-readable names.

## `variables`

```python
def variables():
```

> Variable atoms with engine-readable names.

## `numbers`

```python
def numbers():
```

> Numbers the engine's printer round-trips: integers within the
> tagged-integer range, floats without NaN (never compares equal) or
> infinity (prints as a symbol), both printer limits, not carried bugs.

## `numpy_scalars`

```python
def numpy_scalars():
```

> Generate NumPy integer and real scalar values.
>
> These retain identity while MeTTa accepts them as Number operands and
> dispatches through Python operators.
>
> NumPy is optional. Install ``pymetta[arrays,test]`` before requesting this
> strategy.

## `texts`

```python
def texts():
```

> Strings as the engine stores them; NUL is the one exclusion.

## `grounded`

```python
def grounded():
```

> Grounded atoms over numbers, booleans and strings.

## `atoms`

```python
def atoms(max_leaves: int = 8, *, ground: bool = False):
```

> Whole atoms: symbols, variables (unless ground=True), grounded
> values, and expressions recursively over all of them; max_leaves is
> hypothesis's own size knob for the recursion.
>
>     from hypothesis import given
>     from metta import testing
>
>     @given(testing.atoms())
>     def test_my_translator_round_trips(atom):
>         assert decode(encode(atom)) == atom

## `expressions`

```python
def expressions(max_leaves: int = 8, *, ground: bool = False):
```

> Non-empty expression-rooted atoms, the shape spaces store.

## `ground_atoms`

```python
def ground_atoms(max_leaves: int = 8):
```

> Atoms carrying no variables: what a store holds after matching.
> atoms(ground=True) under the name provider fuzzing reaches for.

## `patterns`

```python
def patterns(max_leaves: int = 8):
```

> Expression-rooted atoms guaranteed to carry at least one variable:
> the query side of match, built rather than filtered so hypothesis
> never discards an example.

## `from_pattern`

```python
def from_pattern(pattern, max_leaves: int = 8):
```

> Generate ground instances of ``pattern`` by consistent substitution.
>
> Repeated named variables share one draw. Each anonymous ``V._`` occurrence
> receives its own draw, matching the engine's non-binding anonymous law.

## `programs`

```python
def programs(*, census=None, depth: int = 3, facts=(1, 4), queries=(1, 3)):
```

> Generate MeTTa program text over the heads an arbiter is known to reduce.
>
> The strategy for differential testing against another engine. Every head it
> writes comes from a CENSUS: the call heads of a corpus that engine ships,
> each one run on that engine and recorded with what it did, so a generated
> program is inside the surface being compared rather than exercising the two
> implementations' error paths. The shipped census is upstream PeTTa's, taken
> from `tests/conformance/petta/examples` and written by
> `tests/conformance/petta_capture.py --census`.
>
>     from hypothesis import given
>     from metta import testing
>
>     @given(testing.programs())
>     def test_both_engines_agree(source):
>         assert run_here(source) == run_there(source)
>
> A program is one to four facts over fresh relation names, up to two
> equations over `$x`, and one to three `!` queries. Every equation body uses
> `$x`, which is the known weakness of generating well-typed terms freely:
> the generator that draws bodies at random writes functions ignoring their
> argument, and the comparison then says nothing about how the argument was
> reduced.
>
> `depth` bounds how deeply a call nests inside another. `facts` and
> `queries` are inclusive ranges. `census` takes a census dict for another
> arbiter; the default reads the one committed in this checkout and refuses
> with the command that writes it when there is none, which is the case in an
> installed wheel.

## `check_space_provider`

```python
def check_space_provider(provider, *, atoms_to_store=None, source='repeated') -> list[str]:
```

> Prove a SpaceProvider before its users find out. Answers the checks run.
>
> The platform ships the conformance suite for its own extension points,
> which is the CSI sanity suite's reading, and JDBC's, and pytest's own
> `pytester`. Without it a downstream library learns its provider is wrong
> from a bug report.
>
>     from metta import testing
>
>     def test_my_provider_conforms():
>         testing.check_space_provider(MyProvider(rows))
>
> Three things are checked, and the second is the one worth having.
>
> **Every declared capability is reachable.** `can_run` may say yes to an
> operation whose method is absent, which is a registration-time mistake
> that otherwise surfaces as an AttributeError inside an engine callback.
>
> **Match over-approximates rather than under-approximates.** The provider
> contract's central soundness claim is that a provider may yield more than
> the pattern asks for, because the engine keeps unification, and may never
> yield less.
> Every stored atom vouches for a whole pattern family, itself, each
> position opened to a variable, and repeated-variable folds, and the
> provider's answers for each are compared with a brute-force unification
> scan of `atoms()`. A provider that filters too eagerly, or that only
> handles ground patterns, or whose filter treats a repeated variable's
> occurrences independently, fails here rather than answering wrongly in
> production. An exact pushdown claim is held to the same family.
>
> **A refusal names itself.** An operation the provider declines raises with
> a sentence rather than failing, so a caller learns what to do instead.
>
> `source` names the provider's consumption discipline, matching its
> (source ...) declaration. A linear provider is one-shot, so every
> check that consumes more than once is skipped and said so; repeated
> and peek providers are enumerated twice and the two enumerations must
> agree, which is the promise those words make.
>
> Raises AssertionError on the first violation, naming the provider class,
> the operation and the atom.
>
> THE CHECK IS UNIVERSAL: a provider is any foreign substrate, not only a
> Python object, and every substrate implements the space-provider protocol.
> Handed a ``Space`` handle, this runs the engine's own checker
> (lib/lib_conformance/lib_conformance.pl's ``check-space-provider``), which holds the
> same laws (capability reachability, the match pattern family, the
> declared source discipline, the canary round trip, the pushdown claim)
> asked through that protocol, so a provider written in Prolog, C, or anything
> else is held to one contract. The object form stays the
> pre-registration half for Python authors; ``source=`` applies to it
> alone, because a registered space carries its declared ``(source ...)``
> class and the engine checker reads that instead of trusting a claim.

## `record_replay`

```python
def record_replay(provider):
```

> Wrap a provider so its answers append to a log, with the replayer.
>
> The CakeML-oracle shape for host-stateful contexts: an append-only
> log makes a nondeterministic context's run replayable, and the
> differential replays the log instead of demanding a determinism the
> world does not have. Returns (recording, replay) where `recording`
> stands in for the provider and `replay()` builds a provider serving
> the log verbatim.

## `check_replay`

```python
def check_replay(provider, patterns) -> list[str]:
```

> The ec_determ lane: for a fixed host state, evaluation is a
> function. Each pattern is matched live and recorded, then the log's
> replay must serve byte-identical answers, which is what makes a
> recorded session a differential oracle for a backend nobody can
> re-run.

## `check_minted_handles`

```python
def check_minted_handles(provider, registered=()) -> list[str]:
```

> The engine-minted-handles law: space identities are the engine's to
> mint, and a backend answers INTO spaces, never fabricates one.
>
> Every &-headed symbol in the provider's answers must be a space the
> engine registered; a fabricated one is the reference nobody can
> resolve, cheap to refuse now and expensive to chase after a program
> stores it. `registered` names the spaces this provider may mention.

## `check_twin`

```python
def check_twin(defined, cases) -> list[str]:
```

> Prove a definition and its Python twin answer the same. Answers the
> cases run.
>
> `@m.define` keeps the original Python reachable as `.py`, and
> `@m.define(prolog=...)` keeps it when the fast side is written in
> Prolog instead. Either way the pair is a differential oracle, and this
> runs it:
>
>     from metta import testing
>
>     def test_the_fast_one_still_agrees():
>         testing.check_twin(vec_dot, [((1, 2), (3, 4)), ((0,), (9,))])
>
> `cases` is an iterable of argument tuples. Drive it with hypothesis for
> a real sweep; `metta.testing` exports the strategies the library fuzzes
> itself with.
>
> A generator twin is compared answer by answer in order, since a
> generator compiles to nondeterminism and order is part of the answer. A
> twin that RAISES on a case requires the engine to answer nothing for
> it: a reference that has no answer and a fast side that invents one is
> the disagreement most worth catching.
>
> Raises AssertionError on the first case where they differ, naming the
> case and both answers.

## `assert_answers`

```python
def assert_answers(actual, expected, *, msg=None) -> None:
```

> Assert that two answer bags are equal, ignoring order.
>
> The Python face of MeTTa's `(assert-answers ...)`, which is the door
> `assertEqualToResult` reaches: multiplicity counts and order does not, so
> `(a a b)` is not `(a b b)` and `(1 2)` is `(2 1)`.
>
>     from metta import testing
>
>     def test_the_edges_are_what_the_program_stored():
>         testing.assert_answers(space.match(pattern).x, [S.b, S.c])
>
> Each side is `Rows`, `Answers`, or any sequence of atoms or of values
> `encode` accepts; a `Rows` compares row by row, each row the expression of
> its values, so project one column with `rows.x` to compare values.
>
> A false claim raises `AssertionFailure` carrying `.missing` and `.excess`,
> the two directed bag differences as tuples of atoms, and a message whose
> report reads exactly as the engine's own does for the same two bags. It is
> printed on stderr as well as raised, which is what every MeTTa assertion
> does and for the same reason: a ball any `except` can swallow says nothing
> when it is swallowed.
>
> pytest's assertion rewriting is not involved. This raises, so it reports
> the same way inside a `unittest` case, a plain script or a notebook.

## `assert_includes`

```python
def assert_includes(actual, expected, *, msg=None) -> None:
```

> Assert that every expected answer was produced, and allow more.
>
> The Python face of MeTTa's `(assert-includes-answers ...)`, which is the
> door `assertIncludes` reaches. The relation is containment, so an answer in
> excess of the expectation is LEGAL and the failure names only what was
> wanted and never came: `.missing` carries that bag and `.excess` is None,
> absence rather than an empty tuple, because a two-sided report of a
> one-sided verdict points the reader at something that is not broken.
>
> `assert_answers` is the two-sided relation. Everything else about the two
> is the same, arguments included.

## `Case`

```python
class Case:
```

> One generated call of a defined head, with its contract checks.
>
> ``call`` is the MeTTa form, ``(double 3)``; calling the case runs the head
> over the arguments and checks every declared contract, answering the
> encoded answers or raising AssertionError naming the call and what it
> violated.

### `Case.call`

```python
def call(self) -> Expression:
```

> The MeTTa form this case evaluates.

## `Cases`

```python
class Cases:
```

> The property test a defined head's declarations write.
>
> Built by ``cases``; see it for the three ways this object is used.

### `Cases.strategy`

```python
def strategy(self) -> dict[str, Any]:
```

> One Hypothesis strategy per parameter, in the head's own order.

## `cases`

```python
def cases(
    head: Defined,
    *,
    examples: int = 100,
    strategies: dict[str, Any] | None = None,
    seed: int | None = None,
) -> Cases:
```

> The property test a defined head's declarations already write.
>
> Every parameter's annotation becomes a Hypothesis strategy through
> ``from_type``, so ``Annotated[int, Gt(0)]`` draws positive integers, an
> atom class draws atoms, and a MeTTa type atom draws the values the space
> declares to inhabit it. Each generated call is run, and three contracts
> are checked: the head answers no ``(Error ...)``, every answer satisfies
> the return annotation's refinements, and a declared effect class at or
> below ``nondeterministicReadOnly`` neither writes into the space nor
> answers differently when the call is repeated. The failing example is
> Hypothesis's own shrunk one, printed with the MeTTa call form.
>
> Three shapes, deal.cases's:
>
>     from metta import testing
>
>     test_double = testing.cases(double)          # pytest collects it
>
>     @testing.cases(double)
>     def test_double_keeps_its_contract(case):
>         case()                                   # run it; inspect case.call
>
>     for case in testing.cases(double, examples=10):
>         print(case.call)
>
> ``strategies`` overrides the draw for named parameters, which is the door
> for a MeTTa type nothing inhabits or an Atom refinement only the engine
> can judge; ``examples`` is Hypothesis's max_examples; ``seed`` derandomises
> one run.

## `Laws`

```python
class Laws:
```

> The property tests a declared algebra's law rows write.
>
> Built by ``laws``; see it for the shapes. Iterating answers ``(law,
> test)`` pairs, one Hypothesis test per canonical law; calling runs them
> all; ``notes`` records the laws that had nothing to compare.

### `Laws.strategy`

```python
def strategy(self) -> Any:
```

> The carrier's values: the declared finite carrier, the declared type, or ``values``.

## `laws`

```python
def laws(
    algebra: Any,
    space: Any = None,
    *,
    laws: Iterable[str] | None = None,
    values: Any = None,
    examples: int = 100,
    seed: int | None = None,
) -> Laws:
```

> The property tests a declared algebra's law rows write.
>
> ``algebra`` is a ``DeclaredAlgebra`` (``metta.algebra.bool``, or what
> ``require`` answers) or its name in ``space``, which must be given
> because the operations are evaluated in it. Every law row the
> declaration names, or every law in ``laws``, becomes one Hypothesis test
> named by the ghostwriter vocabulary the ``AlgebraLaw`` rows spell:
> ``associative`` and ``commutative`` over each operation, ``identity`` for
> the two identities, ``distributes_over`` for extend over combine,
> ``idempotent`` for combine, ``roundtrip`` for every carrier value
> surviving projection through the engine and back, and ``equivalent`` for
> each operation agreeing with its host twin. A failure is the engine's own
> ``algebra_law_violation`` sentence with the shrunk counterexample.
>
>     from metta import algebra, testing
>
>     test_bool_laws = testing.laws(algebra.bool, m)   # pytest collects it
>     for law, test in testing.laws("mine", m, laws=("commutative",)):
>         test()
>
> Values come from the declared finite carrier, from the declared type
> (``Number`` draws integers, because floating-point addition is not
> associative), or from ``values``; a preset with no carrier row is tested
> over its two identities. A symbolic identity such as ``tropical``'s
> ``infinity`` is outside its operation's domain, which the engine's algebra
> scope short-circuits and this sweep does not; pass ``values`` and ``laws``
> that exclude it.
