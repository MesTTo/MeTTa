% Purpose: pin what each cache-policy word builds, what each refusal names, and
%   the (cache Name Policy) row's own lifecycle: install on write, hold until
%   the clauses arrive, withdraw on removal, release the storage watch last.
% Guarantees:
%   - monotonic: an add-atom puts its consequence in the table before the next
%     call, the table is never invalidated, and that call costs a read where
%     the incremental twin re-evaluates
%     [tested: a_monotonic_table_takes_a_new_fact_without_re_evaluation]
%   - lattice: one aggregated answer per input over a cyclic graph, refreshed
%     by table-clear, private and plain by default, refused bare over a read
%     [tested: a_lattice_table_answers_the_minimum_over_a_cycle,
%     a_bare_lattice_over_a_read_is_refused_naming_plain]
%   - subsumptive: a specific call answers from the general table and adds
%     none [tested: a_subsumptive_table_answers_a_specific_call_from_the_general_one]
%   - restraints: max-answers signals through the answer's delay condition and
%     subgoal-abstract through SWI's tripwire, both as
%     metta_control_signal(restraint, [Word, Bound, Call])
%     [tested: a_max_answers_restraint_signals_when_it_trips,
%     a_subgoal_abstract_restraint_signals_through_the_tripwire]
%   - every refusal names its remedy and leaves no row standing
%     [tested: a_watched_policy_over_an_impure_body_is_refused,
%     a_watched_subsumptive_policy_is_refused, one_storage_predicate_carries_one_watch,
%     a_refused_row_does_not_stand, static_conflicts_are_refused_at_compile_time,
%     the_lattice_join_must_be_visible]
%   - the row is the declaration: it installs before its definition arrives,
%     untabled refuses under it, its removal takes its tables and releases the
%     storage watch, and a table a call asked for reverts to the default
%     [tested: a_row_written_before_the_definition_installs_when_the_clauses_arrive,
%     untabled_under_a_standing_row_is_refused,
%     the_policy_in_force_is_reported_and_released,
%     a_tabled_call_under_a_row_keeps_the_table_when_the_row_leaves]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- initialization(consult('../../lib/lib_tabling/lib_tabling.pl')).
:- use_module(library(tableutil)).

policy_definitions("
(= (plt-mono-reach $x $y) (match &plt_pol_mono (link $x $y) $y))
(= (plt-mono-reach $x $z) (let $y (plt-mono-reach $x $y) (match &plt_pol_mono (link $y $z) $z)))
(= (plt-incr-reach $x $y) (match &plt_pol_incr (link $x $y) $y))
(= (plt-incr-reach $x $z) (let $y (plt-incr-reach $x $y) (match &plt_pol_incr (link $y $z) $z)))
(= (plt-lazy-reach $x $y) (match &plt_pol_lazy (link $x $y) $y))
(= (plt-shortest $p $q) (if (< $p $q) $p $q))
(= (plt-cost $x $y) (match &plt_pol_graph (edge $x $y $c) $c))
(= (plt-cost $x $z) (let $c1 (plt-cost $x $y) (match &plt_pol_graph (edge $y $z $c2) (+ $c1 $c2))))
(= (plt-cost2 $x $y) (match &plt_pol_graph (edge $x $y $c) $c))
(= (plt-pure-min $n) (superpose (3 1 2)))
(= (plt-choice $x) (superpose ((pair $x 1) (pair $x 2))))
(= (plt-upto $n) (superpose (1 2 3 4 5 6 7 8 9 10)))
(= (plt-small $n) (superpose (1 2)))
(= (plt-deep $t) $t)
(= (plt-noisy $k) (let $i (println! $k) $k))
(= (plt-pure $k) (+ $k 1))
(= (plt-r1 $k) (match &plt_pol_shared (fact $k $v) $v))
(= (plt-r2 $k) (match &plt_pol_shared (fact $k $v) $v))
(= (plt-called $k) (match &plt_pol_called (fact $k $v) $v))
").

setup_policy_suite :-
    retractall(user:silent(_)),
    assertz(user:silent(true)),
    policy_definitions(Source),
    process_metta_string(Source, _),
    'add-atom'('&plt_pol_mono', [link, a, b], _),
    'add-atom'('&plt_pol_incr', [link, a, b], _),
    'add-atom'('&plt_pol_lazy', [link, a, b], _),
    'add-atom'('&plt_pol_shared', [fact, 1, one], _),
    'add-atom'('&plt_pol_called', [fact, 1, one], _),
    forall(member(Edge, [[edge, a, b, 1], [edge, b, c, 1], [edge, c, a, 1],
                         [edge, a, c, 5]]),
           'add-atom'('&plt_pol_graph', Edge, _)).

%A row written through the engine's own door, so the catalog checks it.
declare(Name, Policy) :-
    'add-atom'('&metta', [cache, Name, Policy], true).

withdraw(Name) :-
    forall('get-atoms'('&metta', [cache, Name, Policy]),
           'remove-atom'('&metta', [cache, Name, Policy], _)).

policy_in_force(Call, Words) :-
    metta_table_statistics(Call, Stats),
    memberchk([policy, Words], Stats).

counter(Call, Name, Value) :-
    metta_table_statistics(Call, Stats),
    memberchk([Name, Value], Stats).

refused(Goal, Reason) :-
    catch(Goal, error(metta_tabling_policy_refused(_, Reason0), _), true),
    (   var(Reason0)
    ->  fail
    ;   Reason = Reason0
    ).

%A refusal must render, or a program sees "Unknown error term".
renders(Reason) :-
    phrase(prolog:error_message(metta_tabling_policy_refused(plt, Reason)), Lines),
    Lines \== [].

inferences(Goal, Cost) :-
    statistics(inferences, Before),
    call(Goal),
    statistics(inferences, After),
    Cost is After - Before.

storage_head('&plt_pol_shared', Storage:Head) :-
    native_storage_module('&plt_pol_shared', Storage),
    Head = '&plt_pol_shared'(_, _, _).

:- begin_tests(lib_tabling_policies, [setup(setup_policy_suite)]).

test(a_monotonic_table_takes_a_new_fact_without_re_evaluation,
     [ cleanup(( withdraw('plt-mono-reach'),
                 catch(metta_untabled_decl(['plt-incr-reach', _, _], true), _, true),
                 'remove-atom'('&plt_pol_mono', [link, b, c], _),
                 'remove-atom'('&plt_pol_incr', [link, b, c], _) )) ]) :-
    declare('plt-mono-reach', monotonic),
    metta_tabled_decl(['plt-incr-reach', _, _], true),
    assertion(policy_in_force(['plt-mono-reach', _, _], [monotonic, shared])),
    assertion(policy_in_force(['plt-incr-reach', _, _], [incremental, shared])),
    native_storage_module('&plt_pol_mono', Storage),
    assertion(predicate_property(Storage:'&plt_pol_mono'(_, _, _), monotonic)),
    assertion(\+ predicate_property(Storage:'&plt_pol_mono'(_, _, _), incremental)),
    metta_self_module(Self),
    findall(Y, Self:'plt-mono-reach'(a, _, Y), First),
    assertion(First == [b]),
    forall(Self:'plt-incr-reach'(a, _, _), true),
    'add-atom'('&plt_pol_mono', [link, b, c], _),
    'add-atom'('&plt_pol_incr', [link, b, c], _),
    %The consequence is in the table before anyone calls, and nothing was
    %invalidated: that pair is what an incremental table cannot show.
    assertion(counter(['plt-mono-reach', _, _], answers, 2)),
    assertion(counter(['plt-mono-reach', _, _], invalidated, 0)),
    assertion(counter(['plt-incr-reach', _, _], answers, 1)),
    assertion(counter(['plt-incr-reach', _, _], invalidated, 1)),
    inferences(findall(Y2, Self:'plt-mono-reach'(a, _, Y2), Mono), MonoCost),
    inferences(findall(Y3, Self:'plt-incr-reach'(a, _, Y3), Incr), IncrCost),
    msort(Mono, MonoSorted), msort(Incr, IncrSorted),
    assertion(MonoSorted == [b, c]),
    assertion(IncrSorted == [b, c]),
    assertion(counter(['plt-mono-reach', _, _], reevaluated, 0)),
    assertion(counter(['plt-incr-reach', _, _], reevaluated, 1)),
    %The monotonic call after a write is a read; the incremental one is a
    %re-evaluation of the body.
    assertion(MonoCost < IncrCost).

test(a_lazy_policy_is_compiled_and_reported,
     [ cleanup(( withdraw('plt-lazy-reach'),
                 'remove-atom'('&plt_pol_lazy', [link, a, c], _) )) ]) :-
    declare('plt-lazy-reach', [monotonic, lazy]),
    assertion(policy_in_force(['plt-lazy-reach', _, _], [monotonic, shared, lazy])),
    metta_self_module(Self),
    assertion('$get_predicate_attribute'(Self:'plt-lazy-reach'(_, _, _), lazy, 1)),
    forall(Self:'plt-lazy-reach'(a, _, _), true),
    'add-atom'('&plt_pol_lazy', [link, a, c], _),
    findall(Y, Self:'plt-lazy-reach'(a, _, Y), Ys),
    msort(Ys, Sorted),
    assertion(Sorted == [b, c]).

test(a_lattice_table_answers_the_minimum_over_a_cycle,
     [ cleanup(( withdraw('plt-cost'),
                 'remove-atom'('&plt_pol_graph', [edge, a, c, 1], _) )) ]) :-
    declare('plt-cost', [plain, [lattice, 'plt-shortest']]),
    assertion(policy_in_force(['plt-cost', _, _],
                              [plain, private, [lattice, 'plt-shortest']])),
    metta_self_module(Self),
    findall(C, Self:'plt-cost'(a, c, C), ToC),
    findall(C2, Self:'plt-cost'(a, a, C2), ToA),
    assertion(ToC == [2]),
    assertion(ToA == [3]),
    %A plain table watches nothing: the new edge is invisible until the table
    %is cleared, which is what the policy's own refusal told the developer.
    'add-atom'('&plt_pol_graph', [edge, a, c, 1], _),
    findall(C3, Self:'plt-cost'(a, c, C3), Stale),
    assertion(Stale == [2]),
    metta_table_clear(['plt-cost', _, _], true),
    findall(C4, Self:'plt-cost'(a, c, C4), Fresh),
    assertion(Fresh == [1]).

test(a_bare_lattice_over_a_read_is_refused_naming_plain) :-
    refused(declare('plt-cost2', [lattice, 'plt-shortest']), Reason),
    assertion(Reason = reads_unwatched(lattice, _)),
    assertion(renders(Reason)),
    assertion(\+ 'get-atoms'('&metta', [cache, 'plt-cost2', _])).

test(a_lattice_over_a_pure_body_needs_no_plain,
     [ cleanup(withdraw('plt-pure-min')) ]) :-
    declare('plt-pure-min', [lattice, 'plt-shortest']),
    assertion(policy_in_force(['plt-pure-min', _],
                              [plain, private, [lattice, 'plt-shortest']])),
    metta_self_module(Self),
    findall(M, Self:'plt-pure-min'(0, M), Answers),
    assertion(Answers == [1]).

test(a_subsumptive_table_answers_a_specific_call_from_the_general_one,
     [ cleanup(withdraw('plt-choice')) ]) :-
    declare('plt-choice', subsumptive),
    assertion(policy_in_force(['plt-choice', _], [plain, shared, subsumptive])),
    metta_self_module(Self),
    findall(X-P, Self:'plt-choice'(X, P), General),
    length(General, 2),
    assertion(counter(['plt-choice', _], tables, 1)),
    findall(P2, Self:'plt-choice'(a, P2), Specific),
    msort(Specific, SpecificSorted),
    assertion(SpecificSorted == [[pair, a, 1], [pair, a, 2]]),
    assertion(counter(['plt-choice', _], tables, 1)).

test(a_watched_subsumptive_policy_is_refused) :-
    refused(declare('plt-choice', [incremental, subsumptive]), Reason),
    assertion(Reason == cannot_watch(subsumptive, incremental)),
    assertion(renders(Reason)).

test(a_max_answers_restraint_signals_when_it_trips,
     [ cleanup(( withdraw('plt-upto'), withdraw('plt-small') )) ]) :-
    declare('plt-upto', ['max-answers', 3]),
    declare('plt-small', ['max-answers', 3]),
    assertion(policy_in_force(['plt-upto', _], [incremental, shared, ['max-answers', 3]])),
    %Under the bound nothing is different.
    process_metta_string("!(collapse (plt-small 1))", [Small]),
    msort(Small, SmallSorted),
    assertion(SmallSorted == [1, 2]),
    catch(process_metta_string("!(collapse (plt-upto 10))", _),
          error(metta_control_signal(restraint, Detail), _),
          true),
    assertion(Detail = ['max-answers', 3, "(plt-upto 10)"]),
    %The signal is a control exception, which is what keeps a MeTTa catch
    %from disarming a program's own bound.
    assertion(control_exception(error(metta_control_signal(restraint, Detail), _))).

test(a_subgoal_abstract_restraint_signals_through_the_tripwire,
     [ cleanup(withdraw('plt-deep')) ]) :-
    declare('plt-deep', ['subgoal-abstract', 2]),
    process_metta_string("!(plt-deep (s 0))", Small),
    assertion(Small == [[s, 0]]),
    catch(process_metta_string("!(plt-deep (s (s (s (s 0)))))", _),
          error(metta_control_signal(restraint, Detail), _),
          true),
    assertion(Detail = ['subgoal-abstract', 2, _]).

test(a_watched_policy_over_an_impure_body_is_refused,
     [ cleanup(withdraw('plt-noisy')) ]) :-
    refused(declare('plt-noisy', monotonic), Reason),
    assertion(Reason == unclassified(metta_impure_goal('println!'/2), monotonic)),
    assertion(renders(Reason)),
    assertion(\+ 'get-atoms'('&metta', [cache, 'plt-noisy', _])),
    %plain is the remedy the refusal named, and it tables the same body.
    declare('plt-noisy', plain),
    assertion(policy_in_force(['plt-noisy', _], [plain, shared])).

test(one_storage_predicate_carries_one_watch,
     [ cleanup(( withdraw('plt-r2'),
                 catch(metta_untabled_decl(['plt-r1', _], true), _, true) )) ]) :-
    metta_tabled_decl(['plt-r1', _], true),
    refused(declare('plt-r2', monotonic), Reason),
    assertion(Reason = storage_watched(_, incremental, 'plt-r1'/2)),
    assertion(renders(Reason)),
    assertion(\+ 'get-atoms'('&metta', [cache, 'plt-r2', _])),
    declare('plt-r2', incremental),
    assertion(policy_in_force(['plt-r2', _], [incremental, shared])),
    storage_head('&plt_pol_shared', Storage:Head),
    assertion(predicate_property(Storage:Head, incremental)),
    %The property outlives neither reader.
    withdraw('plt-r2'),
    assertion(predicate_property(Storage:Head, incremental)),
    metta_untabled_decl(['plt-r1', _], true),
    assertion(\+ predicate_property(Storage:Head, incremental)).

test(a_refused_row_does_not_stand) :-
    refused(declare('plt-pure', lazy), Reason),
    assertion(Reason == needs(lazy, monotonic)),
    assertion(\+ 'get-atoms'('&metta', [cache, 'plt-pure', _])),
    metta_self_module(Self),
    assertion(\+ predicate_property(Self:'plt-pure'(_, _), tabled)).

test(static_conflicts_are_refused_at_compile_time) :-
    refused(declare('plt-pure', [incremental, monotonic]), Two),
    assertion(Two == two_of(incremental, monotonic)),
    refused(declare('plt-pure', [shared, private]), Threads),
    assertion(Threads == two_of(shared, private)),
    refused(declare('plt-pure', [shared, [lattice, 'plt-shortest']]), Shared),
    assertion(Shared == moded_shared),
    refused(declare('plt-pure', [monotonic, [lattice, 'plt-shortest']]), Watched),
    assertion(Watched == cannot_watch(lattice, monotonic)),
    refused(declare('plt-pure', ['max-answers', -1]), Bound),
    assertion(Bound == restraint_bound('max-answers', -1)),
    forall(member(R, [Two, Threads, Shared, Watched, Bound]), assertion(renders(R))),
    %The door's own refusals: a word outside the vocabulary, a memo word
    %beside a tabling word, a parametrised word standing bare.
    forall(member(Bad, [bogus, [force, monotonic], lattice, ['max-answers', many]]),
           assertion(catch(( declare('plt-pure', Bad), fail ),
                           error(metta_declaration_malformed(_, 2, _), _),
                           true))).

test(the_lattice_join_must_be_visible) :-
    refused(declare('plt-pure', [lattice, 'plt-no-such-join']), Reason),
    assertion(Reason = join_missing('plt-no-such-join', _)),
    assertion(renders(Reason)).

test(a_row_written_before_the_definition_installs_when_the_clauses_arrive,
     [ cleanup(( withdraw('plt-late-policy'),
                 remove_sexp('&self', [=, ['plt-late-policy', 'K'], 'K']) )) ]) :-
    declare('plt-late-policy', monotonic),
    assertion(lib_tabling:metta_tabling_row_held('plt-late-policy')),
    assertion(\+ lib_tabling:metta_tabling_policy_installed('plt-late-policy', _, _, _, _, _, _)),
    process_metta_string("(= (plt-late-policy $k) $k) !(plt-late-policy 1)", _),
    assertion(policy_in_force(['plt-late-policy', _], [monotonic, shared])),
    assertion(once('get-atoms'('&metta', [tabled, _, 'plt-late-policy', 1]))).

test(untabled_under_a_standing_row_is_refused,
     [ cleanup(withdraw('plt-called')) ]) :-
    declare('plt-called', incremental),
    catch(metta_untabled_decl(['plt-called', _], true), Error, true),
    assertion(Error = error(metta_tabling_row_governs('plt-called', incremental), _)),
    assertion(policy_in_force(['plt-called', _], [incremental, shared])).

test(the_policy_in_force_is_reported_and_released,
     [ cleanup(withdraw('plt-mono-reach')) ]) :-
    declare('plt-mono-reach', [monotonic, lazy]),
    assertion(policy_in_force(['plt-mono-reach', _, _], [monotonic, shared, lazy])),
    assertion(once('get-atoms'('&metta', [tabled, _, 'plt-mono-reach', 2]))),
    native_storage_module('&plt_pol_mono', Storage),
    assertion(predicate_property(Storage:'&plt_pol_mono'(_, _, _), monotonic)),
    withdraw('plt-mono-reach'),
    metta_table_statistics(['plt-mono-reach', _, _], Stats),
    assertion(\+ memberchk([policy, _], Stats)),
    assertion(\+ 'get-atoms'('&metta', [tabled, _, 'plt-mono-reach', 2])),
    metta_self_module(Self),
    assertion(\+ predicate_property(Self:'plt-mono-reach'(_, _, _), tabled)),
    assertion(\+ predicate_property(Storage:'&plt_pol_mono'(_, _, _), monotonic)).

test(a_tabled_call_under_a_row_keeps_the_table_when_the_row_leaves,
     [ cleanup(( withdraw('plt-called'),
                 catch(metta_untabled_decl(['plt-called', _], true), _, true) )) ]) :-
    metta_tabled_decl(['plt-called', _], true),
    assertion(policy_in_force(['plt-called', _], [incremental, shared])),
    declare('plt-called', monotonic),
    assertion(policy_in_force(['plt-called', _], [monotonic, shared])),
    withdraw('plt-called'),
    assertion(policy_in_force(['plt-called', _], [incremental, shared])),
    metta_untabled_decl(['plt-called', _], true),
    metta_self_module(Self),
    assertion(\+ predicate_property(Self:'plt-called'(_, _), tabled)).

:- end_tests(lib_tabling_policies).
