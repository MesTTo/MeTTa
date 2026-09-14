% Purpose: compare native atom indexes with their backtrackable hash reference.
% Guarantees: keys keep exact value identities through growth, failure,
% exceptions and collection [tested: atom_index; commit=dfd348d37d4cbe3d42d877bd6dcf415b54f82179].
% Owns resources: every index is a local Prolog term released with the test.

:- use_module('../../../../engine/atom_index').
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(clpfd)).

:- begin_tests(atom_index).

provider(native) :- predicate_property(atom_index:metta_c_atom_index_new(_), foreign).
provider(prolog).

new(native, Index) :- metta_atom_index_new(Index).
new(prolog, Index) :- atom_index:prolog_index_new(Index).
bind(native, Index, Key, Value, New) :- metta_atom_index_bind(Index, Key, Value, New).
bind(prolog, Index, Key, Value, New) :- atom_index:prolog_index_bind(Index, Key, Value, New).
get(native, Index, Key, Value) :- metta_atom_index_get(Index, Key, Value).
get(prolog, Index, Key, Value) :- atom_index:prolog_index_get(Index, Key, Value).

test(empty_and_repeated_keys, [forall(provider(Owner))]) :-
    new(Owner, Index),
    assertion(\+ get(Owner, Index, absent, _)),
    bind(Owner, Index, key, Value, true),
    bind(Owner, Index, key, Other, false),
    assertion(Value == Other),
    assertion(\+ bind(Owner, Index, key, wrong, true)),
    assertion(var(Value)),
    bind(Owner, Index, key, retained, false),
    assertion(Value == retained),
    assertion(\+ bind(Owner, Index, key, replaced, false)),
    get(Owner, Index, key, retained).

test(arbitrary_atoms_are_distinct_keys, [forall(provider(Owner))]) :-
    Keys = ['', '[]', '0', 'a', 'a b', 'a\u0000b', 'é', '变量', '$metta_atom_index'],
    new(Owner, Index),
    maplist(insert(Owner, Index), Keys, Values),
    maplist(read(Owner, Index), Keys, Read),
    assertion(Values == Read),
    term_variables(Values, Distinct),
    same_length(Keys, Distinct).

insert(Owner, Index, Key, Value) :- bind(Owner, Index, Key, Value, true).
read(Owner, Index, Key, Value) :- get(Owner, Index, Key, Value).

test(backtracking_retires_only_the_new_branch, [forall(provider(Owner))]) :-
    new(Owner, Index),
    bind(Owner, Index, old, Old, true),
    \+ ( bind(Owner, Index, branch, Added, true),
         Old = changed, Added = transient, fail ),
    assertion(var(Old)),
    assertion(\+ get(Owner, Index, branch, _)),
    bind(Owner, Index, branch, Later, true),
    get(Owner, Index, branch, Read), assertion(Read == Later),
    get(Owner, Index, old, Kept), assertion(Kept == Old).

test(exception_retires_growth, [forall(provider(Owner))]) :-
    new(Owner, Index),
    bind(Owner, Index, old, Old, true),
    catch((bind(Owner, Index, added, _, true), Old = changed, throw(abandon_index_growth)),
          abandon_index_growth, true),
    assertion(var(Old)),
    assertion(\+ get(Owner, Index, added, _)),
    bind(Owner, Index, added, final, true).

test(false_new_claim_never_inserts, [forall(provider(Owner))]) :-
    new(Owner, Index),
    assertion(\+ bind(Owner, Index, absent, _, false)),
    assertion(\+ get(Owner, Index, absent, _)).

test(attributed_and_cyclic_values_keep_identity, [forall(provider(Owner))]) :-
    new(Owner, Index),
    Value in 1..3,
    Cycle = [Cycle],
    bind(Owner, Index, constrained, Value, true),
    bind(Owner, Index, cycle, Cycle, true),
    get(Owner, Index, constrained, Read), assertion(Read == Value),
    assertion(\+ bind(Owner, Index, constrained, 7, false)),
    bind(Owner, Index, constrained, 2, false), assertion(Value == 2),
    get(Owner, Index, cycle, ReadCycle), assertion(ReadCycle == Cycle).

test(growth_and_collection_retain_every_key, [forall(provider(Owner))]) :-
    findall(Key, (between(0, 4095, I), J is (I*2039) mod 4096,
                  format(atom(Key), 'atom-index-~16r', [J])), Keys),
    new(Owner, Index),
    maplist(insert(Owner, Index), Keys, Values),
    garbage_collect, garbage_collect_atoms,
    reverse(Keys, Reverse),
    maplist(read(Owner, Index), Reverse, Read),
    reverse(Read, Restored),
    assertion(Restored == Values),
    term_variables(Values, Distinct), length(Distinct, 4096).

test(duplicated_indexes_own_their_mutations, [forall(provider(Owner))]) :-
    new(Owner, Index),
    bind(Owner, Index, original, retained, true),
    duplicate_term(Index, Copy),
    bind(Owner, Copy, added, only_copy, true),
    assertion(\+ get(Owner, Index, added, _)),
    get(Owner, Copy, original, retained),
    bind(Owner, Index, independent, only_original, true),
    assertion(\+ get(Owner, Copy, independent, _)).

% Generated variable identities may change spelling without changing the
% program's work. Include dense, long and Unicode names in each call frame.
test(native_frame_cost_ignores_name_family, [condition(provider(native))]) :-
    findall(Cost,
            ( member(Prefix, [short, '$private-000000000000000000', '变量']),
              findall(Key, (between(1, 257, N),
                            format(atom(Key), '~w~16r', [Prefix, N])), Keys),
              statistics(inferences, Before),
              new(native, Index),
              maplist(insert(native, Index), Keys, Values),
              maplist(read(native, Index), Keys, Read),
              statistics(inferences, After),
              assertion(Values == Read),
              Cost is After-Before ), Costs),
    sort(Costs, [_]).

test(nonatom_keys_refuse, [forall((provider(Owner), member(Key, [7, "text", key(part)]))),
                         throws(error(type_error(atom, _), _))]) :-
    new(Owner, Index), bind(Owner, Index, Key, _, _).

test(open_key_refuses, [forall(provider(Owner)), throws(error(instantiation_error, _))]) :-
    new(Owner, Index), get(Owner, Index, _, _).

test(cyclic_routing_refuses,
     [condition(provider(native)), throws(error(domain_error(atom_index_branch, _), _))]) :-
    Node = '$metta_atom_branch'(1, Node, Node),
    metta_atom_index_get('$metta_atom_index'(Node), key, _).

:- end_tests(atom_index).
