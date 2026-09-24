% Purpose: hold a space's publication of from rows alone equal to its whole
%   republication, the differential the row delta is checked by.
% Guarantees: after every step of every sequence, and inside the transaction
%   of a step that reads there, a universe whose importer is published by row
%   deltas holds the same faces, support edges, head roots and recorded
%   bindings, answers, metadata projections and their grades, and source plans
%   as an identical universe whose from rows are all republished whole
%   [tested: reference_deltas:every_step_of_a_row_sequence_publishes_what_a_whole_republication_does,
%   reference_deltas:a_sampled_row_sequence_publishes_what_a_whole_republication_does,
%   reference_deltas:rows_after_the_first_are_published_alone; commit=e4b7448d1f1bd98733f1b04c3906aaa42f35ef1a].
% Guarantees: a row after the first is published by itself inside its
%   transaction and at its completion, whichever way its space's name sorts
%   against its home's [tested:
%   reference_deltas:a_row_publishes_alone_whichever_way_its_space_and_home_sort;
%   commit=e4b7448d1f1bd98733f1b04c3906aaa42f35ef1a].
% Guarantees: a row declared while its space publishes stays owed [tested:
%   reference_deltas:a_row_declared_while_its_space_publishes_stays_owed;
%   commit=e4b7448d1f1bd98733f1b04c3906aaa42f35ef1a].
% Guarantees: a drain publishes a space by its rows alone only while no space
%   its standing rows reach is published in the same drain [tested:
%   reference_deltas:a_reached_home_in_the_same_drain_sends_the_rows_whole;
%   commit=e4b7448d1f1bd98733f1b04c3906aaa42f35ef1a].
% Guarantees: a walk reaching a row's node owes its space whole unless the
%   drain publishing the space raised it [tested:
%   reference_deltas:a_row_walked_outside_its_drain_owes_its_space_whole;
%   commit=e4b7448d1f1bd98733f1b04c3906aaa42f35ef1a].
% Assumes: two universes built by the same steps differ only by the names,
%   modules and row tokens of their spaces, which a snapshot replaces
%   [source: engine/metta/references.pl:metta_reference_publish_rows/8;
%   commit=e4b7448d1f1bd98733f1b04c3906aaa42f35ef1a].
% Owns resources: each case releases the spaces it made, retracts the
%   specializer rows its `adopt` step asserts, and removes the wrappers it
%   installs.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap)).
:- use_module(library(random), [random_between/3, random_member/2]).
:- use_module(library(assoc), [assoc_to_list/2]).

:- begin_tests(reference_deltas).

%The homes a universe imports from, by role. `fun` and `overlap` define d-f
%at the same arity, so an importer of both binds a union; `type` and
%`overlap` declare the same constructor, so its origins gain a second root;
%`block` defines a function named like that constructor, so importing it
%blocks the name and withdraws its origins, the change a row delta declines;
%`chain` reaches `fun` through a row of its own.
delta_home_rows(fun,
    [ [=, ['d-f', '$x'], [+, '$x', 1]], [=, ['d-g'], 1],
      [':', 'd-f', [->, 'Number', 'Number']],
      ['@doc', 'd-f', ['@desc', "adds one"]] ]).
delta_home_rows(type,
    [ [':', 'DPoint', 'Type'], [':', 'DPoint', [->, 'Number', 'DPoint']],
      [':<', 'DPoint', 'DBase'], [=, ['d-t'], 2] ]).
delta_home_rows(overlap,
    [ [=, ['d-f', '$x'], '$x'], [':', 'DPoint', 'Type'],
      [=, ['d-o'], 3] ]).
delta_home_rows(internal,
    [ [=, ['d-hidden'], 4], [internal, 'd-hidden'], [=, ['d-shown'], 5] ]).
delta_home_rows(block,
    [ [=, ['DPoint'], 6], [=, ['d-b'], 7] ]).
delta_home_rows(chain,
    [ [=, ['d-c'], 8] ]).

%A from row a step declares: a home by role and the map it is imported with.
delta_row_pool([ row(fun, none), row(type, none), row(overlap, none),
                 row(internal, none), row(chain, none), row(block, none),
                 row(fun, [only, ['d-f']]), row(type, [rename, [['DPoint', 'DPoint2']]]),
                 row(overlap, [except, ['d-o']]) ]).

%The calls whose answers the two universes must agree on.
delta_calls([ ['d-f', 1], ['d-g'], ['d-t'], ['d-o'], ['d-hidden'], ['d-shown'],
              ['DPoint'], ['d-b'], ['d-c'], ['d-own'], ['d-own-alias'], ['d-adopted'],
              ['d-late'],
              ['get-type', ['DPoint', 1]], ['get-type', ['DPoint2', 1]] ]).

%A universe is universe(Importer, Reader, Tag): an importer the steps declare
%rows into, and a reader that imports the importer from the start, so every
%change to the importer's face has somewhere to reach. Its homes are made on
%first use and kept under Tag.
delta_setup :- delta_setup(_).

%Name, when bound, names the delta universe's importer, so a test can order it
%against its homes, which are named as they are made.
delta_setup(Name) :-
    metta_host_set_silent(true),
    nb_setval(reference_delta_spaces, []),
    delta_universe(delta, Name, Delta), delta_universe(whole, _, Whole),
    nb_setval(reference_delta_universes, Delta-Whole).

delta_universe(Tag, Importer, universe(Importer, Reader, Tag)) :-
    delta_homes_key(Tag, Key), nb_setval(Key, []),
    delta_space(Importer), delta_space(Reader),
    metta_add_atom(Reader, [from, Importer], _).

delta_cleanup :-
    nb_getval(reference_delta_spaces, Spaces),
    forall(( member(Space, Spaces), space_module(Space, Module) ),
           retractall(specializer:ho_specialization(Module, 'd-adopted-source', _))),
    maplist(metta_release_space, Spaces),
    delta_homes_key(delta, DeltaHomes), delta_homes_key(whole, WholeHomes),
    forall(member(Key, [reference_delta_spaces, reference_delta_universes,
                        DeltaHomes, WholeHomes]),
           ( nb_current(Key, _) -> nb_delete(Key) ; true )),
    metta_host_set_silent(false).

delta_homes_key(Tag, Key) :- atom_concat(reference_delta_homes_, Tag, Key).

delta_space(Space) :-
    ( var(Space) -> gensym('&reference-delta-', Space) ; true ),
    space_module(Space, _),
    nb_getval(reference_delta_spaces, Spaces),
    nb_setval(reference_delta_spaces, [Space|Spaces]).

%A universe's home by role, made the first time a step asks for it. chain's
%row into fun is declared once it exists, so chain reaches fun transitively.
delta_home(universe(_, _, Tag), Role, Home) :-
    delta_homes_key(Tag, Key), nb_getval(Key, Homes),
    (   memberchk(Role-Home, Homes)
    ->  true
    ;   delta_space(Home),
        nb_setval(Key, [Role-Home|Homes]),
        delta_home_rows(Role, Rows),
        forall(member(Row, Rows), metta_add_atom(Home, Row, _)),
        (   Role == chain
        ->  delta_home(universe(_, _, Tag), fun, Fun),
            metta_add_atom(Home, [from, Fun], _)
        ;   true
        )
    ).

delta_row_atom(Universe, row(Role, Map), Atom) :-
    delta_home(Universe, Role, Home),
    ( Map == none -> Atom = [from, Home] ; Atom = [from, Home, Map] ).

delta_declare(Universe, Row) :-
    Universe = universe(Importer, _, _),
    delta_row_atom(Universe, Row, Atom),
    metta_add_atom(Importer, Atom, _).

%One step, run on one universe, answering what it saw on the way, which the
%other universe must also see. A committed transaction declares its rows and,
%for `home`, changes a home in the same transaction; a rolled-back one
%declares and fails; `batch` declares a row and changes a home the importer
%already reaches inside one source program, so both wait for one drain;
%`read_inside` asks the reader inside the transaction that declares a row, so
%the reader's face has to have followed the importer's already; `remove`
%withdraws a row the importer holds, if it holds it; `own` gives the importer
%an equation of its own; `self` declares a row of the importer into itself,
%aliasing that equation; `internal_from` makes the from rows declared after it
%graded; `adopt` makes a name the importer defines internal with no face
%event, the way a copied space adopts a specialization it carries.
delta_step(plain(Row), Universe, none) :-
    delta_declare(Universe, Row).
delta_step(remove(Row), Universe, none) :-
    Universe = universe(Importer, _, _),
    delta_row_atom(Universe, Row, Atom),
    metta_remove_atom(Importer, Atom, _).
delta_step(commit(Rows), Universe, none) :-
    transaction(forall(member(Row, Rows), delta_declare(Universe, Row))).
delta_step(rollback(Rows), Universe, none) :-
    ignore(transaction(( forall(member(Row, Rows), delta_declare(Universe, Row)),
                         fail ))).
delta_step(home(Row, Role), Universe, none) :-
    delta_home(Universe, Role, Home),
    transaction(( delta_declare(Universe, Row),
                  delta_home_change(Home) )).
delta_step(batch(Row, Role), Universe, none) :-
    delta_home(Universe, Role, Home),
    metta_engine:metta_with_trailed_push('$metta_source_programs', reference_delta_batch,
        plunit_reference_deltas:( delta_declare(Universe, Row),
                                  delta_home_change(Home) )),
    metta_engine:metta_reference_refresh.
delta_step(read_inside(Row), Universe, Seen) :-
    Universe = universe(_, Reader, _),
    transaction(( delta_declare(Universe, Row), delta_answers(Reader, Seen) )).
delta_step(own, universe(Importer, _, _), none) :-
    metta_add_atom(Importer, [=, ['d-own'], own], _).
delta_step(self, universe(Importer, _, _), none) :-
    metta_add_atom(Importer, [from, Importer, [rename, [['d-own', 'd-own-alias']]]], _).
delta_step(internal_from, universe(Importer, _, _), none) :-
    metta_add_atom(Importer, [internal, from], _).
delta_step(adopt, universe(Importer, _, _), none) :-
    metta_add_atom(Importer, [=, ['d-adopted'], 10], _),
    space_module(Importer, Module),
    assertz(specializer:ho_specialization(Module, 'd-adopted-source', 'd-adopted')).

delta_home_change(Home) :-
    (   spaces:metta_space_pair(Home, [=, ['d-late'], _], _, _)
    ->  true
    ;   metta_add_atom(Home, [=, ['d-late'], 9], _)
    ).

delta_answers(Space, Answers) :-
    findall(Call-Bag,
            ( delta_calls(Calls), member(Call, Calls),
              findall(R, catch(evalc(Call, Space, R), _, R = error), Results),
              msort(Results, Bag) ), Answers).

%Runs Goal with every from row it declares announced as a whole change, so
%each of its publications is the whole republication the delta is checked
%against, completions included.
delta_whole(Goal) :-
    setup_call_cleanup(
        wrap_predicate(metta_engine:metta_reference_changed(Space, Change),
                       reference_deltas_whole, Wrapped,
                       (   Change = row(_)
                       ->  metta_engine:metta_reference_changed(Space)
                       ;   Wrapped
                       )),
        Goal,
        unwrap_predicate(metta_engine:metta_reference_changed(_, _),
                         reference_deltas_whole)).

%What a universe's publications left that a whole republication would decide,
%for its importer and its reader, with every space's name, module and row
%tokens replaced before any list is ordered, so two universes compare.
delta_snapshot(Universe, ImporterView-ReaderView) :-
    Universe = universe(Importer, Reader, _),
    delta_renamings(Universe, Pairs),
    delta_space_state(Importer, ImporterState),
    delta_space_state(Reader, ReaderState),
    delta_replace(Pairs, ImporterState, Importer0), delta_ordered(Importer0, ImporterView),
    delta_replace(Pairs, ReaderState, Reader0), delta_ordered(Reader0, ReaderView).

%Every space of a universe named by its role, its module by its role, and its
%row tokens by their order.
delta_renamings(universe(Importer, Reader, Tag), Pairs) :-
    delta_homes_key(Tag, Key), nb_getval(Key, Homes),
    findall(Pair,
            ( member(Name-Space, [importer-Importer, reader-Reader|Homes]),
              delta_renaming(Name, Space, Pair) ), Pairs0),
    append(Pairs0, Pairs).

delta_renaming(Name, Space, [Space-Name, Module-module(Name)|Rows]) :-
    space_module(Space, Module),
    findall(Token, spaces:metta_space_pair(Space, _, Token, _), Tokens0),
    msort(Tokens0, Tokens),
    findall(Token-token(Name, Index), nth1(Index, Tokens, Token), Rows).

delta_space_state(Space, state(Face, Edges, RootRows, Bound, Projections, Grades,
                               Plan, Behaviour)) :-
    space_module(Space, Module),
    ( support_graph:support_stabilized(derived(Module, reference_face), Face)
    -> true ; Face = none ),
    %The edges publication makes have a reference node at one end; the ones
    %between compiled forms carry names the evaluator mints per compile.
    findall(From-To,
            ( support_graph:supports(From, To),
              ( From = derived(Module, _) ; To = derived(Module, _) ) ), Edges),
    findall(Name/Arity-Roots, metta_engine:metta_reference_roots(Module, Name, Arity, Roots), RootRows),
    findall(Name/Arity-Stands,
            ( metta_engine:metta_reference_bound(Module, Name, Arity, Hash),
              ( metta_engine:metta_reference_roots(Module, Name, Arity, Roots),
                metta_engine:metta_reference_bound_key(Roots, Hash)
              -> Stands = true ; Stands = false ) ), Bound),
    findall(Key-Row,
            ( metta_engine:metta_reference_projection(Space, Key, Token, _),
              spaces:metta_space_pair(Space, Row, Token, _) ), Projections),
    findall(Row-Grade,
            ( metta_engine:metta_occurrence_grade(Space, Token, visibility, Grade),
              spaces:metta_space_pair(Space, Row, Token, _) ), Grades),
    ( metta_engine:metta_reference_plan(Space, Plan) -> true ; Plan = none ),
    delta_answers(Space, Behaviour).

%Each list in standard order, the face's two halves included. A head's roots
%and a name's origins are held in the standard order of their spaces' names,
%which two universes spell differently, so they compare as sets; a plan's two
%maps compare as the pairs they hold, since an assoc built by insertion and
%one built from a sorted list can hold the same pairs in different trees.
delta_ordered(state(Face0, E, R0, B, P, G, Plan0, A),
              state(Face, E1, R1, B1, P1, G1, Plan, A1)) :-
    ( Face0 = face(Own0, Public0)
    -> msort(Own0, Own), msort(Public0, Public), Face = face(Own, Public)
    ; Face = Face0 ),
    findall(Key-Roots, ( member(Key-Roots0, R0), msort(Roots0, Roots) ), R),
    (   Plan0 = source_plan(Map0, Origins0)
    ->  assoc_to_list(Map0, MapPairs0),
        findall(Name-Meaning,
                ( member(Name-Meaning0, MapPairs0),
                  ( Meaning0 = ambiguous(Roots0)
                  -> msort(Roots0, Roots), Meaning = ambiguous(Roots)
                  ; Meaning = Meaning0 ) ), MapPairs),
        assoc_to_list(Origins0, OriginPairs0),
        findall(Name-Roots,
                ( member(Name-Roots0, OriginPairs0), msort(Roots0, Roots) ),
                OriginPairs),
        Plan = plan(MapPairs, OriginPairs)
    ;   Plan = Plan0
    ),
    maplist(msort, [E, R, B, P, G, A], [E1, R1, B1, P1, G1, A1]).

delta_replace(Pairs, Term, Replaced) :-
    (   var(Term)
    ->  Replaced = Term
    ;   member(From-To, Pairs), Term == From
    ->  Replaced = To
    ;   compound(Term)
    ->  compound_name_arguments(Term, Name, Arguments),
        maplist(delta_replace(Pairs), Arguments, Replacements),
        compound_name_arguments(Replaced, Name, Replacements)
    ;   Replaced = Term
    ).

delta_sequence(Steps) :-
    delta_sequence(Steps, _).

%Runs Steps on both universes in turn, the reference universe's under
%delta_whole/1, and compares what each step saw and each universe's snapshot
%after it. Rows counts the publications of rows alone each universe's
%importer made, as Whole-Delta: the reference universe's must be none, or it
%was not the whole republication it stands for.
delta_sequence(Steps, Rows) :-
    nb_getval(reference_delta_universes, Delta-Whole),
    delta_counting(
        forall(nth1(Index, Steps, Step),
               ( delta_whole(delta_step(Step, Whole, WholeSeen)),
                 delta_step(Step, Delta, DeltaSeen),
                 delta_view(Whole, WholeSeen, Expected),
                 delta_view(Delta, DeltaSeen, Actual),
                 ( Actual == Expected
                 -> true
                 ; format(user_error, "step ~w of ~q differs~n", [Index, Steps]),
                   delta_report(Expected, Actual),
                   fail ) )),
        Whole, Delta, Rows),
    assertion(Rows = 0-_).

%A universe's snapshot after a step, beside what the step saw inside it, both
%under the universe's renaming.
delta_view(Universe, Seen, Snapshot-SeenView) :-
    delta_snapshot(Universe, Snapshot),
    delta_renamings(Universe, Pairs),
    delta_replace(Pairs, Seen, SeenView0),
    ( SeenView0 == none -> SeenView = none ; msort(SeenView0, SeenView) ).

delta_report((Importer1-Reader1)-Seen1, (Importer2-Reader2)-Seen2) :-
    delta_report(importer, Importer1, Importer2),
    delta_report(reader, Reader1, Reader2),
    ( Seen1 == Seen2 -> true
    ; format(user_error, "  seen: whole ~q~n  seen: delta ~q~n", [Seen1, Seen2]) ).

delta_report(Who, state(F1, E1, R1, B1, P1, G1, S1, A1),
             state(F2, E2, R2, B2, P2, G2, S2, A2)) :-
    forall(member(Part-X-Y, [face-F1-F2, edges-E1-E2, roots-R1-R2, bound-B1-B2,
                             projections-P1-P2, grades-G1-G2, plan-S1-S2,
                             answers-A1-A2]),
           ( X == Y -> true
           ; format(user_error, "  ~w ~w: whole ~q~n  ~w ~w: delta ~q~n",
                    [Who, Part, X, Who, Part, Y]) )).

%Runs Goal counting metta_reference_publish_rows/8 per universe importer.
delta_counting(Goal, universe(Whole, _, _), universe(Delta, _, _), WholeRows-DeltaRows) :-
    space_module(Whole, WholeModule), space_module(Delta, DeltaModule),
    flag(reference_delta_whole_rows, _, 0), flag(reference_delta_rows, _, 0),
    setup_call_cleanup(
        wrap_predicate(metta_engine:metta_reference_publish_rows(_, Module, _, _, _, _, _, _),
                       reference_deltas_count, Wrapped,
                       ( (   Module == WholeModule
                         ->  flag(reference_delta_whole_rows, W, W+1)
                         ;   Module == DeltaModule
                         ->  flag(reference_delta_rows, D, D+1)
                         ;   true ),
                         Wrapped )),
        Goal,
        unwrap_predicate(metta_engine:metta_reference_publish_rows(_, _, _, _, _, _, _, _),
                         reference_deltas_count)),
    flag(reference_delta_whole_rows, WholeRows, WholeRows),
    flag(reference_delta_rows, DeltaRows, DeltaRows).

%Sequences chosen to reach each way a delta can go wrong: a union formed
%across rows, a constructor gaining a second origin and then blocked, a
%renamed and a filtered import, an internal name, a transitive home, rows
%committed together, a rolled-back row, a home changed in the transaction of
%a row and in its drain, the reader asked inside the transaction of a row
%whose home is new and of one whose home was published before, a row
%withdrawn and a union formed again after it, an importer equation between
%rows, a row of the importer into itself, `from` made internal, and a name
%made internal with no event.
delta_case([plain(row(fun, none)), plain(row(type, none)), plain(row(overlap, none))]).
delta_case([plain(row(type, none)), plain(row(overlap, none)), plain(row(block, none))]).
delta_case([plain(row(fun, [only, ['d-f']])), plain(row(fun, none)),
            plain(row(type, [rename, [['DPoint', 'DPoint2']]])), plain(row(type, none))]).
delta_case([plain(row(internal, none)), plain(row(chain, none)),
            plain(row(overlap, [except, ['d-o']]))]).
delta_case([commit([row(fun, none), row(type, none)]), plain(row(overlap, none)),
            commit([row(internal, none), row(chain, none)])]).
delta_case([plain(row(fun, none)), rollback([row(type, none)]),
            plain(row(overlap, none)), rollback([row(block, none), row(chain, none)])]).
delta_case([plain(row(fun, none)), home(row(type, none), fun),
            plain(row(overlap, none))]).
delta_case([plain(row(fun, none)), batch(row(type, none), fun),
            plain(row(overlap, none))]).
delta_case([plain(row(fun, none)), read_inside(row(type, none)),
            read_inside(row(overlap, none))]).
delta_case([plain(row(fun, [only, ['d-f']])), read_inside(row(fun, none)),
            read_inside(row(overlap, none))]).
delta_case([plain(row(fun, none)), plain(row(type, none)), remove(row(fun, none)),
            plain(row(overlap, none)), plain(row(fun, none))]).
delta_case([own, plain(row(fun, none)), own, plain(row(overlap, none)),
            plain(row(type, none))]).
delta_case([own, plain(row(fun, none)), self, plain(row(type, none)),
            plain(row(overlap, none))]).
delta_case([plain(row(block, none)), plain(row(type, none)), plain(row(overlap, none))]).
delta_case([plain(row(fun, none)), internal_from, plain(row(type, none)),
            plain(row(overlap, none))]).
delta_case([plain(row(fun, none)), adopt, plain(row(overlap, none)),
            plain(row(type, none))]).

test(every_step_of_a_row_sequence_publishes_what_a_whole_republication_does,
     [forall(delta_case(Steps)), setup(delta_setup), cleanup(delta_cleanup)]) :-
    delta_sequence(Steps).

%The control that keeps the differential from passing vacuously: rows
%declared one at a time are published alone.
test(rows_after_the_first_are_published_alone,
     [setup(delta_setup), cleanup(delta_cleanup)]) :-
    delta_sequence([plain(row(fun, none)), plain(row(type, none)),
                    plain(row(overlap, none)), plain(row(internal, none))], Rows),
    Rows = 0-Delta,
    assertion(Delta >= 3).

%A drain publishes its spaces in the standard order of their names, so a space
%named before a home it imports for the first time is published before that
%home's first stabilization walks the space's new row. The walk is the drain's
%own, and every row after the first is still published by itself twice, inside
%its declaring transaction and at the completion that makes its bindings
%final, whichever way the names sort.
test(a_row_publishes_alone_whichever_way_its_space_and_home_sort,
     [forall(member(Name, ['&reference-delta-0-first', '&reference-delta-~-last'])),
      setup(delta_setup(Name)), cleanup(delta_cleanup)]) :-
    delta_sequence([plain(row(fun, none)), plain(row(type, none)),
                    plain(row(overlap, none))], Rows),
    assertion(Rows == 0-4).

%The decision a drain makes before it publishes. The rows alone, while every
%other space in the drain publishes for the first time; whole once the drain
%holds a published home the importer's standing rows reach, whose face may
%move under the entries those rows already contributed. Read inside a source
%program, where the drain waits for its flush.
test(a_reached_home_in_the_same_drain_sends_the_rows_whole,
     [setup(delta_setup), cleanup(delta_cleanup)]) :-
    nb_getval(reference_delta_universes, Delta-_),
    delta_step(plain(row(fun, none)), Delta, _),
    Delta = universe(Importer, _, _),
    space_module(Importer, Module),
    delta_home(Delta, fun, Fun), delta_home(Delta, type, Type),
    metta_engine:metta_with_trailed_push('$metta_source_programs', reference_delta_decision,
        plunit_reference_deltas:(
            delta_declare(Delta, row(type, none)),
            metta_engine:metta_reference_owed_rows(Importer, Module, [Importer, Type], Alone),
            metta_engine:metta_reference_owed_rows(Importer, Module, [Fun, Importer, Type], Reached) )),
    metta_engine:metta_reference_refresh,
    assertion(Alone = rows(_, _, _, _, _, _)),
    assertion(Reached == whole).

%A row's node walked while its space owes rows: by the walk a home's
%republication raises in a drain of its own, which moves what the row
%contributes and owes the space whole, and by the same walk raised by a drain
%that publishes the space, whose faces and entries were all read in one epoch,
%which leaves the rows owed. Read inside a source program, where the rows wait.
test(a_row_walked_outside_its_drain_owes_its_space_whole,
     [setup(delta_setup), cleanup(delta_cleanup)]) :-
    nb_getval(reference_delta_universes, Delta-_),
    delta_step(plain(row(fun, none)), Delta, _),
    Delta = universe(Importer, _, _),
    space_module(Importer, Module),
    once(metta_engine:metta_reference_row(Importer, Token, _, _)),
    Node = derived(Module, reference_row(Token)),
    metta_engine:metta_with_trailed_push('$metta_source_programs', reference_delta_walk,
        plunit_reference_deltas:(
            delta_declare(Delta, row(type, none)),
            b_setval('$metta_reference_draining', [Importer]),
            support_graph:support_invalidate_many([Node]),
            b_setval('$metta_reference_draining', []),
            delta_owed(Importer, Inside),
            support_graph:support_invalidate_many([Node]),
            delta_owed(Importer, Outside) )),
    metta_engine:metta_reference_refresh,
    assertion(Inside == rows),
    assertion(Outside == whole).

delta_owed(Space, Owed) :-
    (   metta_engine:metta_reference_owed_ledger(Space, _, _, _)
    ->  Owed = rows
    ;   Owed = whole
    ).

%A row declared while its space's publication runs, as another thread can,
%stays owed: the publication retracts only the rows it published. Read inside
%a source program so both rows wait, the publication settled as if it had
%taken only the first, the way a drain that decided before the second arrived
%settles; the space is then owed whole so the state published after agrees.
test(a_row_declared_while_its_space_publishes_stays_owed,
     [setup(delta_setup), cleanup(delta_cleanup)]) :-
    nb_getval(reference_delta_universes, Delta-_),
    delta_step(plain(row(fun, none)), Delta, _),
    Delta = universe(Importer, _, _),
    metta_engine:metta_with_trailed_push('$metta_source_programs', reference_delta_race,
        plunit_reference_deltas:(
            delta_declare(Delta, row(type, none)),
            metta_engine:metta_reference_owed_ledger(Importer, [First], [], _),
            delta_declare(Delta, row(overlap, none)),
            metta_engine:metta_reference_settle(
                publication(_, _, _, rows(_, _, _, _, _, _, settled([First], [], [], []))),
                Importer) )),
    findall(Token, metta_engine:metta_reference_owed_row(Importer, Token, new), Owed),
    metta_engine:metta_reference_owe(Importer, whole),
    metta_engine:metta_reference_refresh,
    assertion(Owed = [Second]), assertion(Second \== First).

%A seeded sample over the same step kinds, so orders nobody chose are held to
%the same differential.
test(a_sampled_row_sequence_publishes_what_a_whole_republication_does,
     [forall(between(1, 24, Seed)), setup(delta_setup), cleanup(delta_cleanup)]) :-
    set_random(seed(Seed)),
    random_between(3, 6, Length),
    length(Steps, Length),
    maplist(delta_random_step, Steps),
    delta_sequence(Steps).

delta_random_step(Step) :-
    delta_row_pool(Pool),
    random_between(1, 14, Kind),
    random_member(Row, Pool), random_member(Other, Pool),
    random_member(Role, [fun, type, overlap]),
    (   Kind =< 5 -> Step = plain(Row)
    ;   Kind =< 7 -> Step = commit([Row, Other])
    ;   Kind == 8 -> Step = rollback([Row])
    ;   Kind == 9 -> Step = home(Row, Role)
    ;   Kind == 10 -> Step = batch(Row, Role)
    ;   Kind == 11 -> Step = read_inside(Row)
    ;   Kind == 12 -> Step = remove(Row)
    ;   Kind == 13 -> Step = self
    ;   Step = own
    ).

:- end_tests(reference_deltas).
