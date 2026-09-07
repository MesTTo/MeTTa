/* Purpose: the catalog describes its own kinds and one generic checker
   validates every declaration against them, at both '&metta' write doors.
   Assumes:
     - engine/metta.pl loads spaces.pl, whose presets populate '&metta' at
       consult time [tested: the_shipped_catalog_is_queryable_data]
   Guarantees:
     - a declaration violating its kind row is a hard error naming the
       atom, the position and the argspec, never a silent inert atom
       [tested: a_malformed_shipped_declaration_is_refused_loudly]
     - a head with no kind row passes untouched, the open data axis
       [tested: an_undeclared_head_stays_plain_data]
     - materialized annotation and algebra descriptors follow catalog adds,
       removals, and same-name replacements [tested:
       algebra_descriptor_caches_follow_catalog_edits; commit=7ae3103aee78e947d23c5872e3db23c28ad7fe1c]
     - algebra descriptors are cached and validated by context plus name,
       while shipped rows state their global fallback explicitly [tested:
       algebra_descriptor_caches_follow_catalog_edits,
       a_claimed_ordered_value_orders_and_an_unclaimed_one_does_not;
       commit=2e627a593413191cda3170f2eb716835f7f62543]
     - the deprecated kind is queryable with exact name, since, and remedy
       fields [tested: the_shipped_catalog_is_queryable_data;
       commit=d74e2e828cd9272882dcf907cfaf095d2d147ce0]
     - every shipped callable has exactly one visibility row and the internal
       documentation helpers stay classified without leaving the callable set
       [tested: every_shipped_callable_has_one_visibility;
       commit=8779452fed89853c3f77c3469f7a6ec7b12e9efa]
     - fixed-width catalog lookup preserves clause references and ignores
       unrelated storage arities [tested:
       catalog_self_description:catalog_queries_preserve_width_multiplicity_and_references,
       catalog_self_description:fixed_width_catalog_lookup_ignores_unrelated_arities;
       commit=8bd37f3042555ee016a7b917234ce44c75a97c3e]
     - algebra-law vocabulary members and aliases derive from engine facts,
       and every shipped algebra row appears in the semiring vocabulary
       [tested: algebra_law_vocabulary_and_alias_claims_are_exact,
       shipped_algebra_rows_are_the_semiring_vocabulary; commit=5e0ae6c22d604c4b980766e3cc4811ee545e5c9e]
   Open Obligations:
     To Do: None
     Hacks: None
     Future Enhancements: None
*/
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(catalog_self_description).

test(catalog_queries_preserve_width_multiplicity_and_references) :-
    setup_call_cleanup(
        ( add_sexp('&metta', [cat_width, marker, first], Ref1),
          add_sexp('&metta', [cat_width, marker, first], Ref2),
          add_sexp('&metta', [cat_width, marker, extra, tail], Ref3) ),
        ( findall(Head-Value-Ref,
                  spaces:metta_catalog_clause([Head, marker, Value], Ref),
                  Fixed),
          assertion(Fixed == [cat_width-first-Ref1, cat_width-first-Ref2]),
          findall(Tail-Ref,
                  spaces:metta_catalog_clause([cat_width, marker|Tail], Ref),
                  Open0),
          msort(Open0, Open),
          msort([[first]-Ref1, [first]-Ref2, [extra, tail]-Ref3], Expected),
          assertion(Open == Expected),
          findall(Tail-Ref,
                  ( spaces:metta_catalog_clause(Row, Ref),
                    Row = [cat_width, marker|Tail] ),
                  All0),
          msort(All0, All),
          assertion(All == Expected) ),
        ( erase(Ref1), erase(Ref2), erase(Ref3) )).

test(an_improper_catalog_query_keeps_its_type_error,
     [error(type_error(list, improper))]) :-
    spaces:metta_catalog_clause([cat_width|improper], _).

test(catalog_queries_keep_shared_variables_and_transaction_visibility) :-
    snapshot(
        ( add_sexp('&metta', [cat_shared, [pair, X, X]], Stored),
          once(spaces:metta_catalog_clause([cat_shared, [pair, A, B]], Ref)),
          assertion(Ref == Stored),
          assertion(A == B),
          \+ spaces:metta_catalog_clause([cat_shared, [pair, left, right]], _) )),
    \+ spaces:metta_catalog_clause([cat_shared, _], _).

test(a_missing_catalog_width_does_not_read_user_predicates,
     [ setup(\+ current_predicate(user:'&metta'/31)),
       cleanup(abolish(user:'&metta'/31)) ]) :-
    length(Tail, 30),
    maplist(=(padding), Tail),
    Goal =.. ['&metta', cat_outside|Tail],
    assertz(user:Goal),
    \+ spaces:metta_catalog_clause([cat_outside|Tail], _).

% Empty dynamic predicates also enter the arity inventory. The cost must depend
% on the requested width rather than on how many other widths have been stored.
test(fixed_width_catalog_lookup_ignores_unrelated_arities,
     [ setup(( \+ current_predicate('$metta_atoms:&metta':'&metta'/31),
               \+ current_predicate('$metta_atoms:&metta':'&metta'/32) )),
       cleanup(( abolish('$metta_atoms:&metta':'&metta'/31),
                 abolish('$metta_atoms:&metta':'&metta'/32) )) ]) :-
    cat_fixed_lookup_cost(_),
    cat_fixed_lookup_cost(Before),
    dynamic('$metta_atoms:&metta':'&metta'/31),
    dynamic('$metta_atoms:&metta':'&metta'/32),
    cat_fixed_lookup_cost(After),
    assertion(After == Before).

cat_fixed_lookup_cost(Cost) :-
    statistics(inferences, Start),
    forall(between(1, 100, _),
           \+ metta_catalog_row([cat_missing, subject, axis, value])),
    statistics(inferences, End),
    Cost is End - Start.

%The presets are ordinary atoms: the schema of handles is matchable the
%way any data is, which is the self-description the row asks for.
test(the_shipped_catalog_is_queryable_data) :-
    once('get-atoms'('&metta', [kind, handles|Spec])),
    Spec == [symbol, pattern, ['one-of', fidelity],
             [optional, ['one-of', determinism]]],
    once('get-atoms'('&metta', [vocabulary, fidelity|Values])),
    Values == ['Exact', 'Partial', 'Sound', 'Refuse'],
    once('get-atoms'('&metta', [kind, deprecated|DeprecatedSpec])),
    DeprecatedSpec == [symbol, term, term],
    once('get-atoms'('&metta', [vocabulary, visibility|VisibilityValues])),
    VisibilityValues == ['PUBLIC', 'INTERNAL'],
    once('get-atoms'('&metta', [kind, visibility|VisibilitySpec])),
    VisibilitySpec == [symbol, ['one-of', visibility]],
    once('get-atoms'('&metta', [kind, covers|CoverageSpec])),
    CoverageSpec == [term, ['one-of', 'effect-class']],
    once('get-atoms'('&metta', [kind, compensates|CompensationSpec])),
    CompensationSpec == [symbol, symbol].

test(every_shipped_callable_has_one_visibility) :-
    findall(Name,
            ( fun(Name)
            ; metta_special_form_head(Name)
            ),
            Callable0),
    sort(Callable0, Callable),
    findall(Name-Visibility,
            metta_contract_fact([visibility, Name, Visibility]),
            Rows0),
    sort(Rows0, Rows),
    findall(Name, member(Name-_, Rows), Visible0),
    sort(Visible0, Visible),
    assertion(Visible == Callable),
    assertion(memberchk('get-doc-atom'-'INTERNAL', Rows)),
    assertion(memberchk('get-doc-function'-'INTERNAL', Rows)),
    assertion(memberchk('get-doc-params'-'INTERNAL', Rows)),
    assertion(memberchk('get-doc-single-atom'-'INTERNAL', Rows)),
    assertion(memberchk(interpret-'INTERNAL', Rows)),
    assertion(memberchk('match-type-or'-'INTERNAL', Rows)),
    assertion(memberchk('get-doc'-'PUBLIC', Rows)).

test(a_malformed_shipped_declaration_is_refused_loudly,
     [error(metta_declaration_malformed([source, '&cat1', bogus], 2,
                                        ['one-of', 'source-kind']))]) :-
    add_sexp('&metta', [source, '&cat1', bogus], _).

test(a_missing_mandatory_argument_is_refused,
     [error(metta_declaration_malformed([annotations, '&cat2'], 2, _))]) :-
    add_sexp('&metta', [annotations, '&cat2'], _).

test(a_surplus_argument_is_refused,
     [error(metta_declaration_malformed([inverse, f, extra], 2, _))]) :-
    add_sexp('&metta', [inverse, f, extra], _).

test(an_optional_trailing_argument_may_be_omitted_or_given) :-
    add_sexp('&metta', [handles, '&cat3', [p, _X], 'Exact'], Ref1),
    add_sexp('&metta', [handles, '&cat3', [q, _Y], 'Sound', semidet], Ref2),
    erase(Ref1),
    erase(Ref2).

test(an_undeclared_head_stays_plain_data) :-
    add_sexp('&metta', ['third-party-note', anything, [odd, shape], 42], Ref),
    erase(Ref).

%A third party's whole schema path: vocabulary, kind, a valid instance,
%and the invalid instance refused by the same generic checker that guards
%the shipped kinds.
test(a_third_party_kind_is_declared_and_enforced,
     [cleanup(forall(member(A, [[vocabulary, 'cat-level', hot, cold],
                                [kind, 'cat-kind', symbol,
                                 ['one-of', 'cat-level']]]),
                     ( 'get-atoms'('&metta', A)
                     -> metta_remove_atom('&metta', A, _)
                     ;  true )))]) :-
    add_sexp('&metta', [vocabulary, 'cat-level', hot, cold], _),
    add_sexp('&metta', [kind, 'cat-kind', symbol, ['one-of', 'cat-level']], _),
    add_sexp('&metta', ['cat-kind', '&thing', hot], Ref),
    erase(Ref),
    catch(( add_sexp('&metta', ['cat-kind', '&thing', tepid], _),
            fail ),
          error(metta_declaration_malformed(_, 2, ['one-of', 'cat-level']), _),
          true).

test(a_kind_naming_an_undeclared_vocabulary_is_refused,
     [error(metta_declaration_malformed([kind, 'cat-orphan', symbol,
                                         ['one-of', 'never-declared']],
                                        3, _))]) :-
    add_sexp('&metta', [kind, 'cat-orphan', symbol,
                        ['one-of', 'never-declared']], _).

test(a_kind_with_a_nonsense_argspec_is_refused,
     [error(metta_declaration_malformed([kind, 'cat-bad', wobbly], 2, _))]) :-
    add_sexp('&metta', [kind, 'cat-bad', wobbly], _).

test(rest_anywhere_but_final_position_is_refused,
     [error(metta_declaration_malformed(_, 2,
                                        'rest only in final position'))]) :-
    add_sexp('&metta', [kind, 'cat-rest', [rest, symbol], integer], _).

test(a_second_kind_row_for_one_head_is_refused,
     [error(metta_declaration_malformed([kind, source, symbol, term], 1,
                                        _))]) :-
    add_sexp('&metta', [kind, source, symbol, term], _).

test(a_second_vocabulary_row_for_one_name_is_refused,
     [error(metta_declaration_malformed([vocabulary, fidelity, loose], 1,
                                        _))]) :-
    add_sexp('&metta', [vocabulary, fidelity, loose], _).

test(a_claim_on_a_value_outside_its_vocabulary_is_refused,
     [error(metta_declaration_malformed([claim, semiring, sideways, ordered],
                                        2, _))]) :-
    add_sexp('&metta', [claim, semiring, sideways, ordered], _).

test(algebra_law_vocabulary_and_alias_claims_are_exact) :-
    Equational = ['combine-associative', 'combine-commutative',
                  'extend-associative', 'extend-commutative',
                  'left-distributive', 'right-distributive',
                  'combine-idempotent', 'combine-zero-identity',
                  'extend-one-identity', 'extend-zero-annihilates'],
    Accepted = ['combine-associative', 'combine-commutative',
                'extend-associative', 'extend-commutative',
                'left-distributive', 'right-distributive',
                'combine-idempotent', 'combine-zero-identity',
                'extend-one-identity', 'extend-zero-annihilates', contraction,
                roundtrip, equivalent,
                associative, commutative, distributive, idempotent,
                identity, 'distributes-over'],
    once('get-atoms'('&metta', [vocabulary, 'algebra-law'|Accepted])),
    findall([Alias|Expansion],
            'get-atoms'('&metta',
                        [claim, 'algebra-law', Alias, 'expands-to'|Expansion]),
            Claims),
    sort(Claims, SortedClaims),
    SortedClaims ==
        [[associative, 'combine-associative', 'extend-associative'],
         [commutative, 'combine-commutative'],
         [contraction, contraction],
         ['distributes-over', 'left-distributive', 'right-distributive'],
         [distributive, 'left-distributive', 'right-distributive'],
         [idempotent, 'combine-idempotent'],
         [identity, 'combine-zero-identity', 'extend-one-identity']],
    forall(( member([_|Expansion], Claims), member(Law, Expansion) ),
           ( Law == contraction ; memberchk(Law, Equational) )).

test(shipped_algebra_rows_are_the_semiring_vocabulary) :-
    once('get-atoms'('&metta', [vocabulary, semiring|Semirings])),
    findall(Name, 'get-atoms'('&metta', [algebra, Name|_]), Algebras),
    Semirings == Algebras,
    Semirings == [bool, bag, counting, set, ranked, tropical, prob, prov,
                  budget, amplitude].

test(algebra_law_aliases_expand_through_catalog_claims,
     [cleanup(metta_remove_atom('&metta',
                                [algebra, 'catalog-alias-laws', max, min, 0, 1,
                                 [laws, associative], [carrier, 0, 1],
                                 [requires], '&self'], _))]) :-
    add_sexp('&metta',
             [algebra, 'catalog-alias-laws', max, min, 0, 1,
              [laws, associative], [carrier, 0, 1], [requires], '&self'], _),
    metta_algebra_law('catalog-alias-laws', 'combine-associative'),
    metta_algebra_law('catalog-alias-laws', 'extend-associative'),
    metta_algebra_law('catalog-alias-laws', associative).

test(an_unknown_algebra_law_names_the_accepted_vocabulary) :-
    once(catch(add_sexp('&metta',
                        [algebra, 'catalog-unknown-law', max, min, 0, 1,
                         [laws, absorptive], [carrier], [requires], '&self'], _),
               Error,
               true)),
    Error = error(metta_algebra_law_unknown('catalog-unknown-law', absorptive), _),
    once(message_to_string(Error, Message)),
    sub_string(Message, _, _, _, "accepted laws are"),
    once('get-atoms'('&metta', [vocabulary, 'algebra-law'|Accepted])),
    forall(member(Law, Accepted),
           ( atom_string(Law, Text), sub_string(Message, _, _, _, Text) )),
    !.

:- dynamic cat_parked_spec/1.

test(a_removed_kind_row_stops_checking_that_head,
     [setup(( 'get-atoms'('&metta', [kind, cache|CacheSpec]),
              metta_remove_atom('&metta', [kind, cache|CacheSpec], _),
              assertz(cat_parked_spec(CacheSpec)) )),
      cleanup(( retract(cat_parked_spec(Spec)),
                add_sexp('&metta', [kind, cache|Spec], _) ))]) :-
    add_sexp('&metta', [cache, anything, 'not-a-cache-mode'], Ref),
    erase(Ref).

%(some-of Vocab) reads one argument three ways and the claims decide between
%them: a word, a word applied to the arguments its takes claim declares, or a
%list of either. The shapes that must NOT pass are the ones a naive list read
%would let through: a parametrised word standing bare, a standalone word
%beside another, an applied word given the wrong argument type or count.
test(a_some_of_argument_reads_one_applied_member_or_a_list) :-
    assertion(metta_policy_members('cache-policy', monotonic, [monotonic])),
    assertion(metta_policy_members('cache-policy', [monotonic, lazy], [monotonic, lazy])),
    assertion(metta_policy_members('cache-policy', [lattice, join], [[lattice, join]])),
    assertion(metta_policy_members('cache-policy', [monotonic, [lattice, join]],
                                   [monotonic, [lattice, join]])),
    assertion(metta_policy_members('cache-policy', ['max-answers', 3], [['max-answers', 3]])),
    assertion(metta_policy_members('cache-policy', [force], [force])),
    forall(member(Bad, [lattice, [lattice, join, lazy], [force, monotonic],
                        ['max-answers', many], [lattice, 3], [], bogus,
                        [monotonic, bogus]]),
           assertion(\+ metta_policy_members('cache-policy', Bad, _))),
    %The door reads the same parse, so the row that carries a rejected shape
    %never lands.
    catch(( add_sexp('&metta', [cache, 'cat-some-of', [force, monotonic]], Ref),
            erase(Ref), fail ),
          error(metta_declaration_malformed(_, 2, ['some-of', 'cache-policy']), _),
          true),
    assertion(\+ metta_catalog_row([cache, 'cat-some-of', _])).

%A third-party kind enters the ONE shape router through catalog rows
%alone: vocabulary, kind, routed-by-shape, entries. Specificity, adornment
%and coherence are inherited, not reimplemented.
test(a_third_party_shape_routed_kind_rides_the_one_router,
     [setup(( add_sexp('&metta', [vocabulary, 'fr-level', live, cached, stale], _),
              add_sexp('&metta', [kind, freshness, symbol, pattern,
                                  ['one-of', 'fr-level']], _),
              add_sexp('&metta', ['routed-by-shape', freshness], _) )),
      cleanup(forall(member(A, [[freshness, '&fr', [edge, _, _], cached],
                                [freshness, '&fr', [edge, [in, _], _], live],
                                ['routed-by-shape', freshness],
                                [kind, freshness, symbol, pattern,
                                 ['one-of', 'fr-level']],
                                [vocabulary, 'fr-level', live, cached, stale]]),
                     metta_remove_atom('&metta', A, _)))]) :-
    add_sexp('&metta', [freshness, '&fr', [edge, _A, _B], cached], _),
    add_sexp('&metta', [freshness, '&fr', [edge, [in, _C], _D], live], _),
    metta_shape_route(freshness, '&fr', [edge, bound, _E], _, [Level]),
    Level == live,
    metta_shape_route(freshness, '&fr', [edge, _F, _G], _, [General]),
    General == cached.

test(two_disagreeing_maximal_entries_conflict_loudly,
     [setup(( add_sexp('&metta', [vocabulary, 'hot-level', hot, cold], _),
              add_sexp('&metta', [kind, hotness, symbol, pattern,
                                  ['one-of', 'hot-level']], _),
              add_sexp('&metta', ['routed-by-shape', hotness], _),
              add_sexp('&metta', [hotness, '&h', [p, _, q], hot], _),
              add_sexp('&metta', [hotness, '&h', [p, r, _], cold], _) )),
      cleanup(forall(member(A, [[hotness, '&h', [p, _, q], hot],
                                [hotness, '&h', [p, r, _], cold],
                                ['routed-by-shape', hotness],
                                [kind, hotness, symbol, pattern,
                                 ['one-of', 'hot-level']],
                                [vocabulary, 'hot-level', hot, cold]]),
                     metta_remove_atom('&metta', A, _))),
      error(metta_contract_conflict(_, _, _, _))]) :-
    metta_shape_route(hotness, '&h', [p, r, q], _, _).

test(removing_the_routing_row_stops_the_route,
     [setup(( add_sexp('&metta', [vocabulary, 'wet-level', wet, dry], _),
              add_sexp('&metta', [kind, wetness, symbol, pattern,
                                  ['one-of', 'wet-level']], _),
              add_sexp('&metta', ['routed-by-shape', wetness], _),
              add_sexp('&metta', [wetness, '&w', [w, _], wet], _) )),
      cleanup(forall(member(A, [[wetness, '&w', [w, _], wet],
                                [kind, wetness, symbol, pattern,
                                 ['one-of', 'wet-level']],
                                [vocabulary, 'wet-level', wet, dry]]),
                     metta_remove_atom('&metta', A, _)))]) :-
    metta_shape_route(wetness, '&w', [w, 1], _, [wet]),
    metta_remove_atom('&metta', ['routed-by-shape', wetness], true),
    \+ metta_shape_declared(wetness, '&w').

test(a_routing_row_without_its_kind_is_refused,
     [error(metta_declaration_malformed(['routed-by-shape', 'never-kinded'],
                                        1, _))]) :-
    add_sexp('&metta', ['routed-by-shape', 'never-kinded'], _).

test(a_routing_row_over_an_unroutable_kind_is_refused,
     [setup(add_sexp('&metta', [kind, 'flat-kind', symbol, symbol], _)),
      cleanup(metta_remove_atom('&metta', [kind, 'flat-kind', symbol, symbol],
                                _)),
      error(metta_declaration_malformed(['routed-by-shape', 'flat-kind'],
                                        1, _))]) :-
    add_sexp('&metta', ['routed-by-shape', 'flat-kind'], _).

%The advisors' fold at the route classification: a loaded seam:route_cap/4
%clause may demote the declared Exact to inexact or refuse it loudly, and a
%cap outside the vocabulary is the advisor's own bug, refused as one.
:- dynamic cap_clause_ref/1.

%The advisor clause and its cap level are asserted into user explicitly:
%plunit runs setup and bodies in the unit's own module, and a hook clause
%asserted there is invisible to the engine's multifile call.
test(a_route_cap_demotes_and_refuses_through_the_published_seam,
     [setup(( retractall(user:cap_level(_)),
              add_sexp('&metta', [handles, '&cap1', [p, _X], 'Exact'], _),
              assertz(user:( seam:route_cap('&cap1', _, Cap, capped_by_test) :-
                                 cap_level(Cap) ),
                      Ref),
              assertz(cap_clause_ref(Ref)) )),
      cleanup(( retractall(user:cap_level(_)),
                retract(cap_clause_ref(Ref)),
                erase(Ref),
                metta_remove_atom('&metta',
                                  [handles, '&cap1', [p, _Y], 'Exact'],
                                  true) ))]) :-
    foreign_pushdown_class('&cap1', [p, v], exact),
    assertz(user:cap_level(inexact)),
    foreign_pushdown_class('&cap1', [p, v], inexact),
    retractall(user:cap_level(_)),
    assertz(user:cap_level(refuse)),
    catch(( foreign_pushdown_class('&cap1', [p, v], _),
            fail ),
          error(metta_route_capped('&cap1', _, capped_by_test), _),
          true),
    retractall(user:cap_level(_)),
    assertz(user:cap_level(sideways)),
    catch(( foreign_pushdown_class('&cap1', [p, v], _),
            fail ),
          error(metta_route_cap_invalid('&cap1', sideways, _), _),
          true).

%Orderedness is an independent claim in the catalog, so two third-party
%algebras may use the same operations while only the claimed one serves top.
test(a_claimed_ordered_value_orders_and_an_unclaimed_one_does_not,
     [setup(( 'get-atoms'('&metta', [vocabulary, semiring|Shipped]),
              metta_remove_atom('&metta', [vocabulary, semiring|Shipped], _),
              assertz(cat_parked_spec(Shipped)),
              append([vocabulary, semiring|Shipped], [cost, heap], Widened),
              add_sexp('&metta', Widened, _),
              add_sexp('&metta', [algebra, cost, min, '+', infinity, 0,
                                  [laws], [carrier], [requires], '&ord1'], _),
              add_sexp('&metta', [algebra, heap, min, '+', infinity, 0,
                                  [laws], [carrier], [requires], '&ord2'], _),
              add_sexp('&metta', [claim, semiring, cost, ordered], _),
              add_sexp('&metta', [annotations, '&ord1', cost], _),
              add_sexp('&metta', [annotations, '&ord2', heap], _) )),
      cleanup(( forall(member(A, [[claim, semiring, cost, ordered],
                                  [annotations, '&ord1', cost],
                                  [annotations, '&ord2', heap],
                                  [algebra, cost, min, '+', infinity, 0,
                                   [laws], [carrier], [requires], '&ord1'],
                                  [algebra, heap, min, '+', infinity, 0,
                                   [laws], [carrier], [requires], '&ord2']]),
                       metta_remove_atom('&metta', A, _)),
                retract(cat_parked_spec(Shipped)),
                append([vocabulary, semiring|Shipped], [cost, heap], Widened),
                metta_remove_atom('&metta', Widened, _),
                add_sexp('&metta', [vocabulary, semiring|Shipped], _) ))]) :-
    metta_annotations_ordered('&ord1'),
    \+ metta_annotations_ordered('&ord2').

test(a_false_algebra_law_is_refused_before_the_catalog_row_lands,
     [throws(error(metta_algebra_law_violation(
                       p4_bad_zero, 'extend-zero-annihilates', _, _, _), _))]) :-
    add_sexp('&metta',
             [algebra, p4_bad_zero, min, min, 1, 0,
              [laws, 'extend-zero-annihilates'], [carrier, 0, 1], [requires],
              '&self'],
             _).

test(an_amplitude_context_without_the_whole_fragment_is_refused_by_name,
     [throws(error(metta_amplitude_fragment_refused('&p4-amp', finite), _))]) :-
    add_sexp('&metta', [annotations, '&p4-amp', amplitude], _).

test(algebra_descriptor_caches_follow_catalog_edits,
     [cleanup(forall(member(Row,
                             [[annotations, '&p4-cache-context',
                               'p4-cache-algebra'],
                              [algebra, 'p4-cache-algebra', '+', '*', 0,
                               unit, [laws], [carrier], [requires],
                               '&p4-cache-context'],
                              [algebra, 'p4-cache-algebra', '+', '*', 0,
                               replacement, [laws], [carrier], [requires],
                               '&p4-cache-context']]),
                     ( metta_remove_atom('&metta', Row, _)
                     -> true
                     ;  true )))]) :-
    metta_annotations('&p4-cache-context', bool),
    add_sexp('&metta',
             [algebra, 'p4-cache-algebra', '+', '*', 0, unit,
              [laws], [carrier], [requires], '&p4-cache-context'], _),
    add_sexp('&metta',
             [annotations, '&p4-cache-context', 'p4-cache-algebra'], _),
    metta_annotations('&p4-cache-context', 'p4-cache-algebra'),
    metta_algebra_descriptor('&p4-cache-context', 'p4-cache-algebra',
                             '+', '*', 0, unit, [laws], [carrier], [requires]),
    metta_remove_atom('&metta',
                      [annotations, '&p4-cache-context', 'p4-cache-algebra'],
                      true),
    metta_annotations('&p4-cache-context', bool),
    metta_remove_atom('&metta',
                      [algebra, 'p4-cache-algebra', '+', '*', 0, unit,
                       [laws], [carrier], [requires],
                       '&p4-cache-context'], true),
    add_sexp('&metta',
             [algebra, 'p4-cache-algebra', '+', '*', 0, replacement,
              [laws], [carrier], [requires], '&p4-cache-context'], _),
    metta_algebra_descriptor('&p4-cache-context', 'p4-cache-algebra',
                             '+', '*', 0, replacement,
                             [laws], [carrier], [requires]).

%The export parser's word lists are the catalog's volatility vocabulary,
%consulted as data: widening the row widens what the parser accepts.
test(the_export_parser_reads_the_volatility_vocabulary,
     [setup(( 'get-atoms'('&metta', [vocabulary, volatility|Shipped]),
              metta_remove_atom('&metta', [vocabulary, volatility|Shipped], _),
              assertz(cat_parked_spec(Shipped)),
              append([vocabulary, volatility|Shipped], [frozen], Widened),
              add_sexp('&metta', Widened, _) )),
      cleanup(( retractall(metta_function_volatility('cat-vol-f', _)),
                retract(cat_parked_spec(Shipped)),
                append([vocabulary, volatility|Shipped], [frozen], Widened),
                metta_remove_atom('&metta', Widened, _),
                add_sexp('&metta', [vocabulary, volatility|Shipped], _) ))]) :-
    metta_export("(volatility cat-vol-f frozen)"),
    metta_function_volatility('cat-vol-f', frozen),
    catch(( metta_export("(volatility cat-vol-g melty)"),
            fail ),
          error(metta_export_form(_), _),
          true).

%The bulk door refuses the whole batch before any of it lands.
test(the_bulk_door_checks_before_it_writes) :-
    catch(( metta_add_atoms('&metta', [[source, '&cat4', repeated],
                                       [source, '&cat5', wrong]]),
            fail ),
          error(metta_declaration_malformed(_, _, _), _),
          true),
    \+ 'get-atoms'('&metta', [source, '&cat4', repeated]).

%A duplicate declaration leaves &self by TWO doors and both have to say the
%same thing. The batch door throws error(metta_duplicate_declaration(..), _)
%and the direct add keeps the first row and WARNS with the bare term
%[source: engine/spaces/lifecycle.pl:1452, engine/spaces/lifecycle.pl:1531].
%error_message//1 answers only the thrown form, so the warning route printed
%`Unknown message: metta_duplicate_declaration(...)` and told the operator the
%term instead of what happened. The message//1 clause delegates to the error
%one, which is what makes the two routes agree by construction rather than by
%two texts kept in step.
duplicate_declaration_message(Message) :-
    Term = metta_duplicate_declaration('&self',
                                       [':', 'cat-dup-f', ['->', 'Number']],
                                       [':', 'cat-dup-f', ['->', 'Number']]),
    member(Message, [Term, error(Term, none)]).

%message_to_string/2 rather than phrase/2 on the clause, because the defect was
%never that the text was wrong: it was that SWI's dispatch never reached a
%clause for the bare form and printed `Unknown message: ...`. Only rendering
%through the same door print_message/2 uses can see that.
test(both_doors_render_a_duplicate_declaration,
     [forall(duplicate_declaration_message(Message))]) :-
    message_to_string(Message, Text),
    once(sub_string(Text, _, _, _, "is a duplicate in")),
    \+ sub_string(Text, _, _, _, "Unknown message").


%%%% (cost <witness> <class> [<measure>]) %%%%
%
%The row's witness is a CALL with exactly one size hole, because the lane that
%checks it substitutes a ladder of sizes for that hole. Zero holes leaves
%nothing to vary and two leaves no way to say which one the class is in, so
%both are refused HERE, at the write, rather than discovered later as a row
%nothing can measure. Repeated occurrences of ONE hole are a hole.

test(a_cost_witness_needs_exactly_one_hole,
     [forall(member(Witness-Position,
                    [ [cost_none]-1,
                      cost_bare-1,
                      [cost_two, _A, _B]-1 ]))]) :-
    catch(add_sexp('&metta', [cost, Witness, linear], _),
          error(metta_declaration_malformed(_, Position, _), _),
          true),
    \+ spaces:metta_cost_row(_, Witness, _, _).

test(one_hole_used_twice_is_one_hole) :-
    setup_call_cleanup(
        add_sexp('&metta', [cost, [cost_twice, X, X], linear], Ref),
        ( assertion(spaces:metta_cost_row(cost_twice, _, linear, none)) ),
        erase(Ref)).

test(a_second_cost_row_for_one_head_is_refused_with_its_remedy) :-
    setup_call_cleanup(
        add_sexp('&metta', [cost, [cost_once, _], linear], Ref),
        ( catch(add_sexp('&metta', [cost, [cost_once, _], quadratic], _),
                error(metta_declaration_malformed(_, 1, Expected), _),
                true),
          assertion(sub_atom(Expected, _, _, _, 'one cost row per head')),
          assertion(sub_atom(Expected, _, _, _, 'remove-atom')),
          assertion(\+ spaces:metta_cost_row(cost_once, _, quadratic, _)) ),
        erase(Ref)).

test(a_cost_class_outside_the_vocabulary_takes_the_shared_one_of_refusal,
     [error(metta_declaration_malformed([cost, [cost_bogus, _], sublinear], 2,
                                        ['one-of', 'cost-class']))]) :-
    add_sexp('&metta', [cost, [cost_bogus, _], sublinear], _).

test(the_optional_measure_field_is_stored_when_written) :-
    setup_call_cleanup(
        add_sexp('&metta', [cost, [cost_measured, _], linear, depth], Ref),
        assertion(spaces:metta_cost_row(cost_measured, _, linear, depth)),
        erase(Ref)).

%The engine ships ten of these and they enter through the same door: four from
%engine/prelude.metta's own loader and six read out of
%lib_builtin_types.metta by the pass that already reads its (: ...) rows. A
%claim about a builtin has to be LOADED to be worth anything, since explain and
%every host docstring answer from '&metta'.
test(the_shipped_cost_rows_are_loaded_and_every_class_is_a_vocabulary_member) :-
    findall(Head-Class,
            spaces:metta_cost_row(Head, _, Class, _),
            Rows),
    assertion(length(Rows, 10)),
    forall(member(_-Class, Rows),
           assertion(metta_vocabulary_value('cost-class', Class))),
    forall(member(Expected, [+, 'car-atom', 'cdr-atom', 'size-atom',
                             'union-atom', 'intersection-atom',
                             union, intersection, subtraction, 'alpha-unique']),
           assertion(memberchk(Expected-_, Rows))).

%The measure a row does not name comes from the head's arrow at the hole's
%position, and it is compared with == rather than unified: (: min-atom
%(-> $a Number)) carries a type VARIABLE there, which unifies with 'Number'
%and made the whole polymorphic family read as integer-sized.
test(an_unnamed_measure_comes_from_the_arrow_at_the_holes_position) :-
    assertion(metta_cost_declaration(+, _, constant, int)),
    assertion(metta_cost_declaration('car-atom', _, linear, length)),
    setup_call_cleanup(
        add_sexp('&metta', [cost, ['min-atom', _], linear], Ref),
        assertion(metta_cost_declaration('min-atom', _, linear, length)),
        erase(Ref)).

test(explain_answers_a_declared_cost_and_stays_silent_without_one) :-
    metta_explain(['car-atom', [1, 2]], Items),
    assertion(memberchk([cost, linear, length], Items)),
    metta_explain(['if-equal', a, a, 1], Other),
    assertion(\+ memberchk([cost|_], Other)).


%%%% The claim cache %%%%
%
%A claim row's query has an open tail, because the row carries any number of
%properties, and an open-tail catalog read enumerates every storage arity.
%metta_annotations_order/2 asks one per answer, so the answer is cached the way
%a vocabulary's values are. What that cache has to survive is a row landing
%AFTER a read: the erased-reference revalidation the other caches rely on
%cannot see an addition, because every reference the entry watches is still
%live.

test(a_claim_landing_after_a_read_beats_the_cached_answer) :-
    add_sexp('&metta', [vocabulary, cat_claimvocab, cat_a, cat_b], VocabRef),
    setup_call_cleanup(
        true,
        ( assertion(\+ metta_vocabulary_claim(cat_claimvocab, cat_a, cat_prop)),
          add_sexp('&metta', [claim, cat_claimvocab, cat_a, cat_prop], ClaimRef),
          assertion(metta_vocabulary_claim(cat_claimvocab, cat_a, cat_prop)),
          erase(ClaimRef) ),
        erase(VocabRef)).

test(a_claim_removed_after_a_read_stops_answering) :-
    add_sexp('&metta', [vocabulary, cat_claimvocab2, cat_a], VocabRef),
    add_sexp('&metta', [claim, cat_claimvocab2, cat_a, cat_prop], ClaimRef),
    setup_call_cleanup(
        true,
        ( assertion(metta_vocabulary_claim(cat_claimvocab2, cat_a, cat_prop)),
          metta_remove_atom('&metta', [claim, cat_claimvocab2, cat_a, cat_prop], _),
          assertion(\+ metta_vocabulary_claim(cat_claimvocab2, cat_a, cat_prop)) ),
        ( catch(erase(ClaimRef), _, true), erase(VocabRef) )).

%Several rows per value is legal, so the entry watches several references and
%the property may be in any of them.
test(a_value_may_carry_several_claim_rows) :-
    add_sexp('&metta', [vocabulary, cat_claimvocab3, cat_a], VocabRef),
    add_sexp('&metta', [claim, cat_claimvocab3, cat_a, cat_first], First),
    add_sexp('&metta', [claim, cat_claimvocab3, cat_a, cat_second, cat_third], Second),
    setup_call_cleanup(
        true,
        ( forall(member(P, [cat_first, cat_second, cat_third]),
                 assertion(metta_vocabulary_claim(cat_claimvocab3, cat_a, P))),
          assertion(\+ metta_vocabulary_claim(cat_claimvocab3, cat_a, cat_absent)) ),
        ( erase(First), erase(Second), erase(VocabRef) )).

%The shipped claim every (top k ...) evaluation reads, so a cache that answered
%the wrong thing would change what best-first means rather than only what it
%costs.
test(the_shipped_ordered_claims_answer_through_the_cache) :-
    assertion(metta_vocabulary_claim(semiring, prob, ordered)),
    assertion(\+ metta_vocabulary_claim(semiring, bool, ordered)),
    assertion(metta_vocabulary_claim(semiring, prob, ordered)).

:- end_tests(catalog_self_description).
