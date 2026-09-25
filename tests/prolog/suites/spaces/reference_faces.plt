% Purpose: hold the faces a strongly connected component of from rows computes
%   together, by label-setting, equal to the union over simple row paths that
%   the recursion they replaced computed, over seeded universes of cyclic rows
%   whose maps select, rename, prefix and constrain arguments.
% Guarantees: in every sampled universe, every space's published face, the
%   face its component computes for it and the face each row reads of its home
%   equal what faces_oracle/3 computes, which is that recursion without its
%   memo [tested 2026-09-26T02:04:15+10:00:
%   reference_faces:a_component_labels_what_every_simple_path_brings,
%   reference_faces:a_blocked_importer_is_cut_where_every_path_through_it_is].
% Guarantees: the faces of a component in which every space imports every
%   other grow polynomially with its size [tested 2026-09-26T02:04:15+10:00:
%   reference_faces:a_complete_component_costs_polynomially_in_its_size].
% Owns resources: each case releases the spaces it made, in reverse order.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(random), [random_between/3, random_member/2, random_subseq/3,
                                maybe/1]).

:- begin_tests(reference_faces).

%The recursion the component labelling replaced, without its memo: a face is
%a space's local heads and each row's image of what its home publishes, a self
%row reading the space's own heads and any other row its home's face reached
%along a path that has not visited the home
%[source 2026-09-26T01:29:41+10:00: engine/metta/references.pl at 2235ce0ac,
%metta_reference_local_face/3, metta_reference_row_entry/6 and
%metta_reference_source_face/4].
faces_oracle(Space, Visited, Face) :-
    (   memberchk(Space, Visited)
    ->  Face = []
    ;   findall(Name/Arity-root(Space, Name, Arity, []),
                metta_engine:metta_reference_local_head(Space, Name, Arity), Own),
        findall(Entry,
                ( metta_engine:metta_reference_row(Space, Token, Home, Map),
                  faces_oracle_source(Space, Home, Visited, Source),
                  member(SourceEntry, Source),
                  metta_engine:metta_reference_row_image(Space, Token, Map, SourceEntry, Entry) ),
                Imported),
        append(Own, Imported, All), sort(All, Face)
    ).

faces_oracle_source(Space, Space, _, Face) :- !,
    findall(Name/Arity-root(Space, Name, Arity, []),
            metta_engine:metta_reference_own_head(Space, Name, Arity), Face).
faces_oracle_source(Space, Home, Visited, Face) :-
    faces_oracle(Home, [Space|Visited], Local),
    include(metta_engine:metta_reference_public_entry(Home), Local, Face).

%A universe of two to five spaces, each defining some of three heads as a
%constant, a one-input function or a declaration, and holding a row into each
%space, itself included, with probability 0.45 and a map drawn from every
%shape the rows of this engine take.
faces_universe(Seed, Spaces) :-
    set_random(seed(Seed)),
    metta_host_set_silent(true),
    random_between(2, 5, Count),
    findall(Space, ( between(1, Count, _), gensym('&reference-face-', Space) ), Spaces),
    forall(member(Space, Spaces), space_module(Space, _)),
    forall(member(Space, Spaces), faces_heads(Space)),
    forall(( member(Space, Spaces), member(Home, Spaces) ), faces_row(Space, Home)).

faces_heads(Space) :-
    forall(( member(Name, [fa, fb, fc]), maybe(0.5) ),
           ( random_member(Row, [[=, [Name], defined], [=, [Name, X], [got, X]],
                                 [':', Name, [->, 'Number', 'Number']]]),
             metta_add_atom(Space, Row, _) )).

faces_row(Space, Home) :-
    (   maybe(0.45)
    ->  random_between(1, 6, Kind), faces_map(Kind, Map),
        ( Map == none -> Row = [from, Home] ; Row = [from, Home, Map] ),
        metta_add_atom(Space, Row, _)
    ;   true
    ).

faces_map(1, none).
faces_map(2, [prefix, 'p.']).
faces_map(3, [only, Names]) :- random_subseq([fa, fb, fc], Names, _).
faces_map(4, [rename, [[fa, fr]]]).
faces_map(5, [except, [fb]]).
faces_map(6, ['|->', [H],
              [case, H, [[fa, [superpose, [[noeval, fk], [noeval, [fp, ['Pair', _, _]]]]]],
                         [fb, [superpose, [[noeval, fa]]]],
                         [_, [empty]]]]]).

faces_release(Spaces) :-
    reverse(Spaces, Reversed), maplist(metta_release_space, Reversed),
    metta_host_set_silent(false).

test(a_component_labels_what_every_simple_path_brings,
     [forall(between(1, 40, Seed)),
      setup(faces_universe(Seed, Spaces)), cleanup(faces_release(Spaces))]) :-
    forall(member(Space, Spaces),
           ( faces_oracle(Space, [], Expected),
             metta_engine:metta_reference_provider_face(Space, [], Published),
             assertion(Published == Expected),
             metta_engine:metta_reference_component_faces(Space, [], Faces),
             memberchk(Space-Computed, Faces),
             assertion(Computed == Expected) )).

test(a_blocked_importer_is_cut_where_every_path_through_it_is,
     [forall(between(1, 40, Seed)),
      setup(faces_universe(Seed, Spaces)), cleanup(faces_release(Spaces))]) :-
    forall(( member(Space, Spaces), metta_engine:metta_reference_row(Space, _, Home, _),
             Home \== Space ),
           ( faces_oracle(Home, [Space], Expected),
             metta_engine:metta_reference_provider_face(Home, [Space], Computed),
             assertion(Computed == Expected) )).

%A component of N spaces each defining its own head and importing every other,
%as the class spaces of one hierarchy do. Every head reaches every space along
%its one direct row, so each state holds one label and the component's faces
%cost about N^3 row images; remembering faces by blocked set instead computed
%a face for every subset of the component a path could block.
faces_complete(Count, Spaces) :-
    metta_host_set_silent(true),
    findall(Space, ( between(1, Count, _), gensym('&reference-face-', Space) ), Spaces),
    forall(member(Space, Spaces), space_module(Space, _)),
    forall(nth1(Index, Spaces, Space),
           ( atom_concat(head, Index, Name), metta_add_atom(Space, [=, [Name], Index], _) )),
    forall(( member(Space, Spaces), member(Home, Spaces), Home \== Space ),
           metta_add_atom(Space, [from, Home], _)).

faces_complete_cost(Count, Inferences) :-
    setup_call_cleanup(
        faces_complete(Count, Spaces),
        ( Spaces = [Space|_],
          statistics(inferences, Before),
          metta_engine:metta_reference_component_faces(Space, [], Faces),
          statistics(inferences, After),
          Inferences is After - Before,
          length(Spaces, Members),
          forall(member(_-Face, Faces), assertion(length(Face, Members))) ),
        faces_release(Spaces)).

%Doubling the component multiplies a cubic cost by 8 and a quartic one by 16,
%and an exponential one by 2^4 on top of its polynomial. The labelling read
%3,081 inferences at four spaces and 20,343 at eight, 6.6 times, where the
%recursion read 3,655 and 342,420, 93.7 times [measured
%2026-09-26T02:04:10+10:00: faces_complete/2's component at 022c8930e, the
%recursion through metta_reference_local_face/3 before the labelling replaced
%it].
test(a_complete_component_costs_polynomially_in_its_size) :-
    faces_complete_cost(4, Four),
    faces_complete_cost(8, Eight),
    assertion(Eight < 16 * Four).

:- end_tests(reference_faces).
