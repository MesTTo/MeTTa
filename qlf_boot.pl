% Purpose: decide Quick Load Format freshness for the engine tree before
%   any engine file loads, then LOAD the engine under that regime: purge
%   every engine and lib .qlf when any source is newer than any of them or
%   when the .qlf set was written by a different SWI version, and hand every
%   host one qlf_load_engine/0 that consults the umbrella under
%   qcompile(auto), and claim, through seam:compiled_source/1, every Prolog
%   source of that set for the engine's runtime loaders, so a library's
%   Prolog half compiles beside itself on its first import and loads from
%   the artifact in every process after. Exports nothing and lives in its
%   own module for user-surface hygiene; note that ANY boot-content change, however
%   inert, can move a twin's pinned inference count by a few tens
%   through SWI's clause-indexing shape (the benchmark ledger records
%   inert facts moving counts non-monotonically the same way), which is
%   why twin budgets are pinned on the exact shipping tree [measured
%   2026-08-25: examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta reads 2838 without this
%   file loaded and 2878 with it, under source and .qlf boots alike,
%   with user-predicate count, the stamp file, and .qlf presence each
%   ruled out by A/B].
% Assumes:
%   - autoload may be OFF (tests/fixtures/no_autoload_boot.pl). The inventory
%     and freshness predicates depend only on builtins; qlf_load_engine/0
%     explicitly loads identity.pl and source_loading.pl before the engine
%     [tested: sh check.sh qlf-freshness no-autoload; commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d].
% Guarantees:
%   - a missing runtime source or failed extension directive raises a named
%     load error after restoring the loader's source module
%     [tested: tests/shell/test_packaged_cli.sh; commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d].
%   - an edit to ANY engine or lib source, unit files included, defeats
%     every .qlf on the next boot: SWI's own staleness check covers a
%     .qlf's immediate source only, and the engine's units are consulted
%     by umbrellas, so a unit edit leaves the umbrella's .qlf fresh by
%     mtime and would serve the OLD code [measured 2026-08-25: a fact
%     appended to engine/translator/lowering.pl was invisible on the next
%     boot until this purge ran].
%   - a read-only tree stays correct: delete_file failures are absorbed,
%     SWI falls back to source for absent .qlf, and qlf_load_engine/0 writes
%     nothing and says nothing
%     [tested: test_a_read_only_engine_tree_boots_from_source;
%     commit=48b6cb4eea09e6f2f9637c7186e77c628d61b7e3].
%   - every host loads the engine the same way, through qlf_load_engine/0:
%     engine/main.pl and the C host in extensions/cmetta/cmetta.c call the
%     one predicate, so the compiled regime and its recovery have one
%     implementation rather than a copy per host, and the engine a
%     .qlf boot exposes is the engine a source boot exposes
%     [tested: test_the_compiled_boot_is_the_same_engine;
%     commit=48b6cb4eea09e6f2f9637c7186e77c628d61b7e3].
%   - the engine reads its own sources and writes its own output as UTF-8
%     whatever the ambient locale says, and a .qlf set compiled under a
%     different encoding is purged rather than served
%     [tested: tests/shell/test_engine_text_encoding.sh; commit=bdb032a457597ef3b4a1e0d872f66f76bad362e4].
%   - a runtime-loaded source inside the governed set (engine/*.pl,
%     engine/*/*.pl, lib/*.pl, lib/*/*.pl) is claimed for compilation beside
%     itself, and one outside it, or any source while the encoding flag is
%     not the stamped utf8, is not claimed
%     [tested: the_boot_governs_the_sources_its_patterns_name,
%     an_unstamped_encoding_claims_nothing; commit=f26de01fbf3e0e3c64bb691c66a59fa959fee7f3].
%   - a claimed source whose artifact is absent or stale is compiled by a
%     child swipl before the claiming process loads it, so that process reads
%     the artifact and never the compile; a process marked as such a child
%     compiles in place
%     [tested: a_claimed_source_is_compiled_by_a_child_and_this_process_reads_the_artifact,
%     a_stale_artifact_is_recompiled, a_child_marked_process_compiles_in_place;
%     commit=5f8a823d23fbed5c7395912a89ba32760e2df4b1].
%   - the engine's own set is written by the same hermetic child (-f none,
%     --no-packs) when a boot finds it absent, so no process's flags,
%     initialisation file or packs shape an artifact the tree shares
%     [tested: the_engine_set_is_written_by_a_hermetic_child,
%     a_child_marked_process_writes_the_engine_set_in_place; commit=5f8a823d23fbed5c7395912a89ba32760e2df4b1].
% Decides:
%   - artifacts are written only inside the set this file stamps and purges:
%     a program's own Prolog file, or a library under a registered or
%     git-fetched directory, loads from source, because an artifact beside
%     it would outlive the SWI version and the encoding that wrote it with
%     no boot to notice.
%   - freshness is transitive and coarse, the whole set against the
%     newest source: a false purge costs one ~0.25s generating boot; a
%     false keep would run stale engine code under a green-looking gate.
%   - the engine's text encoding is its own, not the operator's: sources,
%     the MeTTa corpus and the verdict marks are UTF-8 by construction, so
%     a C locale gets UTF-8 output it may render as mojibake rather than
%     an ASCII stream that escapes the marks the corpus greps for.
:- module(metta_qlf_boot, []).

%The engine's text encoding is UTF-8 by construction, not by locale. Six
%engine and lib sources carry non-ASCII content (the test verdict marks in
%metta/runtime.pl among them) and the whole MeTTa corpus is UTF-8, but SWI
%derives its default file encoding from setlocale(), so a boot with LANG
%unset reads those bytes as invalid and compiles each one to U+FFFD. The
%artifact then OUTLIVES the locale: the .qlf set is written with the
%replaced atoms, its mtime is newer than every source, and every later boot
%under a correct locale loads the poisoned compile and prints three
%replacement characters where the check mark belongs [measured 2026-08-26:
%one `LC_ALL=C swipl -s engine/main.pl` boot on a purged tree, then an
%ordinary run of examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/01-measure.metta, which read `. \357\277\275 x3`
%against the source's intact `. \342\234\205`; sixteen verdict lines and
%the whole pytest example lane failed on artifacts alone]. Three files
%already carried their own `:- encoding(utf8).`, which is the same fix
%applied one file at a time; this is that fix at the boot, where it covers
%every file including the ones a later commit adds.
%Workaround: swi-locale-default-encoding - the encoding flag and both
%standard streams are pinned to UTF-8 before any file loads, and the
%artifact stamp carries the encoding so a set compiled under another one
%is purged.
:- set_prolog_flag(encoding, utf8).

%The standard streams take the same pinning, because an ASCII output stream
%does not fail, it ESCAPES: the same run under LC_ALL=C with a CORRECT .qlf
%printed the six-character escape backslash-u-2-7-0-5 where test.sh and the
%pytest example lane grep for the mark itself, so the corpus's own verdict
%scan reads every passing check as absent. A host that hands the engine a
%stream it may not reconfigure keeps its own, which is why the failure is
%absorbed rather than aborting a boot.
%
%This file stays pure ASCII on purpose: it is READ before the flag it sets
%takes effect, so a non-ASCII character here would be the one thing the fix
%cannot protect.
:- catch(( set_stream(user_output, encoding(utf8)),
           set_stream(user_error, encoding(utf8)) ), _, true).

qlf_glob_files(Here, Pattern, Files) :-
    atom_concat(Here, '/../', Root),
    atom_concat(Root, Pattern, Glob),
    expand_file_name(Glob, Files).

qlf_member(F, [F|_]).
qlf_member(F, [_|T]) :- qlf_member(F, T).

%The set this file governs, as one table: the Prolog sources whose artifacts
%it stamps and purges, and the other inputs (the corpus the engine reads at
%boot, the C beside its .pl) whose edit stales the set. The artifact globs
%derive from the Prolog rows, and seam:compiled_source/1 below reads the same
%rows, so what is purged, what stales, and what the engine may compile at
%runtime cannot disagree.
qlf_pattern(prolog, 'engine/*.pl').
qlf_pattern(prolog, 'engine/*/*.pl').
qlf_pattern(prolog, 'lib/*.pl').
qlf_pattern(prolog, 'lib/*/*.pl').
qlf_pattern(input, 'engine/*.metta').
qlf_pattern(input, 'engine/*.c').

qlf_artifact_pattern(Artifact) :-
    qlf_pattern(prolog, Source),
    atom_concat(Stem, '.pl', Source),
    atom_concat(Stem, '.qlf', Artifact).

qlf_files(Here, Files) :-
    findall(F, ( qlf_artifact_pattern(Pattern),
                 qlf_glob_files(Here, Pattern, Fs),
                 qlf_member(F, Fs) ),
            Files).

qlf_source_newest(Here, Newest) :-
    findall(T, ( qlf_pattern(_, Pattern),
                 qlf_glob_files(Here, Pattern, Fs),
                 qlf_member(F, Fs),
                 catch(time_file(F, T), _, fail) ),
            Times),
    qlf_time_max(Times, 0, Newest).

%What the engine's runtime loaders ask before compiling a source beside
%itself (engine/metta/interop.pl, metta_load_source/2): is it inside the set
%above, under the encoding the stamp records. The path is canonicalised
%first, because the engine names its library root as <engine>/../lib and a
%pattern cannot see through the dots; then it is matched segment by segment,
%the way expand_file_name/2 reads the same pattern: a star matches inside one
%directory level and never across a slash, so a source two levels under lib/
%is claimed by no row here and purged by no glob above, consistently. The
%answer is a claim (an ownership seam, engine/ext_points.pl): a process that
%never loaded this file has no clause and claims nothing, so it loads every
%runtime source from source and writes no artifact the stamp would not know.
%Every governed Prolog source's artifact brought up to date, aside, from one
%booted process: what a measurement lane runs once before its first measured
%child, so no child pays a library half's compile or the aside check for it.
%The boot's own child regenerates the engine set; a library half otherwise
%compiles at its first import, inside whichever process that is
%[tested: extensions/python/tests/repository/test_twin_coverage.py::test_a_measurement_warms_stale_artifacts_once_per_process;
%commit=bde3d297922bcef86e840361749bced147323977].
qlf_compile_claimed :-
    qlf_boot_directory(Here),
    forall(( qlf_pattern(prolog, Pattern),
             qlf_glob_files(Here, Pattern, Files),
             qlf_member(File, Files) ),
           qlf_compile_aside(File)).

qlf_governed_source(File) :-
    qlf_boot_directory(Here),
    atom_concat(Here, '/..', Parent),
    absolute_file_name(Parent, Root),
    atom_concat(Root, '/', RootSlash),
    absolute_file_name(File, Canon),
    atom_concat(RootSlash, Relative, Canon),
    qlf_pattern(prolog, Pattern),
    qlf_path_matches(Pattern, Relative),
    !.

qlf_path_matches(Pattern, Path) :-
    atomic_list_concat(PatternParts, '/', Pattern),
    atomic_list_concat(PathParts, '/', Path),
    qlf_segments_match(PatternParts, PathParts).

qlf_segments_match([], []).
qlf_segments_match([P|Ps], [S|Ss]) :-
    wildcard_match(P, S),
    qlf_segments_match(Ps, Ss).

:- multifile seam:compiled_source/1.
seam:compiled_source(File) :-
    current_prolog_flag(encoding, utf8),
    qlf_governed_source(File),
    qlf_compile_aside(File).

%A claimed source whose artifact is absent or older than it is compiled by a
%CHILD swipl before this process loads it, so the compile's inferences land
%in no measurement of this process: every importer of a library reads the
%same count, the first one included. Without this the first importer after
%a purge paid the compile, and a lane that prices processes read that one
%process apart from the rest: the twins lane's combinatorics example read
%97,944 inferences in the run that wrote lib_combinatorics.qlf and 75,810
%in every other [measured 2026-09-09: two consecutive
%extensions/python/tools/twin_coverage.py runs on one tree]. The child boots
%the engine through this file, because a library half compiles under the
%engine's goal expansion and the artifact a bare swipl would write is not
%the one the engine loads, then qcompiles the one file its command line
%names; the metta_qlf_child flag it raises first keeps its own boot from
%asking a grandchild for the vocabulary seed. A tree the child may not
%write, a host with no swipl to start, or a child that fails, leave the load
%to SWI's own rule, which compiles in this process as before; the claim
%holds either way, because the file is governed either way.
qlf_compile_aside(File) :-
    (   qlf_artifact_stale(File, Artifact),
        access_file(Artifact, write),
        \+ current_prolog_flag(metta_qlf_child, true)
    ->  qlf_child('metta_qlf_boot:qlf_compile_argument', [File])
    ;   true
    ).

%The child is HERMETIC: -f none reads no user initialisation file and
%--no-packs attaches no add-on, so nothing a developer's own SWI setup loads
%can shape a clause of an artifact every process on the tree will run (a
%pack or an initialisation file can install term or goal expansion). Its
%status is the caller's only reading; a child that cannot be started reads
%as a failed one, and the caller's load then compiles in place.
qlf_child(Goal, Arguments) :-
    (   qlf_swipl(Swipl)
    ->  qlf_boot_directory(Here),
        atom_concat(Here, '/qlf_boot.pl', Boot),
        qlf_shell_word(Swipl, QuotedSwipl),
        qlf_shell_word(Boot, QuotedBoot),
        qlf_shell_words(Arguments, QuotedArguments),
        atomic_list_concat([QuotedSwipl, ' -q -f none --no-packs -s ', QuotedBoot,
                            ' -g ', Goal, ' -t halt --', QuotedArguments,
                            ' >/dev/null 2>&1'],
                           Command),
        catch(shell(Command, _), _, true)
    ;   true
    ).

qlf_shell_words([], '').
qlf_shell_words([Argument|Arguments], Words) :-
    qlf_shell_word(Argument, Word),
    qlf_shell_words(Arguments, Rest),
    atomic_list_concat([' ', Word, Rest], Words).

%system: on exists_file/1, because the engine exports a MeTTa builtin of that
%name and arity into user, which this module's chain reaches once the engine
%has loaded, and the boot depends on nothing of the engine's.
qlf_artifact_stale(File, Artifact) :-
    atom_concat(Stem, '.pl', File),
    atom_concat(Stem, '.qlf', Artifact),
    (   system:exists_file(Artifact)
    ->  time_file(File, Source),
        time_file(Artifact, Written),
        Source > Written
    ;   true
    ).

%The executable flag names the real swipl in a standalone process and in an
%embedding (janus reports /usr/lib/swi-prolog/bin/x86_64-linux/swipl for a
%Python process); a C host may report itself, and SWI's own install layout,
%<home>/bin/<arch>/swipl, is the next answer. The bare name is the last, and
%the shell's failure to find it reads as a failed child.
qlf_swipl(Swipl) :-
    current_prolog_flag(executable, Swipl),
    file_base_name(Swipl, Base),
    qlf_member(Base, [swipl, 'swipl.exe']),
    !.
qlf_swipl(Swipl) :-
    current_prolog_flag(home, Home),
    current_prolog_flag(arch, Arch),
    atomic_list_concat([Home, '/bin/', Arch, '/swipl'], Swipl),
    system:exists_file(Swipl),
    !.
qlf_swipl(swipl).

%POSIX single quoting, the one form that carries any path unchanged: the
%text goes between apostrophes and an apostrophe inside it becomes '\''.
qlf_shell_word(Text, Word) :-
    atomic_list_concat(Parts, '\'', Text),
    atomic_list_concat(Parts, '\'\\\'\'', Joined),
    atomic_list_concat(['\'', Joined, '\''], Word).

%The child's whole job: raise the flag that says so, boot the engine the way
%every host does, and compile the one file its command line names beside
%itself. Its output is discarded by the parent and its status is the
%parent's only reading, and a failure to compile is the next load's to
%report, loudly, in the process that asked.
qlf_compile_argument :-
    create_prolog_flag(metta_qlf_child, true, []),
    current_prolog_flag(argv, Argv),
    qlf_last(Argv, File),
    qlf_load_engine,
    qcompile(File).

%The engine's own set is written by a child for the same reason a library
%half is: the first process to boot after a purge compiled it in place, under
%whatever flags, initialisation file and packs that process ran with, and
%every process after ran that process's engine. A boot that finds the
%umbrella's artifact absent asks a hermetic child to boot first, which
%compiles the set in place because it IS the child, then loads what the child
%wrote. A read-only tree, no swipl to start, or a failed child leave this
%process to compile in place, as before, and a child-marked process never
%asks.
qlf_regenerate_aside(Here) :-
    atom_concat(Here, '/metta.qlf', UmbrellaArtifact),
    (   \+ system:exists_file(UmbrellaArtifact),
        access_file(UmbrellaArtifact, write),
        \+ current_prolog_flag(metta_qlf_child, true)
    ->  qlf_child('metta_qlf_boot:qlf_child_boot', [])
    ;   true
    ).

qlf_child_boot :-
    create_prolog_flag(metta_qlf_child, true, []),
    qlf_load_engine.

qlf_last([File], File) :- !.
qlf_last([_|Rest], File) :- qlf_last(Rest, File).

qlf_time_max([], Acc, Acc).
qlf_time_max([T|Ts], Acc, Max) :-
    ( T > Acc -> qlf_time_max(Ts, T, Max) ; qlf_time_max(Ts, Acc, Max) ).

%The stamp carries the ENCODING beside the version, because the two spoil a
%.qlf set the same way and neither shows up in an mtime: a set compiled
%while the flag read something other than utf8 holds replacement characters
%for every non-ASCII atom, and its files are newer than every source. Both
%are read back by unification against the live values, so a set written
%before this field existed carries a one-argument term, fails to unify, and
%is purged once - which is how a tree already poisoned repairs itself on its
%next boot rather than needing a hand purge.
qlf_stamp_ok(StampFile) :-
    current_prolog_flag(version, V),
    current_prolog_flag(encoding, Enc),
    catch(setup_call_cleanup(open(StampFile, read, In),
                             read(In, qlf_stamp(V, Enc)),
                             close(In)),
          _, fail).

%Written ONLY when absent or wrong, and atomically (a sibling of the
%boot may be reading it at any moment: the lane runs 32 engine boots at
%once). The first cut truncate-rewrote the stamp on every boot, so a
%concurrent reader could catch it mid-truncate, fail the check, and
%purge the whole .qlf set while its siblings were mid-load: one twin in
%a ten-round lane died with Unknown procedure: metta_symbol_writable/1
%out of a half-regenerated engine, and 129 twins picked up one-round
%count outliers from mixed source-and-qlf boots [measured 2026-08-25,
%tools/twin_coverage.py --observe --rounds 10]. rename/2 is atomic on
%POSIX, so a reader now sees the old stamp or the new one, never a
%partial; and an unchanged stamp is never rewritten, so the steady
%state has no write at all.
qlf_write_stamp(StampFile) :-
    (   qlf_stamp_ok(StampFile)
    ->  true
    ;   current_prolog_flag(version, V),
        current_prolog_flag(encoding, Enc),
        atom_concat(StampFile, '.tmp', TmpFile),
        catch(( setup_call_cleanup(open(TmpFile, write, Out),
                                   format(Out, 'qlf_stamp(~w, ~q).~n', [V, Enc]),
                                   close(Out)),
                rename_file(TmpFile, StampFile) ),
              _, true)
    ).

%The recovery door qlf_load_engine/0 below opens on a failed load: purge
%everything so the retry runs from source, whatever state the failure left.
purge_all_qlf :-
    (   qlf_boot_directory(Here)
    ->  qlf_files(Here, QlfFiles),
        forall(qlf_member(Q, QlfFiles), catch(delete_file(Q), _, true))
    ;   true
    ).

:- dynamic qlf_boot_directory/1.

purge_stale_qlf :-
    prolog_load_context(directory, Here),
    (   qlf_boot_directory(Here) -> true
    ;   assertz(qlf_boot_directory(Here))
    ),
    qlf_files(Here, QlfFiles),
    atom_concat(Here, '/.qlf-stamp', StampFile),
    (   QlfFiles == []
    ->  true
    ;   qlf_stamp_ok(StampFile),
        qlf_source_newest(Here, Newest),
        forall(qlf_member(Q, QlfFiles),
               ( catch(time_file(Q, QT), _, QT = 0 ), QT >= Newest ))
    ->  true
    ;   forall(qlf_member(Q, QlfFiles),
               catch(delete_file(Q), _, true))
    ),
    qlf_write_stamp(StampFile).

%The engine load, so every host runs ONE of it: engine/main.pl calls this and
%so does the C host, extensions/cmetta/cmetta.c, which used to consult
%engine/metta.pl by an explicit .pl path of its own and therefore recompiled
%the umbrella and its eleven engine/metta/*.pl units from SOURCE at every
%boot. That was 929,473 of that seat's 1,563,321 boot inferences, 59.5%
%[measured 2026-09-05: extensions/cmetta/bench.sh boot, three identical
%samples on each side of the spelling]. It also charged every engine edit to
%the seat two orders of magnitude harder than to the engine's own boot row:
%the commit that added engine/metta/type_aliases.pl cost +433 inferences there
%and +48,190 here [measured 2026-09-05 by the boot-row bisection this file's
%journal entry records, one extraction per commit across the five merges since
%the seat's pin].
%
%The umbrella is named WITHOUT its extension, which is what lets SWI resolve
%it through the prolog file type and take engine/metta.qlf when the purge
%above has left one standing; naming metta.pl names the SOURCE and loads it.
%The nested unit consults inside engine/metta.pl need no change, because
%under qcompile(auto) a nested consult is recorded INTO the parent being
%compiled rather than beside it: dropping one unit's .pl produced no
%engine/metta/<unit>.qlf and no saving [measured 2026-09-05].
%
%The path is qlf_boot_directory/1, asserted by purge_stale_qlf/0 above from
%this file's own load context, so a host passes no file name and an
%apostrophe in a directory name cannot reach a goal as text. user: imports the
%metta_engine exports into the host tier; the engine's module declaration owns
%its definitions [source: engine/metta.pl:module/2; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720].
%The qcompile flag is scoped to this one load and restored, so a program the
%host runs afterwards does not inherit it.
%
%A tree the process may not write stays correct and silent: SWI compiles from
%source, writes nothing, and the boot pays what a source boot always paid,
%3,400,895 inferences against 617,044 through the artifacts [measured
%2026-09-05 on a copy of this tree with engine/, lib/ and lib/*/ at mode 555
%and every .qlf deleted: exit 0, no artifact written, no warning printed].
%
%The catch is the net for a load ERROR, and it is narrower than it looks.
%SWI writes each artifact to `.<name>.qlf.<pid>` and rename(2)s it into
%place, so concurrent first boots CANNOT tear one [measured 2026-09-05:
%strace -e trace=openat,rename over one generating boot, fourteen
%temp-then-rename pairs]; and an artifact damaged some other way is not a
%catchable condition at all -- an empty or header-short one SWI recompiles by
%itself and exits 0, one truncated to 64 bytes aborts the process from inside
%the loader with `[FATAL ERROR: Unexpected EOF on QLF file at offset 22]` and
%one truncated to 4 kB with `[FATAL ERROR: Illegal XR entry at index 21: -1]`,
%both at exit 134, and one truncated to a quarter, half or three quarters
%hangs the loader with no output at all [measured 2026-09-05: eight damage
%sizes against engine/main.pl]. What it does catch is a
%Prolog-level failure of the load itself, and the purge is what stops the
%retry meeting the same artifact set again.
qlf_load_engine :-
    qlf_boot_directory(Here),
    atom_concat(Here, '/source_loading.pl', SourceLoading),
    use_module(SourceLoading, []),
    atom_concat(Here, '/identity.pl', Identity),
    use_module(Identity, []),
    metta_identity:metta_boot_identity,
    atom_concat(Here, '/metta', Umbrella),
    qlf_regenerate_aside(Here),
    current_prolog_flag(qcompile, Previous),
    setup_call_cleanup(
        set_prolog_flag(qcompile, auto),
        metta_source_loading:loading_loudly(
            metta_qlf_boot:catch(user:ensure_loaded(Umbrella),
                  Error,
                  ( print_message(warning, Error),
                    purge_all_qlf,
                    user:ensure_loaded(Umbrella) ))),
        set_prolog_flag(qcompile, Previous)).

:- purge_stale_qlf.
