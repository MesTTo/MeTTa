% Purpose: check references across the provider occurrence contract.
% Guarantees: missing exact mutation refuses before a row is written; a source
%   needs only tokens, and an owner of both mutation doors can receive live
%   links and withdraw only their metadata [tested: reference_providers;
%   commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
% Owns resources: fixtures release their modules and native backing stores.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- dynamic reference_provider/3.
:- multifile seam:foreign_space/1, seam:foreign_capability/2,
             seam:foreign_token/3, seam:foreign_add/2, seam:foreign_add_token/3,
             seam:foreign_remove/3, seam:foreign_remove_token/3,
             seam:foreign_atoms/2, seam:foreign_match/3, seam:foreign_clear/1.

seam:foreign_space(Space) :- reference_provider(Space, _, _).
seam:foreign_capability(Space, Capability) :-
    reference_provider(Space, _, Capabilities), member(Capability, Capabilities).
seam:foreign_token(Space, Atom, Portable) :-
    reference_provider(Space, Backing, _),
    spaces:metta_native_pair(Backing, Atom, Token, _),
    spaces:metta_token_portable(Token, Portable).
seam:foreign_add(Space, Atom) :-
    reference_provider(Space, Backing, _), spaces:add_sexp(Backing, Atom).
seam:foreign_add_token(Space, Atom, Portable) :-
    reference_provider(Space, Backing, _), spaces:add_sexp(Backing, Atom, Token, _),
    spaces:metta_token_portable(Token, Portable).
seam:foreign_remove(Space, Atom, Removed) :-
    reference_provider(Space, Backing, _), spaces:metta_remove_atom(Backing, Atom, Removed).
seam:foreign_remove_token(Space, Portable, Removed) :-
    reference_provider(Space, Backing, _), spaces:metta_token_receive(Portable, Token),
    ( spaces:metta_native_pair(Backing, _, Token, Ref)
    -> spaces:metta_remove_atom_reference(Ref), Removed = true
    ; Removed = false ).
seam:foreign_atoms(Space, Atom) :-
    reference_provider(Space, Backing, _), spaces:metta_native_pair(Backing, Atom, _, _).
seam:foreign_match(Space, Pattern, Template) :-
    reference_provider(Space, Backing, _), spaces:match(Backing, Pattern, Template, Template).
seam:foreign_clear(Space) :-
    reference_provider(Space, Backing, _), spaces:clear_native_atoms(Backing).

:- begin_tests(reference_providers).

provider_fixture(Capabilities, Space, Backing, Native) :-
    metta_host_set_silent(true), 'new-space'(Backing), 'new-space'(Native),
    gensym('&reference-provider-', Space),
    assertz(user:reference_provider(Space, Backing, Capabilities)),
    spaces:metta_claim_space(Space, reference_fixture), space_module(Space, _).
provider_cleanup(Space, Backing, Native) :-
    metta_release_space(Native), metta_release_space(Space),
    spaces:metta_disclaim_space(Space, reference_fixture),
    retractall(user:reference_provider(Space, _, _)), metta_release_space(Backing),
    metta_host_set_silent(false).

test(a_foreign_receiver_names_each_missing_mutation_and_the_overlay_remedy,
     [forall(member(Extra-Missing, [[]-'add-token', ['add-token']-'remove-token'])),
      setup(provider_fixture([tokens|Extra], Space, Backing, Native)),
      cleanup(provider_cleanup(Space, Backing, Native))]) :-
    catch(metta_add_atom(Space, [from, Native], _), Error, true),
    assertion(Error = error(metta_foreign_token_mutation_required(Space,from,Missing),_)),
    assertion(metta_vocabulary_value('provider-capability', Missing)),
    message_to_string(Error, Message), assertion(sub_string(Message,_,_,_,"native overlay")),
    metta_host_refusal(Error, capability, Fields, 'SpaceCapabilityError', _, Remedy),
    assertion(memberchk(capability-Missing, Fields)),
    assertion(Remedy = [remedy,_,quickfix,prose]),
    assertion(\+ spaces:metta_native_pair(Backing, _, _, _)),
    assertion(\+ metta_engine:metta_reference_observed(Space)).

test(a_token_source_supplies_definitions_and_grades_without_mutation_capabilities,
     [setup(provider_fixture([tokens,add,rules,enumerate,clear], Space, Backing, Native)),
      cleanup(provider_cleanup(Space, Backing, Native))]) :-
    spaces:add_sexp(Backing, [internal,'provider-hidden']),
    metta_add_atom(Space, [=,['provider-visible',X],X], _),
    metta_add_atom(Space, [=,['provider-hidden'],secret], _),
    metta_add_atom(Native, [from,Space], _),
    findall(R, evalc(['provider-visible',42],Native,R), Bag), assertion(Bag == [42]),
    assertion(metta_head_property(Space,'provider-hidden',[visibility,internal])),
    assertion(\+ metta_head_property(Native,'provider-hidden',[origin|_])),
    metta_add_atom(Space,[=,['provider-later'],later],_),
    findall(R,evalc(['provider-later'],Native,R),Later), assertion(Later == [later]).

test(a_receiver_registering_both_doors_preserves_equal_owned_metadata,
     [setup(provider_fixture([tokens,'add-token','remove-token',
                              rules,enumerate,match,clear], Space, Backing, Native)),
      cleanup(provider_cleanup(Space, Backing, Native))]) :-
    Doc = ['@doc','provider-linked',['@desc',"same text"]],
    spaces:add_sexp(Backing, Doc, Owned, _),
    metta_add_atom(Native, [=,['provider-linked',X],X], _),
    metta_add_atom(Native, [':','provider-linked',[->,'Atom','Atom']], _),
    metta_add_atom(Native, Doc, _),
    metta_add_atom(Space, [from,Native], Token, _), assertion(nonvar(Token)),
    findall(R,evalc(['provider-linked',42],Space,R),Bag), assertion(Bag == [42]),
    findall(T,spaces:metta_space_pair(Space,Doc,T,_),Copies), assertion(length(Copies,2)),
    once(spaces:metta_remove_occurrence(Space,Token,true)),
    findall(T,spaces:metta_space_pair(Space,Doc,T,_),Remaining), assertion(Remaining == [Owned]),
    assertion(\+ spaces:metta_space_pair(Space,[':','provider-linked',_],_,_)),
    findall(R,evalc(['provider-linked',42],Space,R),Gone),
    assertion(Gone == [['provider-linked',42]]).

test(exact_equation_removal_keeps_the_other_equal_occurrence_and_clause,
     [setup(provider_fixture([tokens,'add-token','remove-token',rules,enumerate,clear],
                             Space, Backing, Native)),
      cleanup(provider_cleanup(Space, Backing, Native))]) :-
    metta_add_atom(Space,[from,Native],_),
    Equation = [=,['provider-equal'],same],
    metta_add_atom(Space,Equation,First,_), metta_add_atom(Space,Equation,Second,_),
    space_module(Space,Module),
    filereader:'$metta_equation_token'(Module,_,FirstRef,First),
    filereader:'$metta_equation_token'(Module,_,SecondRef,Second),
    once(spaces:metta_remove_occurrence(Space,Second,true)),
    assertion(\+ clause_property(FirstRef,erased)),
    assertion(clause_property(SecondRef,erased)),
    findall(R,evalc(['provider-equal'],Space,R),Bag), assertion(Bag == [same]),
    once(metta_remove_atom(Space,Equation,true)),
    assertion(\+ spaces:metta_space_pair(Space,Equation,_,_)).

:- end_tests(reference_providers).
