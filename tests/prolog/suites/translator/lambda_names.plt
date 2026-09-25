% Purpose: verify that a compiled |-> lambda is named by its content, for every
%   term shape a lifted lambda clause can hold, and that the one predicate a
%   content names is reused, recompiled or refused by what it holds.
% Guarantees:
%   - one lambda compiled twice, or written with other variable names, is one
%     predicate with one clause, and different bodies are different predicates
%     [tested 2026-09-25T16:35:26+10:00: lambda_names:one_content_is_one_clause,
%     lambda_names:variants_share_a_name_and_bodies_do_not]
%   - text atoms, strings, big integers, rationals and floats name a lambda by
%     value, and a non-text blob is lifted into the closure, so a lambda names
%     the same in every process [tested 2026-09-25T16:35:26+10:00:
%     lambda_names:names_are_the_same_in_another_process]
%   - a captured attributed variable names the lambda as the plain one does and
%     keeps its attribute in the closure [tested 2026-09-25T16:35:26+10:00:
%     lambda_names:an_attributed_capture_names_as_the_plain_lambda]
%   - a non-text blob is lifted into a leading parameter, so two blobs share
%     one predicate and each closure answers with its own [tested 2026-09-25T16:35:26+10:00:
%     lambda_names:two_blobs_share_one_predicate]
%   - a cyclic lambda is refused by name at both lambda doors [tested
%     2026-09-25T16:35:26+10:00: lambda_names:a_cyclic_lambda_is_refused_by_name]
%   - a live import of the name is reused, and a name abolished or unimported
%     since its first compile is compiled again, into the module's own
%     predicate [tested 2026-09-25T16:35:26+10:00:
%     lambda_names:an_abolished_lambda_compiles_again,
%     lambda_names:a_live_import_is_reused_and_an_unimported_name_compiles_again]
%   - a live clause compiled from another lambda under the same name is
%     refused as a collision [tested 2026-09-25T16:35:26+10:00:
%     lambda_names:a_name_collision_is_refused_by_name]
%   - a lambda two sources share outlives the one that leaves [tested
%     2026-09-25T16:35:26+10:00: lambda_names:a_shared_lambda_outlives_the_source_that_leaves]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- initialization(consult('../../lib/lib_import/lib_import.pl')).

%The attribute these tests put on a captured variable. No test unifies it with
%a value, and the hook admits any if one does.
lambda_names_attr:attr_unify_hook(_, _).

:- begin_tests(lambda_names).

lambda_name(Lambda, Name) :-
    translate_expr(Lambda, _, Out),
    ( Out = partial(Name, _) -> true ; Name = Out ).

forget_lambda(Name) :-
    metta_self_module(Module),
    specializer:forget_symbol(Module, Name).

own_clauses(Module, Name, Arity, Count) :-
    functor(Head, Name, Arity),
    aggregate_all(count,
                  ( clause(Module:Head, _, Ref), clause_property(Ref, module(Module)) ),
                  Count).

test(one_content_is_one_clause) :-
    lambda_name(['|->', [X], [pair, X, plunit_once]], First),
    lambda_name(['|->', [Y], [pair, Y, plunit_once]], Second),
    setup_call_cleanup(
        true,
        ( First == Second,
          metta_self_module(Module),
          own_clauses(Module, First, 2, 1) ),
        forget_lambda(First)).

test(variants_share_a_name_and_bodies_do_not) :-
    lambda_name(['|->', [A, B], [pair, A, B]], Pair),
    lambda_name(['|->', [C, D], [pair, C, D]], Variant),
    lambda_name(['|->', [E, F], [pair, F, E]], Swapped),
    setup_call_cleanup(
        true,
        ( Pair == Variant, Pair \== Swapped ),
        forall(member(Name, [Pair, Swapped]), forget_lambda(Name))).

%The value shapes, and a blob, named here and in a fresh process. The child is
%this same executable booting the same engine, so a name that differs is a name
%that depends on something besides the lambda's content.
value_lambdas([ ['|->', [X], [pair, X, plunit_text]],
                ['|->', [X], [pair, X, "plunit string"]],
                ['|->', [X], [pair, X, 123456789012345678901234567890]],
                ['|->', [X], [pair, X, 1r3]],
                ['|->', [X], [pair, X, 1.5]] ]).

lambda_names_here(Names) :-
    value_lambdas(Lambdas),
    maplist(lambda_name, Lambdas, Values),
    open_null_stream(Stream),
    lambda_name(['|->', [Y], [pair, Y, Stream]], Lifted),
    close(Stream),
    append(Values, [Lifted], Names).

test(names_are_the_same_in_another_process) :-
    lambda_names_here(Here),
    current_prolog_flag(executable, Swipl),
    tmp_file(lambda_names, Answer),
    format(atom(Goal),
           "ensure_loaded('../../engine/qlf_boot.pl'), ensure_loaded('../../engine/metta.pl'), \c
            ensure_loaded('suites/translator/lambda_names.plt'), \c
            plunit_lambda_names:lambda_names_here(Names), \c
            setup_call_cleanup(open(~q, write, S), format(S, '~~q.~~n', [Names]), close(S))",
           [Answer]),
    setup_call_cleanup(
        process_create(Swipl, ['-q', '-g', Goal, '-t', halt],
                       [stdin(null), stdout(null), stderr(null), process(Pid)]),
        process_wait(Pid, Status),
        true),
    assertion(Status == exit(0)),
    setup_call_cleanup(open(Answer, read, In), read_term(In, There, []),
                       ( close(In), delete_file(Answer) )),
    setup_call_cleanup(
        true,
        assertion(There == Here),
        forall(member(Name, Here), forget_lambda(Name))).

test(an_attributed_capture_names_as_the_plain_lambda) :-
    put_attr(Captured, lambda_names_attr, kept),
    translate_expr(['|->', [X], [pair, X, Captured]], _, partial(Named, [Held])),
    lambda_name(['|->', [Y], [pair, Y, _Plain]], Plain),
    setup_call_cleanup(
        true,
        ( Named == Plain,
          get_attr(Held, lambda_names_attr, kept) ),
        forget_lambda(Named)).

test(two_blobs_share_one_predicate) :-
    open_null_stream(First),
    open_null_stream(Second),
    setup_call_cleanup(
        true,
        ( translate_expr(['|->', [X], [pair, X, First]], _, partial(Name, [First])),
          translate_expr(['|->', [Y], [pair, Y, Second]], _, partial(Other, [Second])),
          Name == Other,
          metta_self_module(Module),
          own_clauses(Module, Name, 3, 1),
          call(Module:Name, First, a, One), One == [pair, a, First],
          call(Module:Name, Second, b, Two), Two == [pair, b, Second] ),
        ( close(First), close(Second), forget_lambda(Name) )).

test(a_cyclic_lambda_is_refused_by_name) :-
    Cycle = f(Cycle),
    catch(translate_expr(['|->', [X], [pair, X, Cycle]], _, _), Compiled, true),
    assertion(subsumes_term(error(metta_lambda_cyclic(_), _), Compiled)),
    catch(translator:written_lambda_closure(['|->', [Y], [pair, Y, Cycle]], _),
          Applied, true),
    assertion(subsumes_term(error(metta_lambda_cyclic(_), _), Applied)).

test(an_abolished_lambda_compiles_again) :-
    lambda_name(['|->', [X], [pair, X, plunit_abolished]], Name),
    metta_self_module(Module),
    abolish(Module:Name/2),
    lambda_name(['|->', [Y], [pair, Y, plunit_abolished]], Again),
    setup_call_cleanup(
        true,
        ( Again == Name,
          own_clauses(Module, Name, 2, 1),
          call(Module:Name, a, Out), Out == [pair, a, plunit_abolished] ),
        forget_lambda(Name)).

%A live import is the definition the module sees, and it is reused, clause and
%all: a local compile would have asserted THROUGH it into the importing
%source. The home is a SIBLING space, off the importer's module chain, so once
%the import is abolished the name reaches no clause there and the module
%compiles one of its own; a lambda &self holds would still be reached through
%the chain every space's module inherits, and rightly reused.
test(a_live_import_is_reused_and_an_unimported_name_compiles_again,
     [cleanup(forall(member(Space, ['&plunit_lambda_home', '&plunit_lambda_importer']),
                     metta_release_space(Space)))]) :-
    space_module('&plunit_lambda_home', Home),
    space_module('&plunit_lambda_importer', Module),
    with_metta_module(Home,
        plunit_lambda_names:lambda_name(['|->', [X], [pair, X, plunit_home_only]], Name)),
    Home:export(Name/2),
    Module:import(Home:Name/2),
    functor(Head, Name, 2),
    with_metta_module(Module,
        plunit_lambda_names:lambda_name(['|->', [Y], [pair, Y, plunit_home_only]], Reused)),
    Reused == Name,
    predicate_property(Module:Head, imported_from(Home)),
    own_clauses(Home, Name, 2, 1),
    abolish(Module:Name/2),
    \+ predicate_property(Module:Head, imported_from(_)),
    with_metta_module(Module,
        plunit_lambda_names:lambda_name(['|->', [Z], [pair, Z, plunit_home_only]], Again)),
    Again == Name,
    \+ predicate_property(Module:Head, imported_from(_)),
    own_clauses(Module, Name, 2, 1),
    own_clauses(Home, Name, 2, 1),
    call(Module:Name, a, Out),
    Out == [pair, a, plunit_home_only].

test(a_name_collision_is_refused_by_name) :-
    lambda_name(['|->', [X], [pair, X, plunit_collision]], Name),
    metta_self_module(Module),
    functor(Head, Name, 2),
    clause(Module:Head, _, Ref),
    %The recorded equation now says the clause came from another lambda, which
    %is what a digest collision leaves behind.
    retract(filereader:translated_from(Ref, _)),
    assertz(filereader:translated_from(Ref, [=, [Name, Z], [pair, Z, plunit_other]])),
    catch(lambda_name(['|->', [Y], [pair, Y, plunit_collision]], _), Error, true),
    setup_call_cleanup(
        true,
        assertion(subsumes_term(error(metta_lambda_name_collision(Name, _, _), _), Error)),
        ( retractall(filereader:translated_from(Ref, _)), forget_lambda(Name) )).

%Two sources written into one space whose functions map with the same lambda,
%so the second compile reuses the first's clause. When the first source
%leaves, its artifacts go with it, and the lambda the second still calls must
%not be one of them.
test(a_shared_lambda_outlives_the_source_that_leaves,
     [cleanup(metta_release_space('&plunit_lambda_shared'))]) :-
    share_source(One, "(= (plunit-share-one $xs) (map-atom $xs $x (pair $x plunit-shared)))~n"),
    share_source(Two, "(= (plunit-share-two $xs) (map-atom $xs $x (pair $x plunit-shared)))~n"),
    Space = '&plunit_lambda_shared',
    space_module(Space, Module),
    setup_call_cleanup(
        asserta(filereader:silent(true), Silent),
        ( 'import!'(Space, One, true),
          'import!'(Space, Two, true),
          findall(R, with_metta_module(Module, eval(['plunit-share-one', [a]], R)), First),
          First == [[[pair, a, 'plunit-shared']]],
          findall(R, with_metta_module(Module, eval(['plunit-share-two', [b]], R)), Second),
          Second == [[[pair, b, 'plunit-shared']]],
          'unimport!'(Space, One, true),
          findall(R, with_metta_module(Module, eval(['plunit-share-two', [c]], R)), After),
          assertion(After == [[[pair, c, 'plunit-shared']]]) ),
        ( erase(Silent), delete_file(One), delete_file(Two) )).

share_source(Path, Text) :-
    tmp_file(lambda_share, Stem),
    atom_concat(Stem, '.metta', Path),
    setup_call_cleanup(open(Path, write, Out), format(Out, Text, []), close(Out)).

:- end_tests(lambda_names).
