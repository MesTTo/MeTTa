# The lambda that took no parameters
Goal: settle the backlog row saying an anonymous lambda cannot be applied where
it is written.
Constraint: `|->` backs `map-atom`, `filter-atom` and `foldl-atom`, so the hot
path stays untouched.

## 2026-09-05

Tried: the row's own program, `!((|-> $x (+ $x 1)) 5)` -> `Domain error:
function_input_arities(lambda_2,[0])' expected, found `1'`. Reproduced.

Rejected: the row's headline, "an anonymous lambda cannot be invoked where it is
written". It can. `!((|-> ($x) (+ $x 1)) 5)` answers 6, `!((|-> ($x $y) (+ $x
$y)) 5 6)` answers 11 and `!((|-> () 7))` answers 7. The row's program writes a
BARE `$x` where the parameter list goes, and that is the whole difference.

Tried: `((|-> $x $x))`, applied to nothing -> `()`. That is the mechanism: the
parameter position is an unbound variable, `append(FreeVars, Args, FullArgs)`
leaves `FullArgs` unbound, and `length/2` on an unbound list is generative, so
it binds it to `[]` and answers 0. The lambda is compiled taking no parameters
with `$x` bound to the empty list, and a wrong answer is returned rather than a
refusal.

Tried: the other malformed spellings. `(|-> foo ..)` and `(|-> 5 ..)` already
answer themselves, because the clause fails and `reduce/3` keeps the term. The
variable was the ONE shape that compiled instead of falling through.

Decided: `is_list(Args)` at the head of the `|->` clause. It is the guard
`lambda_pair_patterns/2` already uses, with the reason stated there: reject a
malformed binding row so its variables stay captured. A list MEMBER that is not
a variable stays a pattern the application must match, so `((|-> (foo) 1) 5)` is
Empty and is not touched.

Decided: the same guard on `lambda_binder_form(['|->', Parameters, _], _)`, and
it is observable rather than tidiness. `(|-> ($a) (pair $a (|-> $b (q $b))))`
compiled to `lambda_2` with NO captures, because the malformed inner form was
read as a binder for `$b` while no inner lambda existed to bind it; it is
`partial(lambda_2,[_])` now [measured 2026-09-05 by removing the guard].

Arbiter: LeaTTa's `tests/regression/lambda.metta` says the parameters are a
"parenthesized tuple, following PeTTa's shipped `|->` surface", and all six
lambda-using examples here write the list. Nothing in the tree writes a bare
variable there.

Open: the row's POINT survives its headline. A malformed lambda answering the
term rather than naming the mistake is the engine's ordinary NotReducible
outcome, and consistent with `(|-> foo ..)`, but a named refusal would say more.
That is a product call about every malformed special form, not about `|->`.

Evidence: 288 plunit units pass and 2,993 Python tests pass with the guards in.
Both were proven to discriminate by removal: four of the new unit's assertions
fail without them while every well-formed control still passes.

The duplicate-declaration warning found while running the translator suite for
this change is its own thread, `2026-09-05-the-warning-nobody-could-read.md`.
