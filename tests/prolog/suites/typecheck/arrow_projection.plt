% Purpose: pin the shared surface-arrow projection used by every runtime type
%   consumer before the compile-time checker interprets its annotation.
% Assumes: engine/metta.pl has loaded the EffectClass catalog and lattice.
% Guarantees: legacy and annotated prefix arrows expose one unchanged runtime
%   chain, while shape projection preserves normalized product metadata and
%   malformed or infix-looking terms fail closed
%   [tested: run_tests(metta_arrow_projection);
%   commit=cba149fe709e7e11b343d7c722ea81b81275a1a5].
% Guarantees: concrete annotated declarations execute, check arguments and
%   type applications while stored types retain their spelling. Annotated
%   callers gain a cardinality checkpoint; callees retain their typed bodies
%   [tested: run_tests(metta_arrow_projection); commit=bbb512316280110a747e31c26adfc31e8c5104be].
% Owns resources: each test releases its space; the export-reader fixture
%   retracts its pending export row even when an assertion fails.

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
                    ['-[]->', 'Number'],
                    ['-[det,bogus]->', 'Number'],
                    ['->']
                  ]),
           assertion(\+ metta_arrow_type_chain(Raw, _))).

%The canonical members come from the catalog's (vocabulary determinism ...)
%row and the long spellings map onto them, the same two-part rule the
%effect-class slot beside them already followed. Reading them from a literal
%list repeated in both branches was one predicate keeping two ownership rules,
%and the policy-inventory lane named it.
test(the_long_determinism_spellings_map_to_the_catalog_members) :-
    forall(member(Spelling-Canonical,
                  [ 'det'-det, 'deterministic'-det,
                    'semidet'-semidet, 'semideterministic'-semidet,
                    'nondet'-nondet, 'nondeterministic'-nondet
                  ]),
           ( atomic_list_concat(['-[', Spelling, ']->'], Head),
             assertion(metta_arrow_type_shape([Head, 'Number', 'Number'],
                                              _, _, effect(Canonical, _), explicit)) )),
    %A spelling the catalog does not own is still refused, so mapping IN has
    %not made a fourth member.
    assertion(\+ metta_arrow_type_shape(['-[bogus]->', 'Number'], _, _, _, _)),
    %And the canonical members are the catalog's, not a copy of them.
    findall(V, spaces:metta_determinism_canonical(V, V), Members),
    assertion(msort(Members, [det, nondet, semidet])).

test(annotated_declarations_execute_and_keep_the_written_type,
     [ forall((member(Head, ['->', '-[det]->', '-[semidet,pureStructural]->']),
               member(Mode, [together, separate]))),
       setup('new-space'(Space)), cleanup(metta_release_space(Space)) ]) :-
    load_arrow_identity(Space, Head, Mode),
    space_module(Space, Module),
    findall(Value, eval_metta_in_module(Module, ['arrow-runtime-f', 1], Value),
            Values),
    assertion(Values == [1]),
    findall(Error,
            eval_metta_in_module(Module, ['arrow-runtime-f', "s"], Error),
            Errors),
    assertion(Errors == [['Error', ['arrow-runtime-f', "s"],
                          ['BadArgType', 1, 'Number', 'String']]]),
    findall(Type,
            eval_metta_in_module(Module, ['get-type', ['arrow-runtime-f', 1]],
                                 Type), Types),
    assertion(Types == ['Number']),
    findall(Type, 'get-type-space'(Space, ['arrow-runtime-f', 1], Type), Scoped),
    assertion(Scoped == Types),
    findall(Type, eval_metta_in_module(Module, ['get-type', 'arrow-runtime-f'],
                                      Type), Written),
    assertion(Written == [[Head, 'Number', 'Number']]),
    assertion(match_stored(Space,
                           [':', 'arrow-runtime-f', [Head, 'Number', 'Number']],
                           true, true)).

load_arrow_identity(Space, Head, Mode) :-
    format(string(Declaration), "(: arrow-runtime-f (~w Number Number))", [Head]),
    Equation = "(= (arrow-runtime-f $x) $x)",
    (   Mode == together
    ->  string_concat(Declaration, Equation, Source),
        process_metta_string(Source, _, Space)
    ;   process_metta_string(Declaration, _, Space),
        process_metta_string(Equation, _, Space)
    ).

test(annotated_function_values_satisfy_higher_order_and_shared_types,
     [ setup('new-space'(Space)), cleanup(metta_release_space(Space)) ]) :-
    load_arrow_identity(Space, '-[det]->', together),
    process_metta_string(
        "(: arrow-apply (-> (-> Number Number) Number Number))
         (= (arrow-apply $f $x) ($f $x))
         (: arrow-same (-> $t $t Bool))
         (= (arrow-same $x $y) True)
         (: arrow-plain (-> Number Number))
         (= (arrow-plain $x) $x)
         (: arrow-many (-[det,pureStructural]-> Number Symbol))
         (= (arrow-many $x) arrow-first)
         (= (arrow-many $x) arrow-second)", _, Space),
    space_module(Space, Module),
    findall(Value, eval_metta_in_module(
                       Module, ['arrow-apply', 'arrow-runtime-f', 1], Value),
            Applied),
    assertion(Applied == [1]),
    findall(Value, eval_metta_in_module(
                       Module, ['arrow-same', 'arrow-runtime-f', 'arrow-plain'],
                       Value), Same),
    assertion(Same == [true]),
    %The two answers are named `arrow-*` rather than `first` and `second`
    %because the declared result is `Symbol` and `first` is a name the engine
    %holds a function for, so it has been Grounded since 2026-09-05 and the
    %result check refuses it. The fixture is about answering BOTH values under
    %an annotated arrow, not about those two spellings.
    findall(Value, eval_metta_in_module(Module, ['arrow-many', 1], Value), Many),
    assertion(Many == ['arrow-first', 'arrow-second']).

test(replacing_a_plain_arrow_instruments_only_its_callers,
     [ setup('new-space'(Space)), cleanup(metta_release_space(Space)) ]) :-
    load_arrow_identity(Space, '->', together),
    process_metta_string(
        "(= (arrow-caller $x) (arrow-runtime-f $x))
         (= (arrow-literal) (arrow-runtime-f 1))", _, Space),
    space_module(Space, Module),
    Predicates = ['arrow-runtime-f'/2, 'arrow-caller'/2, 'arrow-literal'/1],
    forall(member(Predicate/_, Predicates), metta_ensure_compiled(Predicate)),
    findall((Head :- Body),
            (member(Predicate/Arity, Predicates), functor(Head, Predicate, Arity),
             clause(Module:Head, Body)), Plain),
    assertion(length(Plain, 3)),
    metta_remove_atom(Space, [':', 'arrow-runtime-f', ['->', 'Number', 'Number']],
                      true),
    metta_add_atom(Space,
                   [':', 'arrow-runtime-f', ['-[det]->', 'Number', 'Number']], _),
    forall(member(Predicate/_, Predicates), metta_ensure_compiled(Predicate)),
    findall((Head :- Body),
            (member(Predicate/Arity, Predicates), functor(Head, Predicate, Arity),
             clause(Module:Head, Body)), Annotated),
    Plain = [PlainCallee|_], Annotated = [AnnotatedCallee|_],
    assertion(AnnotatedCallee =@= PlainCallee),
    assertion(Annotated \=@= Plain),
    findall(Value, eval_metta_in_module(Module, ['arrow-caller', 1], Value), Values),
    assertion(Values == [1]).

test(rest_reporting_and_documentation_read_annotated_arrows,
     [ setup('new-space'(Space)), cleanup(metta_release_space(Space)) ]) :-
    process_metta_string(
        "(: arrow-rest (-[det]-> (%Rest% Atom) Bool))
         (: arrow-doc (-[det]-> Number Number))
         (@doc arrow-doc (@desc identity) (@params ((@param input)))
                         (@return output))", _, Space),
    space_module(Space, Module),
    findall(Type, eval_metta_in_module(Module, ['get-type', ['arrow-rest']], Type),
            Types),
    assertion(Types == ['Bool']),
    findall(Type, 'get-type-space'(Space, ['arrow-rest'], Type), Scoped),
    assertion(Scoped == Types),
    findall(Doc, 'get-doc-single-atom'(Space, 'arrow-doc', Doc), Docs),
    assertion(Docs == [['@doc-formal', ['@item', 'arrow-doc'], ['@kind', function],
                        ['@type', ['-[det]->', 'Number', 'Number']],
                        ['@desc', identity],
                        ['@params', [['@param', ['@type', 'Number'],
                                                ['@desc', input]]]],
                        ['@return', ['@type', 'Number'], ['@desc', output]]]]).

test(export_readers_preserve_the_annotated_declaration,
     [ cleanup(retractall(user:pending_metta_export('arrow-test-export', _, _))) ]) :-
    parse_metta_source("(: arrow-export (-[det]-> Number Number))", [Parsed]),
    record_metta_export('arrow-test-export', Parsed),
    assertion(pending_metta_export('arrow-test-export', 'arrow-export',
                                    ['-[det]->', 'Number', 'Number'])),
    assertion(declared_predicate_arity(['-[det]->', 'Number', 'Number'], 2)),
    assertion(claimed_export_name([Parsed], 'arrow-export')).

test(runtime_projection_preserves_plain_types_and_variable_sharing) :-
    Plain = ['->', Shared, Shared],
    metta_runtime_type(Plain, Same),
    assertion(Same == Plain),
    metta_runtime_type(['-[$e]->', Shared, Shared], ['->', Input, Output]),
    assertion(Input == Shared),
    assertion(Output == Shared),
    forall(member(Raw, ['Number', ['->'], ['-[]->', 'Number'],
                        ['-[bogus]->', 'Number']]),
           (metta_runtime_type(Raw, Unchanged), assertion(Unchanged == Raw))).

test(native_readers_and_inherited_arity_see_the_annotated_arrow,
     [ setup(('new-space'(Space),
              add_sexp('&self', [':', 'arrow-native',
                        ['-[det]->', 'Number', 'Number']], Ref))),
       cleanup((erase(Ref), metta_release_space(Space))) ]) :-
    space_module(Space, Module),
    assertion(get_function_type(['arrow-native', 1], 'Number')),
    assertion(application_arrow_declared(['arrow-native', "s"])),
    assertion(shallow_declared_type('arrow-native', ['->', 'Number', 'Number'])),
    assertion(shallow_argument_types(['arrow-native', 1], ['Number'])),
    assertion(\+ shallow_argument_types('arrow-native', _)),
    assertion(translator:inherited_stored_declaration_owns_arity(Module,
                                                                 'arrow-native')),
    assertion(with_metta_module(Module,
                translator:arrow_declared_data_head('arrow-native', self))),
    metta_add_atom(Space, [':', 'arrow-native', ['-[det]->', 'String', 'String']], _),
    assertion(\+ translator:inherited_stored_declaration_owns_arity(Module,
                                                                    'arrow-native')),
    assertion(with_metta_module(Module,
                translator:arrow_declared_data_head('arrow-native', local(Space)))).

test(an_annotated_type_marker_rebuilds_its_compiled_caller,
     [ setup('new-space'(Space)), cleanup(metta_release_space(Space)) ]) :-
    process_metta_string(
        "(: ArrowPayload Type)
         (: arrow-inspect (-[det]-> ArrowPayload Symbol))
         (= (arrow-inspect $value) (get-metatype $value))
         (= (arrow-inspection) (arrow-inspect (+ 1 2)))", _, Space),
    space_module(Space, Module),
    findall(Value, eval_metta_in_module(Module, ['arrow-inspection'], Value), Before),
    assertion(Before == [['Error', ['arrow-inspect', [+, 1, 2]],
                          ['BadArgType', 1, 'ArrowPayload', 'Number']]]),
    metta_add_atom(Space, [':', 'ArrowPayload', 'DontEvalType'], _),
    findall(Value, eval_metta_in_module(Module, ['arrow-inspection'], Value), Masked),
    assertion(Masked == ['Expression']),
    metta_remove_atom(Space, [':', 'ArrowPayload', 'DontEvalType'], true),
    findall(Value, eval_metta_in_module(Module, ['arrow-inspection'], Value), After),
    assertion(After == Before).

:- end_tests(metta_arrow_projection).
