% Purpose: fold immutable native scalar calls while compiling retained clauses.
% Assumes: translator.pl owns this unit and retained clause publication keeps
%   the source dependency edges from filereader:record_translated_supports/2.
% Guarantees: the admitted fragment produces the same complete answer bag as
%   runtime dispatch; untracked plans, shadows, effects, variable inputs and
%   ordinary evaluation failures retain the original call
%   [tested: run_tests(translator_constant_folding); commit=WORKTREE].
% Decides: only bounded-result integer primitives and integer-list scalar
%   queries are pre-evaluated; host calls and recursive functions require a
%   termination and result-lifetime contract that their effect rank lacks.

% PostgreSQL 18 evaluate_function requires immutable constant inputs and
% refuses set-returning calls. This engine also proves a finite native input
% mode and retains source dependencies; pureStructural alone cannot establish
% either for a user function.
% https://github.com/postgres/postgres/blob/REL_18_0/src/backend/optimizer/util/clauses.c
% [source: PostgreSQL REL_18_0, evaluate_function; commit=WORKTREE]
fold_native_scalar_call(Module, Fun, Args, Out, Goal) :-
    constant_scalar_arguments(Fun, Args),
    retained_static_type_shortcuts_allowed,
    \+ metta_builtin_overridden(Fun),
    metta_operation_effect(Fun, pureStructural),
    var(Out),
    term_attvars(Out, []),
    append(Args, [Out], DirectArgs),
    Direct =.. [Fun|DirectArgs],
    Goal == Direct,
    % findall copies each answer and unwinds every speculative binding. The
    % exact singleton check retains failure and duplicate multiplicity, even
    % if the native implementation ceases to satisfy the expected mode.
    % DuckDB's TryEvaluateScalar similarly leaves a failed expression intact.
    % https://github.com/duckdb/duckdb/blob/v1.4.0/src/optimizer/rule/constant_folding.cpp
    % [source: DuckDB v1.4.0, ConstantFoldingRule::Apply; commit=WORKTREE]
    catch_recover(findall(Out, call(Module:Goal), Results), fail),
    Results = [Value],
    integer(Value),
    Out = Value.

% These input modes enter finite native branches and produce no value larger
% than the operand representation by more than a constant factor. In
% particular, shifts and powers can request enormous allocations from tiny
% source terms and are left for the branch that actually demands them.
% [source: engine/metta/operators.pl, '+', '-', '*', '%', min, max,
% 'floor-div', metta_bit_binary/4, 'bit-not', 'abs-math'; commit=WORKTREE]
constant_scalar_arguments(Fun, [Left, Right]) :-
    constant_integer_binary(Fun),
    integer(Left),
    integer(Right).
constant_scalar_arguments('abs-math', [Value]) :- integer(Value).
constant_scalar_arguments('bit-not', [Value]) :- integer(Value).
constant_scalar_arguments('size-atom', [Values]) :-
    is_list(Values),
    maplist(integer, Values).
constant_scalar_arguments('min-atom', [Values]) :-
    Values = [_|_],
    is_list(Values),
    maplist(integer, Values).
constant_scalar_arguments('max-atom', [Values]) :-
    Values = [_|_],
    is_list(Values),
    maplist(integer, Values).

constant_integer_binary('+').
constant_integer_binary('-').
constant_integer_binary('*').
constant_integer_binary('%').
constant_integer_binary(min).
constant_integer_binary(max).
constant_integer_binary('floor-div').
constant_integer_binary('bit-and').
constant_integer_binary('bit-or').
constant_integer_binary('bit-xor').
