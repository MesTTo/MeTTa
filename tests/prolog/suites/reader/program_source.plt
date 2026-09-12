% Purpose: check native source projection and portable space allocation.
% Guarantees: scoped allocation preserves the equation home while parent data
%   stays private; references regenerate projected metadata once
%   [tested: program_source; commit=WORKTREE].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(program_source).

test(scoped_allocation_preserves_the_equation_home) :-
    setup_call_cleanup(
        'new-space'(Home),
        setup_call_cleanup(
            'new-space'(Child, [scoped, Home], Child),
            ( 'add-atom'(Home, [private, data], true),
              'add-atom'(Home, [=, [answer], 17], true),
              assertion(spaces:space_equation_home(Child, Home)),
              assertion(\+ 'get-atoms'(Child, [private, data])),
              filereader:process_metta_string("!(answer)", Answers, Child),
              assertion(Answers == [17]) ),
            metta_release_space(Child)),
        metta_release_space(Home)).


:- end_tests(program_source).
