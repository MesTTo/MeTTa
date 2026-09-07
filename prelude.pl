% Purpose: the engine's prelude vocabulary, Prolog-bodied. Every name here was
%   an equation in engine/prelude.metta, parsed and translated at every boot;
%   the equations are now the executable spec in tests/data/prelude-spec.metta
%   and each head below is the body the translator used to derive, written out
%   and compiled into engine/metta.qlf like every other engine predicate
%   [measured 2026-09-07: boot 272,323 -> 248,271 inferences, -8.83%, and the
%   nine heads that reached their answer through a minimal-MeTTa function frame
%   between 15.6 and 56.4 times cheaper per call, match-type-or 4,854.01 to
%   86.01 and match-types 5,401.01 to 156.01 among them; command=swipl -q -g
%   "metta_bench:bench_run(boot)" -t halt engine/bench.pl and 200 rounds per
%   case through eval/2 with the engine's own counter; fixture=warm .qlf,
%   engine C artifacts present, three identical samples per arm;
%   commit=WORKTREE].
% Assumes:
%   - engine/metta.pl loads this file with `use_module(prelude, [])`, importing
%     NOTHING, and metta_base_engine_subsystems/1 then bases this module on the
%     engine's, so every helper below (collapse_runtime/2, 'assert-answers'/5,
%     metta_match_atoms/2, ...) resolves upward while union/3 and
%     intersection/3 stay library(lists)' in the engine module.
%   - engine/metta/prelude.pl registers these names, their arities, their
%     declarations, their documents, their cost rows and the eight translator
%     rules. Nothing here registers anything: this file is the vocabulary's
%     BODIES and that file is its REGISTRY.
%   - the Atom masks the declarations carry are what make the parameters
%     arrive unevaluated, so a body that reads its argument as syntax
%     (assertEqualToResult's second, unquote's, if-equal's branches) depends on
%     engine/metta/prelude.pl's prelude_declaration/2 rows being installed
%     [tested: prelude:expected_set_is_not_evaluated; commit=WORKTREE].
% Guarantees:
%   - every head answers what its spec equation answers, over the whole
%     differential corpus, including nondeterministic arguments, empty answer
%     sets, alpha-equivalent atoms and errors inside arguments
%     [tested: tests/prolog/suites/evaluation/prelude_spec.plt,
%     prelude_spec:every_head_agrees_with_its_spec_equation; commit=WORKTREE].
%   - the eight derived forms answer the EXPANSION their spec equation writes,
%     so a registered translator rule rewrites the call site exactly as it did
%     when the expansion came from a compiled equation: apply_translator_rule_dl/7
%     obtains an expansion by CALLING the name, never by reading equations
%     [source: engine/translator/lowering.pl, apply_translator_rule_dl/7's
%     `HookCall =.. [HV|RuleArgs], call(RuleModule:HookCall)`;
%     tested: prelude_derived_forms; commit=WORKTREE].
% Fails when: a caller wants these names to be a program's own. They are
%   engine vocabulary and a space shadows any of them by defining it, which
%   is what this module being a TIER below the engine and above '&self' is
%   for: a definition compiles into the space's own module and wins there,
%   with no clause of this file to evict.
% Decides: union/3 and intersection/3 are library(lists) predicates in the
%   engine module. MeTTa's union and intersection are these, and a tier module
%   is how both keep their name: the engine module still resolves union/3 to
%   lists', every space resolves it to this file's, and no import list anywhere
%   has to be edited [tested: spaces_execution_modules:the_chain_is_engine_then_prelude_then_self_then_space;
%   commit=WORKTREE].
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

%The export list is the vocabulary and nothing else. A space reaches these
%through the module chain rather than through an import, so the list is what
%the layering contract holds this file to rather than what makes the names
%visible [source: engine/spaces/lifecycle.pl, metta_exec_module_base/2].
:- module(prelude,
          [ 'if-equal'/5,
            'if-equal2'/5,
            'noreduce-eq'/3,
            assertEqual/3,
            assertAlphaEqual/3,
            assertEqualToResult/3,
            assertAlphaEqualToResult/3,
            assertIncludes/3,
            assertEqualMsg/4,
            assertAlphaEqualMsg/4,
            assertEqualToResultMsg/4,
            assertAlphaEqualToResultMsg/4,
            'if-error'/4,
            throw/2,
            'return-on-error'/3,
            'for-each-in-atom'/3,
            atomically/2,
            unquote/2,
            interpret/4,
            'is-function'/2,
            'match-types'/5,
            'match-type-or'/4,
            'type-cast-holds'/4,
            'type-cast'/4,
            'and-then'/3,
            'or-else'/3,
            'trace!'/3,
            unique/2,
            'alpha-unique'/2,
            union/3,
            intersection/3,
            subtraction/3
          ]).

%%%% Equality and reduction %%%%

%(if-equal $a $b $then $else) compares by ALPHA-EQUIVALENCE, not ==: atoms
%equal up to a consistent variable renaming, which is what upstream's own
%if-equal does [source: hyperon-experimental lib/src/atom/mod.rs,
%atoms_are_equivalent]. All four parameters carry the Atom mask, so the two
%operands are compared as written and the selected branch leaves unevaluated;
%the %Undefined% result is what evaluates it at the call site.
'if-equal'(A, B, Then, Else, Out) :-
    '=alpha'(A, B, Verdict),
    (   Verdict == true
    ->  Out = Then
    ;   Out = Else
    ).

%if-equal under its second historical name. Spelled out rather than delegated
%so the two cost the same; the delegation cost one extra frame per call and
%this vocabulary is on the minimal-MeTTa instruction path.
'if-equal2'(A, B, Then, Else, Out) :-
    '=alpha'(A, B, Verdict),
    (   Verdict == true
    ->  Out = Then
    ;   Out = Else
    ).

%A structural comparison whose operands stay written.
'noreduce-eq'(A, B, Out) :-
    '=alpha'(A, B, Out).

%%%% The assert family %%%%
%
%Each of the eight collapses what it is given into an ANSWER SET first, so a
%nondeterministic side is compared set-wise rather than pairwise, and hands
%the VERDICT plus both bags to the reporting door. 'assert-answers'/5 and
%'assert-includes-answers'/5 answer `true` or raise, so the declared
%%Undefined% result never has a term left to re-enter evaluation: the
%masked-result branch the translator emitted for these bodies was dead on
%every path and is not written out [source: engine/metta/runtime.pl,
%'assert-answers'/5's first two clauses; commit=WORKTREE].
%
%The call each reports is the one the PROGRAM wrote, which is why the two
%bag-comparing Msg twins spell their bodies out instead of delegating: a
%delegated body would report the delegate's name and lose the message
%[tested: prelude:assertEqualMsg_failure_reports_its_message; commit=WORKTREE].

assertEqual(A, B, Out) :-
    collapse_runtime(A, Actual),
    collapse_runtime(B, Expected),
    '=='(Actual, Expected, Same),
    'assert-answers'(Same, [assertEqual, A, B], Actual, Expected, Out).

assertAlphaEqual(A, B, Out) :-
    collapse_runtime(A, Actual),
    collapse_runtime(B, Expected),
    '=alpha'(Actual, Expected, Same),
    assert(Same, Out).

%The ToResult forms do not evaluate their second argument: it is the set of
%expected results, written as a tuple. The verdict is the same MULTISET test
%the equation makes, two directed subtraction-atom differences that must both
%be empty, so `(a a b)` does not equal `(a b b)`.
assertEqualToResult(A, B, Out) :-
    collapse_runtime(A, Actual),
    'subtraction-atom'(B, Actual, Missed),
    'subtraction-atom'(Actual, B, Excessive),
    '=alpha'([Missed, Excessive], [[], []], Same),
    'assert-answers'(Same, [assertEqualToResult, A, B], Actual, B, Out).

assertAlphaEqualToResult(A, B, Out) :-
    collapse_runtime(A, Actual),
    '=alpha'(Actual, B, Same),
    assert(Same, Out).

%Containment: every expected result must appear among the results produced,
%so only one direction is subtracted and the ONE-SIDED door reports it. An
%answer in excess of the expectation is legal here, and naming one would give
%the reader a bag that is not a reason for the failure.
assertIncludes(A, B, Out) :-
    collapse_runtime(A, Actual),
    'subtraction-atom'(B, Actual, Diff),
    '=='(Diff, [], Empty),
    'assert-includes-answers'(Empty, [assertIncludes, A, B], Actual, B, Out).

assertEqualMsg(A, B, Message, Out) :-
    collapse_runtime(A, Actual),
    collapse_runtime(B, Expected),
    '=='(Actual, Expected, Same),
    'assert-answers'(Same, [assertEqualMsg, A, B, Message], Actual, Expected,
                     Out).

assertAlphaEqualMsg(A, B, _Message, Out) :-
    collapse_runtime(A, Actual),
    collapse_runtime(B, Expected),
    '=alpha'(Actual, Expected, Same),
    assert(Same, Out).

assertEqualToResultMsg(A, B, Message, Out) :-
    collapse_runtime(A, Actual),
    'subtraction-atom'(B, Actual, Missed),
    'subtraction-atom'(Actual, B, Excessive),
    '=alpha'([Missed, Excessive], [[], []], Same),
    'assert-answers'(Same, [assertEqualToResultMsg, A, B, Message], Actual, B,
                     Out).

%The alpha twins delegate, because their relation computes no bag difference
%and their report is the delegate's already.
assertAlphaEqualToResultMsg(A, B, _Message, Out) :-
    assertAlphaEqualToResult(A, B, Out).

%%%% Error handling %%%%

%(if-error $atom $then $else) selects $then when $atom is an (Error ...)
%expression. The spec equation reaches that verdict through a function frame
%and four minimal-MeTTa instructions, which is 3,800 inferences a call; the
%question it asks is whether the atom is an expression whose head is Error,
%and asking it directly costs 127 [measured 2026-09-07: 3800.01 against
%127.01 per call on `(if-error (Error a b) yes no)`, and 1578.01 against 81.01
%on `(if-error 42 yes no)`; command=200 rounds through eval/2 with the engine's
%own counter; fixture=warm .qlf; commit=WORKTREE].
%
%The metatype is asked FIRST and the decons only under its answer, which is
%the frame's own order and is what keeps the list pattern off a variable: an
%unbound operand answers Variable and leaves through the else branch without
%the pattern ever binding it.
'if-error'(Atom, Then, Else, Out) :-
    'get-metatype'(Atom, Meta),
    (   Meta == 'Expression',
        Atom = [Head|_],
        Head == 'Error'
    ->  Out = Then
    ;   Out = Else
    ).

%throw PRODUCES an error, the half of the error story a program could not
%reach: it could BUILD an (Error ...) atom and CATCH a host exception, but a
%built atom is data. A reason that is ALREADY an error atom is handed on
%unchanged rather than wrapped a second time, so `(throw (catch (/ 1 0)))`
%raises the host error the catch reified instead of burying it.
throw(Reason, Out) :-
    'if-error'(Reason, Reason, ['Error', [throw, Reason], Reason], Out).

%(return-on-error $atom $then) answers the frame marker `(return $atom)` when
%$atom is an error, `(return Empty)` when it is Empty, and $then otherwise.
%The two markers are what the spec's nested `(return (return ...))` leaves
%once the enclosing function frame consumes one level.
'return-on-error'(Atom, Then, Out) :-
    (   Atom == 'Empty'
    ->  Out = [return, 'Empty']
    ;   'if-error'(Atom, [return, Atom], Then, Out)
    ).

%%%% Evaluation control %%%%

%map-atom under its historical name. The mapped expression is a result the
%%Undefined% declaration re-enters evaluation for, so the masked-result door
%decides it exactly as the compiled equation did; the middle branch is the
%irreducible call handed back as data.
'for-each-in-atom'(Expression, Function, Out) :-
    'map-atom'(Expression, Function, Mapped),
    (   atomic(Mapped)
    ->  Out = Mapped
    ;   Mapped == ['map-atom', Expression, Function]
    ->  Out = Mapped
    ;   metta_masked_result(Mapped, Out)
    ).

%%%% Atomicity %%%%

%atomically runs its argument inside one transaction. It is sugar over
%(transaction ...) deliberately, so the two cannot drift: every guarantee
%here is metta_transaction/1's, answer preservation and whole-set
%commit-or-rollback included. They are still not the same operation.
%transaction is a SPECIAL FORM whose body is compiled into the call site, so
%the body has to be written there; atomically takes its body as an unreduced
%Atom and evaluates it, so the body may be a term the program computed.
atomically(Expression, Out) :-
    metta_transaction(( metta_eval_step(Expression, Produced),
                        metta_boundary_result(Expression, Produced, Out) )).

%%%% Quoting %%%%

%The operand is Atom, so the written `(quote X)` reaches the first head. That
%is load-bearing now that quote is an evaluation barrier rather than a value:
%an operand that evaluated would arrive with the wrapper already gone and
%`(unquote (quote (+ 1 2)))` would answer `(unquote (+ 1 2))` instead of 3
%[source: PeTTa@ae66fa8 lib/lib_he.metta:64-67].
%
%The cut is the spec equation's `(let $cut (cut) ...)`. The second clause is
%the inert fallback and relies on the barrier as well: `(quote (unquote $A))`
%answers `(unquote $A)` and stops, where a quote that built a value would
%send the same rule round again.
unquote([quote, Atom], Out) :-
    !,
    metta_eval_step(Atom, Produced),
    metta_boundary_result(Atom, Produced, Out).
unquote(Atom, [unquote, Atom]).

%The public evaluator entry, whose first operand is held and whose Atom
%result is already final. The spec equation wraps the native `metta`
%operation in a function frame so the Atom result rule does not return the
%`(metta ...)` call itself as inert data; a Prolog body returns the
%operation's own answer and has nothing to hold back.
interpret(Atom, Type, Space, Out) :-
    metta(Atom, Type, Space, Out).

%%%% Types %%%%

%An arrow type is variadic, so its first element decides. size-atom is asked
%before the decons for the empty expression, which is an Expression with no
%head at all.
'is-function'(Type, Out) :-
    'get-metatype'(Type, Meta),
    (   Meta == 'Expression'
    ->  'size-atom'(Type, Size),
        (   Size == 0
        ->  Out = false
        ;   'decons-atom'(Type, [Head|_]),
            (   metta_match_atoms(Head, '->')
            *-> Out = true
            ;   Out = false
            )
        )
    ;   Out = false
    ).

%match-types is UNIFICATION with wildcards, not equality: %Undefined% and
%Atom on either side match anything, and otherwise the two types unify,
%bindings and all. The soft cut is the `unify` instruction's own: every
%binding set the match offers is one answer, and the else branch runs exactly
%when none exists.
%
%The spec reaches this through a function frame and four nested if-equal
%steps, 5,401.01 inferences a call against 156.01 here, and it is the fold
%type-cast runs once per declared type [measured 2026-09-07:
%`(match-types (List $x) (List Number) t e)`, 200 rounds through eval/2 with
%the engine's own counter; commit=WORKTREE].
'match-types'(Type1, Type2, Then, Else, Out) :-
    (   (   Type1 == '%Undefined%'
        ;   Type2 == '%Undefined%'
        ;   Type1 == 'Atom'
        ;   Type2 == 'Atom'
        )
    ->  Out = Then
    ;   metta_match_atoms(Type1, Type2)
    *-> Out = Then
    ;   Out = Else
    ).

%Upstream's parameter order: the fold accumulator FIRST, then the candidate
%type, then the wanted type.
'match-type-or'(Folded, Next, Type, Out) :-
    'match-types'(Next, Type, true, false, Matched),
    or(Folded, Matched, Out).

%Whether any declared type of the atom in the space unifies with the
%requested one. The space argument keeps the call-site check its SpaceType
%declaration asks for, so a non-space still reports the dispatch mismatch the
%compiled equation reported rather than failing silently.
'type-cast-holds'(Atom, RawType, Space, Out) :-
    normalize_cast_type(Space, RawType, Type),
    findall(Declared,
            (   once(check_argument_type_under_live_policy(Space, 'SpaceType',
                                                           ordinary)),
                'get-type-space'(Space, Atom, Declared)
            *-> true
            ;   dispatch_mismatch_result('get-type-space', [Space, Atom],
                                         Declared)
            ),
            Found),
    metta_prune_empty(Found, Declarations),
    foldl(prelude_type_cast_fold(Type), Declarations, false, Out).

%foldl/4's calling convention takes the element before the accumulator while
%match-type-or takes the accumulator first, so the step is named rather than
%written as a lambda: a yall lambda copies its term once per element and this
%fold runs once per declared type of the subject.
prelude_type_cast_fold(Type, Declared, Folded, Out) :-
    'match-type-or'(Folded, Declared, Type, Out).

%type-cast, upstream's contract: the atom when the cast holds, the flat
%(Error $atom BadType) when it does not. UNDECLARED ON PURPOSE, and the
%absence carries behaviour: the operands evaluate before the cast runs, so an
%ill-typed subject reports its OWN error instead of being swallowed by an
%Atom mask. The metatype is named before the comparison because both of
%=alpha's parameters are Atom and an operand written as a call would
%otherwise be compared as a call.
'type-cast'(Atom, RawType, Space, Out) :-
    normalize_cast_type(Space, RawType, Type),
    'get-metatype'(Atom, Meta),
    '=alpha'(Type, Meta, IsMetatype),
    (   IsMetatype == true
    ->  Out = Atom
    ;   'type-cast-holds'(Atom, RawType, Space, Holds),
        (   Holds == true
        ->  Out = Atom
        %An error produced while collecting the declared types finishes the
        %call with itself, which is what the `if` special form does for a
        %condition that raised rather than answered a Bool.
        ;   Holds = [ErrorHead|Rest],
            ErrorHead == 'Error',
            nonvar(Rest)
        ->  Out = Holds
        ;   Out = ['Error', Atom, 'BadType']
        )
    ).

%%%% Derived forms %%%%
%
%Each of the eight answers the term its call EXPANDS TO, and
%engine/metta/prelude.pl registers it as a translator rule, so the expansion
%happens once while the call site compiles rather than once per call:
%apply_translator_rule_dl/7 obtains an expansion by calling the name and
%taking its output, which is exactly what these clauses provide.
%
%They keep their bodies for the RUNTIME path too, which is where a computed
%head lands: `(let $f union ($f (superpose (1 2)) (superpose (2 3))))`
%dispatches at run time, reaches these clauses, and the %Undefined% result
%evaluates the expansion they hand back.
%
%The let binders each expansion introduces are FRESH per call because they are
%clause variables, which is what the extra-variables-exempt declaration on
%five of these registrations says out loud.

%and-then and or-else ARE `if` with one branch decided.
'and-then'(A, B, [if, A, B, false]).

'or-else'(A, B, [if, A, true, B]).

'trace!'(Message, Value, [progn, ['println!', Message], Value]).

unique(Stream,
       [let, Collapsed, [collapse, Stream],
        [let, Kept, ['unique-atom', Collapsed], [superpose, Kept]]]).

'alpha-unique'(Stream,
               [let, Collapsed, [collapse, Stream],
                [let, Kept, ['alpha-unique-atom', Collapsed],
                 [superpose, Kept]]]).

%The set operations name the shape they rewrite, `(superpose ...)` on both
%sides. The second clause of each is the identity the compiler's own clause
%was: a call that is not that shape is a program using the name as data, and
%`noeval` hands it back unevaluated rather than letting the expansion recurse.
union([superpose, A], [superpose, B],
      [let, Left, [collapse, [superpose, A]],
       [let, Right, [collapse, [superpose, B]],
        [let, Combined, ['union-atom', Left, Right],
         [superpose, Combined]]]]).
union(A, B, [noeval, [union, A, B]]).

intersection([superpose, A], [superpose, B],
             [let, Left, [collapse, [superpose, A]],
              [let, Right, [collapse, [superpose, B]],
               [let, Combined, ['intersection-atom', Left, Right],
                [superpose, Combined]]]]).
intersection(A, B, [noeval, [intersection, A, B]]).

subtraction([superpose, A], [superpose, B],
            [let, Left, [collapse, [superpose, A]],
             [let, Right, [collapse, [superpose, B]],
              [let, Combined, ['subtraction-atom', Left, Right],
               [superpose, Combined]]]]).
subtraction(A, B, [noeval, [subtraction, A, B]]).
