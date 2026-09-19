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
%   - a row reaches its claimant as DATA, so a one-name list is a list and not
%     a nullary call to the name in it
%     [tested: packages:a_backing_row_reaches_its_claimant_as_data]
%   - the claimant resolves its own locator, so `(library x.pl)` in a row
%     reaches the importer as the path it names
%     [tested: packages:a_backing_row_resolves_its_library_locator]
%   - a row performs for the file that carries it and for no other load into
%     the same space
%     [tested: packages:a_backing_row_performs_only_for_the_file_that_carries_it]
%   - a row's head list is data, so no head it names becomes a dependency of
%     the `package` equation
%     [tested: packages:importing_a_backed_library_leaves_the_package_head_alone]
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
   forall(member(Kind, [backed, unbacked, unclaimed, requires, absent, declared,
                        undepended]),
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
%Zero or one artifact. Every case that loads one names it in its body through
%`~w`, and the locator case below names a library that does not exist, so it
%has no artifact to name and passes no argument.
package_fixture(Name, Body, Path) :-
    (   packages_artifact(Name, Artifact)
    ->  Arguments = [Artifact]
    ;   Arguments = []
    ),
    packages_scratch(Scratch),
    make_directory_path(Scratch),
    atomic_list_concat([Scratch, '/ai-packages-', Name, '.metta'], Path),
    setup_call_cleanup(open(Path, write, Stream),
                       format(Stream, Body, Arguments),
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

%A row is DATA: the claimant reads the subterms the file WROTE, never what
%they reduce to. The fixture makes the two answers differ by naming its head
%through a nullary equation, so an evaluated row hands the importer the bare
%atom `packages_declared_double` where a list of names belongs and a row kept
%as data hands it `(packages_declared_name)`, which the artifact does not
%export. Both refuse, and WHICH refusal arrives is the observable:
%`existence_error(procedure, packages_declared_name)` names what was written,
%`type_error(list, packages_declared_double)` names what it reduced to
%[measured 2026-09-19, both ways, by removing the Atom mask on `perform`].
%
%What the mask costs in the field, rather than in a fixture: minimal_metta_lib
%names `(unify-mod)` beside `(: unify-mod (-> Atom Atom Atom Atom %Undefined%))`
%and _support/collections names `(collections-expression)` beside its own
%declaration, and ten of the thirteen tests in
%extensions/python/tests/ch19_spaces_backed_by_anything/test_imports.py failed
%with `Type error: `atom\' expected, found `[\'collections-expression\']\'`
%until `perform` carried the mask [measured 2026-09-19].
%
%The older `!(import_prolog_functions_from_file ...)` spelling never needed it:
%translate_prolog_import_dl/5 compiles the name list where the literal sits and
%never evaluates it. A claim body has a variable there instead, which that
%special form passes through untouched, so the mask is what it was.
test(a_backing_row_reaches_its_claimant_as_data) :-
    package_fixture(declared,
                    '(= (packages_declared_name) packages_declared_double)\n\c
                     (= (package backing) (prolog "~w" (packages_declared_name)))\n',
                    Path),
    catch('import!'('&self', Path, _), error(Formal, _), true),
    Formal = existence_error(procedure, packages_declared_name).

%The claimant's half of the same law. The mask hands `(library x.pl)` over as
%the two-element list it is, and only the claimant knows that is a locator, so
%the claim evaluates it and the engine never does. Without that the importer
%consults `library` and `x.pl` as two separate files and the refusal names
%neither the library nor a path [measured 2026-09-19: source_sink `library\'
%does not exist]. A library nothing holds is what makes the resolved path
%observable, since the refusal quotes the path it tried.
test(a_backing_row_resolves_its_library_locator) :-
    package_fixture(locator,
                    '(= (package backing) (prolog (library packages_no_such_library.pl) \c
                     (packages_locator_double)))\n',
                    Path),
    catch('import!'('&self', Path, _), error(Formal, _), true),
    Formal = existence_error(source_sink, Tried),
    sub_atom(Tried, _, _, _,
             'packages_no_such_library/packages_no_such_library.pl').

%Law 14 performs a file's rows AT ONCE, when the file carrying them loads, and
%the rows of one file are no part of the next load into the same space. This
%reads the plainest consequence: a refusing row is refused once, by the import
%that declared it, and a file declaring nothing afterwards still loads.
%
%The performer matched the SPACE until 2026-09-19, so every load re-performed
%every row the space held. N libraries in one space cost N*(N+1)/2 performs
%rather than N, and the refusal below arrived on the next three unrelated
%imports instead of on its own [measured 2026-09-19].
test(a_backing_row_performs_only_for_the_file_that_carries_it) :-
    package_fixture(refusing,
                    '(= (package backing) (prolog (library packages_no_second_library.pl) \c
                     (packages_refusing_double)))\n',
                    Refusing),
    catch('import!'('&self', Refusing, _),
          error(existence_error(source_sink, _), _),
          true),
    package_fixture(afterwards, '(= (package version) "0.0.2")\n', Afterwards),
    'import!'('&self', Afterwards, _).

%A row NAMES the heads its artifact exports, and naming is not calling. The
%body's head is `prolog`, which the translator compiles to a literal, so the
%compiled clause holds the whole row as data and no arrival can turn a name
%inside it into a call.
%
%Recording one anyway made every `package` equation a dependent of every head
%it backs, so performing a row recompiled the `package` head, which carries a
%clause per library in the space. The recompile is a no-op, the clause bodies
%being identical under =@= either side of it, and it made importing N
%Prolog-backed libraries cost O(N*N): per-import cost fitted 702i + 6,438
%inferences and now fits 11i + 5,874, the 11 being the same noise floor a row
%nobody claims reads [measured 2026-09-19].
test(importing_a_backed_library_leaves_the_package_head_alone) :-
    package_fixture(undepended,
                    '(= (package backing) (prolog "~w" (packages_undepended_double)))\n',
                    Path),
    'import!'('&self', Path, _),
    packages_undepended_double(21, 42),
    \+ ( support_graph:supports(function_view(Module, packages_undepended_double),
                               translated_form(Module, Id)),
         support_graph:support_translated_form_id(Ref, Module, Id),
         clause(Clause, _, Ref),
         strip_module(Clause, _, Bare),
         functor(Bare, package, _) ).

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

%Law 10. A requirement names a library and the CATALOGS say where it lives, so
%the loader resolves one by matching and never looks in a directory itself.
test(the_catalog_answers_where_a_library_lives) :-
    eval([match, '&catalogs', [package, lib_regex, Where], Where], _),
    nonvar(Where),
    exists_directory_of(Where).

test(the_catalog_enumerates_only_libraries) :-
    findall(Name, eval([match, '&catalogs', [package, Name, _], Name], _), Names),
    length(Names, Count),
    Count > 1,
    forall(member(Held, Names),
           ( atom(Held), \+ sub_atom(Held, 0, 1, _, '.') )).

test(a_requirement_loads_before_the_file_that_declares_it) :-
    %The observable is the required library's OWN predicate, which nothing
    %else defines, rather than the loader's bookkeeping: the file declares the
    %requirement and imports nothing, so a defined regex_match/3 can only have
    %come from the requirement being performed.
    \+ regex_loaded,
    package_fixture(requires, '(= (package requires) lib_regex) ; not ~w~n', Path),
    'import!'('&self', Path, _),
    regex_loaded.

%Law 9. An absent requirement refuses BY NAME. It would otherwise be skipped
%in silence: the catalog match has zero solutions and a `forall/2` over them
%succeeds, so the failure would surface later as a head that does not answer.
test(a_requirement_no_catalog_holds_refuses_by_name) :-
    package_fixture(absent, '(= (package requires) lib_no_catalog_holds_this) ; not ~w~n', Path),
    catch('import!'('&self', Path, _), error(Formal, _), true),
    Formal = existence_error(package_requirement, lib_no_catalog_holds_this).

test(the_catalog_answers_nothing_for_a_library_it_does_not_hold) :-
    \+ eval([match, '&catalogs', [package, lib_no_catalog_holds_this, _], x], _).

regex_loaded :-
    catch(predicate_property(_:regex_match(_, _, _), defined), _, fail).

%A library is a directory holding a file named after it, so the catalog's
%answer names the stem and the directory is what must be there.
exists_directory_of(Where) :-
    file_directory_name(Where, Directory),
    exists_directory(Directory).

%Law 1. Written as a clause rather than as an `(internal package)` row every
%library would carry, so it holds in a space nobody declared anything in.
test(the_package_head_is_internal_in_every_space) :-
    metta_engine:metta_reference_internal('&self', package),
    metta_engine:metta_reference_internal('&metta', package),
    metta_engine:metta_reference_internal('a-space-that-was-never-made', package).

:- end_tests(packages).
