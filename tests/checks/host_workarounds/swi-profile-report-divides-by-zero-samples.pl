% Purpose: answer whether this SWI-Prolog still raises out of profile/2's
%   report when the sampler took no sample, discarding the goal's answer with
%   it: profile/2 a goal too short for one sampling period, with the report's
%   own output swallowed, and see whether the call raises and whether the
%   binding the goal made survives to the catcher. Prints `present` while the
%   report raises and `absent` once a zero-sample profile answers.
% Assumes:
%   - run as `swipl -q -f none -s FILE -g main -t halt` by the host-workarounds
%     lane, which reads the last line printed
%   - the box finishes `X is 1 + 1` inside one 5 ms sampling period, which is
%     what makes the profile a zero-sample one; a box slow enough to sample it
%     reads `absent` for that reason and the lane says so rather than passing
%     silently, because the printed line carries the sample count
% Guarantees:
%   - `present` iff profile/2 raises evaluation_error(zero_divisor) from its
%     report after the goal answered
%     [measured 2026-09-12: `profile(true, [top(0)])` raises on 10.1.13 at
%     loadavg 4, where a 3,000,000-inference loop profiles to samples=6
%     ticks=26; command=sh check.sh host-workarounds; fixture=SWI-Prolog
%     10.1.13; commit=WORKTREE]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

main :-
    catch(( with_output_to(string(_), profile(X is 1 + 1, [top(0)])),
            Raised = no ),
          error(evaluation_error(zero_divisor), _),
          Raised = yes),
    samples(Samples),
    (   Raised == yes
    ->  Verdict = present
    ;   Verdict = absent
    ),
    (   var(X)
    ->  Answer = discarded
    ;   Answer = kept
    ),
    format("samples=~w answer=~w~n~w~n", [Samples, Answer, Verdict]).

%The count the profiler collected for that goal, read the way the engine's own
%door reads it, so the printed line says whether this box sampled at all.
samples(Samples) :-
    (   catch(( profile_data(Data),
                get_dict(summary, Data, Summary),
                get_dict(samples, Summary, Samples) ),
              _, fail)
    ->  true
    ;   Samples = unknown
    ).
