/* Purpose: the four rows a vocabulary carries beside its members - its MeTTa
   type name, its subtype chain, whether a library may extend it and the
   members one did - and the wire grammar those rows also hold.
   Assumes:
     - engine/metta.pl loads spaces.pl, whose presets populate '&metta' at
       consult time, and whose initialization publishes the type atoms
   Guarantees:
     - every vocabulary row carries a (: <TypeName> Type) atom and one
       (: <member> <TypeName>) per member, under the mechanical CamelCase of
       the row name or its declared exception [tested:
       every_vocabulary_row_is_typed, the_declared_type_name_beats_the_map]
     - a declared order is written as its (:< ...) edges and a member left out
       of the row stays outside the chain [tested: a_declared_order_is_a_chain]
     - the open/closed property is enforced at one door, and a closed row's
       refusal names the row and the property [tested:
       a_closed_vocabulary_refuses_a_member, an_open_vocabulary_admits_a_member]
     - a member registered against an open row answers from every consulting
       site and leaves with its row [tested: an_open_vocabulary_admits_a_member]
     - an (algebra ...) row registers its own name, so a declared carrier can
       claim its ordering [tested:
       a_declared_algebra_joins_the_semiring_vocabulary]
     - a capability word outside the provider-capability row is refused at the
       declaration door rather than gating nothing [tested:
       an_unknown_capability_word_is_refused]
     - a member type atom beside a callable does not shadow its arrow: six of
       these members are engine callables or special forms [tested:
       a_member_type_atom_does_not_shadow_a_callable]
     - the shim's encoder and decoder speak exactly the tags the (wire-tag ...)
       rows declare [tested: the_shim_speaks_the_declared_wire_tags]
   Open Obligations:
     To Do: None
     Hacks: None
     Future Enhancements: None
*/
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- ensure_loaded('../../../../extensions/python/metta/_binding/shim.pl').

:- begin_tests(catalog_vocabulary_words).

%The rule and its one declared exception, over every shipped row.
test(every_vocabulary_row_is_typed) :-
    forall(metta_catalog_row([vocabulary, Vocab|_]),
           ( spaces:metta_vocabulary_type(Vocab, Type),
             assertion(metta_catalog_row([':', Type, 'Type'])),
             spaces:metta_vocabulary_values(Vocab, Values),
             forall(member(Value, Values),
                    assertion(metta_catalog_row([':', Value, Type]))) )).

test(the_declared_type_name_beats_the_map) :-
    spaces:metta_vocabulary_type('on-error-mode', Declared),
    assertion(Declared == 'OnError'),
    assertion(metta_catalog_row([':', keep, 'OnError'])),
    assertion(\+ metta_catalog_row([':', 'OnErrorMode', 'Type'])),
    spaces:metta_vocabulary_type('effect-class', Mechanical),
    assertion(Mechanical == 'EffectClass').

test(a_declared_order_is_a_chain) :-
    assertion(metta_catalog_row([':<', 'Exact', 'Partial'])),
    assertion(metta_catalog_row([':<', 'Partial', 'Sound'])),
    %Refuse is a Fidelity and deliberately not in the chain: it is not a
    %weaker claim, it is the absence of a stream.
    assertion(metta_catalog_row([':', 'Refuse', 'Fidelity'])),
    assertion(\+ metta_catalog_row([':<', 'Refuse', 'Sound'])),
    assertion(\+ metta_catalog_row([':<', 'Exact', 'Sound'])).

test(a_closed_vocabulary_refuses_a_member) :-
    catch(add_sexp('&metta', ['vocabulary-member', fidelity, 'Approximate'], _),
          error(metta_declaration_malformed(_, Position, Remedy), _),
          true),
    assertion(Position == 1),
    assertion(sub_atom(Remedy, _, _, _, 'fidelity is closed')),
    assertion(sub_atom(Remedy, _, _, _, '(vocabulary-open fidelity')),
    assertion(\+ spaces:metta_vocabulary_value(fidelity, 'Approximate')).

test(an_open_vocabulary_admits_a_member, [cleanup(
         metta_remove_atom('&metta',
                           ['vocabulary-member', 'provider-capability',
                            cvw_probe], _))]) :-
    add_sexp('&metta',
             ['vocabulary-member', 'provider-capability', cvw_probe], _),
    assertion(spaces:metta_vocabulary_value('provider-capability', cvw_probe)),
    assertion(metta_catalog_row([':', cvw_probe, 'ProviderCapability'])),
    %A registered member is a member everywhere, so a claim about it lands
    %and a (one-of ...) argument admits it.
    add_sexp('&metta', [claim, 'provider-capability', cvw_probe, cvw_prop], _),
    assertion(metta_vocabulary_claim('provider-capability', cvw_probe,
                                     cvw_prop)),
    metta_remove_atom('&metta',
                      [claim, 'provider-capability', cvw_probe, cvw_prop], _).

test(a_withdrawn_member_leaves_with_its_type_atom) :-
    add_sexp('&metta',
             ['vocabulary-member', 'provider-capability', cvw_gone], _),
    metta_remove_atom('&metta',
                      ['vocabulary-member', 'provider-capability', cvw_gone],
                      Removed),
    assertion(Removed == true),
    assertion(\+ spaces:metta_vocabulary_value('provider-capability', cvw_gone)),
    assertion(\+ metta_catalog_row([':', cvw_gone, 'ProviderCapability'])).

%The hole this closes. The semiring vocabulary was derived from the shipped
%algebra presets once, at boot, and frozen: a program's own carrier could
%never claim its ordering, so metta_annotations_order/2 could never see it.
test(a_declared_algebra_joins_the_semiring_vocabulary, [cleanup(
         metta_remove_atom('&metta',
                           [algebra, cvw_alg, max, *, 0, 1, [laws],
                            [carrier, 0, 1], [requires], global], _))]) :-
    add_sexp('&metta', [algebra, cvw_alg, max, *, 0, 1, [laws],
                        [carrier, 0, 1], [requires], global], _),
    assertion(spaces:metta_vocabulary_value(semiring, cvw_alg)),
    assertion(metta_catalog_row([':', cvw_alg, 'Semiring'])),
    add_sexp('&metta', [claim, semiring, cvw_alg, ordered, ascending], _),
    assertion(metta_vocabulary_claim(semiring, cvw_alg, ordered)),
    metta_remove_atom('&metta',
                      [claim, semiring, cvw_alg, ordered, ascending], _).

test(an_algebra_row_leaving_takes_its_membership) :-
    add_sexp('&metta', [algebra, cvw_gone_alg, max, *, 0, 1, [laws],
                        [carrier, 0, 1], [requires], global], _),
    metta_remove_atom('&metta',
                      [algebra, cvw_gone_alg, max, *, 0, 1, [laws],
                       [carrier, 0, 1], [requires], global], _),
    assertion(\+ spaces:metta_vocabulary_value(semiring, cvw_gone_alg)).

test(an_unknown_capability_word_is_refused) :-
    catch(metta_require_foreign_capability('&cvw-space', cvw_not_a_word),
          error(metta_foreign_capability_unknown(Space, Word), _),
          true),
    assertion(Space == '&cvw-space'),
    assertion(Word == cvw_not_a_word),
    %Every shipped word passes the same door.
    forall(spaces:metta_vocabulary_value('provider-capability', Known),
           metta_require_foreign_capability('&cvw-space', Known)).

%A member type atom sits beside whatever else the word means, and six members
%of these vocabularies are also engine callables or special forms: `min`,
%`max`, `metta`, `Predicate`, `empty`, `inferences` and `timeout`. So the
%question this answers is whether (: min MemoAggregate) shadows min's own
%arrow or changes what a call answers. It does not, and the reason is that a
%bare symbol's declaration is not the arrow a CALL resolves through.
test(a_member_type_atom_does_not_shadow_a_callable) :-
    assertion(metta_catalog_row([':', min, 'MemoAggregate'])),
    assertion(metta_catalog_row([':', max, 'MemoAggregate'])),
    assertion(metta_catalog_row([':', timeout, 'Limit'])),
    assertion(metta_catalog_row([':', inferences, 'Limit'])),
    assertion(metta_catalog_row([':', empty, 'OnError'])),
    cvw_answers("(min 1 2)", [1]),
    cvw_answers("(max 1 2)", [2]),
    cvw_answers("(+ 1 2)", [3]),
    cvw_answers("(timeout 1 (+ 1 2))", [3]),
    %The arrow, alone: a call resolves through it and the member declaration
    %is a separate fact about the bare symbol.
    cvw_answers("(get-type min)", ['(-> Number Number Number)']),
    cvw_answers("(get-type (min 1 2))", ['Number']).

%One MeTTa form's answers, as the strings the writer prints.
cvw_answers(Text, Expected) :-
    sread(Text, Term),
    findall(Answer,
            ( translate_expr(Term, Goals, Produced),
              cvw_call(Goals),
              cvw_answer(Produced, Answer) ),
            Answers),
    assertion(Answers == Expected).

cvw_call([]).
cvw_call([Goal|Goals]) :- call(Goal), cvw_call(Goals).

cvw_answer(Produced, Answer) :-
    (   number(Produced)
    ->  Answer = Produced
    ;   swrite(Produced, Text),
        atom_string(Answer, Text)
    ).

%One grammar, three copies retired. The rows are the authority and this holds
%the shim's own clauses to them: a tag the encoder or decoder speaks and no
%row declares, or a declared term tag neither of them handles, is drift.
test(the_shim_speaks_the_declared_wire_tags) :-
    findall(Tag, metta_catalog_row(['wire-tag', Tag, _, _, _]), Declared0),
    sort(Declared0, Declared),
    findall(Tag,
            ( metta_catalog_row(['wire-tag', Tag, term, _, _]) ),
            TermTags0),
    sort(TermTags0, TermTags),
    findall(Tag, shim_decoder_tag(Tag), Decoded0),
    sort(Decoded0, Decoded),
    findall(Tag, shim_encoder_tag(Tag), Encoded0),
    sort(Encoded0, Encoded),
    assertion(Decoded == TermTags),
    assertion(Encoded == TermTags),
    %Every tag the shim writes anywhere is a declared one, frames and the
    %cast reply included.
    assertion(subtract(Encoded, Declared, [])),
    assertion(memberchk(r, Declared)),
    assertion(\+ memberchk(r, TermTags)).

%The decoder's own clause heads, read from the program rather than listed.
shim_decoder_tag(Tag) :-
    clause(metta_py_decode_(Tag0, _, _), _),
    atom(Tag0),
    Tag = Tag0.

%The encoder's, read the same way: every clause answers a ["tag", ...] wire
%term, and the tag is the head of that list.
shim_encoder_tag(Tag) :-
    clause(metta_py_encode(_, _, _, Wire), _),
    nonvar(Wire),
    Wire = [Text|_],
    string(Text),
    atom_string(Tag, Text).

:- end_tests(catalog_vocabulary_words).
