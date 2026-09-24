% Purpose: refuse to boot the engine on a SWI-Prolog that does not carry every
%   host-workaround patch the engine relies on, naming what is missing and how
%   to get a host that has it; and give a host whose own bridge relies on
%   patches of its own the same check against its own list, so the engine names
%   no host's patches.
% Assumes:
%   - engine/host_patches.pl is current, which the host-declaration lane holds
%     [tested: tests/checks/check_host_declaration.py; commit=622e425d40c126681c04c7f7f81d92618ab83d0d].
%   - a patched host carries <home>/metta-host.pl, written by
%     tools/pymetta-host/declare-host.sh from the tree it was built from; the
%     host-workarounds lane runs every reproduction against that host, which is
%     what makes the declaration mean the defects are gone rather than merely
%     that a file says so [source: tests/checks/check_host_workarounds.py].
%   - autoload may be OFF, so every library predicate used here is imported.
% Guarantees:
%   - a declaration is believed only for the build it names: when its
%     host_build(CompiledAt) is not the running compiled_at flag,
%     metta_require_patched_host/0 throws
%     error(metta_host_declaration_foreign(Declaration, Built, Running), _)
%     before comparing a single patch, because the C patches live in the
%     binary and SWI_HOME_DIR can start any binary on any home
%     [tested: tests/prolog/suites/host/host_check.plt; commit=622e425d40c126681c04c7f7f81d92618ab83d0d].
%   - metta_require_host_patches(Requirer, Required) succeeds exactly when,
%     beyond that, every File-Sha256 pair in Required appears in the host's
%     declaration with the same digest, and otherwise throws
%     error(metta_host_unpatched(Requirer, Missing, Stale, Declaration, N), _),
%     where Missing lists patches the declaration lacks, Stale those it lists
%     under another digest, Declaration is the file read or none(Home), and N
%     counts Required. Requirer is the caller's own name for itself, which the
%     refusal quotes [tested: tests/prolog/suites/host/host_check.plt;
%     commit=622e425d40c126681c04c7f7f81d92618ab83d0d].
%   - metta_require_patched_host/0 is that check over the engine's own
%     requirement, engine/host_patches.pl, under the name `the MeTTa engine`.
%     The patches to a package only one host loads are that host's to require:
%     janus's are required by the Python host's bridge, which calls
%     metta_require_host_patches/2 with the list declare-host.sh generates for
%     packages/swipy [source: tools/pymetta-host/patch-root.sh;
%     commit=622e425d40c126681c04c7f7f81d92618ab83d0d].
%   - the declaration is READ as terms, never consulted, so a file in the SWI
%     home cannot run code in the engine; a term that is not one host_build/1
%     or a host_patch/2 over atoms is refused as malformed rather than skipped
%     [tested: tests/prolog/suites/host/host_check.plt; commit=622e425d40c126681c04c7f7f81d92618ab83d0d].
% Fails when: a host is patched by hand without running declare-host.sh; the
%   engine then refuses a host that may be sound, and the remedy it prints is
%   the command that writes the declaration.
%
% Why the boot refuses rather than warns: the stock SWI 10.1.14 binary answers
% present for 14 of the ledger's reproductions and aborts the process on two,
% one of them the thread join every worker evaluating MeTTa can reach
% [measured 2026-09-23: SWIPL=/usr/bin/swipl tests/checks/check_host_workarounds.py
% under a venv exporting SWI_HOME_DIR, so that binary ran the PATCHED home's
% boot and library files and these are its C-level defects alone].
% A warning would leave the crash and the wrong answers in place.
:- module(metta_host_check, [metta_require_patched_host/0,
                             metta_require_host_patches/2]).

:- use_module(library(apply), [partition/4]).
:- use_module(library(pairs), [pairs_keys/2]).
:- use_module(host_patches, []).

metta_require_patched_host :-
    findall(File-Sha, metta_host_patches:host_patch(File, Sha), Required),
    metta_require_host_patches('the MeTTa engine', Required).

metta_require_host_patches(Requirer, Required) :-
    host_declaration(Built, Declared, Declaration),
    current_prolog_flag(compiled_at, Running),
    (   ( Declaration = none(_) ; Built == Running )
    ->  true
    ;   throw(error(metta_host_declaration_foreign(Declaration, Built, Running), _))
    ),
    partition(declared_exactly(Declared), Required, _Carried, Unmet),
    partition(declared_by_name(Declared), Unmet, Stale0, Missing0),
    (   Unmet == []
    ->  true
    ;   pairs_keys(Missing0, Missing),
        pairs_keys(Stale0, Stale),
        length(Required, NRequired),
        throw(error(metta_host_unpatched(Requirer, Missing, Stale, Declaration,
                                         NRequired), _))
    ).

declared_exactly(Declared, File-Sha) :-
    memberchk(File-Sha, Declared).

declared_by_name(Declared, File-_) :-
    memberchk(File-_, Declared).

%The home's declaration, or none(Home) when it has none, which is what every
%stock host answers. Built is the one host_build/1 it names, or none.
host_declaration(Built, Declared, Declaration) :-
    (   absolute_file_name(swi('metta-host.pl'), Declaration,
                           [access(read), file_errors(fail)])
    ->  setup_call_cleanup(open(Declaration, read, In),
                           read_declaration(In, Declaration, none, Built, Declared),
                           close(In))
    ;   current_prolog_flag(home, Home),
        Declaration = none(Home),
        Built = none,
        Declared = []
    ).

read_declaration(In, Declaration, Built0, Built, Declared) :-
    read_term(In, Term, []),
    (   Term == end_of_file
    ->  Built = Built0,
        Declared = []
    ;   Term = host_build(At), atom(At), Built0 == none
    ->  read_declaration(In, Declaration, At, Built, Declared)
    ;   Term = host_patch(File, Sha), atom(File), atom(Sha)
    ->  Declared = [File-Sha|Rest],
        read_declaration(In, Declaration, Built0, Built, Rest)
    ;   throw(error(metta_host_declaration_malformed(Declaration, Term), _))
    ).

:- multifile prolog:message//1.

prolog:message(error(metta_host_unpatched(Requirer, Missing, Stale, Declaration,
                                          NRequired), _)) -->
    { length(Missing, NMissing), length(Stale, NStale) },
    [ 'This SWI-Prolog does not carry every patch ~w needs, so the engine does not boot on it.'-[Requirer], nl ],
    unpatched_lines(NMissing, 'missing', Missing),
    unpatched_lines(NStale, 'built from an older version of the patch', Stale),
    declaration_line(Declaration, NRequired, Requirer),
    [ 'A stock SWI-Prolog has defects that crash the engine or change its answers.'-[], nl,
      'The patched host comes with `npm install tsmetta`, and with `pip install pymetta` on Linux x86_64 under CPython 3.12 to 3.14.'-[], nl,
      'Anywhere else, build it as docs/patched-host.md describes:'-[], nl,
      '    https://github.com/MesTTo/MeTTa/blob/main/docs/patched-host.md'-[] ].
prolog:message(error(metta_host_declaration_foreign(Declaration, Built, Running), _)) -->
    [ '~w vouches for the SWI-Prolog build compiled at ~w, and the one running was compiled at ~w.'-[Declaration, Built, Running], nl,
      'A home\'s declaration covers only the binary installed with it, since the C patches live in that binary.'-[], nl,
      'This usually means SWI_HOME_DIR starts another swipl on that home: unset it, or run the swipl installed there.'-[] ].
prolog:message(error(metta_host_declaration_malformed(Declaration, Term), _)) -->
    [ '~w holds ~q, which is neither its one host_build/1 nor a host_patch(File, Sha256) fact.'-[Declaration, Term], nl,
      'Rewrite it with tools/pymetta-host/declare-host.sh declare SRC HOME.'-[] ].

unpatched_lines(0, _, _) --> !.
unpatched_lines(N, Why, Files) -->
    [ '~d patch(es) ~w:'-[N, Why], nl ],
    unpatched_files(Files).

unpatched_files([]) --> [].
unpatched_files([File|Files]) -->
    [ '    ~w'-[File], nl ],
    unpatched_files(Files).

declaration_line(none(Home), NRequired, _) -->
    [ 'The home ~w has no metta-host.pl declaring any of the ~d.'-[Home, NRequired], nl ].
declaration_line(File, NRequired, Requirer) -->
    { atom(File) },
    [ 'Read from ~w, against the ~d ~w requires.'-[File, NRequired, Requirer], nl ].
