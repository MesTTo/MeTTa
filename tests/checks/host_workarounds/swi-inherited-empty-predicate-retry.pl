% Purpose: detect an inherited first-call retry determined by retired clauses.
% Assumes: SWI's '$cgc_params'/6 can hold automatic collection off while the
%   diagnostic process compares retained and explicitly collected clauses.
% Guarantees: first/warm inherited and direct calls run in separate fresh
%   processes; unequal controls and child failures refuse a verdict [tested:
%   sh tools/check.sh host-workarounds host-workarounds-selftest; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
%   [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14 as shipped,
%   absent on 10.1.14 built with
%   tests/checks/host_workarounds/swi-erased-definition-bypasses-loader.patch;
%   command=sh tools/check.sh host-workarounds;
%   fixture=SWI-Prolog 10.1.14 with the patch; commit=9d54ed2129cea9859779419d6120636486eb6585].
% Owns resources: children own their clauses and collector policy; the parent
%   closes each output stream and joins the child, including on read errors.

:- module(inherited_empty_counter, [main/0]).
:- use_module(library(process)).
:- thread_local(inherited_empty_provider:pending/2).
:- dynamic(inherited_empty_provider:generation_marker/0).
:- set_module(base(inherited_empty_provider)).

main :-
    inherited_empty_sample(retained, inherited, R, RW),
    inherited_empty_sample(collected, inherited, C, CW),
    inherited_empty_sample(retained, direct, DR, DRW),
    inherited_empty_sample(collected, direct, DC, DCW),
    format('inherited_retained=~d/~d inherited_collected=~d/~d ', [R,RW,C,CW]),
    format('direct_retained=~d/~d direct_collected=~d/~d~n', [DR,DRW,DC,DCW]),
    ( RW =:= CW, CW =:= DR, DR =:= DRW, DRW =:= DC, DC =:= DCW
    -> true
    ; throw(error(unequal_controls(RW,CW,DR,DRW,DC,DCW), _)) ),
    ( ( R < C ; C < CW )
    -> throw(error(reversed_inherited_cost(R,C,CW), _))
    ; R > C -> writeln(present)
    ; writeln(absent) ).

inherited_empty_sample(Collection, Access, First, Warm) :-
    source_file(main, File),
    current_prolog_flag(executable, Swipl),
    format(atom(Goal), 'inherited_empty_counter:inherited_empty_child(~q,~q)',
           [Collection, Access]),
    setup_call_cleanup(
        process_create(Swipl,
            ['-f', none, '-q', '-s', File, '-g', Goal, '-t', halt],
            [stdout(pipe(Output)), process(Pid)]),
        read_term(Output, Sample, []),
        (close(Output), process_wait(Pid, Status))),
    ( Status == exit(0), Sample = counts(First,Warm),
      integer(First), integer(Warm)
    -> true
    ; throw(error(broken_counter_child(Status,Sample), _)) ).

inherited_empty_child(Collection, Access) :-
    set_prolog_gc_thread(false),
    '$cgc_params'(_, _, _, 0, 1.0e20, 1.0e20),
    assertz(inherited_empty_provider:pending(id,fun)),
    retractall(inherited_empty_provider:pending(id,fun)),
    % Collection removes clauses erased BEFORE its starting generation.
    assertz(inherited_empty_provider:generation_marker),
    ( Collection == collected -> garbage_collect_clauses ; true ),
    inherited_empty_probe(Access, First), inherited_empty_probe(Access, Warm),
    write_canonical(counts(First,Warm)), writeln('.').

% Literal calls preserve S_VIRGIN's inherited and direct entry paths.
inherited_empty_probe(inherited, Count) :-
    statistics(inferences, Before),
    ( pending(id,fun) -> Answer = true ; Answer = false ),
    statistics(inferences, After),
    Count is After-Before,
    Answer == false.
inherited_empty_probe(direct, Count) :-
    statistics(inferences, Before),
    ( inherited_empty_provider:pending(id,fun)
    -> Answer = true ; Answer = false ),
    statistics(inferences, After),
    Count is After-Before,
    Answer == false.
