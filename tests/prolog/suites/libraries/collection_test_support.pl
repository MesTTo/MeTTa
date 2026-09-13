% Purpose: exercise collection libraries through their public MeTTa equations.
% Guarantees: each argument enters as a bound literal, preserving held values,
% variables and caller identity [tested: lib_combinatorics_surface, lib_functional,
% lib_pairs, lib_sets; commit=WORKTREE].
:- module(collection_test_support,
          [load_collection_library/1, eval_expr/2, invoke/1, collection_answers/1,
           refused/1, collection_items/2]).
:- user:ensure_loaded('../../../../engine/qlf_boot.pl').
:- user:ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../engine/metta.pl', [current_metta_module/1,eval_metta_in_module/3]).
:- use_module(library(lists), [append/3,numlist/3]).
:- use_module(library(debug), [assertion/1]).

load_collection_library(Name) :-
    format(string(Source),"!(import! &self (library ~w))",[Name]),
    filereader:metta_host_run_source(Source,'&self',[],_).

eval_expr(Expression,Answer) :-
    current_metta_module(Module),eval_metta_in_module(Module,Expression,Answer).

% Single-value checks commit explicitly; stream checks collect every answer.
invoke(Goal) :- once(collection_answers(Goal)).

% Binding before application also covers Atom parameters, which hold syntax.
collection_answers(Goal) :-
    call_expression(Goal,Expression,Answer),
    eval_expr(Expression,Answer).
call_expression(Goal,Expression,Answer) :-
    Goal=..[Head|Arguments],once(append(Inputs,[Answer],Arguments)),
    bind_inputs(Inputs,Parameters,[Head|Parameters],Expression).
bind_inputs([],[],Call,Call).
bind_inputs([Input|Inputs],[Parameter|Parameters],Call,
            [let,Parameter,[quote,Input],Body]) :-
    bind_inputs(Inputs,Parameters,Call,Body).

refused(Goal) :-
    call_expression(Goal,Expression,_),
    eval_expr(['if-error',[catch,Expression],refused,accepted],Verdict),
    assertion(Verdict==refused).

% numlist/3 fails for an empty interval.
collection_items(0,[]) :- !.
collection_items(Size,Items) :- numlist(1,Size,Items).
