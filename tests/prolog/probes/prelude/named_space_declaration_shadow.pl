% Purpose: show that a prelude head redefined in a NAMED space at a different
%   arity answers the space's own equation, whichever space defines it first.
%   Before 2026-09-07 the prelude's declaration tier never asked whether the
%   module defines the name, so a named space defining `(= (if-equal $a $b)
%   SHADOWED)` kept the prelude's four-input arrow and `!(if-equal 1 1)`
%   compiled to an arity refusal there, while &self, which EVICTS the prelude
%   row outright, answered SHADOWED; the same file therefore answered
%   differently through `sh tools/run.sh` (&self) and through a host that mints a
%   named space. prelude_declaration_governs_in/2 in engine/metta/types.pl is
%   the repair; the plunit case is
%   prelude:a_named_space_shadows_a_prelude_name_at_another_arity.
% Run: cd <checkout> && swipl -q tests/prolog/probes/prelude/named_space_declaration_shadow.pl
%      (the named space first), or the same with `named_first` after the file
%      (get-type read before and after the definition in the named space).
%   Expected on a repaired tree, both orders: the named space answers
%   ['SHADOWED'] for the call and '%Undefined%' for get-type once it has
%   defined the name (before that, the prelude's arrow), and &self still
%   answers [yes] for (if-equal 1 1 yes no).
:- initialization(main, main).
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

main :-
    current_prolog_flag(argv, Argv),
    (   memberchk(named_first, Argv)
    ->  Order = named
    ;   Order = self
    ),
    probe_order(Order).

probe_order(named) :-
    process_metta_string("!(get-type if-equal)", B0, '&probe-gt'),
    format("named  get-type BEFORE : ~q~n", [B0]),
    process_metta_string("(= (if-equal $a $b) SHADOWED)\n!(get-type if-equal)\n!(if-equal 1 1)", B, '&probe-gt'),
    format("named  after defining  : ~q~n", [B]),
    process_metta_string("!(if-equal 1 1 yes no)", C, '&self'),
    format("&self untouched answer : ~q~n", [C]).
probe_order(self) :-
    process_metta_string("(= (if-equal $a $b) SHADOWED)\n!(get-type if-equal)\n!(if-equal 1 1)", A, '&self'),
    format("&self  after defining  : ~q~n", [A]),
    process_metta_string("(= (if-equal $a $b) SHADOWED2)\n!(if-equal 1 1)", B, '&probe-gt2'),
    format("named  once evicted    : ~q~n", [B]).
