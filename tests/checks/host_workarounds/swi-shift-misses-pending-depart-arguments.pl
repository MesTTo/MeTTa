% Purpose: expose a stack shift that leaves a parent query's pending call
%   arguments at their pre-shift addresses: I_DEPART on a frame marked by
%   prolog_frame_attribute/3 runs frame_finished listeners with the depart's
%   arguments pushed, and a listener that shifts the stacks hands the callee
%   the old address of every compound those arguments hold.
% Assumes: a plain SWI process; SWIPL names the interpreter under test, the
%   one this file runs under otherwise; each arm runs in a child of its own,
%   because the defect kills the process that meets it.
% Owns resources: each child process, waited for before its arm is read.
% Guarantees: the unshifted control and every shifted arm deliver the term
%   the caller built, and the file answers absent; a shifted arm whose child
%   dies or whose callee reads another term answers present; a control that
%   fails prints control_lost and exits 1
%   [measured 2026-09-25T12:59:14+10:00: present on SWI-Prolog 10.1.14 as
%   shipped (/usr/bin/swipl, compiled Aug 30 2026, 09:21:19) and with the
%   ledger's earlier patches (compiled Sep 24 2026, 16:08:19); absent with
%   those and
%   tests/checks/host_workarounds/swi-shift-misses-pending-depart-arguments.patch
%   (compiled Sep 25 2026, 12:27:40); three runs each;
%   command=swipl -q -f none -s FILE -g main -t halt].

:- use_module(library(process), [process_create/3, process_wait/2]).
:- use_module(library(apply), [include/3]).
:- use_module(library(yall)).

:- dynamic shift_mode/1.

% The shift is forced as swipl-devel tests/GC/test_tracer_callback.pl forces
% one: grow a term, or recurse, until the named shift counter moves.
finished(_) :- shift_mode(Stat), Stat \== none, !, shift_stack(Stat).
finished(_).

shift_stack(local_shifts) :- !, statistics(local_shifts, S0), lshift(S0), !.
shift_stack(Stat) :- statistics(Stat, S0), shift_stack(S0, Stat, X), used(X).

shift_stack(S0, Stat, s(X)) :- statistics(Stat, S0), !, shift_stack(S0, Stat, X).
shift_stack(_, _, _).

lshift(S0) :- statistics(local_shifts, S0), lshift(S0).
lshift(_).

used(_).

callee(Term, Term).

% prolog_frame_attribute/3 sets FR_NOTIFY on the caller's own frame, so its
% last call is I_DEPART with its argument pushed while frameFinished() runs.
caller(N, Out) :-
    prolog_current_frame(Frame),
    prolog_frame_attribute(Frame, predicate_indicator, _),
    callee(t(N, [x, y, z], f(N)), Out).

% One arm: twenty fresh engines, whose small stacks move when they grow.
depart_arm(Mode) :-
    assertz(shift_mode(Mode)),
    prolog_listen(frame_finished, finished),
    findall(N-Out,
            ( between(1, 20, N),
              engine_create(O, caller(N, O), Engine),
              engine_next(Engine, Out),
              engine_destroy(Engine) ),
            Results),
    include([N-O]>>(O \== t(N, [x, y, z], f(N))), Results, Lost),
    length(Lost, Count),
    format("lost ~w~n", [Count]).

interpreter(Swipl) :-
    (   getenv('SWIPL', Swipl), Swipl \== ''
    ->  true
    ;   current_prolog_flag(executable, Swipl)
    ).

depart_child(Mode, Verdict) :-
    interpreter(Swipl),
    source_file(depart_child(_, _), File),
    format(atom(Goal), "depart_arm(~q)", [Mode]),
    process_create(path(sh),
                   ['-c', 'exec "$0" -q -f none -s "$1" -g "$2" -t halt 2>/dev/null',
                    Swipl, File, Goal],
                   [stdout(pipe(Out)), process(Pid)]),
    read_string(Out, _, Text),
    close(Out),
    process_wait(Pid, Status),
    (   Status == exit(0), sub_string(Text, _, _, _, "lost 0")
    ->  Verdict = kept
    ;   Verdict = lost(Status)
    ).

main :-
    depart_child(none, Control),
    (   Control \== kept
    ->  format("control_lost ~w~n", [Control]), halt(1)
    ;   findall(Mode-Verdict,
                ( member(Mode, [global_shifts, local_shifts, trail_shifts]),
                  depart_child(Mode, Verdict) ),
                Arms),
        (   member(_-lost(_), Arms)
        ->  writeln(present)
        ;   writeln(absent)
        )
    ).
