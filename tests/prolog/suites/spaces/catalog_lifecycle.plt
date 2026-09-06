% Purpose: verify that catalog declarations follow their owning space's life.
% Guarantees: release removes owned rows, preserves other owners and global
%   vocabularies, and permits a different declaration in the next life
%   [tested: run_tests(catalog_lifecycle); commit=WORKTREE].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(catalog_lifecycle).

algebra_row(Space, Combine,
            [algebra, 'life-algebra', Combine, '*', 0, 1,
             [laws], [carrier], [requires], Space]).

clean_life(Space) :-
    catch(metta_release_space(Space), _, true),
    findall(Row,
            ( metta_catalog_row(Row),
              ( Row = [_, Space|_]
              ; Row = [algebra, _, _, _, _, _, _, _, _, Space] ) ),
            Rows),
    forall(member(Row, Rows), remove_sexp('&metta', Row)).

test(release_retires_cached_algebra_and_annotations_before_redeclaration,
     [cleanup((clean_life('&catalog-life'), clean_life('&catalog-sibling')))]) :-
    algebra_row('&catalog-life', max, First),
    algebra_row('&catalog-sibling', '+', Sibling),
    add_sexp('&metta', First),
    add_sexp('&metta', Sibling),
    add_sexp('&metta', [annotations, '&catalog-life', 'life-algebra']),
    metta_effective_algebra('&catalog-life', 'life-algebra'),
    metta_algebra_descriptor('&catalog-life', 'life-algebra', max, '*',
                             0, 1, [laws], [carrier], [requires]),
    metta_release_space('&catalog-life'),
    assertion(\+ metta_catalog_row(First)),
    assertion(\+ metta_catalog_row([annotations, '&catalog-life'|_])),
    assertion(metta_catalog_row(Sibling)),
    assertion(metta_effective_algebra('&catalog-life', bool)),
    algebra_row('&catalog-life', '+', Next),
    add_sexp('&metta', Next),
    assertion(metta_algebra_descriptor('&catalog-life', 'life-algebra',
                                       '+', '*', 0, 1,
                                       [laws], [carrier], [requires])).

owned_row(S, [handles, S, [fact, _], 'Exact']).
owned_row(S, [handles, S, [item, _], 'Exact', det]).
owned_row(S, ['on-error', S, [fact, _], keep]).
owned_row(S, [annotations, S, bool]).
owned_row(S, [annotations, S, bool, [capabilities]]).
owned_row(S, [source, S, linear]).
owned_row(S, [context, S, 'open-world']).
owned_row(S, [admits, S, 'Atom']).
owned_row(S, [capacity, S, 100]).
owned_row(S, [writes, S, 'best-effort']).
owned_row(S, [events, S, 'per-write-exactly']).
owned_row(S, [events, S, 'per-write-exactly', ordered]).
owned_row(S, [emits, S, fair]).
owned_row(S, [image, S, 'Box', transparent]).
owned_row(S, [on, S, [never], [insert, S, [unused]]]).
owned_row(S, [on, S, [never], [insert, S, [unused]], 2]).
owned_row(S, [agenda, S, declaration]).
owned_row(S, [agenda, S, user, 'unused-score']).
owned_row(S, [tabled, S, 'unused-function', 1]).
owned_row(S, [defined, S, 'unused-function']).
owned_row(S, [subscription, S, [never], both]).
owned_row(S, [inherits, S, '&self']).
owned_row(S, [restricted, S]).
owned_row(S, [grants, S, file]).
owned_row(S, [parametric, S]).
owned_row(S, [covers, S, readOnlyLookup]).
owned_row(S, ['pre-add', S, 'unused-judge']).
owned_row(S, ['post-add', S, 'unused-judge']).

test(every_space_keyed_catalog_family_retires_including_optional_shapes,
     [cleanup(clean_life('&catalog-families'))]) :-
    findall(Row, owned_row('&catalog-families', Row), Rows),
    forall(member(Row, Rows), add_sexp('&metta', Row)),
    metta_release_space('&catalog-families'),
    forall(member(Row, Rows), assertion(\+ metta_catalog_row(Row))),
    assertion(\+ spaces:metta_ctx_declared('&catalog-families')),
    assertion(\+ spaces:metta_events_declared('&catalog-families')).

test(release_preserves_global_vocabulary_claims_and_same_spelled_operation,
     [cleanup(clean_life('&catalog-global-name'))]) :-
    add_sexp('&metta', [vocabulary, '&catalog-global-name', value]),
    add_sexp('&metta', [claim, '&catalog-global-name', value, property]),
    add_sexp('&metta', [effect, '&catalog-global-name', pureStructural]),
    findall(Row,
            ( member(Head, [vocabulary, claim, algebra]),
              metta_catalog_row(Row), Row = [Head|_] ),
            Before),
    metta_release_space('&catalog-global-name'),
    forall(member(Row, Before), assertion(metta_catalog_row(Row))),
    assertion(metta_catalog_row([effect, '&catalog-global-name', pureStructural])).

test(ordinary_clear_preserves_the_live_spaces_algebra,
     [cleanup(clean_life('&catalog-clear'))]) :-
    algebra_row('&catalog-clear', max, Row),
    add_sexp('&metta', Row),
    add_sexp('&catalog-clear', [fact, value]),
    metta_host_clear_space('&catalog-clear'),
    assertion(metta_catalog_row(Row)),
    assertion(\+ 'get-atoms'('&catalog-clear', [fact, value])).

test(a_space_named_global_cannot_retire_the_shipped_algebras,
     [cleanup(metta_release_space(global))]) :-
    findall(Row,
            ( metta_catalog_row(Row),
              Row = [algebra, _, _, _, _, _, _, _, _, global] ),
            Presets),
    assertion(Presets \== []),
    metta_release_space(global),
    forall(member(Row, Presets), assertion(metta_catalog_row(Row))).

test(failed_storage_cleanup_keeps_its_catalog_declarations,
     [cleanup(clean_life('&catalog-failed-clear'))]) :-
    algebra_row('&catalog-failed-clear', max, Row),
    add_sexp('&metta', Row),
    catch(spaces:with_metta_space_releasing(
              '&catalog-failed-clear', throw(storage_clear_refused)),
          Error, true),
    assertion(Error == storage_clear_refused),
    assertion(metta_catalog_row(Row)).

test(catalog_retirement_rolls_back_with_its_transaction,
     [cleanup(clean_life('&catalog-rollback'))]) :-
    algebra_row('&catalog-rollback', max, Row),
    add_sexp('&metta', Row),
    add_sexp('&metta', [annotations, '&catalog-rollback', 'life-algebra']),
    metta_effective_algebra('&catalog-rollback', 'life-algebra'),
    \+ transaction((spaces:with_metta_space_releasing('&catalog-rollback', true),
                    fail)),
    assertion(metta_catalog_row(Row)),
    assertion(metta_effective_algebra('&catalog-rollback', 'life-algebra')).

test(release_retires_custom_context_routes_but_preserves_global_routes,
     [cleanup((clean_life('&catalog-route'),
               remove_sexp('&metta', ['routed-by-shape', 'life-route']),
               remove_sexp('&metta', [kind, 'life-route', symbol, pattern, term]),
               remove_sexp('&metta', [merge, ['&catalog-route'], fair])))]) :-
    add_sexp('&metta', [kind, 'life-route', symbol, pattern, term]),
    add_sexp('&metta', ['routed-by-shape', 'life-route']),
    add_sexp('&metta', ['life-route', '&catalog-route', [fact, _], payload]),
    add_sexp('&metta', [merge, ['&catalog-route'], fair]),
    metta_release_space('&catalog-route'),
    assertion(\+ metta_catalog_row(['life-route', '&catalog-route'|_])),
    assertion(metta_catalog_row([merge, ['&catalog-route'], fair])).

test(release_retires_the_live_hook_claim_as_well_as_its_reflection,
     [cleanup((clean_life('&catalog-hooks'), clean_life('&catalog-judge')))]) :-
    metta_add_atom('&catalog-judge', [=, ['life-judge', _], [accept]], _),
    space_module('&catalog-judge', Module),
    with_metta_module(Module,
        ( 'declare-pre-add!'('&catalog-hooks', 'life-judge', []),
          'declare-post-add!'('&catalog-hooks', 'life-judge', []) )),
    metta_release_space('&catalog-hooks'),
    assertion(\+ user:metta_hook_claim('&catalog-hooks', _, _, _)),
    assertion(\+ metta_catalog_row(['pre-add', '&catalog-hooks'|_])),
    assertion(\+ metta_catalog_row(['post-add', '&catalog-hooks'|_])),
    metta_add_atom('&catalog-hooks', [fact, next], _),
    assertion('get-atoms'('&catalog-hooks', [fact, next])).

:- end_tests(catalog_lifecycle).
