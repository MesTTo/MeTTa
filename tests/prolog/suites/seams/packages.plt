% Purpose: gate the package rows the loader performs, and the reservation of
%   the `package` head.
%
% A library used to CALL the importer:
%
%     !(import_prolog_functions_from_file (library lib_x/lib_x.pl) (head ...))
%
% and now DESCRIBES what backs its heads:
%
%     (= (package backing) (prolog "lib_x.pl" (head ...)))
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
%   - an uncovered backing without a claimant refuses by its named head
%     [tested: packages:an_uncovered_backing_without_a_claimant_refuses;
%     commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
%   - `package` is internal in every space, so one library's package rows are
%     never read as its importer's own
%     [tested: packages:the_package_head_is_internal_in_every_space]
%   - a requirement publishes into its importing space even when the native
%     artifact is already loaded elsewhere
%     [tested: packages:a_requirement_loads_before_the_file_that_declares_it;
%     commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
%   - a row reaches its claimant as DATA, so a one-name list is a list and not
%     a nullary call to the name in it
%     [tested: packages:a_backing_row_reaches_its_claimant_as_data]
%   - the claimant resolves its own locator, and the two shapes differ only
%     in the base: `(library dir/x.pl)` is under the library root and a plain
%     `"x.pl"` is beside the manifest carrying it
%     [tested: packages:a_backing_row_resolves_its_library_locator,
%     packages:a_plain_backing_locator_resolves_beside_its_own_manifest]
%   - neither shape can leave the library root, through the two-argument
%     door or the three-argument one that joins to a git-fetched root: a
%     `..` path SEGMENT is refused by name, while a doubled dot INSIDE a
%     name still resolves
%     [tested: packages:a_library_spec_cannot_walk_out_of_the_library_root,
%     packages:a_fetched_library_spec_cannot_walk_out_either,
%     packages:a_doubled_dot_inside_a_name_is_not_an_escape]
%   - a row performs for the file that carries it and for no other load into
%     the same space
%     [tested: packages:a_backing_row_performs_only_for_the_file_that_carries_it]
%   - a row's head list is data, so no head it names becomes a dependency of
%     the `package` equation
%     [tested: packages:importing_a_backed_library_leaves_the_package_head_alone]
%   - a row PUBLISHES the heads it names, so a reader asking what a library
%     declares sees them where the older spelling put them
%     [tested: packages:a_backing_row_publishes_the_heads_it_names]
%   - a row whose head no claim answers is NORMALISED before it is performed,
%     in the home space, under law 3's reads ceiling and inference budget
%     [tested: packages:a_computed_row_normalises_and_then_performs,
%     packages:a_row_reaching_the_filesystem_refuses_by_name,
%     packages:a_row_reading_the_runtime_is_allowed,
%     packages:a_row_that_will_not_reduce_refuses_past_its_budget]
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
                        undepended, computed]),
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
%Ask the importing home's module explicitly. Execution modules are hidden
%from current_module/1 and cannot be discovered through an unbound qualifier.
%
%One artifact and one predicate PER CASE, so the result does not depend on the
%order the cases run in: the tests share an engine, and a positive case that
%loaded a shared artifact would make every later negative case read as a pass
%for the wrong reason.
artifact_loaded(Kind) :-
    atom_concat(packages_, Kind, Prefix),
    atom_concat(Prefix, '_double', Name),
    Head =.. [Name, _, _],
    metta_engine:space_module('&self', Module),
    catch(predicate_property(Module:Head, defined), _, fail), !.

test(a_backing_row_installs_the_head_its_artifact_exports) :-
    package_fixture(backed, '(= (package backing) (prolog "~w" (packages_backed_double)))~n', Path),
    \+ artifact_loaded(backed),
    'import!'('&self', Path, _),
    artifact_loaded(backed),
    eval([packages_backed_double, 21], 42).

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

%The claimant's half of the same law. The mask hands `"x.pl"` over as
%the two-element list it is, and only the claimant knows that is a locator, so
%the claim evaluates it and the engine never does. Without that the importer
%consults `library` and `x.pl` as two separate files and the refusal names
%neither the library nor a path [measured 2026-09-19: source_sink `library\'
%does not exist]. A library nothing holds is what makes the resolved path
%observable, since the refusal quotes the path it tried.
test(a_backing_row_resolves_its_library_locator) :-
    package_fixture(locator,
                    '(= (package backing) (prolog (library \c
                     packages_no_such_library/packages_no_such_library.pl) \c
                     (packages_locator_double)))\n',
                    Path),
    catch('import!'('&self', Path, _), error(Formal, _), true),
    Formal = existence_error(source_sink, Tried),
    sub_atom(Tried, _, _, _,
             'packages_no_such_library/packages_no_such_library.pl').

%The OTHER locator shape, and the one every shipped row uses since the
%manifest became the entry point: a plain filename, resolved beside the
%manifest that carries it rather than under the library root. That is what
%makes a row portable with its own directory, and it is the same base
%Cargo.toml's `path` and package.json's `main` resolve against.
%
%The two shapes differ in exactly one thing, the base they resolve against,
%so the pair above and here is the whole of it: `(library dir/file.pl)` is
%<library root>/dir/file.pl and "file.pl" is <this manifest's directory>/file.pl.
test(a_plain_backing_locator_resolves_beside_its_own_manifest) :-
    package_fixture(plainloc,
                    '(= (package backing) (prolog "packages_no_plain_library.pl" \c
                     (packages_plain_double)))\n',
                    Path),
    catch('import!'('&self', Path, _), error(Formal, _), true),
    Formal = existence_error(source_sink, Tried),
    file_directory_name(Path, Directory),
    directory_file_path(Directory, 'packages_no_plain_library.pl', Beside),
    % Normalised before comparing: the fixture's own path reaches here with the
    % suite's `../../../..` still in it, and the resolver answers the canonical
    % form, so a string comparison of the two fails on spelling rather than on
    % the directory they both name.
    absolute_file_name(Beside, Expected, [access(none)]),
    Tried == Expected.

%A spec is joined to the library root verbatim, so before the guard existed a
%`..` SEGMENT walked straight out of it: (library '../../../../etc/passwd')
%resolved to <lib>/../../../../etc/passwd. A manifest is data a library ships,
%so the spec is not always something this engine wrote.
%
%Nothing shipped uses one. Every spec in the tree is a bare name or a single
%dir/file.pl, which is why refusing costs nothing: reaching a SIBLING library
%is what the bare-name form already does.
%The outcome is named on BOTH paths on purpose. Catching into a bare Formal
%and then unifying it makes the check vacuous: when nothing throws, Formal is
%unbound and the unification BINDS it rather than testing it, so the test
%passes with the guard deleted. This one did, and only the mutation run said
%so.
test(a_library_spec_cannot_walk_out_of_the_library_root) :-
    forall(member(Spec, ['../../../../etc/passwd',
                         '../shared/Helper.metta',
                         'nested/../../escape.metta']),
           ( catch(( metta_engine:library(Spec, Resolved),
                     Outcome = resolved(Resolved) ),
                   error(Formal, _),
                   Outcome = refused(Formal)),
             Outcome == refused(domain_error(library_name, Spec)) )).

%A `from` source is a NAME or a PATH and the spelling decides, so the guard
%above binds names without stopping a program naming a file beside itself. The
%last case is the one that matters: a `..` that does not START the spec is
%still a name, so it still takes the guarded route rather than slipping into
%the path one.
test(a_from_spec_is_a_path_only_when_it_says_so) :-
    forall(member(Spec, ['./fixtures/x', '../fixtures/x', "./fixtures/x"]),
           metta_engine:metta_reference_source_is_path(Spec)),
    forall(member(Spec, [lib_json, 'builtin_mods/skel.pl', 'nested/../escape.metta']),
           \+ metta_engine:metta_reference_source_is_path(Spec)).

%The THREE-argument door is the other route and the worse one: its first
%clause joins the caller's Y to a GIT-FETCHED library's root, which is
%third-party content. Guarding only library/2 left this open, and only
%re-reading the neighbourhood after the first fix found it.
test(a_fetched_library_spec_cannot_walk_out_either) :-
    setup_call_cleanup(
        assertz(metta_engine:git_library_path(packages_fetched_probe,
                                              '/tmp/packages-probe-root')),
        forall(member(Y-Want, ['fast.pl'-resolved,
                               '../../../../etc/passwd'-refused,
                               'a/../../b'-refused]),
               ( catch(( metta_engine:library(packages_fetched_probe, Y, _),
                         Outcome = resolved ),
                       error(domain_error(library_name, _), _),
                       Outcome = refused),
                 Outcome == Want )),
        retract(metta_engine:git_library_path(packages_fetched_probe, _))).

%The guard tests a path SEGMENT, never a substring, because a doubled dot is
%a legal thing to have in a filename. The substring version is the obvious
%one to write and it refuses these, which is how it would be found: by a
%library that simply could not be loaded any more.
test(a_doubled_dot_inside_a_name_is_not_an_escape) :-
    metta_engine:standard_library_path(Base),
    forall(member(Spec-Tail, ['permissive names/foo..bar.metta'
                                  -'permissive names/foo..bar.metta',
                              'a/b..c/d.metta'-'a/b..c/d.metta']),
           ( metta_engine:library(Spec, Path),
             directory_file_path(Base, Tail, Expected),
             Path == Expected )).

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
                    '(= (package backing) (prolog "packages_no_second_library.pl" \c
                     (packages_refusing_double)))\n',
                    Refusing),
    catch('import!'('&self', Refusing, _),
          error(existence_error(source_sink, _), _),
          true),
    package_fixture(afterwards, '(= (package version) "0.0.2")\n', Afterwards),
    'import!'('&self', Afterwards, _).

%A row NAMES the heads its artifact exports, and naming is not calling. What
%makes that true is the RESERVED HEAD it sits under: `package` is fixed by the
%law, so its rows are declarations and hold their payload as data whatever
%arrives later.
%
%It is NOT true of the row's own head being one the translator has nothing to
%compile, which is how this was first written. That test reads a mutable
%condition, "nothing defines this yet", as a permanent one, and applying it to
%every body let an import change what an already-read definition meant
%[measured 2026-09-20; the end-to-end case is
%examples/ch17-concurrency-and-the-loop/11-class_dispatch.metta].
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
    eval([packages_undepended_double, 21], 42),
    \+ ( support_graph:supports(function_view(Module, packages_undepended_double),
                               translated_form(Module, Id)),
         support_graph:support_translated_form_id(Ref, Module, Id),
         clause(Clause, _, Ref),
         strip_module(Clause, _, Bare),
         functor(Bare, package, _) ).

%A row is a REGISTRATION FORM, the fifth metta_registration_names/2 covers.
%The four before it are the importer spellings, and a reader that knows only
%those reports a migrated library as empty of its Prolog-backed heads: the
%reference page read lib_reflect at 21 heads under the old spelling and 12
%after the migration, the nine missing being its own backing row's list
%[measured 2026-09-20].
%
%Read without performing anything, which is what the relation is for: a reader
%asking what a library declares must not load it.
test(a_backing_row_publishes_the_heads_it_names) :-
    Row = ['=', [package, backing],
           [prolog, "somewhere.pl", [packages_named_one, packages_named_two]]],
    metta_engine:metta_registration_names(Row, Named),
    Named == [packages_named_one, packages_named_two].

%A token nobody claims still SAYS which heads it would publish, because which
%tokens exist is the claimants' business rather than this engine's.
test(an_unclaimed_token_still_names_its_heads) :-
    Row = ['=', [package, backing],
           [nobody_claims_this, "somewhere.pl", [packages_named_three]]],
    metta_engine:metta_registration_names(Row, Named),
    Named == [packages_named_three].

%A name list that is not literal claims NOTHING rather than guessing, which is
%the rule the four importer spellings already follow.
test(a_computed_head_list_publishes_nothing) :-
    Row = ['=', [package, backing], [prolog, "somewhere.pl", [car, _Rest]]],
    metta_engine:metta_registration_names(Row, Named),
    Named == [].

%Every constant in a row's shape is RECOGNISED rather than unified into, so an
%atom that merely could be a row is not one. A space holds whatever a file
%wrote, including a bare variable and a form with a variable in head position,
%and a variable unifies with any pattern offered to it: reading one as a row
%carried an unbound payload to check_prolog_function_names/3, which refused
%`a var` where the names belong
%[measured 2026-09-20; the field case is
% lib_import_tokens:static_equations_and_variable_data_remain_inert].
test(an_atom_that_only_resembles_a_row_is_not_one) :-
    \+ filereader:package_row(_, _, _),
    \+ filereader:package_row([_, [package, backing], packages_shape_probe], _, _),
    \+ filereader:package_row(['=', [_, backing], packages_shape_probe], _, _),
    \+ filereader:package_row(['=', [package, _], packages_shape_probe], _, _),
    \+ filereader:package_row(['=', [package, backing], _], _, _),
    filereader:package_row(['=', [package, backing], packages_shape_probe], Kind, Payload),
    Kind == backing,
    Payload == packages_shape_probe.

%Law 3. A row whose head a CLAIM answers is the answer already and is read as
%written; anything else is a term and is evaluated in the home space first. The
%fixture writes the row through an equation of its own, so the payload reaching
%the loader is `(packages-computed-row)`, which no claim answers.
test(a_computed_row_normalises_and_then_performs) :-
    package_fixture(computed,
                    '(= (packages-computed-row) (prolog "~w" (packages_computed_double)))\n\c
                     (= (package backing) (packages-computed-row))\n',
                    Path),
    \+ artifact_loaded(computed),
    'import!'('&self', Path, _),
    artifact_loaded(computed),
    eval([packages_computed_double, 21], 42).

%The ceiling, refusing BY NAME and naming the operation rather than the class:
%`it reads too much` says nothing a writer can act on where `exists_file` names
%the line to move. The filesystem is what law 3 excludes first.
test(a_row_reaching_the_filesystem_refuses_by_name) :-
    package_fixture(ceiling,
                    '(= (packages-ceiling-row) (prolog (exists_file "no-such-file.pl") (packages_ceiling_double)))\n\c
                     (= (package backing) (packages-ceiling-row))\n',
                    Path),
    catch('import!'('&self', Path, _), error(Formal, _), true),
    Formal = permission_error(normalise, package_row, Named),
    memberchk(exists_file, Named).

%And the other side of the same ceiling. Law 2 makes `get-property` the way a
%package reads the runtime facts law 3 allows, and the engine classifies it
%`oracleIO`, so a ceiling written as a bare rank would refuse the one read the
%design provides. It is admitted by name for that reason.
test(a_row_reading_the_runtime_is_allowed) :-
    package_fixture(runtime,
                    '(= (package backing) (prolog (get-property lib version) (packages_runtime_double)))\n',
                    Path),
    catch('import!'('&self', Path, _), error(Formal, _), true),
    ( var(Formal) -> true ; Formal \= permission_error(normalise, package_row, _) ).

%The budget, and the pragma that moves it. A row that will not converge is
%refused rather than hanging the load, and the refusal names the budget so the
%writer can tell "raise it" from "this does not terminate".
test(a_row_that_will_not_reduce_refuses_past_its_budget) :-
    package_fixture(budget,
                    '!(pragma! package-budget 2000)\n\c
                     (= (packages-budget-spin) (packages-budget-spin))\n\c
                     (= (package backing) (packages-budget-spin))\n',
                    Path),
    catch('import!'('&self', Path, _), error(Formal, _), true),
    Formal = resource_error(package_budget).

% Laws 3 and 6 require a named refusal for an unreduced row. The old case
% accepted the missing behavior while coverage had no library implementation.
test(a_row_that_answers_nothing_refuses_by_name) :-
    package_fixture(unreduced,
                    '(= (packages-unreduced-row) (empty))\n\c
                     (= (package backing) (packages-unreduced-row))\n\c
                     (= (packages-unreduced-witness) 42)\n',
                    Path),
    catch('import!'('&self', Path, _), error(Formal, _), true),
    nonvar(Formal),
    Formal = domain_error(package_backing, ['packages-unreduced-row']).

test(a_file_with_no_backing_row_installs_nothing) :-
    package_fixture(unbacked, '(= (package version) "0.0.1") ; no backing row for ~w~n', Path),
    \+ artifact_loaded(unbacked),
    'import!'('&self', Path, _),
    \+ artifact_loaded(unbacked).

test(an_uncovered_backing_without_a_claimant_refuses) :-
    package_fixture(unclaimed, '(= (package backing) (nobody-claims-this "~w" (packages_unclaimed_double)))~n', Path),
    \+ artifact_loaded(unclaimed),
    catch('import!'('&self', Path, _), error(Formal, _), true),
    nonvar(Formal),
    Formal = existence_error(package_backing, [packages_unclaimed_double]),
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

test(a_requirement_loads_before_the_file_that_declares_it,
     [setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    % Native clauses have process lifetime. A fresh space must receive the
    % required source's declarations and callable heads even if another test
    % or importing home already loaded its Prolog artifact.
    library('lib_regex/lib_regex.pl', Native), use_module(Native, []),
    \+ 'get-atoms'(Space, [':', regex_match, _]),
    package_fixture(requires, '(= (package requires) lib_regex) ; not ~w~n', Path),
    'import!'(Space, Path, true),
    once('get-atoms'(Space, [':', regex_match, _])),
    findall(Result, eval([evalc, [regex_match, "^a$", "a"], Space], Result), [true]).

%Law 9. An absent requirement refuses BY NAME. It would otherwise be skipped
%in silence: the catalog match has zero solutions and a `forall/2` over them
%succeeds, so the failure would surface later as a head that does not answer.
test(a_requirement_no_catalog_holds_refuses_by_name) :-
    package_fixture(absent, '(= (package requires) lib_no_catalog_holds_this) ; not ~w~n', Path),
    catch('import!'('&self', Path, _), error(Formal, _), true),
    Formal = existence_error(package_requirement, lib_no_catalog_holds_this).

test(the_catalog_answers_nothing_for_a_library_it_does_not_hold) :-
    \+ eval([match, '&catalogs', [package, lib_no_catalog_holds_this, _], x], _).

%A library is a directory holding a file named after it, so the catalog's
%answer names the stem and the directory is what must be there.
exists_directory_of(Where) :-
    file_directory_name(Where, Directory),
    exists_directory(Directory).

%Law 1. Written as a clause rather than as an `(internal package)` row every
%library would carry, so it holds in a space nobody declared anything in.
test(the_package_head_is_internal_in_every_space) :-
    forall(member(Space, ['&self', '&metta', 'a-space-that-was-never-made']),
           metta_engine:metta_reference_internal(Space, package)).

%Law 1's CONSEQUENCE, which nothing asserted. The case above tests that
%metta_reference_internal/2 HOLDS for `package`, which is the clause existing;
%it never asks whether an importer comes back clean. The reservation was built
%by halves: the NAME is hidden from faces, exports and doors, while the ROW was
%stored by the loader and compiled by store_metta_equation/6, and internal-ness
%is consulted at neither. While a pkg.metta carried
%`!(import_prolog_functions_from_file ...)` directives the gap was unreachable,
%because a directive stores no atom; migrating the manifests to equations made
%it live [measured 2026-09-23: importing lib_spaces and lib_uuid into `&self`
%left 27 atoms where the shipped ruling for spaces_removeallatoms derives 26,
%nine of them identical `(= (package requires) "lib.metta")` rows whose subject
%is the file that carried them and is unrecoverable once merged, and
%`!(package requires)` answered their union instead of refusing].
%
%ONE assertion over any key and TWO packages rather than a case per key: the
%law reserves the HEAD, so a row of any key from any number of packages is the
%same claim, and the second package is what makes the surviving rows
%indistinguishable. One performs (`requires`) and one is inert (`version`), so
%neither the performing path nor a key with no machinery behind it is the
%reason the space is clean.
test(a_manifest_row_does_not_reach_the_importing_space) :-
    package_fixture(no_leak_performed,
        '(= (package version) "1.0.0")\n(= (package requires) lib_pairs)\n', One),
    package_fixture(no_leak_inert, '(= (package version) "2.0.0")\n', Two),
    'import!'('&self', One, _),
    'import!'('&self', Two, _),
    \+ spaces:metta_space_pair('&self', ['=', [package, _], _], _, _),
    findall(Answer, eval([package, version], Answer), Answers),
    Answers == [[package, version]],
    %Retiring the rows retracts their JOURNAL rows with them. Left behind, an
    %erased reference fails this receipt's own `forall` over the load's stored
    %references, and a stale receipt reloads the file on every later import.
    %The journal keys on the CANONICAL path, and package_fixture/3 builds one
    %through `../../../../ai-tmp`, so the receipt must be asked for the name
    %the loader recorded rather than the name the fixture wrote.
    forall(member(Manifest, [One, Two]),
           ( absolute_file_name(Manifest, Canonical),
             filereader:source_load_receipt_current(Canonical, '&self', _, _) )).

%A manifest validates its OWN stored atoms, and a requirement's equations are
%not among them, so before currency became transitive this manifest answered
%current however much of the required file had been taken out of the space:
%the second import! answered True and rebuilt nothing, and the equation stayed
%gone for the rest of the process. Deleting the
%import_nested_sources_current/2 conjunct in import_cache_current/2 fails this
%test at its last line and leaves the other 28 passing.
test(a_removed_equation_comes_back_when_its_manifest_is_imported_again) :-
    package_fixture(nested_content, '(= (nested-probe) 42)\n', Content),
    file_base_name(Content, ContentName),
    format(atom(ManifestBody), '(= (package requires) "~w")\n', [ContentName]),
    package_fixture(nested_manifest, ManifestBody, Manifest),
    'import!'('&self', Manifest, _),
    findall(A, eval(['nested-probe'], A), Before),
    Before == [42],
    eval(['remove-atom', '&self', ['=', ['nested-probe'], 42]], _),
    findall(A, eval(['nested-probe'], A), Removed),
    Removed \== [42],
    'import!'('&self', Manifest, _),
    findall(A, eval(['nested-probe'], A), After),
    After == [42].

:- end_tests(packages).
