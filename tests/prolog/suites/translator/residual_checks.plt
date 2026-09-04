% Purpose: report which argument type checks the translator LEFT in the
%   compiled code, and prove the reader tells those apart from the ones it
%   discharged to an intrinsic test.
% Assumes: run from tests/prolog, which is what check.sh does; the relative
%   load path resolves against the working directory.
% Guarantees:
%   - a declared nominal parameter, which no intrinsic test decides, is
%     reported as residual against the function that carries it
%   - a declared Number parameter is NOT reported, because number/1 decides it
%     and the check is the fallback of a shortcut rather than a goal that runs
%   - the reader answers from the compiled clauses, so it costs nothing until
%     it is called: the translate case measures 380730 inferences with and
%     without it, byte-identical, where recording the same information on the
%     emission path cost +1093
%     [measured 2026-09-05: 381823 recording against 380730 reading, three
%     identical samples each; command=CHECK_PY=$CHECK_PY $CHECK_PY
%     engine/bench.py --counter-only translate; fixture=warm main-checkout
%     engine artifacts]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

%Unit-level setup, which plunit runs ONCE. Per-test setup was tried and is
%wrong here: process_metta_string/2 on the same equation appends a clause
%rather than replacing it, so three tests sharing a per-test setup left blend/3
%with three identical clauses answering three times. Measured directly: two
%setups, two clauses.
:- begin_tests(residual_checks, [setup(setup_residual_program)]).

setup_residual_program :-
    forall(member(Text,
                  [ "(: Shade Type)",
                    "(: Dark Shade)",
                    "(: blend (-> Shade Shade Shade))",
                    "(= (blend $a $b) $a)",
                    "(: double (-> Number Number))",
                    "(= (double $x) (+ $x $x))",
                    "(= (rc-uses-blend) (blend Dark Dark))",
                    "(= (rc-uses-double) (double 21))" ]),
           process_metta_string(Text, _)).

test(a_nominal_parameter_is_reported_as_a_residual_check) :-
    findall(Type,
            metta_residual_check('rc-uses-blend', Type, _),
            Types),
    assertion(memberchk('Shade', Types)).

test(an_intrinsic_parameter_is_not_reported) :-
    %number/1 decides Number in one VM instruction, so the check survives only
    %as the fallback of a shortcut and never runs on the proved path.
    assertion(\+ metta_residual_check('rc-uses-double', 'Number', _)).

test(the_report_names_the_function_and_the_type) :-
    with_output_to(string(_),
                   catch(metta_runtime_check_report, _, true)),
    findall(Function-Type,
            metta_residual_check(Function, Type, _),
            Rows),
    assertion(memberchk('rc-uses-blend'-'Shade', Rows)).

:- end_tests(residual_checks).
