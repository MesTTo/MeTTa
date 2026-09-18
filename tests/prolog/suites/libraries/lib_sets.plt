% Purpose: compare derived set operations with independent definitions and laws.
% Guarantees: generated canonical sets retain order, identity and uniqueness;
% every variadic argument is checked, including singleton intersections.
% [tested: lib_sets; commit=6471fbad35eced5ed6440ebf2c25a053b20221f3].
:- use_module(collection_test_support).
:- use_module(library(lists), [append/2,member/2,memberchk/2,numlist/3]).
:- use_module(library(apply), [maplist/2]).
:- use_module(library(yall), [(>>)/3]).
:- use_module(library(ordsets), [is_ordset/1]).
:- use_module(library(random), [random_between/3]).
:- initialization(load_collection_library(lib_sets)).

:- begin_tests(lib_sets).

random_set(Set) :-
    random_between(0,6,Size),length(Draws,Size),
    maplist([D]>>random_between(0,9,D),Draws),sort(Draws,Set).
by_definition(Left,Right,union,Answer) :-
    findall(X,(member(X,Left);member(X,Right)),Xs),sort(Xs,Answer).
by_definition(Left,Right,intersection,Answer) :-
    findall(X,(member(X,Left),memberchk(X,Right)),Xs),sort(Xs,Answer).
by_definition(Left,Right,difference,Answer) :-
    findall(X,(member(X,Left),\+memberchk(X,Right)),Xs),sort(Xs,Answer).
by_definition(Left,Right,symmetric,Answer) :-
    findall(X,(member(X,Left),\+memberchk(X,Right)
              ;member(X,Right),\+memberchk(X,Left)),Xs),sort(Xs,Answer).
merge(Operation,Left,Right,Answer) :-
    (Operation==symmetric->Suffix='symmetric-difference';Suffix=Operation),
    atom_concat('set-',Suffix,Head),Goal=..[Head,Left,Right,Answer],invoke(Goal).

test(the_merges_agree_with_their_list_definitions) :-
    set_random(seed(20260912)),
    forall(between(1,300,_),
        (random_set(Left),random_set(Right),
         forall(member(Op,[union,intersection,difference,symmetric]),
            (merge(Op,Left,Right,Answer),by_definition(Left,Right,Op,Expected),
             assertion(Answer==Expected))))).

test(set_of_sorts_and_removes_duplicates, [forall(between(1,100,_))]) :-
    random_between(0,12,Size),length(Draws,Size),
    maplist([D]>>random_between(0,5,D),Draws),invoke('set-of'(Draws,Set)),
    sort(0,@<,Draws,Expected),assertion(Set==Expected),assertion(is_ordset(Set)),
    forall(member(Draw,Draws),invoke('set-member'(Set,Draw,true))),
    length(Set,Distinct),
    findall(D,(member(D,[0,1,2,3,4,5]),memberchk(D,Draws)),Present),
    length(Present,Counted),assertion(Distinct==Counted).

test(every_answer_is_a_set) :-
    set_random(seed(20260912)),
    forall(between(1,200,_),
        (random_set(Left),random_set(Right),random_between(0,9,E),
         forall(member(Op,[union,intersection,difference,symmetric]),
                (merge(Op,Left,Right,Answer),assertion(is_ordset(Answer)))),
         invoke('set-insert'(Left,E,Bigger)),assertion(is_ordset(Bigger)),
         invoke('set-remove'(Left,E,Smaller)),assertion(is_ordset(Smaller)),
         invoke('set-union'(Left,Right,Bigger,All)),assertion(is_ordset(All)),
         invoke('set-intersection'(Left,Right,Bigger,Common)),assertion(is_ordset(Common)))).

test(the_laws_of_the_algebra_hold) :-
    set_random(seed(20260912)),numlist(0,9,Universe),
    forall(between(1,200,_),
        (random_set(A),random_set(B),random_set(C),
         invoke('set-union'(A,B,AB)),invoke('set-union'(B,A,BA)),assertion(AB==BA),
         invoke('set-intersection'(A,B,AiB)),invoke('set-intersection'(B,A,BiA)),
         assertion(AiB==BiA),
         invoke('set-union'(AB,C,AB_C)),invoke('set-union'(B,C,BC)),
         invoke('set-union'(A,BC,A_BC)),assertion(AB_C==A_BC),
         invoke('set-intersection'(A,BC,AiBC)),invoke('set-intersection'(A,C,AiC)),
         invoke('set-union'(AiB,AiC,AiB_AiC)),assertion(AiBC==AiB_AiC),
         invoke('set-difference'(Universe,AB,NotAB)),
         invoke('set-difference'(Universe,A,NotA)),invoke('set-difference'(Universe,B,NotB)),
         invoke('set-intersection'(NotA,NotB,NotA_NotB)),assertion(NotAB==NotA_NotB),
         invoke('set-difference'(A,B,AmB)),invoke('set-difference'(B,A,BmA)),
         invoke('set-union'(AmB,BmA,Either)),invoke('set-symmetric-difference'(A,B,Symmetric)),
         assertion(Either==Symmetric),
         invoke('set-subset'(A,B,Sub)),
         (forall(member(X,A),memberchk(X,B))->assertion(Sub==true);assertion(Sub==false)),
         invoke('set-disjoint'(A,B,Dis)),
         (AiB==[]->assertion(Dis==true);assertion(Dis==false)),
         invoke('set-subset'(A,A,true)),invoke('set-subset'([],A,true)),
         invoke('set-disjoint'([],A,true)))).

test(insertion_and_removal_agree_with_the_merges, [forall(between(1,100,_))]) :-
    random_set(Set),random_between(0,12,E),
    invoke('set-insert'(Set,E,Bigger)),invoke('set-union'(Set,[E],ExpectedBigger)),
    assertion(Bigger==ExpectedBigger),
    invoke('set-remove'(Set,E,Smaller)),invoke('set-difference'(Set,[E],ExpectedSmaller)),
    assertion(Smaller==ExpectedSmaller),
    (memberchk(E,Set)->assertion(Bigger==Set);assertion(Smaller==Set)).

test(variadic_merges_accept_zero_one_and_arbitrary_many_arguments) :-
    set_random(seed(20260912)),
    forall(between(0,12,Count),
        (length(Sets,Count),maplist(random_set,Sets),append(Sets,All),sort(All,Expected),
         append(Sets,[Union],UnionArgs),UnionGoal=..['set-union'|UnionArgs],
         invoke(UnionGoal),assertion(Union==Expected),
         ( Sets=[First|Rest]
         -> findall(X,(member(X,First),forall(member(Set,Rest),memberchk(X,Set))),Common),
            append(Sets,[Intersection],IntersectionArgs),
            IntersectionGoal=..['set-intersection'|IntersectionArgs],
            invoke(IntersectionGoal),assertion(Intersection==Common)
         ; refused('set-intersection'(_))))),
    invoke('set-union'([],[])),invoke('set-intersection'([1,2],[1,2])).

test(membership_compares_terms_rather_than_unifying) :-
    invoke('set-member'([1,2,3],2,true)),invoke('set-member'([1,2,3],4,false)),
    invoke('set-member'([1,2,3],Var,false)),assertion(var(Var)),
    invoke('set-member'([a,b],b,true)),invoke('set-member'([[1,2],[3]],[1,2],true)),
    invoke('set-member'([[1,2],[3]],[1,_],false)),invoke('set-member'([],anything,false)),
    invoke('set-member'([Var],Var,true)),assertion(var(Var)).

test(an_invalid_argument_is_refused_at_every_position) :-
    forall(member(Bad,[[2,1],[1,1],notalist]),
        forall(member(Goal,['set-member'(Bad,1,_),'set-insert'(Bad,1,_),
                            'set-remove'(Bad,1,_),'set-union'(Bad,[1],_),
                            'set-union'([1],Bad,_),'set-intersection'(Bad,[1],_),
                            'set-intersection'([1],Bad,_),'set-difference'([1],Bad,_),
                            'set-symmetric-difference'(Bad,[1],_),
                            'set-subset'(Bad,[1],_),'set-disjoint'([1],Bad,_),
                            'set-union'([1],[2],Bad,_),'set-intersection'(Bad,_)]),
               refused(Goal))),
    refused('set-of'(notalist,_)),
    forall(member(Bad,[[2,1],[1,1],notalist]),invoke('set-is'(Bad,false))),
    invoke('set-is'([],true)),invoke('set-is'([1,2],true)).

test(literal_terms_and_caller_identity_survive_canonicalization) :-
    Input=[['+',1,2],['Error',a,b],X,X,Y],
    sort(Input,Expected),invoke('set-of'(Input,Actual)),assertion(Actual==Expected),
    invoke('set-is'(['Error',a,b],true)),
    invoke('set-union'(['Error',a,b],[],['Error',a,b])),
    invoke('set-intersection'(['Error',a,b],['Error',a,b],['Error',a,b])),
    assertion(var(X)),assertion(var(Y)),assertion(X\==Y).

:- end_tests(lib_sets).
