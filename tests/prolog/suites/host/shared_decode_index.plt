% Purpose: exercise variable identity, binding order and rollback in fresh and
% seeded Python wire decoders.
% Guarantees: indexed roots agree with the seeded decoder on generated wires
% and refuse contradictory occurrences of one name
% [tested: shared_decode_index; commit=dfd348d37d4cbe3d42d877bd6dcf415b54f82179];
% the translator loaded through the shim alone, without engine/metta.pl, still
% names the engine's artifacts from the engine's directory
% [tested: the_translator_loaded_through_the_shim_names_the_engine_artifacts;
% commit=WORKTREE].

:- consult('../../../../extensions/python/metta/_binding/shim.pl').

:- begin_tests(shared_decode_index).

% The shim's use_module loads engine/translator.pl before engine/metta.pl,
% the umbrella that records the engine's directory, so the translator umbrella
% records it too; without that, runtime.pl's directive fails at load and the
% analyzer's artifact is never named.
test(the_translator_loaded_through_the_shim_names_the_engine_artifacts) :-
    translator:metta_mbr_artifact(MbrSo),
    file_base_name(MbrSo, 'mbr.so'),
    file_directory_name(MbrSo, EngineDir),
    file_base_name(EngineDir, engine),
    metta_engine:metta_engine_src_dir(EngineDir).

test(the_first_decode_does_not_pay_for_dependency_loading) :-
    Wire = [e, [[v, x], [v, y]]],
    statistics(inferences, A),
    metta_py_decode_shared(Wire, _, _),
    statistics(inferences, B),
    metta_py_decode_shared(Wire, _, _),
    statistics(inferences, C),
    First is B-A, Next is C-B,
    assertion(First =< Next+20).

% A deterministic recursive corpus varies shape, name reuse and both text
% spellings independently. The retained list frame is the differential oracle.
wire(Seed, Depth, Wire) :-
    Kind is Seed mod 11,
    ( Depth > 0, Kind >= 7
    -> Next is Depth - 1,
       A is Seed // 3, B is Seed // 5, C is Seed // 7,
       wire(A, Next, WA), wire(B, Next, WB), wire(C, Next, WC),
       Wire = [e, [WA, WB, WC]]
    ; leaf(Kind, Wire)
    ).

leaf(0, [v, x]).
leaf(1, ["v", "x"]).
leaf(2, [v, y]).
leaf(3, [v, '_']).
leaf(4, [n, 3.5]).
leaf(5, [b, true]).
leaf(6, [g, "text"]).
leaf(7, [s, '&self']).
leaf(8, [p, "&self"]).
leaf(9, [e, []]).
leaf(10, [s, word]).

test(generated_roots_agree_with_ordered_list_frames,
     [forall((between(0, 511, Seed), between(0, 3, Depth)))]) :-
    wire(Seed, Depth, Wire),
    findall(T-B, metta_py_decode_shared_(Wire, T, [], B), Expected),
    findall(T-B, metta_py_decode_shared(Wire, T, B), Actual),
    assertion(Actual =@= Expected),
    findall(T-B, metta_py_decode_target_(Wire, named, T, [], B), Target),
    findall(T-B, metta_py_decode_target(named, Wire, T, B), Named),
    assertion(Named =@= Target).

test(a_prebound_name_cannot_acquire_a_second_value,
     [forall(member(Route, [shared, target, seeded])), fail]) :-
    Wire = [e, [[v, x], ["v", "x"]]],
    ( Route == shared -> metta_py_decode_shared(Wire, [a,b], _)
    ; Route == target -> metta_py_decode_target(named, Wire, [a,b], _)
    ; metta_py_decode_shared_(Wire, [a,b], [], _) ).

test(a_seeded_name_is_selected_before_its_value_is_unified, [fail]) :-
    metta_py_decode_shared_([v, x], b, [x-a], _).

test(prebound_values_preserve_binding_order) :-
    metta_py_decode_shared([e, [[v, x], [v, y], [v, x]]], [a,b,a], B),
    assertion(B == [y-b,x-a]).

test(anonymous_occurrences_do_not_constrain_each_other) :-
    metta_py_decode_target(named, [e, [[v, '_'], [v, "_"]]], [a,b], B),
    assertion(B == []).

test(separate_roots_do_not_share_variables) :-
    metta_py_decode_shared([v, x], A, _),
    metta_py_decode_shared([v, x], B, _),
    assertion(A \== B).

test(failed_decoding_rolls_back_the_index_and_seed_value) :-
    metta_atom_index_new(Index),
    metta_atom_index_bind(Index, old, Old, true),
    \+ metta_py_decode_shared_([e, [[v, old], [v, new], [bad, value]]],
                              [bound,_,_], indexed([old-Old], Index), _),
    assertion(var(Old)),
    assertion(\+ metta_atom_index_get(Index, new, _)),
    metta_py_decode_shared_([v, old], Value, indexed([old-Old], Index), _),
    assertion(Value == Old).

test(failure_rolls_back_construction_of_the_index) :-
    Frame = indexed([x-X], Index),
    \+ metta_py_decode_shared_([e, [[v, x], [v, y], [bad, value]]],
                              [bound,_,_], Frame, _),
    assertion(var(Index)), assertion(var(X)),
    metta_py_decode_shared_([v, x], Value, Frame, _),
    assertion(Value == X), assertion(var(Index)).

test(a_supplied_index_contains_a_single_name) :-
    metta_py_decode_indexed([v, x], X, indexed([x-X], Index)),
    metta_atom_index_get(Index, x, Y), assertion(X == Y).

test(malformed_nested_payload_fails,
     [forall(member(Bad, [[v, 7], [e, bad], [unknown, x], [n, "3"]])), fail]) :-
    metta_py_decode_target(named, [e, [[v, x], Bad, [v, x]]], _, _).

test(wide_distinct_names_keep_every_identity_and_order) :-
    findall([v, Name], (between(1, 8192, I), atom_number(Name, I)), Wires),
    metta_py_decode_shared([e, Wires], Terms, Bindings),
    term_variables(Terms, Variables),
    length(Variables, 8192),
    reverse(Bindings, Ordered),
    pairs_values(Ordered, Values),
    assertion(Values == Variables),
    findall(Name, member([v, Name], Wires), Names),
    pairs_keys(Ordered, Keys),
    assertion(Keys == Names).

:- end_tests(shared_decode_index).
