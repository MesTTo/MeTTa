% Purpose: gate the one table of names this tree reaches without defining, in
%   both directions, so neither half can rot.
%
% A suppression that is never exercised is the failure mode every mature
% analyser ended up gating: mypy has warn_unused_ignores, PHPStan has
% --fail-on-unused-baseline, and Rust's #[expect(...)] warns when the lint does
% NOT fire. This tree needed it too. engine/check.sh's PROLOG_KNOWN_UNDEFINED
% carried mettafunc/2 with a comment saying `:- dynamic mettafunc/2.` would
% clear it, and both halves were wrong by the time anyone looked: the walk had
% stopped reporting the name at all, and the declaration would have named the
% wrong module, because engine/main.pl is module metta_main while its generated
% mettafunc/2 is resolved through the &self execution module
% [measured 2026-09-20: the raw walk over a tokenless engine boot reports
% lib_file:metta_staged_publish/2 and nothing else; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
%
% Guarantees:
%   - a name no row licenses is reported
%     [tested: deferred_references:a_name_no_row_licenses_is_reported]
%   - a licensed name reached from the file its row names is not reported
%     [tested: deferred_references:a_licensed_name_from_its_own_file_is_not_reported]
%   - the same licensed name reached from any OTHER file IS reported, so
%     widening a deferred call to a new caller is a finding rather than a free
%     pass under an existing row
%     [tested: deferred_references:a_licensed_name_from_another_file_is_reported]
%   - a row is stale exactly while its caller is loaded and its name is absent,
%     which is what lets one table stay honest in a lane that loads the provider
%     and in a lane that does not
%     [tested: deferred_references:a_row_is_stale_exactly_while_its_name_is_absent]
%   - a row the walk did report is never stale
%     [tested: deferred_references:a_row_the_walk_reported_is_not_stale]
%   - the walk refuses to answer at all when it cannot see the call it planted
%     itself, so a clean verdict is a tested claim
%     [tested: deferred_references:the_walk_refuses_to_answer_when_blinded]
%
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- ensure_loaded('../../deferred_references.pl').

:- begin_tests(deferred_references).

% SWI's `:` is priority 600 xfy and `-` is 500, so `m:n/2-[Site]` reads as
% `m:(n/2-[Site])` and the pair does not split. Every synthetic row below
% therefore parenthesises the indicator, which is the same reason list_undefined
% prints `(lib_file:metta_staged_publish/2)-[...]` with brackets of its own.
%
% A clause reference whose file ends in Relative, which is what the walk hands
% the partition: it reports a caller as a clause, not as a path.
%
% Through predicate_property/2 rather than source_file/2, because the engine
% loads from .qlf and that leaves the predicate-to-file attribution almost
% empty: 6 pairs over the 118 loaded files, and none of them the engine's
% [measured 2026-09-20; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]. nth_clause/3 also raises on a
% predicate with no clauses, and one throw inside a catch would end the search
% rather than move to the next candidate, so the guard is per candidate.
a_clause_in(Relative, Ref) :-
    current_module(Module),
    predicate_property(Module:Head, file(File)),
    sub_atom(File, _, _, 0, Relative),
    catch(nth_clause(Module:Head, 1, Ref), _, fail),
    !.

% A clause of this suite's own, which no row licenses and which cannot drift
% when the engine is reorganised.
a_clause_in_this_suite(Ref) :-
    nth_clause(licensed(_), 1, Ref).

licensed(lib_file:metta_staged_publish/2).

test(a_name_no_row_licenses_is_reported) :-
    unexpected_sites([(zzz_absent_module:zzz_absent_name/1)-[somewhere]], Unexpected),
    Unexpected = [(zzz_absent_module:zzz_absent_name/1)-_].

test(a_licensed_name_from_its_own_file_is_not_reported) :-
    a_clause_in('lib/lib_package/lib_package.pl', Ref),
    licensed(PI),
    unexpected_sites([PI-[clause_term_position(Ref, _)]], Unexpected),
    Unexpected == [].

test(a_licensed_name_from_another_file_is_reported) :-
    a_clause_in_this_suite(Ref),
    licensed(PI),
    unexpected_sites([PI-[clause_term_position(Ref, _)]], Unexpected),
    Unexpected = [PI-_].

% Stated as the rule rather than as one configuration's answer, because the
% suites run in a process that may or may not have reached lib_file.
test(a_row_is_stale_exactly_while_its_name_is_absent) :-
    licensed(Module:Name/Arity),
    functor(Head, Name, Arity),
    stale_rows([], Stale),
    (   catch(predicate_property(Module:Head, defined), _, fail)
    ->  Stale == []
    ;   Stale == [Module:Name/Arity]
    ).

test(a_row_the_walk_reported_is_not_stale) :-
    licensed(PI),
    stale_rows([PI-[]], Stale),
    Stale == [].

test(the_walk_refuses_to_answer_when_blinded,
     [throws(error(deferred_references(the_walk_reported_nothing, _), _))]) :-
    setup_call_cleanup(
        assertz(user:deferred_references_probe_target),
        undefined_findings(_, _),
        retractall(user:deferred_references_probe_target)).

:- end_tests(deferred_references).
