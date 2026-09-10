% Purpose: expose collection clearing a completed inline unification's output.
% Assumes: a plain SWI process; no repository engine or workaround is loaded.
% Owns resources: the trace and frame-finished listener end with the probe.
% Guarantees: a lost intermediate answers present; otherwise absent [tested:
%   sh check.sh host-workarounds; commit=WORKTREE].
:- use_module(library(lists), [append/3]).

user:prolog_trace_interception(Port, Frame, _, continue) :-
    ( Port == call, nb_current(reference_frames, true),
      prolog_frame_attribute(Frame, pc, _)
    -> true
    ; true ).

finished(_) :- garbage_collect.

sample(Input, Output) :-
    ( Input == yes -> Intermediate = [] ; Intermediate = Input ),
    append(Intermediate, [], Output).

observed(Reference, Output) :-
    setup_call_cleanup(
        nb_setval(reference_frames, Reference),
        ( trace, sample([arithmetic], Output) ),
        ( notrace, nb_delete(reference_frames) )).

verdict(Output) :-
    ( Output == [] -> writeln(present) ; writeln(absent) ).

main :-
    sample([arithmetic], [arithmetic]),
    setup_call_cleanup(
        prolog_listen(frame_finished, finished),
        ( observed(false, Control), verdict(Control),
          observed(true, Output) ),
        prolog_unlisten(frame_finished, finished)),
    verdict(Output).
