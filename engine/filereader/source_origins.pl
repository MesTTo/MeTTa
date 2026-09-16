% Purpose: carry source origins beside supplied values through reader rewrites.
% Assumes: parsed kinds describe executed forms, while source/value/children
%   origins describe subterms independently [source:
%   engine/filereader.pl:metta_host_run_source/4; commit=WORKTREE].
% Guarantees: supplied and token-returned values never acquire FROM meanings
%   [tested: reference_source_origins:explicit_atom_values_keep_their_origins_inside_nested_source,
%   reference_source_origins:data_doors_keep_their_existing_token_difference_and_share_from_resolution,
%   test_supplied_atoms_keep_their_heads_inside_fresh_source; commit=WORKTREE].
% Decides: introduction positions shadow imported names within their form.

:- use_module(library(assoc), [get_assoc/3]).
:- meta_predicate source_replace(2, ?, +, ?, -).
:- dynamic process_form/3, process_loader_form/3.
:- dynamic data_run/4, definition_run/4, rewrite_source_data/4.

source_form(bound_source(_, Parsed), Parsed) :- !.
source_form(Parsed, Parsed).

% A replacement is a complete value. Only the original tree is traversed.
source_replace(_, Term, Origins, Term, Origins) :- var(Term), !.
source_replace(Resolve, Term, _, Bound, value) :-
    atom(Term), call(Resolve, Term, Bound), !.
source_replace(Resolve, Terms, Origins, Bound, children(BoundOrigins)) :-
    is_list(Terms), !,
    source_children(Origins, Terms, Children),
    maplist(source_replace(Resolve), Terms, Children, Bound, BoundOrigins).
source_replace(_, Term, Origins, Term, Origins).

source_children(source, Terms, Origins) :- !,
    same_length(Terms, Origins), maplist(=(source), Origins).
source_children(value, Terms, Origins) :- !,
    same_length(Terms, Origins), maplist(=(value), Origins).
source_children(children(Origins), _, Origins).

validate_source_origins(Term, Origins) :-
    ( acyclic_term(Term), ground(Origins), acyclic_term(Origins),
      source_origins_valid(Term, Origins)
    -> true
    ; throw(error(metta_source_origins(Term, Origins), none)) ).

source_origins_valid(_, source) :- !.
source_origins_valid(_, value) :- !.
source_origins_valid(Terms, children(Origins)) :-
    is_list(Terms), is_list(Origins),
    same_length(Terms, Origins),
    maplist(source_origins_valid, Terms, Origins).

% The extension boundary owns invocation and validation together. Opt-in
% source observation can inspect this boundary without changing its caller.
rewrite_source_form(Rewriter, Term, Origins, Rewritten, RewrittenOrigins) :-
    call(Rewriter, Term, Origins, Rewritten, RewrittenOrigins),
    validate_source_origins(Rewritten, RewrittenOrigins).

% The direct data door keeps its established global-token behavior.
rewrite_source_data(_, _, Term, Rewritten) :-
    metta_engine:substitute_bound_tokens(Term, Rewritten).

source_bound_names(Map, origin(Kind, Origins), tokens, Term, Rewritten) :-
    ( metta_engine:metta_token_claim(_, _, _, _)
    -> source_replace(metta_engine:metta_token, Term, Origins, Bound, BoundOrigins)
    ; Bound = Term, BoundOrigins = Origins ),
    source_name_form(Map, Kind, BoundOrigins, Bound, Rewritten).
source_bound_names(Map, origin(Kind, Origins), literal, Term, Rewritten) :-
    source_name_form(Map, Kind, Origins, Term, Rewritten).

source_name_form(_, _, value, Term, Term) :- !.
source_name_form(Map, function, Origins, [=, [Name|Args], Body],
                 [=, [Name|BoundArgs], BoundBody]) :-
    atom(Name), !,
    source_children(Origins, [=, [Name|Args], Body], [_, CallOrigin, BodyOrigin]),
    source_children(CallOrigin, [Name|Args], [_|ArgOrigins]),
    maplist(source_name_walk(Map, shadow(Name)), Args, ArgOrigins, BoundArgs),
    source_name_walk(Map, shadow(Name), Body, BodyOrigin, BoundBody).
source_name_form(Map, expression, Origins, [Head, Name, Type],
                 [Head, Name, BoundType]) :-
    source_declaration_head(Head), atom(Name), !,
    source_children(Origins, [Head, Name, Type], [_, _, TypeOrigin]),
    source_name_walk(Map, shadow(Name), Type, TypeOrigin, BoundType).
source_name_form(_, expression, _, [from|Rest], [from|Rest]) :- !.
source_name_form(_, expression, _, [internal|Rest], [internal|Rest]) :- !.
source_name_form(Map, _, Origins, Term, Rewritten) :-
    source_name_walk(Map, none, Term, Origins, Rewritten).

source_declaration_head(':').
source_declaration_head(':<').

source_name_walk(_, _, Term, value, Term) :- !.
source_name_walk(_, _, Term, _, Term) :- var(Term), !.
source_name_walk(Map, Shadow, Term, _, Rewritten) :-
    atom(Term), !,
    ( Shadow == shadow(Term) -> Rewritten = Term
    ; get_assoc(Term, Map, Meaning) -> source_name_value(Term, Meaning, Rewritten)
    ; Rewritten = Term ).
source_name_walk(Map, Shadow, Terms, Origins, Rewritten) :-
    is_list(Terms), !,
    source_children(Origins, Terms, Children),
    maplist(source_name_walk(Map, Shadow), Terms, Children, Rewritten).
source_name_walk(_, _, Term, _, Term).

source_name_value(_, value(Original), Original).
source_name_value(Name, ambiguous(Origins), _) :-
    throw(error(metta_source_name_ambiguity(Name, Origins), none)).

% Generate the supplied-origin variant from the same source processor body.
% Storage, translation and source ownership remain in the ordinary clause.
source_origin_processor(process_form(Space, Parsed, Result),
                        process_form(Space, bound_source(Origins, Parsed), Result),
                        Origins).
source_origin_processor(process_loader_form(Space, Parsed, Result),
                        process_loader_form(Space, bound_source(Origins, Parsed), Result),
                        Origins).

source_origin_body((First, Rest), Origins, (BoundFirst, BoundRest)) :- !,
    source_origin_body(First, Origins, BoundFirst),
    source_origin_body(Rest, Origins, BoundRest).
source_origin_body(rewrite_parsed_form(Space, origin(Kind, source), Text, Term, Out),
                   Origins,
                   rewrite_parsed_form(Space, origin(Kind, Origins), Text, Term, Out)) :- !.
source_origin_body(rewrite_source_data(Space, origin(Kind, source), Term, Out),
                   Origins,
                   rewrite_source_data(Space, origin(Kind, Origins), Term, Out)) :- !.
source_origin_body(Goal, _, Goal).

term_expansion((Head :- Body), [(Head :- Body), (BoundHead :- BoundBody)]) :-
    source_origin_processor(Head, _, _),
    arg(2, Head, Parsed), nonvar(Parsed), functor(Parsed, parsed, _),
    copy_term((Head :- Body), (CopiedHead :- CopiedBody)),
    source_origin_processor(CopiedHead, BoundHead, Origins),
    source_origin_body(CopiedBody, Origins, BoundBody).
