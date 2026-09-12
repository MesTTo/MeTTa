% Purpose: verify that reference publication visits only affected spaces.
% Guarantees: adding an importer leaves existing siblings untouched, while a
%   provider change reaches its transitive importers
%   [tested: reference_publication; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: declaration discovery and projection read only matching stored
%   declarations [tested: reference_publication; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Owns resources: fixtures release their spaces and remove publication tracing.

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
    Face = ['publication-metadata'/2-root(Home, 'publication-metadata', 2)],
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

:- end_tests(reference_publication).
