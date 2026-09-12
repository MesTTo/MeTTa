% Purpose: check native source projection and portable space allocation.
% Guarantees: scoped allocation preserves the equation home while parent data
%   stays private; references regenerate projected metadata once
%   [tested: program_source; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].

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

test(source_omits_only_projected_occurrences) :-
    setup_call_cleanup(
        ('new-space'(Library), 'new-space'(Caller)),
        ( 'add-atom'(Library, [':', documented, [->, 'Number']], true),
          'add-atom'(Library, ['@doc', documented, ['@desc', "one"]], true),
          'add-atom'(Caller, [from, Library], true),
          'add-atom'(Caller, ['@doc', local, ['@desc', "two"]], true),
          metta_host_source_atoms(Caller, Source),
          msort(Source, Sorted),
          msort([[from, Library], ['@doc', local, ['@desc', "two"]]], Expected),
          assertion(Sorted == Expected),
          assertion('get-atoms'(Caller, ['@doc', documented, ['@desc', "one"]])) ),
        (metta_release_space(Caller), metta_release_space(Library))).

:- end_tests(program_source).
