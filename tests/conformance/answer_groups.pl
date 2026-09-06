% Purpose: run ONE MeTTa file under this engine and print the answer
%   GROUP of each `!` form on a marker line, so a comparator can read them
%   without having to tell an answer apart from the loader's own echo.
% Assumes:
%   - argv carries `--file <path>`, and the engine is already consulted.
% Guarantees:
%   - one `ANSWER-GROUP ` line per RUNNABLE form, in source order, holding that
%     form's answers in the engine's display spelling. A form with no answers
%     prints an empty group rather than nothing, because "no answers" is an
%     observation a comparator records as `[]` and dropping it would misalign
%     every line after it [tested:
%     test_a_prelude_derived_form_matches_its_fused_twin_on_the_corpus;
%     commit=c1eaa36c7a2089801fe9da3cbec3fc02833d66fe].
%   - an application error prints `ANSWER-ERROR ` and stops; SWI unwind
%     exceptions retain process control without becoming answer errors
%     [tested: test_process_exit_is_not_an_answer_error; commit=bbb512316280110a747e31c26adfc31e8c5104be].
%   - reader variable names carried with collected answers are rendered by the
%     engine's named writer [assumed: this was exercised by a conformance
%     runner this repository no longer ships; no lane covers it today;
%     commit=916def0562c211143bb91cd0bd8b2c9dac7ab4fa].
% Fails when:
%   - never silently: an unreadable file raises out of read_metta_source/2 and
%     is reported on the error line.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- initialization(main, main).

main :-
    current_prolog_flag(argv, Argv),
    (   append(_, ['--file', File|_], Argv)
    ->  true
    ;   throw(error(existence_error(argument, '--file'), _))
    ),
    catch(( load_metta_source_groups(File, '&self', Groups),
            forall(member(Group, Groups),
                   ( parser:sdisplay_answer_group(Group, Written),
                     format("ANSWER-GROUP ~w~n", [Written]) )) ),
          Error,
          report_error(Error)),
    halt.

%The loader's own flattening path is right for a program and wrong here: the
%arbiter records one bracketed line per form, so the grouping IS the
%observation. load_metta_source_groups/3 is the engine's own grouped loader,
%which `include` also reads, so this file no longer keeps a second copy of it.

%SWI reserves unwind/1 for process and thread control. The reporter must not
%label a normal halt as an application error before the runtime rethrows it.
%[source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/man/builtin.plx,
%section unwind-exceptions; commit=bbb512316280110a747e31c26adfc31e8c5104be].
report_error(unwind(Cause)) :- !,
    throw(unwind(Cause)).
report_error(Error) :-
    message_to_text(Error, Text),
    format("ANSWER-ERROR ~w~n", [Text]).

%print_message/2 writes to user_error and returns nothing a caller can hold, so
%the message is rendered through its own DCG and captured instead.
message_to_text(Error, Text) :-
    (   catch(( message_to_codes(Error, Codes), Codes \== [] ), _, fail)
    ->  string_codes(Text, Codes)
    ;   term_string(Error, Text)
    ).

message_to_codes(Error, Codes) :-
    message_to_lines(Error, Lines),
    with_output_to(codes(Codes),
                   print_message_lines(current_output, '', Lines)).

message_to_lines(Error, Lines) :-
    (   phrase(prolog:message(Error), Lines)
    ->  true
    ;   Error = error(Formal, _),
        phrase(prolog:error_message(Formal), Lines)
    ).
