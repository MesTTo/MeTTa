% Purpose: decide space length refinements from visible storage and owner metadata.
% Guarantees: lengths track native rows, inheritance and foreign size promises
% without reading a name as a list [tested: run_tests(space_length_refinements);
% commit=WORKTREE].
% Owns resources: each fixture releases its explicit native names child-first.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- multifile seam:foreign_space/1, seam:grounded_length/2, seam:foreign_atoms/2.
seam:foreign_space('&plunit-sized-length').
seam:foreign_space('&plunit-unsized-length').
seam:foreign_space('&plunit-broken-length').
seam:grounded_length('&plunit-sized-length', 1000000).
seam:grounded_length('&plunit-broken-length', _) :-
    throw(error(plunit_length_failed, none)).
seam:foreign_atoms(Space, _) :-
    memberchk(Space, ['&plunit-sized-length', '&plunit-unsized-length',
                     '&plunit-broken-length']),
    throw(error(plunit_length_enumerated, none)).

:- begin_tests(space_length_refinements).

length_setup(atomic, Space) :- 'new-space'(Space).
length_setup(parametric, Space) :-
    Space = ['plunit-native-length', 1.0],
    metta_declare_parametric_space(Space).

visible_length(Space, Count) :-
    aggregate_all(count, 'get-atoms'(Space, _), Count).

test(native_lengths_follow_mutations_instead_of_name_arity,
     [ forall(member(Kind, [atomic, parametric])),
       setup(length_setup(Kind, Space)), cleanup(metta_release_space(Space)) ]) :-
    assertion(metta_refinement_holds(['Len', 0, 0], Space)),
    assertion(\+ metta_refinement_holds(['MinLen', 1], Space)),
    forall(member(Row, [[entry, 1], [entry, 1], scalar, 7, "text"]),
           metta_add_atom(Space, Row, true)),
    visible_length(Space, 5),
    assertion(metta_refinement_holds(['Len', 5, 5], Space)),
    assertion(metta_refinement_holds(['MinLen', 4], Space)),
    assertion(metta_refinement_holds(['MaxLen', 6], Space)),
    metta_remove_atom(Space, [entry, 1], true),
    assertion(metta_refinement_holds(['Len', 4, 4], Space)),
    metta_host_clear_space(Space),
    assertion(metta_refinement_holds(['Len', 0, 0], Space)).

inherited_length_setup(Parent, Child) :-
    Parent = '&plunit-length-parent', Child = '&plunit-length-child',
    metta_declare_space_parent(Child, Parent),
    metta_add_atom(Parent, [same, row], true),
    metta_add_atom(Parent, scalar, true),
    metta_add_atom(Child, [same, row], true).

test(native_lengths_include_each_visible_inherited_occurrence,
     [ setup(inherited_length_setup(Parent, Child)),
       cleanup((metta_release_space(Child), metta_release_space(Parent))) ]) :-
    space_atom_count(Child, 1),
    visible_length(Child, 3),
    assertion(metta_refinement_holds(['Len', 3, 3], Child)),
    metta_remove_atom(Parent, scalar, true),
    assertion(metta_refinement_holds(['Len', 2, 2], Child)).

test(a_native_child_requires_every_parents_length,
     [ forall(member(Parent-Outcome,
                     ['&plunit-sized-length'-true, '&plunit-unsized-length'-false])),
       setup((Child = '&plunit-length-foreign-child',
              metta_declare_space_parent(Child, Parent),
              metta_add_atom(Child, [own, row], true))),
       cleanup(metta_release_space(Child)) ]) :-
    ( metta_refinement_holds(['Len', 1000001, 1000001], Child) -> Holds = true ; Holds = false ),
    assertion(Holds == Outcome).

test(an_unclaimed_space_length_is_not_assumed_empty) :-
    assertion(\+ metta_refinement_holds(['Len', 0, 0], '&plunit-unsized-length')).

test(a_foreign_owner_answers_without_enumeration) :-
    assertion(metta_refinement_holds(['Len', 1000000, 1000000], '&plunit-sized-length')),
    assertion(\+ metta_refinement_holds(['MaxLen', 2], '&plunit-sized-length')).

test(a_raising_owner_keeps_its_error,
     [throws(error(plunit_length_failed, none))]) :-
    metta_refinement_holds(['Len', 0, 0], '&plunit-broken-length').

test(length_metadata_does_not_consume_a_linear_source,
     [ setup((metta_add_atom('&metta', [source, '&plunit-sized-length', linear], true),
              metta_source_reset('&plunit-sized-length'))),
       cleanup((metta_remove_atom('&metta', [source, '&plunit-sized-length', linear], true),
                metta_source_reset('&plunit-sized-length'))) ]) :-
    assertion(metta_refinement_holds(['Len', 1000000, 1000000], '&plunit-sized-length')),
    assertion(metta_refinement_holds(['MinLen', 1], '&plunit-sized-length')),
    metta_source_guard('&plunit-sized-length'),
    catch((metta_source_guard('&plunit-sized-length'), Second = answered),
          error(metta_source_discipline('&plunit-sized-length', linear), _),
          Second = refused),
    assertion(Second == refused).

test(ordinary_expressions_and_strings_retain_their_lengths) :-
    assertion(metta_refinement_holds(['Len', 2, 2], [ordinary, expression])),
    assertion(metta_refinement_holds(['Len', 3, 3], "abc")),
    Open = ['plunit-native-length', Variable],
    assertion(metta_refinement_holds(['Len', 2, 2], Open)),
    assertion(var(Variable)).

:- end_tests(space_length_refinements).
