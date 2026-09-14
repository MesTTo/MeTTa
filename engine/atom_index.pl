% Purpose: own backtrackable atom-key bindings without copying their values.
% Guarantees: bind/4 reports first insertion and otherwise unifies with the
% original value; get/3 never inserts [tested: atom_index; commit=WORKTREE].
% Owns resources: indexes are local Prolog terms, reclaimed and rolled back
% by their engine; the C artifact holds no index outside those terms.
% Guarded by: an index is confined to its Prolog engine's trailed state.

:- module(atom_index,
          [ metta_atom_index_new/1,
            metta_atom_index_bind/4,
            metta_atom_index_get/3
          ]).
:- use_module(library(hashtable), [ht_new/1, ht_get/3, ht_put/3]).
:- use_module(library(error), [must_be/2]).
:- use_module(library(filesex), [directory_file_path/3]).
:- catch(use_module(library(shlib)), _, true).

% An absent accelerator keeps the executable reference. A present artifact
% that cannot load raises its actual error instead of hiding a broken build.
:- prolog_load_context(directory, Directory),
   directory_file_path(Directory, 'atom_index.so', Object),
   ( current_predicate(load_foreign_library/1), exists_file(Object)
   -> load_foreign_library(Object)
   ; true ).

% Undefined-predicate checking also covers C-free builds. Create declarations
% only there: repeating dynamic/1 on reconsult disables a foreign definition.
% [tested: test_atom_index_reload_preserves_native_owner; commit=WORKTREE].
:- ( predicate_property(metta_c_atom_index_new(_), foreign)
   -> true
   ; dynamic([metta_c_atom_index_new/1, metta_c_atom_index_bind/4,
              metta_c_atom_index_get/3]) ).

% A QLF may move to a machine without its accelerator. Select at creation,
% and let each index's representation retain its owner afterward.
% [tested: test_atom_index_loads_with_runtime_artifact_presence; commit=WORKTREE].
metta_atom_index_new(Index) :-
    ( predicate_property(metta_c_atom_index_new(_), foreign)
    -> metta_c_atom_index_new(Index)
    ; prolog_index_new(Index) ).
metta_atom_index_bind(Index, Key, Value, New) :-
    ( nonvar(Index), Index = '$metta_atom_index'(_)
    -> metta_c_atom_index_bind(Index, Key, Value, New)
    ; prolog_index_bind(Index, Key, Value, New) ).
metta_atom_index_get(Index, Key, Value) :-
    ( nonvar(Index), Index = '$metta_atom_index'(_)
    -> metta_c_atom_index_get(Index, Key, Value)
    ; prolog_index_get(Index, Key, Value) ).

prolog_index_new(Index) :- ht_new(Index).
prolog_index_bind(Index, Key, Value, New) :-
    must_be(atom, Key),
    ( ht_get(Index, Key, Known)
    -> New = false, Value = Known
    ; New = true, ht_put(Index, Key, Value) ).
prolog_index_get(Index, Key, Value) :-
    must_be(atom, Key), ht_get(Index, Key, Value).
