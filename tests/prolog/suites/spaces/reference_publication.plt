% Purpose: verify that reference publication visits only affected spaces.
% Guarantees: adding an importer leaves existing siblings untouched, while a
%   provider change reaches its transitive importers
%   [tested: reference_publication; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: declaration discovery and projection read only matching stored
%   declarations [tested: reference_publication; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Assumes: reference roots carry their canonical argument-pattern list
%   [source: engine/metta/references.pl:metta_reference_target/5; commit=a95e6c90c910db30c72311abadd58dee5349978c].
% Owns resources: fixtures release their spaces and remove publication tracing.
% Guarantees: content clearing preserves dependencies owned by live importers
%   and retires unused function indexes [tested: reference_publication;
%   commit=901a768e17b3ad2559b19d2895a250451a88da99].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap)).

:- begin_tests(reference_publication).

publication_setup :-
    metta_host_set_silent(true),
    nb_setval(reference_publication_spaces, []).

publication_space(Space) :-
    gensym('&reference-publication-', Space), space_module(Space, _),
    nb_getval(reference_publication_spaces, Spaces),
    nb_setval(reference_publication_spaces, [Space|Spaces]).

publication_cleanup :-
    nb_getval(reference_publication_spaces, Spaces),
    maplist(metta_release_space, Spaces),
    nb_delete(reference_publication_spaces),
    metta_host_set_silent(false).

publication_from(Space, Home) :- metta_add_atom(Space, [from, Home], _).

publication_note(Space) :-
    nb_getval(reference_publication_trace, Before),
    nb_setval(reference_publication_trace, [Space|Before]).

publication_trace(Goal, Published) :-
    setup_call_cleanup(
        ( nb_setval(reference_publication_trace, []),
          wrap_predicate(metta_engine:metta_reference_publish_face(Space, _Module, _Face, _Faces),
                         reference_publication_trace, Original,
                         ( plunit_reference_publication:publication_note(Space),
                           call(Original) )) ),
        ( call(Goal), nb_getval(reference_publication_trace, Trace),
          sort(Trace, Published) ),
        ( unwrap_predicate(metta_engine:metta_reference_publish_face(_, _, _, _),
                           reference_publication_trace),
          nb_delete(reference_publication_trace) )).

test(a_new_importer_does_not_republish_existing_siblings,
     [forall(member(Count, [1, 8, 64])),
      setup(publication_setup), cleanup(publication_cleanup)]) :-
    publication_space(Home),
    metta_add_atom(Home, [=, ['publication-value'], 7], _),
    forall(between(1, Count, _),
           ( publication_space(Peer), publication_from(Peer, Home) )),
    publication_space(Fresh),
    publication_trace(publication_from(Fresh, Home), Published),
    assertion(Published == [Fresh]),
    findall(Value, evalc(['publication-value'], Fresh, Value), Values),
    assertion(Values == [7]).

test(a_provider_change_reaches_its_transitive_importers_only,
     [setup(publication_setup), cleanup(publication_cleanup)]) :-
    maplist(publication_space, [Home, Middle, Leaf, Other, Unrelated]),
    publication_from(Middle, Home), publication_from(Leaf, Middle),
    publication_from(Unrelated, Other),
    publication_trace(metta_add_atom(Home, [=, ['publication-arrival'], 9], _),
                      Published),
    sort([Home, Middle, Leaf], Expected),
    assertion(Published == Expected),
    findall(Value, evalc(['publication-arrival'], Leaf, Value), Values),
    assertion(Values == [9]),
    findall(Value, evalc(['publication-arrival'], Unrelated, Value), Absent),
    assertion(Absent == [['publication-arrival']]).

test(metadata_projection_does_not_enumerate_a_providers_population,
     [setup(publication_setup), cleanup(publication_cleanup)]) :-
    publication_space(Home), publication_space(Receiver),
    Arrow = [':', 'publication-metadata', ['->', 'Number', 'Number']],
    metta_add_atom(Home, Arrow, Token, true),
    forall(between(1, 512, N), metta_add_atom(Home, [population, N], _)),
    Face = ['publication-metadata'/2-root(Home, 'publication-metadata', 2, [])],
    publication_pairs(Home,
        findall(Key-Row,
                metta_engine:metta_reference_metadata(Receiver, Face, Key, Row),
                Rows), Enumerated),
    assertion(Rows == [origin(Home, Token, 'publication-metadata')-Arrow]),
    assertion(Enumerated == 1).

test(declaration_discovery_does_not_enumerate_a_providers_population,
     [setup(publication_setup), cleanup(publication_cleanup)]) :-
    publication_space(Home),
    metta_add_atom(Home, [':', 'PublicationValue', 'Type'], _),
    metta_add_atom(Home, [':<', 'PublicationValue', 'PublicationBase'], _),
    forall(between(1, 512, N), metta_add_atom(Home, [population, N], _)),
    publication_pairs(Home,
        findall(Name, metta_engine:metta_reference_declared_head(Home, Name),
                Names), Enumerated),
    assertion(Names == ['PublicationValue','PublicationValue']),
    assertion(Enumerated == 2).

publication_pairs(Home, Goal, Enumerated) :-
    setup_call_cleanup(
        ( nb_setval(reference_publication_pairs, 0),
          wrap_predicate(spaces:metta_space_pair(Source, _Row, _Token, _Ref),
                         reference_publication_pairs, Original,
                         ( call(Original),
                           ( Source == Home
                           -> nb_getval(reference_publication_pairs, Before),
                              After is Before+1,
                              nb_setval(reference_publication_pairs, After)
                           ; true ) )) ),
        ( call(Goal), nb_getval(reference_publication_pairs, Enumerated) ),
        ( unwrap_predicate(spaces:metta_space_pair(_, _, _, _),
                           reference_publication_pairs),
          nb_delete(reference_publication_pairs) )).

test(clearing_a_provider_preserves_its_live_importers,
     [forall(member(Initial, [[], [[=, ['publication-clear'], old]]])),
      setup(publication_setup), cleanup(publication_cleanup)]) :-
    publication_space(Home), publication_space(Receiver),
    forall(member(Row, Initial), metta_add_atom(Home, Row, _)),
    publication_from(Receiver, Home),
    metta_host_clear_space(Home),
    findall(Value, evalc(['publication-clear'], Receiver, Value), Cleared),
    assertion(Cleared == [['publication-clear']]),
    metta_add_atom(Home, [=, ['publication-clear'], new], _),
    findall(Value, evalc(['publication-clear'], Receiver, Value), Values),
    assertion(Values == [new]).

test(clearing_an_importer_preserves_its_own_live_importers,
     [setup(publication_setup), cleanup(publication_cleanup)]) :-
    maplist(publication_space, [Home, Middle, Leaf]),
    metta_add_atom(Home, [=, ['publication-clear-middle'], old], _),
    publication_from(Middle, Home), publication_from(Leaf, Middle),
    metta_host_clear_space(Middle),
    findall(Value, evalc(['publication-clear-middle'], Leaf, Value), Cleared),
    assertion(Cleared == [['publication-clear-middle']]),
    metta_add_atom(Middle, [=, ['publication-clear-middle'], new], _),
    findall(Value, evalc(['publication-clear-middle'], Leaf, Value), Values),
    assertion(Values == [new]).

test(rolling_back_clear_restores_the_provider_and_its_live_links,
     [setup(publication_setup), cleanup(publication_cleanup)]) :-
    publication_space(Home), publication_space(Receiver),
    Old = [=, ['publication-clear-rollback'], old],
    metta_add_atom(Home, Old, _), publication_from(Receiver, Home),
    \+ transaction((metta_host_clear_space(Home), fail)),
    findall(Value, evalc(['publication-clear-rollback'], Receiver, Value), Before),
    assertion(Before == [old]),
    metta_remove_atom(Home, Old, true),
    metta_add_atom(Home, [=, ['publication-clear-rollback'], new], _),
    findall(Value, evalc(['publication-clear-rollback'], Receiver, Value), After),
    assertion(After == [new]).

test(clearing_content_releases_unused_function_indexes,
     [setup(publication_setup), cleanup(publication_cleanup)]) :-
    publication_space(Home), space_module(Home, Module),
    forall(between(1, 10, N),
           ( atom_concat('publication-obsolete-', N, Name),
             metta_add_atom(Home, [=, [Name], N], _),
             metta_host_clear_space(Home),
             assertion(\+ support_graph:support_function_module(_, Module)),
             assertion(\+ support_graph:support_view_module(_, Module)),
             assertion(\+ support_graph:support_translated_form_id(_, Module, _)),
             assertion(\+ support_graph:support_memo_rule(Module, _, _, _)) )).

:- end_tests(reference_publication).
