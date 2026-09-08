% Purpose: validate immutable process identity before native catalog writes.
% Guarantees: receipts advance the atomic generation counter before publication
%   [tested: spaces_tokens; commit=WORKTREE].
% Owns resources: actor and generation flags last until process exit.
% Guarded by: flag/3 serializes counter changes
%   [tested: spaces_tokens:concurrent_minting_is_unique; commit=WORKTREE].
% Decides: boot options override environment values; UUID and zero are defaults.
:- module(metta_identity, [metta_actor/1, metta_boot_identity/0, metta_token_actor/1, metta_token_generation/1, metta_token_parts/3, metta_token_order/3, metta_token_portable/2, metta_token_receive/2, metta_generation_receive/1]).
:- use_module(library(uuid), [uuid/2]).
:- use_module(library(error), [must_be/2, domain_error/2, representation_error/1]).
:- use_module(library(lists), [member/2]).

metta_actor(Actor) :- current_prolog_flag(metta_actor, Actor).

metta_boot_identity :-
    (   current_prolog_flag(metta_actor, _)
    ->  true
    ;   metta_boot_option(actor, 'METTA_ACTOR', ActorOption),
        metta_boot_option(generation, 'METTA_GENERATION', GenerationOption),
        ( ActorOption = some(Actor) -> metta_token_actor(Actor)
        ; uuid(Actor, [version(4)]) ),
        (   GenerationOption = some(Text)
        ->  ( atom_number(Text, Next) -> metta_token_generation(Next)
            ; domain_error(generation, Text) )
        ;   Next = 0
        ),
        flag('$metta_generation', _, Next),
        create_prolog_flag(metta_actor, Actor,
                           [type(atom), access(read_only), keep(true)])
    ).

metta_boot_option(Name, Environment, Option) :-
    current_prolog_flag(argv, Arguments),
    atomic_list_concat(['--', Name, '='], Prefix),
    findall(Value,
            ( member(Argument, Arguments), atom_concat(Prefix, Value, Argument) ),
            Values),
    (   Values = [Value]
    ->  Option = some(Value)
    ;   Values == []
    ->  ( getenv(Environment, Value) -> Option = some(Value) ; Option = none )
    ;   throw(error(domain_error(single_boot_option, Name-Values),
                    context(metta_boot_identity/0, 'specify each identity option once')))
    ).

metta_token_actor(Actor) :-
    must_be(atom, Actor),
    ( Actor == '' -> domain_error(nonempty_actor, Actor) ; true ).

metta_token_generation(Generation) :-
    must_be(nonneg, Generation),
    ( Generation =< 9223372036854775807 -> true
    ; representation_error(int64_t) ).

metta_token_parts(Token, Actor, Generation) :-
    (   integer(Token)
    ->  Generation = Token, metta_actor(Actor)
    ;   nonvar(Token), Token = t(Actor, Generation)
    ->  metta_token_actor(Actor)
    ;   domain_error(occurrence_token, Token)
    ),
    metta_token_generation(Generation).

metta_token_order(Left, Right, Order) :-
    metta_token_parts(Left, LeftActor, LeftGeneration),
    metta_token_parts(Right, RightActor, RightGeneration),
    compare(Order, LeftGeneration-LeftActor, RightGeneration-RightActor).

metta_token_portable(Token, t(Actor, Generation)) :-
    metta_token_parts(Token, Actor, Generation).

metta_token_receive(Token, Stored) :-
    metta_token_parts(Token, Actor, Generation),
    flag('$metta_generation', Current, max(Current, Generation+1)),
    ( metta_actor(Actor) -> Stored = Generation ; Stored = t(Actor, Generation) ).

metta_generation_receive(Next) :-
    metta_token_generation(Next),
    flag('$metta_generation', Current, max(Current, Next)).
