% Purpose: pin the shared surface-arrow projection used by every runtime type
%   consumer before the compile-time checker interprets its annotation.
% Assumes: engine/metta.pl has loaded the EffectClass catalog and lattice.
% Guarantees: legacy and annotated prefix arrows expose one unchanged runtime
%   chain, while shape projection preserves normalized product metadata and
%   malformed or infix-looking terms fail closed
%   [tested: run_tests(metta_arrow_projection);
%   commit=48cf04fb8dd80149b5e46e15f499f19f6c45348f].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(metta_arrow_projection).

test(unannotated_and_annotated_arrows_project_the_same_runtime_chain) :-
    metta_arrow_type_chain(['->', 'Atom', 'String', 'Symbol'], Plain),
    metta_arrow_type_chain(
        ['-[det]->', 'Atom', 'String', 'Symbol'], Annotated),
    assertion(Plain == ['Atom', 'String', 'Symbol']),
    assertion(Annotated == Plain).

test(shape_projection_keeps_implicit_and_explicit_products_distinct) :-
    metta_arrow_type_shape(
        ['->', 'Atom', 'String'], PlainInputs, PlainOutput,
        PlainProduct, PlainExplicitness),
    metta_arrow_type_shape(
        ['-[semidet]->', 'Atom', 'String'], AnnotatedInputs,
        AnnotatedOutput, AnnotatedProduct, AnnotatedExplicitness),
    assertion(PlainInputs == ['Atom']),
    assertion(PlainOutput == 'String'),
    assertion(AnnotatedInputs == PlainInputs),
    assertion(AnnotatedOutput == PlainOutput),
    assertion(PlainProduct == effect(nondet, oracleIO)),
    assertion(PlainExplicitness == implicit),
    assertion(AnnotatedProduct == effect(semidet, oracleIO)),
    assertion(AnnotatedExplicitness == explicit).

test(long_cardinality_spellings_normalize_to_the_short_vocabulary,
     [ forall(member(Head-Expected,
                     [ '-[deterministic]->'-det,
                       '-[semideterministic]->'-semidet,
                       '-[nondeterministic]->'-nondet
                     ])) ]) :-
    metta_arrow_type_shape([Head, 'Number'], [], 'Number',
                           effect(Expected, oracleIO), explicit).

test(effect_classes_use_the_engine_catalog_and_nondet_floor) :-
    metta_arrow_type_shape(
        ['-[det,stable]->', 'Number'], [], 'Number',
        effect(det, readOnlyLookup), explicit),
    metta_arrow_type_shape(
        ['-[nondet,pureStructural]->', 'Number'], [], 'Number',
        effect(nondet, nondeterministicReadOnly), explicit).

test(product_and_component_binders_are_canonical_data) :-
    metta_arrow_type_shape(
        ['-[$e]->', 'Number'], [], 'Number', effect_variable(e), explicit),
    metta_arrow_type_shape(
        ['-[$e,$e]->', Shared, Shared], [Input], Output,
        effect(cardinality_variable(CardinalityName),
               effect_class_variable(ClassName)), explicit),
    assertion(CardinalityName == ClassName),
    assertion(Input == Output).

test(presentation_uses_the_same_rest_expansion_for_annotated_arrows) :-
    metta_presented_arrow_chain(
        ['-[det]->', ['%Rest%', 'Atom'], 'Bool'], 3, Presented),
    assertion(Presented == ['Atom', 'Atom', 'Atom', 'Bool']).

test(non_arrows_and_malformed_annotations_fail_instead_of_passing_through) :-
    forall(member(Raw,
                  [ ['Number', 'String'],
                    ['Number', '-[det]->', 'String'],
                    ['-[det]', 'Number'],
                    ['-[bogus]->', 'Number'],
                    ['-[det,bogus]->', 'Number'],
                    ['->']
                  ]),
           assertion(\+ metta_arrow_type_chain(Raw, _))).

:- end_tests(metta_arrow_projection).
