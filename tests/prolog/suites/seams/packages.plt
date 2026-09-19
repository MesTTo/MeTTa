% Purpose: gate the package rows the loader performs, and the reservation of
%   the `package` head.
%
% A library used to CALL the importer:
%
%     !(import_prolog_functions_from_file (library lib_x.pl) (head ...))
%
% and now DESCRIBES what backs its heads:
%
%     (= (package backing) (prolog (library lib_x.pl) (head ...)))
%
% The difference is that the row is data any implementation can read, decide
% whether it can perform, and refuse by name when it cannot, where the call was
% an instruction only this engine understands
% [source: docs/journal/2026-09-09-packages-are-equations.md, laws 1, 4, 5, 14].
%
% Guarantees:
%   - a backing row installs the head its artifact exports
%     [tested: packages:a_backing_row_installs_the_head_its_artifact_exports]
%   - the same library WITHOUT the row installs nothing, so the row is what
%     does it rather than the import
%     [tested: packages:a_file_with_no_backing_row_installs_nothing]
%   - a token no claimant answers leaves the head absent rather than failing
%     silently somewhere later
%     [tested: packages:a_backing_no_claimant_answers_installs_nothing]
%   - `package` is internal in every space, so one library's package rows are
%     never read as its importer's own
%     [tested: packages:the_package_head_is_internal_in_every_space]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(packages).

%Resolved at LOAD time, against this file's own directory. A relative path
%resolved inside a test resolves against the working directory the runner
%happened to have, which is not where this suite sits.
:- prolog_load_context(directory, Here),
   atomic_list_concat([Here, '/../../../../ai-tmp'], Scratch),
   assertz(packages_scratch(Scratch)),
   forall(member(Kind, [backed, unbacked, unclaimed]),
          ( atomic_list_concat([Here, '/../../../data/packages/', Kind, '.pl'], Relative),
            absolute_file_name(Relative, Artifact, [access(read)]),
            assertz(packages_artifact(Kind, Artifact)) )).

%The artifact ships as a fixture and the .metta naming it is written here,
%because a backing row names its artifact by a path this suite only knows at
%run time; a committed .metta would have to hard-code one. Written under the
%repository's ai-tmp rather than /tmp, which is a RAM disk here, and named
%.metta because that is the extension `import!` resolves.
%
%One file PER TEST, because `import!` skips a path it has already loaded
%unchanged: three tests sharing one path would import the first one's rows
%three times and the later fixtures never at all.
package_fixture(Name, Body, Path) :-
    packages_artifact(Name, Artifact),
    packages_scratch(Scratch),
    make_directory_path(Scratch),
    atomic_list_concat([Scratch, '/ai-packages-', Name, '.metta'], Path),
    setup_call_cleanup(open(Path, write, Stream),
                       format(Stream, Body, [Artifact]),
                       close(Stream)).

%The artifact's own predicate, which nothing else in the tree defines, so its
%being defined is the observable that must differ if the backing was performed.
%Read through `predicate_property/2` with the module unbound, because the
%importer consults the file into a module this suite does not name.
%
%One artifact and one predicate PER CASE, so the result does not depend on the
%order the cases run in: the tests share an engine, and a positive case that
%loaded a shared artifact would make every later negative case read as a pass
%for the wrong reason.
artifact_loaded(Kind) :-
    atom_concat(packages_, Kind, Prefix),
    atom_concat(Prefix, '_double', Name),
    Head =.. [Name, _, _],
    catch(predicate_property(_:Head, defined), _, fail).

test(a_backing_row_installs_the_head_its_artifact_exports) :-
    package_fixture(backed, '(= (package backing) (prolog "~w" (packages_backed_double)))~n', Path),
    \+ artifact_loaded(backed),
    'import!'('&self', Path, _),
    artifact_loaded(backed),
    packages_backed_double(21, 42).

test(a_file_with_no_backing_row_installs_nothing) :-
    package_fixture(unbacked, '(= (package version) "0.0.1") ; no backing row for ~w~n', Path),
    \+ artifact_loaded(unbacked),
    'import!'('&self', Path, _),
    \+ artifact_loaded(unbacked).

test(a_backing_no_claimant_answers_installs_nothing) :-
    package_fixture(unclaimed, '(= (package backing) (nobody-claims-this "~w" (packages_unclaimed_double)))~n', Path),
    \+ artifact_loaded(unclaimed),
    'import!'('&self', Path, _),
    \+ artifact_loaded(unclaimed).

%Law 1. Written as a clause rather than as an `(internal package)` row every
%library would carry, so it holds in a space nobody declared anything in.
test(the_package_head_is_internal_in_every_space) :-
    metta_engine:metta_reference_internal('&self', package),
    metta_engine:metta_reference_internal('&metta', package),
    metta_engine:metta_reference_internal('a-space-that-was-never-made', package).

:- end_tests(packages).
