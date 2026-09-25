% Purpose: retain source maps beside compiled clauses and collect observations.
% Assumes: nothing loads this file at boot. engine/metta.pl reaches it only
%   through metta_ensure_source_observation/0, which also gives it the engine's
%   base module, and the only callers of that door are lib_observe's
%   observe-source and the tests that drive this module directly.
% Owns resources: source maps, compiler wrappers, observation buffers and the
%   two SWI hook clauses are released at observation exit; debugger settings
%   are restored.
% Guarded by: an observation mutex serializes compiler wrapper installation;
%   source maps and execution buffers are thread-local.
% Guarantees: resolved equations retain their stored source occurrence; a
%   subtree a form rewriter returns unchanged at its position keeps its
%   coordinates, and every node above a change reports a generated site at the
%   whole form instead of the span it displaced [tested:
%   reference_source_origins:source_observation_keeps_the_canonical_answer_and_original_coordinates,
%   reference_source_origins:equal_shape_does_not_fabricate_coordinates_for_a_rewritten_body,
%   reference_source_origins:a_rebuilding_rewriter_keeps_every_unchanged_coordinate,
%   reference_source_origins:a_rewritten_leaf_marks_its_own_path_and_keeps_its_siblings;
%   commit=1a8c00f93ae6c63ccabd41d39fed3f967dadd3a9].
% Guarantees: compiler observation emits no runtime goals and changes no atom
%   representation [tested: source_observation:compiled_goals_are_unchanged;
%   commit=6f634f6705fc1e40e0c2e3970d4156ee574ab70d].
% Guarantees: only the starting thread is observed, and a hook that throws
%   is reported without ending the observation [tested 2026-09-25T04:02:23+10:00:
%   source_observation:ordinary_other_thread_execution_does_not_enter_observation,
%   source_observation:a_throwing_exit_hook_is_reported_and_the_observation_completes].
% Guarantees: an observation records every error raised under it, and stores
%   each error and the exception that ends it as text that is a function of
%   the term as raised, whatever prolog:prolog_exception_hook/5 clauses other
%   libraries hold and whatever those clauses answer, so two observations of
%   one source store identical rows, and every such clause still answers as it
%   would without an observation [tested 2026-09-25T04:02:23+10:00:
%   source_observation:two_observations_of_one_source_store_identical_rows,
%   source_observation:an_answering_exception_hook_hides_no_native_error_from_the_observer,
%   source_observation:a_rewriting_exception_hook_leaves_the_escaping_exception_as_raised].
% Guarantees: an engine that never runs observe-source loads none of this and
%   pays nothing for it. Loading it at boot cost 3,696 inferences, and its
%   resident prolog:prolog_exception_hook/5 clause cost another 119 on the
%   engine's translate case and 2 on every compiled host request, none of it
%   work any of those cases performs [measured 2026-09-05: boot 536,337 with
%   the boot load against 532,641 without, translate 362,516 against 362,397,
%   evaluate 558,643 against 558,636, foreign-match 788,827 against 784,829
%   over its 2,000 runs; command=engine/bench.py and extensions/python/bench.py
%   --counter-only; fixture=worktree at a94f804c with the MORK artifacts
%   present and the .qlf set cleared and warmed for every arm; three identical
%   samples per arm; commit=b96e1a15260b7538a8e42be613bcc5dd0dddd136].

:- module(source_observation, [record_error/2, observe_source/4]).

% Assumes: metta_engine:goal_expansion/2 is visible while clauses compile.
% Set the base before the clauses and their engine-dependent directives.
% [source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/expand.pl#L239; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
:- set_module(base(metta_engine)).
:- use_module(source_positions, [source_positions/3]).
:- use_module(library(assoc)).
:- use_module(library(prolog_wrap)).
:- use_module(library(prolog_code), [comma_list/2]).
%Declared rather than left to autoload, because the engine supports booting
%with set_prolog_flag(autoload, false) and nothing else in its module chain
%imports library(pairs): with autoload off, observing any source raised
%existence_error(procedure, source_observation:pairs_keys_values/3) from
%with_source/4 and the observation returned `exception` where the example
%expects `complete` [measured 2026-09-05: NO_AUTOLOAD=1 sh run.sh
%examples/ch20-extending-the-engine/20-05-observing-execution/02-source-coverage.metta].
:- use_module(library(pairs), [pairs_keys_values/3]).

:- meta_predicate with_source(+, +, +, 0).
:- meta_predicate compile_clause(+, -, 0).
:- meta_predicate compile_expression(+, ?, ?, 0).
:- meta_predicate observe_equation(+, +, +, +, 0).
:- meta_predicate observe_rewriter(+, ?, 0).
:- meta_predicate observe_rewritten(+, ?, 0).
:- meta_predicate observe_positioned_form(+, +, ?, +, +, ?, 0).

:- thread_local source_document/3, source_equation/6, clause_source/4,
                clause_location/5, unavailable_location/4, unavailable_function/1.

% PEP 657 keeps source locations in code metadata rather than data values.
% https://peps.python.org/pep-0657/
% Compiler wrappers exist only inside the explicit observation operation.
install_compiler_observers :-
    wrap_predicate(filereader:store_metta_equation(_, Module, Raw, Bound, StoredRef, _),
                   source_map, OriginalStore,
                   source_observation:observe_equation(Module, Raw, Bound, StoredRef, OriginalStore)),
    wrap_predicate(translator:translate_clause_impl(Input, Clause, _C, _A),
                   source_map, OriginalClause,
                   source_observation:compile_clause(Input, Clause, OriginalClause)),
    wrap_predicate(translator:translate_expr_dl(Expression, Start, End, _Out),
                   source_map, OriginalExpression,
                   source_observation:compile_expression(Expression, Start, End,
                                                         OriginalExpression)).

remove_compiler_observers :-
    remove_wrapper(filereader:store_metta_equation/6, source_map),
    remove_wrapper(translator:translate_clause_impl/4, source_map),
    remove_wrapper(translator:translate_expr_dl/4, source_map).

save_context(Key, saved(Value)) :- nb_current(Key, Value), !.
save_context(_, absent).
restore_context(Key, saved(Value)) :- !, nb_linkval(Key, Value).
restore_context(Key, absent) :- nb_delete(Key).

with_source(Source, Parsed, Space, Goal) :-
    source_positions(Source, Parsed, Positioned),
    spaces:space_module(Space, Module),
    source_label(Label),
    flag('$metta_source_document', Id, Id+1),
    assertz(source_document(Id, Label, Source)),
    ( nb_current('$metta_source_context',_) -> true
    ; nb_current('$metta_observation',Buffer), nb_setarg(4,Buffer,Id) ),
    empty_assoc(Empty),
    source_queues(Parsed, Positioned, Empty, Queues),
    save_context('$metta_source_context', Previous),
    pairs_keys_values(FormPairs, Parsed, Positioned),
    setup_call_cleanup(
        nb_linkval('$metta_source_context', context(Module, Id, Queues, FormPairs)),
        call(Goal),
        restore_context('$metta_source_context', Previous)).

source_label(Label) :-
    ( nb_current('$metta_source_context',_),
      filereader:current_source_identity(file(Path), _) -> atom_string(Path, Label)
    ; nb_current('$metta_source_context',_) -> Label="<nested-source>"
    ; nb_current('$metta_observe_label', Label) -> true
    ; Label = "<string>" ).

source_queues([], [], Queues, Queues).
source_queues([Form|Forms], [positioned(_,_,_,_,Tree)|Trees], Q0, Q) :-
    ( filereader:source_form(Form, parsed(function, _, Term))
    -> variant_sha1(Term, Key),
       ( get_assoc(Key, Q0, Existing) -> true ; Existing = [] ),
       append(Existing, [origin(Term, Tree)], Values),
       put_assoc(Key, Q0, Values, Q1)
    ; Q1 = Q0 ),
    source_queues(Forms, Trees, Q1, Q).

record_stored(Ref) :-
    ( nb_current('$metta_source_context', Context),
      Context = context(Module, Id, Queues, _),
      spaces:stored_atom_of_ref(Ref, _, Term, _),
      nonvar(Term), Term = [=, [_|_], _],
      variant_sha1(Term, Key),
      get_assoc(Key, Queues, [origin(Original, Tree)|Rest]),
      Original =@= Term
    -> put_assoc(Key, Queues, Rest, Remaining),
       nb_linkarg(3, Context, Remaining),
       assertz(source_equation(Key, Module, Ref, Id, Term, Tree))
    ; true ).

% The store already carries the raw term, resolved term and exact occurrence.
% Retain that association in the existing observation row before compilation,
% including when the store defers compilation to a later source form.
observe_equation(Module, Raw, Bound, StoredRef, Goal) :-
    ( source_equation(Key, Module, StoredRef, Id, _, Tree),
      spaces:stored_atom_of_ref(StoredRef, _, Written, _), Written =@= Raw
    -> observe_bound_tree(Tree, BoundTree),
       variant_sha1(Bound, BoundKey),
       retractall(source_equation(Key, Module, StoredRef, _, _, _)),
       assertz(source_equation(BoundKey, Module, StoredRef, Id, Bound, BoundTree))
    ; true ),
    call(Goal).

% Extensions receive source terms as values. A rewritten node keeps its
% coordinates only where the rewriter returned the written subterm at that
% position; every node above a change is generated. recast reprints a
% transformed AST the same way, reusing the original text of subtrees that
% are deep-equal in place and printing only the changed ones:
% https://github.com/benjamn/recast/blob/v0.23.9/lib/patcher.ts (findChildReprints)
observe_rewriter(Term, Bound, Goal) :-
    ( nb_current('$metta_observed_form', Context)
    -> copy_term(Term, Before), call(Goal),
       arg(1, Context, Tree),
       ( Before =@= Term
       -> align_rewritten(Term, Bound, Tree, Aligned, Verdict)
       ; Tree = node(Span, _), Aligned = node(Span, generated('form-rewriter')),
         Verdict = changed ),
       ( Verdict == same -> true ; nb_setarg(2, Context, aligned(Aligned)) )
    ; call(Goal) ).

% Leaves compare by ==, so a rebuilt list holding the same atoms is the
% written list and two variables correspond only when they are one variable.
% A list of another length, or a leaf where a list stood, has no known
% children; a token constructor's list value is a leaf in the written tree.
align_rewritten(Original, Rewritten, Tree, Aligned, Verdict) :-
    Tree = node(Span, Children),
    (   Children == []
    ->  ( Original == Rewritten -> Aligned = Tree, Verdict = same
        ; Aligned = node(Span, generated('form-rewriter')), Verdict = changed )
    ;   is_list(Children), is_list(Original), is_list(Rewritten),
        same_length(Original, Children), same_length(Rewritten, Children)
    ->  align_rewritten_children(Original, Rewritten, Children, AlignedChildren,
                                 same, Verdict),
        ( Verdict == same -> Aligned = Tree
        ; Aligned = node(Span, generated('form-rewriter', AlignedChildren)) )
    ;   Aligned = node(Span, generated('form-rewriter')), Verdict = changed
    ).

align_rewritten_children([], [], [], [], Verdict, Verdict).
align_rewritten_children([Original|Originals], [Rewritten|Rewrittens], [Tree|Trees],
                         [Aligned|Aligneds], Verdict0, Verdict) :-
    align_rewritten(Original, Rewritten, Tree, Aligned, Child),
    ( Child == same -> Verdict1 = Verdict0 ; Verdict1 = changed ),
    align_rewritten_children(Originals, Rewrittens, Trees, Aligneds, Verdict1, Verdict).

observe_bound_tree(_, Aligned) :-
    nb_current('$metta_observed_form', observed(_, aligned(Aligned))), !.
observe_bound_tree(Tree, Tree).

observe_rewritten(Origin, Bound, Goal) :-
    call(Goal),
    ( Origin = origin(runnable, _),
      nb_current('$metta_compile_locations', Context),
      Context = compiling(_, Tree, _),
      nb_current('$metta_observed_runnable', Runnable)
    -> observe_bound_tree(Tree, BoundTree),
       nb_linkarg(1, Context, Bound), nb_linkarg(2, Context, BoundTree),
       nb_linkarg(3, Runnable, BoundTree)
    ; true ).

source_for_clause(Input, StoredRef, Id, Tree) :-
    variant_sha1(Input, Key),
    current_metta_module(Module),
    source_equation(Key, Module, StoredRef, Id, Expected, Tree),
    Expected =@= Input,
    spaces:stored_atom_of_ref(StoredRef, _, _, _),
    \+ ( clause_source(Compiled, StoredRef, _, _),
         \+ clause_property(Compiled, erased) ),
    !.

compile_clause(Input, Clause, Goal) :-
    ( source_for_clause(Input, StoredRef, Id, Tree)
    -> save_context('$metta_compile_locations', Previous),
       Context = compiling(Input, Tree, []),
       setup_call_cleanup(
           nb_linkval('$metta_compile_locations', Context),
           ( call(Goal),
             arg(3, Context, Records),
             save_pending(Clause, StoredRef, Id, Tree, Records) ),
           restore_context('$metta_compile_locations', Previous))
    ; call(Goal) ).

save_pending(Clause, StoredRef, Id, Tree, Records) :-
    ( nb_current('$metta_pending_source_maps', Pending) -> true ; Pending=[] ),
    nb_linkval('$metta_pending_source_maps',
               [pending(Clause, StoredRef, Id, Tree, Records)|Pending]).

compile_expression(Expression, Start, End, Goal) :-
    call(Goal),
    ( nonvar(Expression), Expression = [_|_],
      nb_current('$metta_compile_locations', Context),
      Context = compiling(Input, Tree, Records),
      source_subterm(Input, Tree, Expression, Span, Kind)
    -> Expression=[Name|_],
       observed_construct(Kind, Name, Construct),
       nb_linkarg(3, Context, [emitted(Span, Construct, Start, End)|Records])
    ; true ).

observed_construct(token, Name, token(Name)).
observed_construct(generated(Reason), _, generated(Reason)).
observed_construct(source, Name, Name).

source_subterm(Term, node(Span,Children), Wanted, Span, Kind) :-
    same_term(Term, Wanted), !,
    ( generated_children(Children, Reason) -> Kind = generated(Reason)
    ; Children==[], Term=[_|_] -> Kind=token
    ; Kind=source ).
source_subterm(Term, node(_,Children), Wanted, Span, Kind) :-
    is_list(Term), aligned_children(Children, Trees),
    same_length(Term, Trees),
    source_subterms(Term, Trees, Wanted, Span, Kind).

% A node's second argument is the list of written subterm nodes, or
% generated(Reason) when nothing below the span is known, or
% generated(Reason, Nodes) when the node was rewritten but its children align.
generated_children(generated(Reason), Reason).
generated_children(generated(Reason, _), Reason).
aligned_children(generated(_, Trees), Trees) :- !.
aligned_children(Trees, Trees) :- is_list(Trees).
source_subterms([Term|_], [Tree|_], Wanted, Span, Kind) :-
    source_subterm(Term, Tree, Wanted, Span, Kind), !.
source_subterms([_|Terms], [_|Trees], Wanted, Span, Kind) :-
    source_subterms(Terms, Trees, Wanted, Span, Kind).

% The compiler retains goal identities while joining its goal lists. Resolve
% those identities against the final clause before assertz copies the term.
% Recursive fuel prefixes may add goals but leave the original goals shared.
publish_clause(Ref, Clause) :-
    ( nb_current('$metta_pending_source_maps', Pending),
      select_pending(Clause, Pending, Entry, Rest)
    -> nb_linkval('$metta_pending_source_maps', Rest),
       Entry = pending(_, StoredRef, Id, node(ClauseSpan,Children), Records),
       assertz(clause_source(Ref, StoredRef, Id, ClauseSpan)),
       ( generated_children(Children, Reason)
       -> assertz(unavailable_location(Id, ClauseSpan, Reason, Ref))
       ; true ),
       publish_locations(Ref, Clause, Id, ClauseSpan, Records)
    ; true ).

publish_locations(Ref, Clause, Id, ClauseSpan, Records) :-
    forall(( clause_shape_matches(Ref,Clause),
             goal_path(Clause, [], Path, Goal),
             most_specific_span(Goal, Records, Span, Construct) ),
           publish_location(Ref, Path, Id, ClauseSpan, Span, Construct, Goal)),
    forall(( member(emitted(Span, Emitted, Start, End), Records),
             \+ same_term(Start, End),
             \+ clause_location(Ref, _, Id, Span, _),
             \+ unavailable_location(Id, Span, _, Ref),
             ( Emitted = generated(Construct) -> true
             ; containing_construct(Span, Ref, Construct) ) ),
           assertz(unavailable_location(Id, Span, Construct, Ref))).

% Code a rewriter generated is located at the whole form, the nearest span the
% written source still vouches for, and the span it displaced reports its
% coverage unavailable; SWI likewise reports a generated closure by its
% parent's construct (goal_attribution/3 below).
publish_location(Ref, Path, Id, ClauseSpan, Span, generated(Reason), _) :- !,
    assertz(clause_location(Ref, Path, Id, ClauseSpan, ['generated-by', Reason])),
    ( unavailable_location(Id, Span, Reason, Ref) -> true
    ; assertz(unavailable_location(Id, Span, Reason, Ref)) ).
publish_location(Ref, Path, Id, _, Span, Construct, Goal) :-
    goal_attribution(Goal, Construct, Attribution),
    assertz(clause_location(Ref, Path, Id, Span, Attribution)).

% Validate the complete normalized compiler tree against SWI's actual clause.
% Unknown VM simplifications invalidate attribution rather than shifting a
% written site to a different instruction with a coincidentally equal term.
clause_shape_matches(Ref, (Head:-Body)) :-
    clause(QualifiedHead,DecodedBody,Ref),
    strip_module(QualifiedHead,_,DecodedHead),
    canonical_control(Body,Canonical),
    copy_term_nat((Head:-Canonical),Plain),
    Plain =@= (DecodedHead:-DecodedBody).

% A meta predicate executes a generated closure. SWI reports its parent's PC,
% which identifies the generating construct, not an inner source instruction.
%
% The goals walked here are a compiled clause's own, so most of them are MeTTa
% functions in their space's module and not host predicates. meta_predicate/1
% is one of the properties SWI answers through the undefined-procedure trap,
% which searches the whole autoload library index before raising the existence
% error, so asking it about such a name cost 1,030 inferences to learn "no".
% current_predicate/1 admits what the module already has and
% implementation_module/1 admits what it would autoload, for 33, so the ask
% below still autoloads exactly when it used to
% [source: /usr/lib/swi-prolog/boot/syspred.pl, property_predicate/2;
% measured 2026-09-06; commit=693b1bdb6ed06cd0ba01e901a8a6d774bc733d19].
goal_attribution(_, token(Name), ['generated-by',['token-constructor',Name]]) :- !.
goal_attribution(Goal, Construct, ['generated-by', Construct]) :-
    strip_module(Goal, Module, Plain),
    resolves_for_property(Module, Plain),
    predicate_property(Module:Plain, meta_predicate(_)), !.
goal_attribution(_, _, exact).

% Whether asking Module for a property of Head can answer at all, without
% paying the search that answering "no" costs. True for a name the module
% holds, imports or inherits, and for one the autoloader would supply;
% implementation_module/1 reports the module itself when nothing resolves the
% name, which is the case worth not paying for.
resolves_for_property(Module, Head) :-
    functor(Head, Name, Arity),
    (   current_predicate(Module:Name/Arity)
    ->  true
    ;   predicate_property(Module:Head, implementation_module(Home)),
        Home \== Module
    ).

containing_construct(span(A,B,_,_,_,_), Ref, Construct) :-
    findall(Width-Name,
            ( clause_location(Ref,_,_,span(C,D,_,_,_,_),['generated-by',Name]),
              C =< A, B =< D, Width is D-C ), Candidates),
    keysort(Candidates, [_-Construct|_]), !.
containing_construct(_, _, compiler).

select_pending(Clause, [Entry|Rest], Entry, Rest) :-
    Entry = pending((Head:-Body), _, _, _, _),
    Clause = (FinalHead:-FinalBody),
    same_term(Head, FinalHead),
    ( same_term(Body,FinalBody) ; FinalBody=(_,Tail), same_term(Body,Tail) ), !.
select_pending(Clause, [Entry|Pending], Found, [Entry|Rest]) :-
    select_pending(Clause, Pending, Found, Rest).

goal_path((Head:-Body), Path0, Path, Goal) :- !,
    nonvar(Head), canonical_control(Body,Canonical),
    append(Path0,[2],BodyPath), goal_path(Canonical,BodyPath,Path,Goal).
goal_path(Term, Path0, Path, Goal) :-
    nonvar(Term), compound(Term), compound_name_arity(Term,Name,2),
    % policy-inventory-exempt: mechanism-internal; reason=the four binary control functors are Prolog's own clause-body syntax, the shapes the debugger's goal paths descend, not a MeTTa policy value; evidence=engine/source_observation.pl:canonical_control/2
    memberchk(Name, [',',';','->','*->']), !,
    ( arg(1,Term,Child), append(Path0,[1],Next)
    ; arg(2,Term,Child), append(Path0,[2],Next) ),
    goal_path(Child,Next,Path,Goal).
goal_path(Goal, Path, Path, Goal) :- compound(Goal).

% assertz compiles conjunction trees associatively; its debugger paths describe
% the canonical decompiled tree. Reassociate controls while retaining leaf goal
% identities. Without this, ((a,b),c) puts b at a path that the VM assigns c.
canonical_control(Goal, Canonical) :-
    compound(Goal), compound_name_arity(Goal,Name,2),
    % policy-inventory-exempt: mechanism-internal; reason=the same four control functors, reassociated the way assertz compiles them so debugger paths match the VM; evidence=engine/source_observation.pl:goal_path/4
    memberchk(Name,[',',';','->','*->']), !,
    arg(1,Goal,Left), arg(2,Goal,Right),
    canonical_control(Left,A), canonical_control(Right,B),
    % policy-inventory-exempt: mechanism-internal; reason=only conjunction and disjunction are associative, so only these two reassociate and the arrows keep their shape; evidence=engine/source_observation.pl:join_control/4
    ( memberchk(Name,[',',';']) -> join_control(Name,A,B,Canonical)
    ; compound_name_arguments(Canonical,Name,[A,B]) ).
canonical_control(Goal,Goal).

join_control(Name,Left,Right,Combined) :-
    nonvar(Left), compound(Left), compound_name_arity(Left,Name,2), !,
    arg(1,Left,A),arg(2,Left,B),
    join_control(Name,B,Right,Rest),
    compound_name_arguments(Combined,Name,[A,Rest]).
join_control(Name,Left,Right,Combined) :-
    compound_name_arguments(Combined,Name,[Left,Right]).

emitted_goal(Start, End, Goal) :-
    \+ same_term(Start,End), Start=[First|Rest],
    ( goal_path(First,[],_,Goal) ; emitted_goal(Rest,End,Goal) ).

most_specific_span(Goal, Records, Span, Construct) :-
    findall(Width-(Candidate-Name),
            ( member(emitted(Candidate,Name,Start,End),Records),
              once((emitted_goal(Start,End,Original),same_term(Goal,Original))),
              Candidate=span(A,B,_,_,_,_), Width is B-A ), Pairs),
    keysort(Pairs, [_-(Span-Construct)|_]), !.
most_specific_span(Goal, Records, Span, Construct) :-
    % Lowering rebuilds meta-goal compounds while retaining their fresh result
    % variable. Require one unique origin; shared or ground results refuse.
    compound(Goal), compound_name_arity(Goal,Name,Arity),
    arg(Arity,Goal,Result), var(Result),
    findall(Width-(Candidate-SourceName),
            ( member(emitted(Candidate,SourceName,Start,End),Records),
              emitted_goal(Start,End,Original),
              compound(Original), compound_name_arity(Original,Name,Arity),
              arg(Arity,Original,OriginalResult), var(OriginalResult),
              same_term(Result,OriginalResult),
              Candidate=span(A,B,_,_,_,_), Width is B-A ), Candidates),
    keysort(Candidates,[Minimum-First|Rest]),
    findall(Other,member(Minimum-Other,Rest),Ties),
    sort([First|Ties],[Span-Construct]).

% The engine announces a constructed Error through the sink this module puts
% in the observation buffer, so nothing here is installed while no observation
% is running and the engine names no predicate of this module
% [source: engine/metta/terms.pl metta_record_error/1].
record_error(Buffer, Error) :-
    current_source_frames(Frames),
    observation_error(Buffer, Error, Frames).

% Follow the actual environment chain without a guessed depth limit. The PC
% on a child frame belongs to its suspended parent, as in SWI prolog_stack.pl.
current_source_frames(Frames) :-
    prolog_current_frame(Current),
    source_frames(Current, call, Frames).

source_frames(Current, PC, Frames) :-
    ( source_frame(Current, PC, Frame)
    -> Frames=[Frame|Rest]
    ; Frames=Rest ),
    ( prolog_frame_attribute(Current, parent, Parent)
    -> ( prolog_frame_attribute(Current, pc, ParentPC) -> true ; ParentPC=foreign ),
       source_frames(Parent, ParentPC, Rest)
    ; Rest=[] ).

source_frame(Current, PC, frame(Name,Label,Span,Attribution)) :-
    integer(PC),
    prolog_frame_attribute(Current,clause,Ref),
    clause_source(Ref,_,_,_),
    clause_position(Ref,PC,Path),
    clause_location(Ref,Path,Id,Span,Attribution),
    source_document(Id,Label,_),
    prolog_frame_attribute(Current,predicate_indicator,Indicator),
    ( Indicator=(_:Plain) -> true ; Plain=Indicator ),
    Plain=RawName/_,
    ( sub_atom(RawName,0,_,_,'$metta_observed_') -> Name='top-level' ; Name=RawName ).
source_frame(Current, _, unavailable('top-level','source-site-unavailable')) :-
    prolog_frame_attribute(Current,clause,Ref),
    clause_source(Ref,temporary,_,_), !.
source_frame(Current, _, unavailable(Name,Reason)) :-
    prolog_frame_attribute(Current,clause,Ref),
    filereader:translated_from(Ref,[=,[Name|_],_]),
    ( clause_source(Ref,_,_,_) -> Reason='source-site-unavailable'
    ; Reason='source-not-observed' ).

observation_error(Buffer, Error, Frames) :-
    arg(2,Buffer,Errors),
    copy_term(Error-Frames, Copy-FrozenFrames),
    nb_setarg(2,Buffer,[error(Copy,FrozenFrames)|Errors]).

% Both hooks are DECLARED here and CLAUSED only while an observation runs.
% SWI decides whether to consult prolog:prolog_exception_hook/5 by whether it
% holds a clause, not by whether the predicate exists, so one resident clause
% taxes every exception the process throws for as long as the module is
% loaded: it cost 119 inferences on the engine's translate case and 2 per
% compiled host request, which is 3,998 over foreign-match's 2,000 runs
% [measured 2026-09-05: engine/bench.py translate reads 362,516 with the
% clause resident and 362,397 with it removed or merely declared, three
% identical samples each]. Its clause is asserted beside the compiler
% wrappers and erased with them. Loading this module then costs a caught
% DivisionByZero nothing, against 3 inferences with a resident clause, and one
% completed observation leaves that same exception 1 inference dearer for the
% rest of the process where a resident clause leaves it 2; the remaining 1 is
% SWI's own hook machinery staying armed once a clause has existed, it does
% not accumulate over further observations, and no clause of ours survives
% [measured 2026-09-05: 34 before loading, 34 after loading, 35 after one
% observation and 35 after two, against 34/37/36/36 with the clause resident;
% command=statistics(inferences) around a caught (/ 1 0) through
% metta_run_named/3, taken before loading this module, after loading it, and
% after each of two observations, in one swipl that consulted
% engine/qlf_boot.pl and engine/metta.pl; tested:
% source_observation:the_observer_holds_no_hook_outside_an_observation].
% library(prolog_stack) declares the same hook dynamic and multifile and adds
% a clause of its own, so removal erases THIS clause by reference and never
% retracts the predicate [source: /usr/lib/swi-prolog/library/prolog_stack.pl
% lines 699-702, SWI-Prolog 10.1.13].
:- multifile prolog:prolog_exception_hook/5.
:- dynamic prolog:prolog_exception_hook/5.

% Dynamic clauses are omitted by SWI's native coverage counters. Its debugger
% still exposes the caller clause and program counter at each call port, so
% the observer maps those events through the same code metadata as errors.
:- multifile user:prolog_trace_interception/4.
:- dynamic user:prolog_trace_interception/4.

%The clause refs of the two hooks above, erased when the observation that
%asserted them ends. observe_source/4 holds '$metta_observation_session' for
%the whole observation, so one process-wide record is enough.
:- dynamic installed_hook/1.

%The exception observer goes FIRST and FAILS. SWI runs the hook as one query
%and keeps its first solution, so a clause that answers hides every clause
%after it [source 2026-09-25T00:44:28+10:00: https://github.com/SWI-Prolog/swipl-devel/blob/69775434c8226897626b226aefcc8266499f1e2e/src/pl-wam.c#L2314-L2321].
%Appended and answering, the observer saw an error only when no clause before
%it answered. Under NO_AUTOLOAD=1 library(prolog_stack) is loaded, and its
%clause answers every error raised under the observation's trace, because the
%trace makes DebugMode true [source 2026-09-25T00:44:28+10:00: https://github.com/SWI-Prolog/swipl-devel/blob/69775434c8226897626b226aefcc8266499f1e2e/library/prolog_stack.pl#L702-L717].
%So observe-source stored no native error at all: the hook held prolog_stack's
%clause and then this one, and no division raised under the observations
%reached this one [measured 2026-09-25T00:01:55+10:00: the observer
%instrumented in a battery of the tree before this change, NO_AUTOLOAD=1 sh
%tools/run.sh on a source observed twice]. A failing hook leaves ExceptionIn
%in force, so every other clause still answers as it would without an
%observation [source 2026-09-25T00:44:28+10:00: https://github.com/SWI-Prolog/swipl-devel/blob/69775434c8226897626b226aefcc8266499f1e2e/man/hack.plx#L444],
%and running first is also what lets observe_exception/4 keep the exception
%that escapes to the observation as it was raised.
%library(prolog_debug) installs its own observing hook the same way, asserta'd
%and failing [source 2026-09-25T00:44:28+10:00: https://github.com/SWI-Prolog/swipl-devel/blob/69775434c8226897626b226aefcc8266499f1e2e/library/prolog_debug.pl#L319-L368].
install_exception_observers :-
    asserta((prolog:prolog_exception_hook(Error, _, Frame, Catcher, _) :-
                 nb_current('$metta_observation', Buffer),
                 source_observation:observe_exception(Buffer,Error,Frame,Catcher),
                 fail),
            ExceptionReference),
    assertz(installed_hook(ExceptionReference)),
    % The buffer is a global variable of the observing thread, so the
    % process-wide hook is inert at every port of every other thread.
    assertz((user:prolog_trace_interception(Port, Frame, _, continue) :-
                 nb_current('$metta_observation', Buffer),
                 source_observation:observe_port(Port,Frame,Buffer)),
            TraceReference),
    assertz(installed_hook(TraceReference)).

%Total, like remove_wrapper/2 below, because this runs in the cleanup that
%also removes the compiler and runtime wrappers: a raise here would strand them, and a
%hook clause outlives the whole rest of the process. Nothing hides behind the
%catch, because the_observer_holds_no_hook_outside_an_observation asks the
%database whether the clauses are actually gone.
%NOT host_transactions:try_erase/1, which propagates a raise on purpose, and
%the reason is this site's own rather than a count: the erase runs while the
%exception observers are being torn down, so a raise here would strand the
%remaining hooks. The other broad catch is filereader's retirement loop,
%where the clause carries a prolog_listen/2 callback that can raise for its
%own reasons; every erase over a table another path can reach is try_erase/1.
%[The claim here used to be that this was the ONE such erase. It counted
%wrong: space_hooks and native_matching had four between them, none with a
%reason of its own, and they became try_erase/1 on 2026-09-21.]
%
%Total for a LOST reference too, which catch/3 alone was not: an erase that
%failed made forall/2 fail at that row and left every later hook installed.
%A row can name a clause that is already gone, because installed_hook/1 is
%transactional and an observation inside a transaction opened during an
%earlier observation still reads that observation's rows after it removed
%them [tested 2026-09-25T19:33:07+10:00: host_transactions:a_row_naming_a_clause_another_thread_erased_is_released_only_by_try_erase].
remove_exception_observers :-
    forall(retract(installed_hook(Reference)),
           % erase-license: teardown; the observers' teardown must reach its
           % last hook, so it contains a raise and a reference already gone
           % [tested 2026-09-25T19:33:07+10:00: source_observation:the_observer_holds_no_hook_outside_an_observation,
           % erase_sites:a_stale_observer_row_leaves_no_hook_behind].
           ( catch(erase(Reference), _, true) -> true ; true )).

observe_port(call, Frame, Buffer) :- !,
    ( prolog_frame_attribute(Frame,pc,PC),
      prolog_frame_attribute(Frame,parent,Parent),
      prolog_frame_attribute(Parent,clause,Ref),
      clause_source(Ref,_,_,_),
      integer(PC), clause_position(Ref,PC,Path),
      clause_location(Ref,Path,Id,Span,_)
    -> observation_hit(Buffer, site(Ref,Path,Id,Span))
    ; true ).
observe_port(unify, Frame, Buffer) :- !,
    ( prolog_frame_attribute(Frame,clause,Ref),
      clause_source(Ref,_,Id,Span)
    -> observation_hit(Buffer, clause(Ref,Id,Span))
    ; prolog_frame_attribute(Frame,clause,Ref),
      filereader:translated_from(Ref,[=,[Name|_],_])
    -> ( unavailable_function(Name) -> true ; assertz(unavailable_function(Name)) )
    ; true ).
observe_port(_,_,_).

observation_hit(Buffer, Key) :-
    arg(1,Buffer,Hits),
    ( get_assoc(Key,Hits,_) -> true
    ; put_assoc(Key,Hits,1,Updated), nb_linkarg(1,Buffer,Updated) ).

:- meta_predicate observe_form(+, +, ?, 0).
:- meta_predicate observe_goals(+, +, 0).

observe_form(Space, Form, Answers, Goal) :-
    ( nb_current('$metta_observation', _),
      filereader:source_form(Form, ParsedForm),
      filereader:parsed_form_parts(ParsedForm, Kind, _, Term),
      nb_current('$metta_source_context',context(_,Id,_,Pairs)),
      member(PairForm-positioned(_,_,_,_,Tree),Pairs),
      same_term(ParsedForm,PairForm)
    -> save_context('$metta_observed_form', Previous),
       setup_call_cleanup(
           nb_linkval('$metta_observed_form', observed(Tree, none)),
           observe_positioned_form(Kind, Space, Term, Id, Tree, Answers, Goal),
           restore_context('$metta_observed_form', Previous))
    ; call(Goal) ).

observe_positioned_form(runnable, Space, Term, Id, Tree, Answers, Goal) :- !,
    save_context('$metta_compile_locations', Previous),
    save_context('$metta_observed_runnable', PreviousRunnable),
    Context=compiling(Term,Tree,[]),
    setup_call_cleanup(
        ( nb_linkval('$metta_compile_locations',Context),
          nb_linkval('$metta_observed_runnable',runnable(Space,Id,Tree,Context)) ),
        (call(Goal),record_answers(Id,Answers)),
        ( restore_context('$metta_compile_locations',Previous),
          restore_context('$metta_observed_runnable',PreviousRunnable) )).
observe_positioned_form(_, _, _, _, _, _, Goal) :- call(Goal).

observe_goals(Module, Goals, Original) :-
    ( nb_current('$metta_observed_runnable', runnable(_,Id,Tree,Context))
    -> save_context('$metta_observed_runnable', Previous),
       setup_call_cleanup(
           nb_delete('$metta_observed_runnable'),
           execute_observed_goals(Module,Goals,Id,Tree,Context),
           restore_context('$metta_observed_runnable',Previous))
    ; call(Original) ).

execute_observed_goals(Module,Goals,Id,node(Span,_),Context) :-
    term_variables(Goals,Variables),
    ( Goals==[] -> Body=true ; comma_list(Body,Goals) ),
    flag('$metta_observed_goal',Serial,Serial+1),
    atomic_list_concat(['$metta_observed_',Serial],Name),
    Head=..[Name,Variables], Clause=(Head:-Body),
    setup_call_cleanup(
        assertz(Module:Clause,Ref),
        ( assertz(clause_source(Ref,temporary,Id,Span)),
          arg(3,Context,Records),
          publish_locations(Ref,Clause,Id,Span,Records),
          forall((goal_path(Clause,[],Path,_),\+ clause_location(Ref,Path,_,_,_)),
                 assertz(clause_location(Ref,Path,Id,Span,['generated-by',execution]))),
          call(Module:Head) ),
        % try_erase/1 because the observed goal runs the program, and a
        % program that clears its own space retracts this clause with every
        % other predicate its module owns, so the abolish still has to run
        % [source 2026-09-25T16:46:51+10:00: engine/spaces/lifecycle.pl,
        % clear_generated_predicates/1].
        ( host_transactions:try_erase(Ref), abolish(Module:Name/1) )).

:- meta_predicate source_input(+,0), source_forms(+,+,0).
source_input(Source,Goal) :-
    ( nb_current('$metta_observation',_) ->
      save_context('$metta_source_input',Previous),
      setup_call_cleanup(nb_linkval('$metta_source_input',pending(Source,new)),
                         Goal,restore_context('$metta_source_input',Previous))
    ; call(Goal) ).
source_forms(Parsed,Space,Goal) :-
    ( nb_current('$metta_source_input',Pending), Pending=pending(Source,new)
    -> nb_linkarg(2,Pending,consumed),
       maplist(filereader:source_form, Parsed, Forms),
       with_source(Source,Forms,Space,Goal)
    ; call(Goal) ).

install_runtime_observers :-
    install_exception_observers,
    wrap_predicate(filereader:rewrite_source_form(_, Input, _, Bound, _), source_observer,
                   Rewriter, source_observation:observe_rewriter(Input, Bound, Rewriter)),
    wrap_predicate(filereader:metta_host_run_source(Source,_,_,_), source_observer,
                   Host, source_observation:source_input(Source,Host)),
    wrap_predicate(filereader:process_direct_metta_string(Source,_,_), source_observer,
                   Direct, source_observation:source_input(Source,Direct)),
    wrap_predicate(filereader:process_loader_string(Source,_,_), source_observer,
                   Loader, source_observation:source_input(Source,Loader)),
    wrap_predicate(filereader:metta_host_process_groups(Parsed,Space,_), source_observer,
                   Groups, source_observation:source_forms(Parsed,Space,Groups)),
    wrap_predicate(filereader:process_forms(_,Space,Parsed,_), source_observer,
                   Forms, source_observation:source_forms(Parsed,Space,Forms)),
    wrap_predicate(filereader:record_source_atom_assertion(Ref), source_observer,
                   Stored, (Stored,source_observation:record_stored(Ref))),
    wrap_predicate(spaces:assert_function_clause(_,Clause,Ref), source_observer,
                   Asserted, (Asserted,source_observation:publish_clause(Ref,Clause))),
    wrap_predicate(filereader:process_form(Space,Form,Answers), source_observer,
                   OriginalForm, source_observation:observe_form(Space,Form,Answers,OriginalForm)),
    wrap_predicate(filereader:process_loader_form(Space,Form,LoaderAnswers), source_observer,
                   OriginalLoader, source_observation:observe_form(Space,Form,LoaderAnswers,OriginalLoader)),
    metta_engine_module(Engine),
    % wrap_predicate/4 takes the most general head; the origin's kind is read inside.
    wrap_predicate(Engine:rewrite_parsed_form(_, Origin, _, _, Rewritten), source_observer,
                   ParsedRewrite, source_observation:observe_rewritten(Origin, Rewritten, ParsedRewrite)),
    wrap_predicate(Engine:call_goals_in(Module,Goals), source_observer,
                   OriginalGoals, source_observation:observe_goals(Module,Goals,OriginalGoals)).

remove_runtime_observers :-
    remove_exception_observers,
    % policy-inventory-exempt: mechanism-internal; reason=the loader predicates this observer wraps at install, listed so removal unwraps exactly the set installation wrapped; evidence=engine/source_observation.pl:remove_wrapper/2
    forall(member(PI,[metta_host_run_source/4,process_direct_metta_string/3,
                      process_loader_string/3,metta_host_process_groups/3,
                      process_forms/4,record_source_atom_assertion/1,
                      process_form/3,process_loader_form/3,rewrite_source_form/5]),
           remove_wrapper(filereader:PI,source_observer)),
    remove_wrapper(spaces:assert_function_clause/3,source_observer),
    metta_engine_module(Engine),
    remove_wrapper(Engine:rewrite_parsed_form/5,source_observer),
    remove_wrapper(Engine:call_goals_in/2,source_observer).

remove_wrapper(PI,Name) :-
    ( unwrap_predicate(PI,Name) -> true ; true ).

observe_source(Space, Label, Source, Atoms) :-
    observation_string(Label,'pass the source label as a string'),
    observation_string(Source,'pass executable MeTTa source as a string'),
    ( spaces:metta_space_name(Space) -> true
    ; throw(error(type_error('SpaceType',Space),
                  context('observe-source','pass &self or a space returned by new-space'))) ),
    ( nb_current('$metta_observation',_)
    -> throw(error(permission_error(observe,execution,nested),
                    context('observe-source','finish the current observation first')))
    ; true ),
    ( tracing
    -> throw(error(permission_error(observe,debugger,active),
                   context('observe-source','finish the active native debugger trace first')))
    ; true ),
    with_mutex('$metta_observation_session',
               observe_source_locked(Space,Label,Source,Atoms)).

observation_string(Value,Remedy) :-
    ( string(Value) -> true
    ; throw(error(type_error(string,Value),context('observe-source',Remedy))) ).

%The shape the engine reads. Argument five is the sink engine/metta/terms.pl
%calls for a constructed Error, which is what keeps the engine free of any
%reference to this module; the first four are the hit set, the recorded
%errors, the completed root-form answers and the document being observed; six
%is the frame run_observed/5 calls its catch/3 from, `none` outside it, and
%seven is escaped(Raised) once the exception observer has seen an exception
%raised to that catch, `none` before.
%One constructor because the shape has two readers, this file and
%tests/prolog/suites/reader/source_observation.plt, and a second spelling of
%it in the suite is a shape that can drift.
new_observation_buffer(observations(Hits,[],answers(0,[]),none,
                                    source_observation:record_error,
                                    none,none)) :-
    empty_assoc(Hits).

observe_source_locked(Space,Label,Source,Atoms) :-
    new_observation_buffer(Buffer),
    save_context('$metta_observe_label', PreviousLabel),
    current_prolog_flag(debug, Debug),
    current_prolog_flag(last_call_optimisation,LCO),
    '$visible'(Visible,Visible),
    setup_call_cleanup(
        true,
        ( nb_linkval('$metta_observe_label',Label),
          nb_linkval('$metta_observation',Buffer),
          install_compiler_observers, install_runtime_observers,
          visible([+all,+cut,+exception]),
          run_observed(Buffer,Source,Space,Groups,Error),
          notrace,
          collect_observation(Buffer,Groups,Error,Atoms) ),
        ( notrace,
          '$visible'(_,Visible), set_prolog_flag(debug,Debug),
          set_prolog_flag(last_call_optimisation,LCO),
          remove_runtime_observers, remove_compiler_observers,
          retractall(source_document(_,_,_)),
          retractall(source_equation(_,_,_,_,_,_)),
          retractall(clause_source(_,_,_,_)),
          retractall(clause_location(_,_,_,_,_)),
          retractall(unavailable_location(_,_,_,_)),
          retractall(unavailable_function(_)),
          nb_delete('$metta_pending_source_maps'),
          nb_delete('$metta_observation'),
          restore_context('$metta_observe_label',PreviousLabel) )).

%The observed run, in a predicate of its own because SWI hands the exception
%hook, as CatcherFrame, the frame that calls the catch/3 an exception will
%reach [source 2026-09-25T00:44:28+10:00: https://github.com/SWI-Prolog/swipl-devel/blob/69775434c8226897626b226aefcc8266499f1e2e/src/pl-wam.c#L2294-L2306].
%An exception whose catcher is this frame is therefore the one this catch
%receives, and the observer keeps it as raised: this catch receives it only
%after every other hook clause has had it, and library(prolog_stack)'s clause
%replaces an error's context with a backtrace. The goal after the catch keeps
%last-call optimisation from giving this frame to catch/3, which would hand
%the hook this frame's caller instead.
run_observed(Buffer,Source,Space,Groups,Error) :-
    prolog_current_frame(Frame),
    nb_setarg(6,Buffer,Frame),
    catch((trace,filereader:metta_host_run_source(Source,Space,[],Groups)),
          Error,true),
    nb_setarg(6,Buffer,none).

%The exception observer's record of one raise: the exception as raised when
%run_observed/5's catch will receive it, and the error with its source frames
%when observed source raised it.
observe_exception(Buffer,Error,Frame,Catcher) :-
    ( arg(6,Buffer,Run), integer(Run), Catcher == Run
    -> nb_setarg(7,Buffer,escaped(Error))
    ; true ),
    ( source_frames(Frame,call,Frames), Frames \== []
    -> observation_error(Buffer,Error,Frames)
    ; true ).

%The exception the observed run raised, as the observer kept it, or the caught
%term when the observer saw no raise to that catch. SWI does not call the hook
%for unwind(_) or a resource error, while tracing is suspended, or for a catch
%frame whose exception it is already rewriting [source 2026-09-25T00:44:28+10:00: https://github.com/SWI-Prolog/swipl-devel/blob/69775434c8226897626b226aefcc8266499f1e2e/src/pl-vmi.c#L4933-L4939,
%https://github.com/SWI-Prolog/swipl-devel/blob/69775434c8226897626b226aefcc8266499f1e2e/src/pl-wam.c#L2297-L2302].
raised_exception(Buffer,Caught,Raised) :-
    ( arg(7,Buffer,escaped(Raised)) -> true ; Raised=Caught ).

collect_observation(Buffer, _Groups, Error, Atoms) :-
    arg(1,Buffer,Hits), arg(2,Buffer,Errors0), reverse(Errors0,Errors),
    arg(3,Buffer,answers(_,ReverseAnswers)), reverse(ReverseAnswers,Answers),
    ( var(Error)
    -> Extra=[], Status=['observation-status',complete]
    ; raised_exception(Buffer,Error,Raised),
      observation_text(Raised,Message), Extra=[['observation-exception',Message]],
      Status=['observation-status',exception] ),
    findall(['source-coverage',Label,L,C,EL,EC,Count],
            ( observed_location(Id,Span),
              source_document(Id,Label,_),
              Span=span(_,_,L,C,EL,EC),
              location_hits(Hits,Id,Span,Count) ), Coverage),
    error_atoms(Errors,0,ErrorAtoms),
    % A location at the same span attributed to the same construct anchors the
    % frames of generated code there; it is not a coverage claim for the span.
    findall(['source-coverage-unavailable',Label,L,C,EL,EC,['generated-by',Construct]],
            ( unavailable_location(Id,Span,Construct,_),
              \+ ( clause_location(_,_,Id,Span,Attribution),
                   Attribution \== ['generated-by',Construct] ),
              Span=span(_,_,L,C,EL,EC),
              source_document(Id,Label,_) ), Unavailable0),
    findall(['source-coverage-unavailable',Label,L,C,EL,EC,'not-compiled'],
            ( source_equation(_,_,Stored,Id,_,node(_,Children)),
              aligned_children(Children, [_,_,node(span(_,_,L,C,EL,EC),_)]),
              \+ clause_source(_,Stored,_,_), source_document(Id,Label,_) ),
            Deferred),
    append(Unavailable0,Deferred,Unavailable1),
    sort(Unavailable1,Unavailable),
    findall(['source-function-unavailable',Name,'source-not-observed'],
            unavailable_function(Name),UnmappedFunctions),
    append([[Status],Answers,Extra,Coverage,Unavailable,UnmappedFunctions,ErrorAtoms],Atoms).

observed_location(Id,Span) :-
    findall(Id0-Span0,
            ( clause_location(_,_,Id0,Span0,_)
            ; clause_source(_,_,Id0,Span0)
            ; source_equation(_,_,_,Id0,_,node(Span0,_)) ),
            Locations),
    sort(Locations,Pairs), member(Id-Span,Pairs).

location_hits(Hits,Id,Span,Count) :-
    assoc_to_list(Hits,Pairs),
    findall(N,(member(Key-N,Pairs),hit_location(Key,Id,Span)),Counts),
    ( member(N,Counts), N > 0 -> Count=1 ; Count=0 ).
hit_location(site(_,_,Id,Span),Id,Span).
hit_location(clause(_,Id,Span),Id,Span).

% A later exception backtracks the loader's grouped result. Snapshot completed
% root forms when each returns, so the report keeps their answers and writes.
record_answers(Id,Answers) :-
    nb_getval('$metta_observation',Buffer),
    ( arg(4,Buffer,Id)
    -> arg(3,Buffer,answers(Index,Previous)),
       findall(['observation-answer',Index,Answer],
               (member(Carried,Answers),filereader:metta_answer_term(Carried,Answer)),Rows),
       reverse(Rows,Reverse), append(Reverse,Previous,Combined),
       Next is Index+1, nb_setarg(3,Buffer,answers(Next,Combined))
    ; true ).

error_atoms([],_,[]).
error_atoms([error(Error,Frames)|Errors],Index,Atoms) :-
    ( is_list(Error) -> Value=Error ; observation_text(Error,Value) ),
    frame_atoms(Frames,Index,0,FrameAtoms),
    Next is Index+1, error_atoms(Errors,Next,Rest),
    append([['source-error',Index,Value]|FrameAtoms],Rest,Atoms).
frame_atoms([],_,_,[]).
frame_atoms([frame(Name,Label,span(_,_,L,C,EL,EC),Attribution)|Frames],Id,Depth,
             [['source-frame',Id,Depth,Name,Label,L,C,EL,EC,Attribution]|Atoms]) :-
    Next is Depth+1, frame_atoms(Frames,Id,Next,Atoms).

frame_atoms([unavailable(Name,Reason)|Frames],Id,Depth,
             [['source-frame-unavailable',Id,Depth,Name,Reason]|Atoms]) :-
    Next is Depth+1, frame_atoms(Frames,Id,Next,Atoms).

%An error or exception an observation stores as text, written as a function of
%the term alone. term_string/2 names an unbound variable by its place on the
%engine's stacks, which everything that ran before decides, so one source
%observed twice in one engine stored
%error(evaluation_error(zero_divisor),context((/)/2,_3264)) and then _3278.
%The copy is numbered in one pass instead, as swrite_prolog/2 names variables
%(engine/parser.pl): a singleton prints as _ and a shared variable as A, B, ...,
%so sharing stays visible, and copy_term_nat/2 leaves no attribute for
%numbervars/4 to refuse. A ground term reads as term_string/2 wrote it.
observation_text(Term,Text) :-
    copy_term_nat(Term,Copy),
    numbervars(Copy,0,_,[singletons(true)]),
    format(string(Text),"~W",[Copy,[quoted(true),numbervars(true)]]).


% Some generated VM frames expose a non-source PC that SWI cannot decode.
% Such a frame is unavailable; it is never assigned an enclosing exact span.
clause_position(Ref,PC,Path) :-
    catch('$clause_term_position'(Ref,PC,Path),
          error(representation_error(int),_), fail).
