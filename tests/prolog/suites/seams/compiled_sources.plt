/* Purpose: prove the boot's claim over the Prolog sources it governs and the
   engine's one door for a runtime-loaded unit, metta_load_source/2: a claimed
   source's artifact is written by a child swipl and this process reads it,
   the first time included; an unclaimed one loads from source and leaves
   nothing behind; a stale artifact is recompiled; a process marked as a
   compile child compiles in place; and the process-tier loaders reach the
   door.
   Assumes: a swipl the boot can start exists, which is the shipped
   configuration. The shared tree's lib/lib_conformance artifact is current,
   or the checkout is writable so the claim's child can write it, since the
   conformance kit test reads that artifact on the shared tree. The scratch
   parent, scratch_parent/1, has room for a copy of engine/ and lib/ without
   their artifacts [measured 2026-09-25T15:22:20+10:00: 383 files, 13.3 MB].
   Guarantees: every test that deletes, backdates or regenerates an artifact
   runs in the second unit, compiled_sources_private_tree, against that copy,
   so this suite writes no artifact in the tree the other suites and a
   concurrent twins lane boot from [measured 2026-09-25T15:22:20+10:00: two plunit runs
   over a warmed set rewrote, deleted and re-timed none of its artifacts].
   Run on the shared tree, a_stale_artifact_is_recompiled's backdate of
   lib_datetime.qlf made the next boot purge every governed artifact, and the
   suites then rewrote the 41 they import on every plunit run
   [measured 2026-09-25T04:06:21+10:00: strace -f of a plunit run]. The claim
   remains an artifact claim when dev_typed loads the engine and this suite
   with source=true: each unit scopes source=false to its tests' runtime loads
   and restores it [tested 2026-09-25T15:34:15+10:00: sh tools/check.sh dev-typed]. The
   governance follows the boot's pattern table and the claim follows the
   stamped encoding [tested 2026-09-25T15:34:15+10:00:
   the_boot_governs_the_sources_its_patterns_name,
   an_unstamped_encoding_claims_nothing]. The door's arms are observed through
   SWI's own load_file(done(...)) message, which says loaded for a process that
   reads the artifact, *qcompiled* for one that writes it and compiled for a
   source load [tested 2026-09-25T15:34:15+10:00:
   a_claimed_source_is_compiled_by_a_child_and_this_process_reads_the_artifact,
   a_child_marked_process_compiles_in_place,
   an_unclaimed_source_loads_from_source_and_leaves_no_artifact,
   a_stale_artifact_is_recompiled,
   consult_global_loads_a_library_half_through_the_door]. The engine's own set
   goes through the same child when its umbrella artifact is absent, and never
   in a child-marked process [tested 2026-09-25T15:34:15+10:00:
   the_engine_set_is_written_by_a_hermetic_child,
   a_child_marked_process_writes_the_engine_set_in_place]. The conformance kit,
   a runtime-loaded half, loads through the door and reads its artifact
   [tested 2026-09-25T15:34:15+10:00: the_conformance_kit_loads_through_the_door]. Three
   things are proved elsewhere, by
   extensions/python/tests/repository/test_library_halves.py: the first and
   later processes and the child's nested closure, because each takes more
   than one process; and the child being the running home's own swipl,
   because only an embedding's executable flag can name another build, and in
   a standalone swipl the two rules pick the same binary.
   Owns resources: the second unit's copy, made by its setup and deleted with
   its contents by its cleanup, which also points
   metta_qlf_boot:qlf_boot_directory/1 back at the shared tree; each test that
   writes an artifact removes it before and after, and unloads the unit it
   loaded.
*/
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../scratch.pl').
:- use_module(library(filesex), [directory_file_path/3, set_time_file/3,
                                 copy_file/2, delete_directory_and_contents/1]).

% Everything but the tests is defined here, in this file's module, which both
% units inherit from. A unit that ran retractall/1 on the load record below
% would create an empty cs_load_seen/2 of its own, and the check after it,
% \+ cs_load_seen(_, _), would then hold whatever had been loaded.

:- dynamic cs_load_seen/2.

% SWI's own account of how a file was loaded, kept per source stem: the done
% message names the .qlf when the artifact was read and the .pl otherwise.
:- multifile user:message_hook/3.
user:message_hook(load_file(done(_, file(_, Absolute), How, _, _, _)), _, _) :-
    file_name_extension(Stem, _, Absolute),
    assertz(cs_load_seen(Stem, How)),
    fail.

cs_loaded_how(File, How) :-
    file_name_extension(Stem, _, File),
    findall(H, retract(cs_load_seen(Stem, H)), Hows),
    Hows = [How|_].

cs_forget_loads :- retractall(cs_load_seen(_, _)).
cs_loaded_nothing :- \+ cs_load_seen(_, _).

% The tree the boot governs, which is the copy while the second unit runs.
cs_root(Root) :-
    metta_qlf_boot:qlf_boot_directory(Here),
    atom_concat(Here, '/..', Parent),
    absolute_file_name(Parent, Root).

cs_kit(Kit) :-
    cs_root(Root),
    atom_concat(Root, '/lib/lib_conformance/lib_conformance.pl', Kit).

cs_unload_kit :-
    cs_kit(Kit),
    ( source_file(Kit) -> unload_file(Kit) ; true ),
    cs_forget_loads.

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
    cs_forget_loads,
    ( current_prolog_flag(metta_qlf_child, true)
    -> set_prolog_flag(metta_qlf_child, false)
    ;  true ).

cs_cost(Goal, Inferences) :-
    statistics(inferences, Before),
    call(Goal),
    statistics(inferences, After),
    Inferences is After - Before.

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
    cs_forget_loads.

% The copy the second unit's tests write. Every path the claim, the purge and
% the compile child use derives from qlf_boot_directory/1 (engine/qlf_boot.pl):
% the child boots through <Here>/qlf_boot.pl, whose load purges and stamps the
% set under <Here>/.. and nowhere else. So moving that one fact to the copy's
% boot directory moves every artifact these tests delete, backdate or
% regenerate out of the shared tree. Go's own tests of its build cache's
% staleness run the same way, against a fresh GOCACHE=$WORK/cache
% [source 2026-09-25T04:34:00+10:00: https://github.com/golang/go/blob/f30a9b3490f8c6ffa6e2a492dcc4523df9769adc/src/cmd/go/testdata/script/mod_stale.txt].
% The roots copied are the top-level directories the boot's own pattern table
% names, engine/ and lib/ today, so the copy holds everything a child's boot
% and the purge read and follows the table when it changes. A setup that cannot
% finish removes what it made, because plunit runs no cleanup for a unit whose
% setup raised.
cs_enter_private_tree(Shared, Private) :-
    metta_qlf_boot:qlf_boot_directory(Shared),
    cs_root(Root),
    setof(Top, Kind^Pattern^Parts^( metta_qlf_boot:qlf_pattern(Kind, Pattern),
                                    atomic_list_concat(Parts, '/', Pattern),
                                    Parts = [Top|_] ),
          Tops),
    make_scratch_directory(compiled_sources, Private),
    catch(forall(member(Top, Tops),
                 ( directory_file_path(Root, Top, From),
                   directory_file_path(Private, Top, To),
                   cs_copy_tree(From, To) )),
          Error,
          ( delete_directory_and_contents(Private), throw(Error) )),
    file_base_name(Shared, Boot),
    directory_file_path(Private, Boot, Here),
    retract(metta_qlf_boot:qlf_boot_directory(Shared)),
    assertz(metta_qlf_boot:qlf_boot_directory(Here)).

% cs_forget/0 runs first because it names lib_datetime by the boot's root: run
% after the root is put back, it would delete the shared tree's artifact.
cs_leave_private_tree(Shared, Private) :-
    call_cleanup(cs_forget,
                 ( retractall(metta_qlf_boot:qlf_boot_directory(_)),
                   assertz(metta_qlf_boot:qlf_boot_directory(Shared)),
                   delete_directory_and_contents(Private) )).

% A copy of a tree other suites write while this one reads it, keeping each
% file's modification time, because lib/_support/native_build.pl keeps a
% native half only while it is at least as new as its inputs, and a copy
% stamped in copy order would rebuild any half copied before its C source. The
% time kept is floored to the second, which is what set_time_file/3 writes
% [measured 2026-09-25T04:35:10+10:00: strace of the copy, utimensat with
% tv_nsec=0 for a source whose mtime ends .967487]. That comparison and the
% purge's are >=, which a floor preserves, and qlf_artifact_stale/2's strict
% one only meets artifacts the copy's children write after it, since none is
% copied. An entry that vanished between the listing and its copy, a native
% build's staged object renamed into place, say, is skipped, as rsync skips a
% file that vanished on the sending side and reports it as a warning rather
% than an error
% [source 2026-09-25T04:34:00+10:00: https://github.com/RsyncProject/rsync/blob/912644c94d68c7716c68fb06e6538120c8dcbaec/log.c,
% "VANISHED is not an error, only a warning"]. Any other error is raised.
% Time: one read and one write of every byte copied, 13.3 MB in 383 files here.
cs_copy_tree(From, To) :-
    make_directory(To),
    directory_files(From, Names),
    forall(( member(Name, Names), \+ cs_left_out(Name) ),
           ( directory_file_path(From, Name, Source),
             directory_file_path(To, Name, Target),
             catch(cs_copy_entry(Source, Target), Error,
                   ( cs_vanished(Error, Source) -> true ; throw(Error) )) )).

cs_copy_entry(Source, Target) :-
    (   exists_directory(Source)
    ->  cs_copy_tree(Source, Target)
    ;   time_file(Source, Modified),
        copy_file(Source, Target),
        set_time_file(Target, _, [modified(Modified)])
    ).

cs_vanished(error(existence_error(_, _), _), Source) :-
    \+ exists_file(Source),
    \+ exists_directory(Source).

% Left out: whatever the boot writes, so the copy starts with no artifact for a
% test to find (every name holding .qlf: an artifact, SWI's in-flight
% .<name>.qlf.<pid>, the stamp and its .tmp), and two things no load reads that
% other lanes write while this one copies, Python's bytecode and a nested
% repository's metadata.
cs_left_out('.').
cs_left_out('..').
cs_left_out('__pycache__').
cs_left_out('.git').
cs_left_out(Name) :- sub_atom(Name, _, _, _, '.qlf').

:- begin_tests(compiled_sources,
               [setup((current_prolog_flag(source, Source),
                       set_prolog_flag(source, false))),
                cleanup(set_prolog_flag(source, Source))]).

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

% On the shared tree, because the engine names the kit by its own library root
% (ensure_conformance_kit/0 in engine/metta/interop.pl), which the second
% unit's move of the boot's root does not reach. Once the kit's artifact is
% current it only reads.
test(the_conformance_kit_loads_through_the_door,
     [setup(cs_unload_kit), cleanup(cs_unload_kit)]) :-
    cs_kit(Kit),
    metta_engine:ensure_conformance_kit,
    assertion(cs_loaded_how(Kit, loaded)),
    predicate_property(lib_conformance:metta_check_space_provider(_, _),
                       number_of_clauses(Clauses)),
    assertion(Clauses > 0).

:- end_tests(compiled_sources).

:- begin_tests(compiled_sources_private_tree,
               [setup((cs_enter_private_tree(Shared, Private),
                       current_prolog_flag(source, Source),
                       set_prolog_flag(source, false))),
                cleanup(call_cleanup(cs_leave_private_tree(Shared, Private),
                                     set_prolog_flag(source, Source)))]).

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

test(the_engine_set_is_written_by_a_hermetic_child, [cleanup(cs_restore_engine_set)]) :-
    cs_umbrella_artifact(Artifact),
    metta_qlf_boot:qlf_boot_directory(Here),
    delete_file(Artifact),
    cs_forget_loads,
    metta_qlf_boot:qlf_regenerate_aside(Here),
    assertion(exists_file(Artifact)),
    % this process loaded nothing: the child did the compiling
    assertion(cs_loaded_nothing).

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

:- end_tests(compiled_sources_private_tree).
