/* Purpose: prove the boot's claim over the Prolog sources it governs and the
   engine's one door for a runtime-loaded unit, metta_load_source/2: a claimed
   source's artifact is written by a child swipl and this process reads it,
   the first time included; an unclaimed one loads from source and leaves
   nothing behind; a stale artifact is recompiled; a process marked as a
   compile child compiles in place; and the process-tier loaders reach the
   door.
   Assumes: the checkout is writable, so an artifact can be written beside
   lib/lib_datetime/lib_datetime.pl and removed again; each test that makes
   one removes it before and after, and unloads the unit it loaded. A swipl
   the boot can start exists, which is the shipped configuration.
   Guarantees: the claim remains an artifact claim when dev_typed loads the
   engine and this suite with source=true: source=false is scoped to the
   tests' runtime loads, then restored along with library cleanup
   [tested: sh tools/check.sh dev-typed
   dev-typed-selftest prolog; commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d]. The governance follows
   the boot's pattern table and the claim follows the stamped encoding
   [tested: the_boot_governs_the_sources_its_patterns_name,
   an_unstamped_encoding_claims_nothing; commit=5f8a823d23fbed5c7395912a89ba32760e2df4b1]; the door's arms are
   observed through SWI's own load_file(done(...)) message, which says loaded
   for a process that reads the artifact, *qcompiled* for one that writes it
   and compiled for a source load
   [tested: a_claimed_source_is_compiled_by_a_child_and_this_process_reads_the_artifact,
   a_child_marked_process_compiles_in_place,
   an_unclaimed_source_loads_from_source_and_leaves_no_artifact,
   a_stale_artifact_is_recompiled,
   consult_global_loads_a_library_half_through_the_door; commit=5f8a823d23fbed5c7395912a89ba32760e2df4b1]; the
   engine's own set goes through the same child when its umbrella artifact is
   absent, and never in a child-marked process
   [tested: the_engine_set_is_written_by_a_hermetic_child,
   a_child_marked_process_writes_the_engine_set_in_place; commit=5f8a823d23fbed5c7395912a89ba32760e2df4b1].
*/
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(compiled_sources,
               [setup((current_prolog_flag(source, Source),
                       set_prolog_flag(source, false))),
                cleanup(call_cleanup(cs_forget, set_prolog_flag(source, Source)))]).
:- dynamic cs_load_seen/2.

% SWI's own account of how a file was loaded, kept per source stem: the done
% message names the .qlf when the artifact was read and the .pl otherwise.
:- multifile user:message_hook/3.
user:message_hook(load_file(done(_, file(_, Absolute), How, _, _, _)), _, _) :-
    file_name_extension(Stem, _, Absolute),
    assertz(plunit_compiled_sources:cs_load_seen(Stem, How)),
    fail.

cs_loaded_how(File, How) :-
    file_name_extension(Stem, _, File),
    findall(H, retract(cs_load_seen(Stem, H)), Hows),
    Hows = [How|_].

cs_root(Root) :-
    metta_qlf_boot:qlf_boot_directory(Here),
    atom_concat(Here, '/..', Parent),
    absolute_file_name(Parent, Root).

cs_library(File) :-
    cs_root(Root),
    atom_concat(Root, '/lib/lib_datetime/lib_datetime.pl', File).
cs_artifact(Artifact) :-
    cs_root(Root),
    atom_concat(Root, '/lib/lib_datetime/lib_datetime.qlf', Artifact).

cs_forget :-
    cs_library(File),
    ( source_file(File) -> unload_file(File) ; true ),
    cs_artifact(Artifact),
    ( exists_file(Artifact) -> delete_file(Artifact) ; true ),
    retractall(cs_load_seen(_, _)),
    ( current_prolog_flag(metta_qlf_child, true)
    -> set_prolog_flag(metta_qlf_child, false)
    ;  true ).

cs_cost(Goal, Inferences) :-
    statistics(inferences, Before),
    call(Goal),
    statistics(inferences, After),
    Inferences is After - Before.

test(the_boot_governs_the_sources_its_patterns_name) :-
    cs_root(Root),
    atom_concat(Root, '/lib/lib_datetime/lib_datetime.pl', Library),
    atom_concat(Root, '/engine/../lib/lib_datetime/lib_datetime.pl', Dotted),
    atom_concat(Root, '/engine/metta.pl', Umbrella),
    atom_concat(Root, '/engine/metta/interop.pl', Unit),
    atom_concat(Root, '/lib/lib_datetime/deeper/lib_datetime.pl', Deeper),
    atom_concat(Root, '/tests/fixtures/no_autoload_boot.pl', Outside),
    atom_concat(Root, '/lib/lib_datetime/pkg.metta', Program),
    assertion(metta_qlf_boot:qlf_governed_source(Library)),
    assertion(metta_qlf_boot:qlf_governed_source(Dotted)),
    assertion(metta_qlf_boot:qlf_governed_source(Umbrella)),
    assertion(metta_qlf_boot:qlf_governed_source(Unit)),
    assertion(\+ metta_qlf_boot:qlf_governed_source(Deeper)),
    assertion(\+ metta_qlf_boot:qlf_governed_source(Outside)),
    assertion(\+ metta_qlf_boot:qlf_governed_source(Program)).

test(an_unstamped_encoding_claims_nothing,
     [setup(cs_forget), cleanup(( set_prolog_flag(encoding, utf8), cs_forget ))]) :-
    cs_library(Library),
    cs_artifact(Artifact),
    assertion(seam:compiled_source(Library)),
    assertion(exists_file(Artifact)),
    set_prolog_flag(encoding, iso_latin_1),
    assertion(\+ seam:compiled_source(Library)).

test(a_claimed_source_is_compiled_by_a_child_and_this_process_reads_the_artifact,
     [setup(cs_forget), cleanup(cs_forget)]) :-
    cs_library(File),
    cs_artifact(Artifact),
    cs_cost(metta_load_source(user:File, []), First),
    assertion(cs_loaded_how(File, loaded)),
    assertion(exists_file(Artifact)),
    assertion(source_file(File)),
    assertion(current_predicate(lib_datetime:now/1)),
    unload_file(File),
    assertion(\+ current_predicate(lib_datetime:now/1)),
    cs_cost(metta_load_source(user:File, []), Second),
    assertion(cs_loaded_how(File, loaded)),
    assertion(current_predicate(lib_datetime:now/1)),
    % The compile this process never paid: the same load with the artifact
    % gone and no child to write it.
    unload_file(File),
    delete_file(Artifact),
    create_prolog_flag(metta_qlf_child, true, []),
    cs_cost(metta_load_source(user:File, []), Compiled),
    assertion(cs_loaded_how(File, '*qcompiled*')),
    assertion(First < Compiled),
    assertion(Second < Compiled).

test(a_child_marked_process_compiles_in_place,
     [setup(cs_forget), cleanup(cs_forget)]) :-
    cs_library(File),
    cs_artifact(Artifact),
    create_prolog_flag(metta_qlf_child, true, []),
    metta_load_source(user:File, []),
    assertion(cs_loaded_how(File, '*qcompiled*')),
    assertion(exists_file(Artifact)),
    assertion(current_predicate(lib_datetime:now/1)).

test(an_unclaimed_source_loads_from_source_and_leaves_no_artifact) :-
    tmp_file(compiled_source, Directory),
    make_directory(Directory),
    atom_concat(Directory, '/outside.pl', File),
    atom_concat(Directory, '/outside.qlf', Artifact),
    setup_call_cleanup(open(File, write, Out),
                       format(Out, ":- module(cs_outside, [cs_outside/0]).~ncs_outside.~n", []),
                       close(Out)),
    setup_call_cleanup(
        true,
        ( assertion(\+ seam:compiled_source(File)),
          metta_load_source(user:File, []),
          assertion(cs_loaded_how(File, compiled)),
          assertion(current_predicate(cs_outside:cs_outside/0)),
          assertion(\+ exists_file(Artifact)) ),
        ( unload_file(File),
          delete_file(File),
          delete_directory(Directory) )).

test(a_stale_artifact_is_recompiled, [setup(cs_forget), cleanup(cs_forget)]) :-
    cs_library(File),
    cs_artifact(Artifact),
    metta_load_source(user:File, []),
    assertion(cs_loaded_how(File, loaded)),
    time_file(File, SourceTime),
    Older is SourceTime - 100,
    set_time_file(Artifact, _, [modified(Older)]),
    unload_file(File),
    metta_load_source(user:File, []),
    assertion(cs_loaded_how(File, loaded)),
    time_file(Artifact, Rewritten),
    assertion(Rewritten >= SourceTime).

cs_umbrella_artifact(Artifact) :-
    metta_qlf_boot:qlf_boot_directory(Here),
    atom_concat(Here, '/metta.qlf', Artifact).

% The engine this process runs is already in memory, so its umbrella artifact
% can go and come back without touching a loaded clause.
cs_restore_engine_set :-
    ( current_prolog_flag(metta_qlf_child, true)
    -> set_prolog_flag(metta_qlf_child, false)
    ;  true ),
    metta_qlf_boot:qlf_boot_directory(Here),
    metta_qlf_boot:qlf_regenerate_aside(Here),
    retractall(cs_load_seen(_, _)).

test(the_engine_set_is_written_by_a_hermetic_child, [cleanup(cs_restore_engine_set)]) :-
    cs_umbrella_artifact(Artifact),
    metta_qlf_boot:qlf_boot_directory(Here),
    delete_file(Artifact),
    retractall(cs_load_seen(_, _)),
    metta_qlf_boot:qlf_regenerate_aside(Here),
    assertion(exists_file(Artifact)),
    % this process loaded nothing: the child did the compiling
    assertion(\+ cs_load_seen(_, _)).

test(a_child_marked_process_writes_the_engine_set_in_place,
     [cleanup(cs_restore_engine_set)]) :-
    cs_umbrella_artifact(Artifact),
    metta_qlf_boot:qlf_boot_directory(Here),
    delete_file(Artifact),
    create_prolog_flag(metta_qlf_child, true, []),
    metta_qlf_boot:qlf_regenerate_aside(Here),
    assertion(\+ exists_file(Artifact)).

test(consult_global_loads_a_library_half_through_the_door,
     [setup(cs_forget), cleanup(cs_forget)]) :-
    cs_library(File),
    cs_artifact(Artifact),
    consult_global(File),
    assertion(cs_loaded_how(File, loaded)),
    assertion(exists_file(Artifact)),
    assertion(current_predicate(lib_datetime:now/1)).

:- end_tests(compiled_sources).
