% Purpose: distinguish registered namespaces from the native space species.
% Guarantees: reflection follows the existing registration owners through
% creation and retirement [tested: run_tests(space_registration); commit=WORKTREE].
% Owns resources: cleanup releases native stores and erases the foreign claim.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- dynamic registration_foreign/1.
:- multifile seam:foreign_space/1.
seam:foreign_space(Name) :- registration_foreign(Name).

:- begin_tests(space_registration).

test(a_bare_namespace_keeps_its_symbol_species,
     [ cleanup(metta_release_space('plunit-registration-bare')) ]) :-
    Name = 'plunit-registration-bare',
    assertion(\+ metta_space_registered(Name)),
    metta_add_atom(Name, [key, value], true),
    assertion(metta_space_registered(Name)),
    assertion(\+ metta_space_operand(Name)),
    'is-space'(Name, IsSpace), assertion(IsSpace == false),
    'get-metatype'(Name, Type), assertion(Type == 'Symbol'),
    findall(Row, 'get-atoms'(Name, Row), Rows),
    assertion(Rows == [[key, value]]).

test(native_names_share_the_registration_relation,
     [ setup(('new-space'(Atomic),
              Parametric = ['plunit-registration', "tenant"],
              metta_declare_parametric_space(Parametric))),
       cleanup(maplist(metta_release_space, [Atomic, Parametric])) ]) :-
    forall(member(Name, [Atomic, Parametric]),
           ( assertion(metta_space_registered(Name)),
             assertion(metta_space_operand(Name)) )).

test(foreign_claims_share_the_registration_relation,
     [ setup(assertz(user:registration_foreign('&plunit-registration-foreign'), Ref)),
       cleanup(erase(Ref)) ]) :-
    assertion(metta_space_registered('&plunit-registration-foreign')),
    metta_space_names(Names),
    assertion(memberchk('&plunit-registration-foreign', Names)).

test(enumeration_and_the_sorted_snapshot_agree) :-
    findall(Name, metta_space_registered(Name), Found),
    sort(Found, Expected),
    metta_space_names(Names),
    assertion(Names == Expected).

test(retirement_removes_a_registration,
     [ setup('new-space'(Name)), cleanup(metta_release_space(Name)) ]) :-
    assertion(metta_space_registered(Name)),
    metta_release_space(Name),
    assertion(\+ metta_space_registered(Name)).

test(a_ground_value_guard_does_not_select_a_registration) :-
    Candidate = ['plunit-registration', Parameter],
    assertion(\+ (ground(Candidate), metta_space_registered(Candidate))),
    assertion(var(Parameter)).

:- end_tests(space_registration).
