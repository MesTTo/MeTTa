% Purpose: prove literal inspection and exact simultaneous term replacement.
% Guarantees: tests compare live Prolog variable identity as well as answer bags,
% preserving runnable syntax, shared replacements and every duplicate occurrence.
% [tested: lib_reflect_terms; commit=505ce25b9384e782afa26f621527d4b1fd695924].
:- use_module(collection_test_support).
:- use_module(library(lists), [member/2]).
:- initialization(load_collection_library(lib_reflect)).

:- begin_tests(lib_reflect_terms).

test(variables_are_the_callers_own_in_first_appearance_order) :-
    invoke('atom-variables'([X,[Y,X],Z,Y],Variables)),
    assertion(Variables==[X,Y,Z]),
    assertion(var(X)), assertion(var(Y)), assertion(var(Z)),
    invoke('atom-variables'(X,Single)), assertion(Single==[X]).

test(ground_and_empty_terms_have_no_variables) :-
    forall(member(Term,[a,42,[],['+',1,2],['Error',data,code]]),
           invoke('atom-variables'(Term,[]))).

test(binder_syntax_is_inspected_structurally) :-
    invoke('atom-variables'([let,X,Y,[f,X,Z]],Variables)),
    assertion(Variables==[X,Y,Z]).

test(exact_variable_keys_do_not_unify_other_terms) :-
    invoke('atom-replace'([X,Y,X],[[X,Z]],Replaced)),
    assertion(Replaced==[Z,Y,Z]),
    assertion(var(X)), assertion(var(Y)), assertion(var(Z)),
    invoke('atom-replace'([p,X],[[[p,Y],wrong]],Kept)),
    assertion(Kept==[p,X]), assertion(X\==Y).

test(root_match_precedes_descendants) :-
    invoke('atom-replace'([f,a],[[[f,a],root],[a,child]],root)).

test(replacements_are_not_rewritten_again) :-
    invoke('atom-replace'([a,a],[[a,b],[b,c]],[b,b])).

test(duplicates_and_separate_positions_form_the_whole_product) :-
    findall(Result,collection_answers('atom-replace'([a,a],[[a,b],[a,c],[a,c]],Result)),Answers),
    assertion(Answers==[[b,b],[b,c],[b,c],[c,b],[c,c],[c,c],[c,b],[c,c],[c,c]]).

test(literal_programs_and_errors_are_never_run) :-
    Term=['+',1,['Error',data,code]],
    invoke('atom-replace'(Term,[[1,['+',2,3]]],Result)),
    assertion(Result==['+',['+',2,3],['Error',data,code]]).

test(empty_symbol_is_a_value_and_not_strategy_failure) :-
    invoke('strategy-apply'(id,'Empty','Empty')),
    findall(Root,collection_answers('atom-replace'(a,[[a,'Empty'],[a,b]],Root)),Roots),
    assertion(Roots==['Empty',b]),
    findall(Result,collection_answers('atom-replace'([a,a],[[a,'Empty'],[a,b]],Result)),Answers),
    assertion(Answers==[['Empty','Empty'],['Empty',b],[b,'Empty'],[b,b]]).

test(expression_heads_and_empty_expressions_are_replaceable) :-
    invoke('atom-replace'([f,[]],[[f,g],[[],empty_value]],[g,empty_value])),
    invoke('atom-replace'([],[[[],[f,a]]],[f,a])).

test(absent_keys_and_empty_relations_preserve_identity) :-
    invoke('atom-replace'([X,a],[],Empty)), assertion(Empty==[X,a]),
    invoke('atom-replace'([X,a],[[b,c]],Absent)), assertion(Absent==[X,a]).

test(numeric_identity_distinguishes_integer_and_float) :-
    invoke('atom-replace'([1,1.0],[[1,integer],[1.0,float]],[integer,float])).

test(replacement_variables_remain_shared_between_positions) :-
    invoke('atom-replace'([a,a],[[a,[X,X]]],Result)),
    assertion(Result==[[X,X],[X,X]]), assertion(var(X)).

test(malformed_relations_refuse_without_inventing_pairs) :-
    forall(member(Rows,[invalid,[invalid],[[a]],[[a,b,c]]]),
           refused('atom-replace'(a,Rows,_))),
    refused('atom-replace'(a,[Pair],_)), assertion(var(Pair)),
    refused('atom-replace'(a,Rows,_)), assertion(var(Rows)).

test(open_and_cyclic_host_terms_refuse) :-
    Open=[a|Tail],
    refused('atom-replace'(a,Open,_)), assertion(var(Tail)),
    Cycle=[a,Cycle],
    refused('atom-replace'(Cycle,[],_)),
    refused('atom-variables'(Cycle,_)).

test(reflection_can_reconstruct_the_library_equation) :-
    once(eval_expr([match,'&self',[=,['atom-variables',Argument],Body],[quote,Body]],Definition)),
    once(eval_expr([let,Argument,[quote,[X,[Y,X]]],Definition],Variables)),
    assertion(Variables==[X,Y]).

:- end_tests(lib_reflect_terms).
