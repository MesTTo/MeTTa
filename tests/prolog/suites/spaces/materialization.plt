% Purpose: compare materialized function-free calls with retained compiled
%   clauses, including duplicate proofs, source prefixes and space mutations.
% Guarantees: the differential compares complete answer bags and the growth
%   gate measures completed queries [tested: function_free_materialization;
%   commit=3c64e2e24787362a5a5081513bc24b880711a1d7].
% Owns resources: fixture spaces, reader engines and message queues are
%   released by cleanup goals; collection probes restore the GC thread flag.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(random)).

% Preparation is off unless a program asks for it, so the unit declares the
% pragma for its own scope and restores the previous value. A differential run
% without it would compare the compiled program with itself.
% [tested: preparation_is_declared_rather_than_the_default; commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
:- begin_tests(function_free_materialization,
                [setup(( filereader:metta_host_set_silent(true),
                         enable_source_materialization(Previous) )),
                 cleanup(set_metta_pragma('materialize-source-relations',
                                          Previous))]).

enable_source_materialization(Previous) :-
    (   metta_pragma('materialize-source-relations', Previous)
    ->  true
    ;   Previous = none ),
    set_metta_pragma('materialize-source-relations', true).

:- meta_predicate with_program(+, 0).

with_program(Source, Goal) :-
    setup_call_cleanup(
        ( spaces:metta_host_clear_space('&plunit_materialized'),
          spaces:metta_host_clear_space('&plunit_materialized_reference'),
          process_metta_string(Source, _, '&plunit_materialized'),
          process_metta_string(Source, _, '&plunit_materialized_reference'),
          %The reference is the original compiled program retained beneath
          %the derived relation. Discard is also the space lifecycle door.
          discard_reference,
          % Loading the oracle can change global function metadata. Refresh
          % the tested space afterward so an admitted differential uses it.
          findall(F, (spaces:get_native_atom('&plunit_materialized',
                                             [=,[F|_],_]), atom(F)), Names0),
          sort(Names0, Names),
          materialize:with_source_materialization('&plunit_materialized',
                                                    Names, true) ),
        Goal,
        ( spaces:metta_host_clear_space('&plunit_materialized'),
          spaces:metta_host_clear_space('&plunit_materialized_reference') )).

query_bag(Space, Query, Bag) :-
    process_metta_string(Query, Answers, Space),
    maplist(canonical_answer(Space), Answers, Canonical),
    msort(Canonical, Bag).

discard_reference :-
    ( current_predicate(materialize:discard_space/1)
    -> materialize:discard_space('&plunit_materialized_reference')
    ; true ).

canonical_answer(Space, Answer, Canonical) :-
    copy_term_nat(Answer, Copy),
    normalize_context(Copy, Space, Canonical),
    numbervars(Canonical, 0, _).

normalize_context(Term, _, Term) :- var(Term), !.
normalize_context(Space, Space, '&self') :- !.
normalize_context([H|T], Space, [NH|NT]) :- !,
    normalize_context(H, Space, NH), normalize_context(T, Space, NT).
normalize_context(Term, _, Term).

same_bag(Query) :-
    query_bag('&plunit_materialized_reference', Query, Expected),
    query_bag('&plunit_materialized', Query, Actual),
    assertion(Actual == Expected).

reach_rules("(= (reach $x $y) (match &self (edge $x $y) True))\n\c
             (= (reach $x $y) (match &self (edge $x $z) (reach $z $y)))\n").

source_with_reach(Facts, Source) :-
    reach_rules(Rules), string_concat(Facts, Rules, Source).

test(ground_open_and_projected_bags_keep_duplicate_proofs) :-
    source_with_reach("(edge a b) (edge a b) (edge b d) (edge a c) (edge c d)\n",
                      Source),
    with_program(Source,
        ( assertion(materialize:materialized_snapshot(
                        '&plunit_materialized', _, _, _, _)),
          same_bag("!(reach a d)"),
          same_bag("!(reach $x $y)"),
          same_bag("!(reach a $y)"),
          same_bag("!(reach missing d)"),
          query_bag('&plunit_materialized', "!(reach a d)", Bag),
          assertion(Bag == [true,true,true]) )).

test(a_terminal_callee_multiplies_every_duplicate_proof) :-
    with_program("(seed a) (seed a) (seed b)\n\c
                  (= (leaf $x) (match &self (seed $x) yes))\n\c
                  (= (through $x) (match &self (seed $x) (leaf $x)))\n",
        ( materialize:materialized_snapshot('&plunit_materialized', _, Token, _, _),
          assertion(trie_lookup(Token, [through,a], one(yes,4))),
          same_bag("!(through a)"), same_bag("!(through $x)") )).

test(proof_counts_beyond_machine_integers_keep_an_exact_streaming_prefix) :-
    findall(Fact,
            ( between(0, 69, I), J is I+1, between(1, 2, _),
              format(string(Fact), '(edge n~d n~d) ', [I,J]) ), Facts),
    atomics_to_string(Facts, FactSource), source_with_reach(FactSource, Source),
    with_program(Source,
        ( materialize:materialized_snapshot('&plunit_materialized', Fast,
                                             Trie, _, _),
          Count is 2^70,
          assertion(trie_lookup(Trie, [reach,n0,n70], one(true,Count))),
          spaces:space_module('&plunit_materialized_reference', Slow),
          once(findnsols(4, Out, call(Slow:reach(n0,n70,Out)), Expected)),
          once(findnsols(4, Out, materialize:materialized_call(
                                  '&plunit_materialized', Fast, reach,
                                  [n0,n70], Out), Actual)),
          assertion(Expected == [true,true,true,true]),
          assertion(Actual == Expected) )).

test(repeated_variables_ground_heads_and_duplicate_equations) :-
    with_program("(edge a a) (edge a a) (edge a b)\n\c
                  (= (diagonal $x) (match &self (edge $x $x) hit))\n\c
                  (= (fixed a) (match &self (edge a b) hit))\n\c
                  (= (fixed a) (match &self (edge a b) hit))\n",
        ( same_bag("!(diagonal $x)"),
          same_bag("!(fixed a)"),
          same_bag("!(fixed b)"),
          same_bag("!(fixed $x)") )).

test(nested_conjunctive_matches_and_immutable_outputs) :-
    with_program("(left a) (left a) (right a b) (right a c)\n\c
                  (= (joined $x $y)\n\c
                     (match &self (, (left $x) (right $x $y))\n\c
                        (match &self (left $x) (pair $x $y))))\n",
        ( materialize:materialized_snapshot('&plunit_materialized', _, Token, _, _),
          assertion(trie_lookup(Token, [joined,a,b], one([pair,a,b],4))),
          same_bag("!(joined a $y)"), same_bag("!(joined a b)") )).

test(nonground_or_constructed_data_retains_the_original_path) :-
    with_program("(edge $stored b) (edge (node a) c)\n\c
                  (= (lookup $x $y) (match &self (edge $x $y) True))\n",
        ( same_bag("!(lookup a b)"),
          same_bag("!(lookup (node a) c)"),
          same_bag("!(lookup $x $y)") )).

% A native `&self` handed to the one-equation door now resolves to the space
% the equation is added to, the split a source load already makes (the stored
% atom keeps the author's `&self`, the compiled clause reads this space): the
% twins burn-down measured the two doors disagreeing about one word, where the
% same equation loaded from source answered ((1)) and handed to add-atom
% answered nothing. So the native call answers, the materializer reads the
% space through that resolved clause and takes its snapshot exactly as it does
% for a source-loaded equation, and the materialized door answers the same bag
% as the compiled clause.
test(a_native_literal_self_reads_its_own_space_through_the_materializer) :-
    Space = '&plunit_materialized_native_self',
    setup_call_cleanup(
        ( spaces:metta_add_atom(Space, [native_edge,a,b], _),
          spaces:metta_add_atom(Space,
              [=,[native_lookup,X,Y],[match,'&self',[native_edge,X,Y],true]], _),
          materialize:with_source_materialization(Space, [native_lookup], true) ),
        ( assertion(materialize:materialized_snapshot(Space, _, _, _, _)),
          spaces:space_module(Space, Module),
          findall(Out, call(Module:native_lookup(a,b,Out)), Expected),
          findall(Out, materialize:materialized_call(
                          Space, Module, native_lookup, [a,b], Out), Actual),
          assertion(Expected == [true]), assertion(Actual == Expected) ),
        spaces:metta_host_clear_space(Space)).

test(a_raw_variable_relation_head_retains_native_unification) :-
    with_program("(edge a c z)\n\c
                  (= (wildcard-lookup $x $y $z)\n\c
                     (match &self (edge $x $y $z) True))\n",
        ( forall(member(Space, ['&plunit_materialized',
                                '&plunit_materialized_reference']),
                 % Public admission gives variable heads directive meaning;
                 % a native clause exercises the storage invariant directly.
                 ( spaces:native_storage_module_ready(Space, Storage),
                   spaces:native_storage_functor(Space, Predicate),
                   Head =.. [Predicate,_,a,b,z], assertz(Storage:Head) )),
          materialize:with_source_materialization('&plunit_materialized',
                                                    ['wildcard-lookup'], true),
          assertion(\+ materialize:materialized_snapshot(
                            '&plunit_materialized', _, _, _, _)),
          same_bag("!(wildcard-lookup a b z)"),
          same_bag("!(wildcard-lookup a c z)"),
          same_bag("!(wildcard-lookup $x $y $z)") )).

test(floating_keys_keep_the_native_matchers_identity_and_multiplicity) :-
    Values = [0,0.0,-0.0,1,1.0,1.0Inf,-1.0Inf,1.5NaN],
    with_program("(= (numeric-key $x) (match &self (numeric-value $x) $x))",
        ( forall((member(Space, ['&plunit_materialized',
                                 '&plunit_materialized_reference']),
                  nth1(Count, Values, Value), between(1, Count, _)),
                 spaces:metta_add_atom(Space, ['numeric-value',Value], _)),
          materialize:materialize_source('&plunit_materialized'),
          assertion(materialize:materialized_snapshot(
                        '&plunit_materialized', _, _, _, _)),
          spaces:space_module('&plunit_materialized', Fast),
          spaces:space_module('&plunit_materialized_reference', Slow),
          forall(member(Value, Values),
                 ( findall(Out, call(Slow:'numeric-key'(Value,Out)), Expected),
                   findall(Out, materialize:materialized_call(
                                   '&plunit_materialized', Fast,
                                   'numeric-key', [Value], Out), Actual),
                   assertion(Actual == Expected) )) )).

test(typed_effectful_and_unbound_templates_retain_the_original_path) :-
    with_program("(edge a b)\n\c
                  (: typed (-> Atom Atom))\n\c
                  (= (typed $x) (match &self (edge $x $y) $y))\n\c
                  (= (open $x) (match &self (edge $x $y) $free))\n\c
                  (= (arithmetic $x) (match &self (edge $x $y) (+ 2 3)))\n",
        ( same_bag("!(typed a)"), same_bag("!(open a)"),
          same_bag("!(arithmetic a)") )).

test(generated_acyclic_duplicate_bags_match_the_original_program) :-
    set_random(seed(902025)),
    forall(between(1, 24, _),
        ( findall(Fact,
                  ( between(1, 10, _), random_between(0, 4, A),
                    Low is A+1, random_between(Low, 5, B),
                    format(string(Fact), '(edge n~d n~d) ', [A,B]) ), Facts),
          atomics_to_string(Facts, FactSource),
          source_with_reach(FactSource, Source),
          with_program(Source,
              ( assertion(materialize:materialized_snapshot(
                              '&plunit_materialized', _, _, _, _)),
                same_bag("!(reach $x $y)"),
                same_bag("!(reach n0 n5)"),
                same_bag("!(reach n2 $y)"),
                forall((between(0, 5, X), between(0, 5, Y)),
                       ( format(string(Q), '!(reach n~d n~d)', [X,Y]),
                         same_bag(Q) )) ) ) )).

test(add_remove_clear_and_reload_invalidate_the_derived_relation) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    with_program(Source,
        ( same_bag("!(reach a c)"),
          forall(member(Space, ['&plunit_materialized',
                                '&plunit_materialized_reference']),
                 spaces:metta_add_atom(Space, [edge,a,c], _)),
          same_bag("!(reach a c)"),
          forall(member(Space, ['&plunit_materialized',
                                '&plunit_materialized_reference']),
                 spaces:metta_remove_atom(Space, [edge,b,c], _)),
          same_bag("!(reach a c)"),
          forall(member(Space, ['&plunit_materialized',
                                '&plunit_materialized_reference']),
                 ( spaces:metta_host_clear_space(Space),
                   process_metta_string(Source, _, Space) )),
          discard_reference,
          same_bag("!(reach a c)") )).

test(a_rolled_back_mutation_restores_the_original_bag) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    with_program(Source,
        ( \+ transaction(( spaces:metta_add_atom('&plunit_materialized',
                                                 [edge,a,c], _), fail )),
          same_bag("!(reach a c)") )).

test(a_transaction_reads_its_changes_and_a_commit_invalidates_the_image) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    with_program(Source,
        ( transaction((
              spaces:metta_add_atom('&plunit_materialized', [edge,a,c], _),
              query_bag('&plunit_materialized', "!(reach a c)", [true,true]) )),
          spaces:metta_add_atom('&plunit_materialized_reference', [edge,a,c], _),
          same_bag("!(reach a c)") )).

test(a_transactional_clear_reclaims_its_relation_at_commit) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    with_program(Source,
        ( materialize:materialized_snapshot('&plunit_materialized', _, Token, _, _),
          transaction(spaces:metta_host_clear_space('&plunit_materialized')),
          assertion(\+ materialize:materialized_snapshot(
                             '&plunit_materialized', _, _, _, _)),
          assertion(\+ materialize:materialized_predicate(_, _, _, Token)) )).

test(a_rolled_back_clear_restores_the_source_and_relation) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    with_program(Source,
        ( \+ transaction((spaces:metta_host_clear_space('&plunit_materialized'),
                           fail)),
          same_bag("!(reach a c)") )).

test(a_late_parent_is_refused_before_it_can_change_the_relation) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    with_program(Source,
        ( catch(spaces:metta_declare_space_parent('&plunit_materialized', '&self'),
                Error, true),
          assertion(Error == error(
              metta_space_parent_after_use('&plunit_materialized'), none)),
          same_bag("!(reach a c)") )).

test(an_external_parent_change_cannot_reuse_a_local_only_relation) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    setup_call_cleanup(
        spaces:metta_add_atom('&plunit_materialized_parent', [edge,a,c], _),
        with_program(Source,
            setup_call_cleanup(
                ( assertz(spaces:space_parent('&plunit_materialized',
                                              '&plunit_materialized_parent'), A),
                  assertz(spaces:space_parent('&plunit_materialized_reference',
                                              '&plunit_materialized_parent'), B) ),
                same_bag("!(reach a c)"),
                (erase(A), erase(B)))),
        spaces:metta_host_clear_space('&plunit_materialized_parent')).

test(cyclic_bags_are_declined_and_reduction_fuel_keeps_its_answer) :-
    source_with_reach("(edge a a)\n", Cyclic),
    with_program(Cyclic,
        ( assertion(\+ materialize:materialized_snapshot(
                            '&plunit_materialized', _, _, _, _)),
          same_bag("!(with-pragma! ((max-stack-depth 8)) (reach a a))") )),
    chain_source(16, Acyclic),
    with_program(Acyclic,
        same_bag("!(with-pragma! ((max-stack-depth 8)) (reach n0 n16))")).

test(attributed_inputs_keep_the_compiled_constraint_behaviour) :-
    with_program("(edge a b) (edge c d)\n\c
                  (= (lookup $x $y) (match &self (edge $x $y) True))\n",
        ( spaces:space_module('&plunit_materialized', Fast),
          spaces:space_module('&plunit_materialized_reference', Slow),
          findall(X-Y, (dif(X,a), call(Slow:lookup(X,Y,true))), Expected),
          findall(X-Y, (dif(X,a), materialize:materialized_call(
                                   '&plunit_materialized', Fast, lookup,
                                   [X,Y], true)), Actual),
          assertion(Actual == Expected) )).

test(a_running_reader_keeps_its_result_after_the_relation_is_removed) :-
    source_with_reach("(edge a b) (edge a b) (edge b c)\n", Source),
    with_program(Source,
        ( materialize:materialized_snapshot('&plunit_materialized', M,
                                             Token, _, _),
          setup_call_cleanup(
              engine_create(Out,
                  materialize:materialized_call('&plunit_materialized', M,
                                                reach, [a,c], Out), Engine),
              ( engine_next(Engine, true),
                materialize:discard_space('&plunit_materialized'),
                assertion(\+ materialize:materialized_predicate(_, _, _, Token)),
                engine_next(Engine, true),
                \+ engine_next(Engine, _) ),
              engine_destroy(Engine)) )).

test(a_reader_cut_holds_no_relation_registry_resource) :-
    source_with_reach("(edge a b) (edge a b) (edge b c)\n", Source),
    with_program(Source,
        ( materialize:materialized_snapshot('&plunit_materialized', M,
                                             Token, _, _),
          setup_call_cleanup(
              engine_create(Out,
                  materialize:materialized_call('&plunit_materialized', M,
                                                reach, [a,c], Out), Engine),
              ( engine_next(Engine, true),
                materialize:discard_space('&plunit_materialized') ),
              engine_destroy(Engine)),
          assertion(\+ materialize:materialized_predicate(_, _, _, Token)) )).

test(a_reader_started_after_a_transaction_began_survives_its_clear) :-
    source_with_reach("(edge a b) (edge a b) (edge b c)\n", Source),
    with_program(Source,
        setup_call_cleanup(
            ( message_queue_create(Ready), message_queue_create(Proceed),
              thread_create(
                  transaction(( thread_send_message(Ready, started),
                                thread_get_message(Proceed, clear),
                                spaces:metta_host_clear_space('&plunit_materialized') )),
                  Writer, []) ),
            ( thread_get_message(Ready, started),
              materialize:materialized_snapshot('&plunit_materialized', M,
                                                 Token, _, _),
              setup_call_cleanup(
                  engine_create(Out,
                      materialize:materialized_call('&plunit_materialized', M,
                                                    reach, [a,c], Out), Engine),
                  ( engine_next(Engine, true),
                    thread_send_message(Proceed, clear),
                    thread_join(Writer, true),
                    assertion(\+ materialize:materialized_predicate(_, _, _, Token)),
                    engine_next(Engine, true), \+ engine_next(Engine, _) ),
                  engine_destroy(Engine)) ),
            (message_queue_destroy(Ready), message_queue_destroy(Proceed)) )).

test(a_failed_file_load_restores_the_source_and_discards_partial_materialization) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    with_program(Source,
        setup_call_cleanup(
            ( tmp_file_stream(text, File, Stream),
              format(Stream, '(edge a c)~n!(reach a c)~n!(pragma! nonexistent 1)~n', []),
              close(Stream) ),
            ( catch(filereader:metta_host_load_file(
                        File, '&plunit_materialized', _), Error, true),
              assertion(nonvar(Error)),
              same_bag("!(reach a c)"),
              assertion(\+ materialize:materialized_snapshot(
                                  '&plunit_materialized', _, _, _, _)) ),
            delete_file(File))).

test(recycled_module_names_inherit_no_materialized_rows) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    forall(between(1, 4, _),
        setup_call_cleanup(
            process_metta_string(Source, _, '&plunit_materialized_recycled'),
            query_bag('&plunit_materialized_recycled', "!(reach a c)", [true]),
            ( spaces:metta_clear_space_for_release('&plunit_materialized_recycled'),
              spaces:metta_release_space('&plunit_materialized_recycled'),
              assertion(\+ materialize:materialized_snapshot(
                             '&plunit_materialized_recycled', _, _, _, _)),
              assertion(\+ spaces:metta_exec_module_known(
                             '&plunit_materialized_recycled', _)) ))).

test(transactional_release_removes_every_materialized_row) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    process_metta_string(Source, _, '&plunit_materialized_released'),
    materialize:materialized_snapshot('&plunit_materialized_released', _,
                                       Token, _, _),
    transaction(spaces:metta_release_space('&plunit_materialized_released')),
    assertion(\+ materialize:materialized_snapshot(
                       '&plunit_materialized_released', _, _, _, _)),
    assertion(\+ materialize:materialized_predicate(_, _, _, Token)).

test(source_runnables_see_only_the_loaded_prefix) :-
    process_metta_string("(edge a b)\n\c
                         (= (prefix $x $y) (match &self (edge $x $y) True))\n\c
                         !(prefix a c)\n\c
                         (edge a c)\n\c
                         !(prefix a c)", Answers, '&plunit_materialized'),
    assertion(Answers == [true]),
    spaces:metta_host_clear_space('&plunit_materialized').

chain_source(N, Source) :-
    Last is N-1,
    findall(Fact, ( between(0, Last, I), J is I+1,
                    format(string(Fact), '(edge n~d n~d) ', [I,J]) ), Facts),
    atomics_to_string(Facts, FactSource),
    source_with_reach(FactSource, Source).

chain_cost(N, Cost) :-
    chain_source(N, Source),
    with_program(Source,
        ( format(string(Query), '!(reach n0 n~d)', [N]),
          query_bag('&plunit_materialized', Query, [true]),
          statistics(inferences, Before),
          query_bag('&plunit_materialized', Query, [true]),
          statistics(inferences, After), Cost is After-Before )).

test(a_ground_chain_query_reuses_the_load_time_relation) :-
    chain_cost(32, A), chain_cost(128, B), chain_cost(512, C),
    assertion(B < A*1.5), assertion(C < B*1.5).

test(a_loaded_relation_owns_a_completed_index_before_its_first_query) :-
    chain_source(32, Source),
    with_program(Source,
        ( materialize:materialized_snapshot('&plunit_materialized', _, Trie, _, _),
          % Inferences do not count C-level lazy index construction. Inspect
          % the completed index before making the first public query.
          assertion(is_trie(Trie)),
          trie_property(Trie, value_count(Count)), assertion(Count > 32),
          same_bag("!(reach n0 n32)") )).

test(an_empty_derived_relation_has_a_completed_index) :-
    with_program("(= (empty-lookup $x) (match &self (empty-edge $x) True))",
        ( materialize:materialized_snapshot('&plunit_materialized', _, Trie, _, _),
          assertion(is_trie(Trie)),
          assertion(trie_property(Trie, value_count(0))),
          same_bag("!(empty-lookup absent)"),
          same_bag("!(empty-lookup $x)") )).

test(a_second_image_clear_and_rolled_back_rebuild_preserve_the_first_index) :-
    chain_source(16, Source), chain_source(128, OtherSource),
    Other = '&plunit_materialized_other_image',
    with_program(Source,
        setup_call_cleanup(
            process_metta_string(OtherSource, _, Other),
            ( materialize:materialize_source('&plunit_materialized'),
              materialize:materialize_source(Other),
              materialize:materialized_snapshot('&plunit_materialized', _,
                                                 First, _, _),
              materialize:materialized_snapshot(Other, _, Second, _, _),
              assertion(First \== Second),
              assertion(trie_lookup(First, [reach,n0,n16], one(true,1))),
              assertion(trie_lookup(Second, [reach,n0,n128], one(true,1))),
              transaction(spaces:metta_host_clear_space(Other)),
              assertion(materialize:materialized_snapshot(
                            '&plunit_materialized', _, First, _, _)),
              same_bag("!(reach n0 n16)"),
              \+ metta_transaction((
                     materialize:discard_space('&plunit_materialized'),
                     materialize:materialize_source('&plunit_materialized'),
                     materialize:materialized_snapshot('&plunit_materialized', _,
                                                        Replacement, _, _),
                     assertion(Replacement \== First), fail )),
              assertion(materialize:materialized_snapshot(
                            '&plunit_materialized', _, First, _, _)),
              same_bag("!(reach n0 n16)") ),
            spaces:metta_host_clear_space(Other))).

many_value_prefix_cost(N, Cost) :-
    findall(Fact, (between(1, N, I), format(string(Fact), '(item ~d) ', [I])), Facts),
    atomics_to_string(Facts, FactSource),
    string_concat(FactSource,
                  "(= (many-values fixed) (match &self (item $value) $value))", Source),
    with_program(Source,
        ( same_bag("!(many-values fixed)"),
          materialize:materialized_snapshot('&plunit_materialized', _, Token, _, _),
          assertion(trie_lookup(Token, ['many-values',fixed], original)),
          spaces:space_module('&plunit_materialized', M),
          once(materialize:materialized_call('&plunit_materialized', M,
                                              'many-values', [fixed], 1)),
          statistics(inferences, Before),
          once(materialize:materialized_call('&plunit_materialized', M,
                                              'many-values', [fixed], _)),
          statistics(inferences, After), Cost is After-Before )).

test(a_many_value_call_keeps_constant_prefix_startup) :-
    many_value_prefix_cost(32, A), many_value_prefix_cost(128, B),
    many_value_prefix_cost(512, C),
    assertion(B < A*1.5), assertion(C < B*1.5).

test(a_committed_source_transaction_prepares_the_relation_before_returning) :-
    source_with_reach("(edge a b) (edge a b) (edge b c)\n", Source),
    Space = '&plunit_materialized_transaction',
    setup_call_cleanup(
        spaces:metta_host_clear_space(Space),
        ( metta_transaction(process_metta_string(Source, _, Space)),
          assertion(materialize:materialized_snapshot(Space, _, _, _, _)),
          query_bag(Space, "!(reach a c)", Bag),
          assertion(Bag == [true,true]) ),
        spaces:metta_host_clear_space(Space)).

test(nested_source_transactions_finish_and_restore_the_rolled_back_bag) :-
    source_with_reach("(edge a b) (edge a b) (edge b c)\n", Source),
    Space = '&plunit_materialized_nested_source',
    setup_call_cleanup(
        spaces:metta_host_clear_space(Space),
        ( metta_transaction(process_metta_string(Source, _, Space)),
          call_with_inference_limit(
              \+ metta_transaction((
                     metta_transaction(process_metta_string("(edge a c)", _, Space)),
                     query_bag(Space, "!(reach a c)", Inside),
                     assertion(Inside == [true,true,true]),
                     fail )),
              100000, Outcome),
          assertion(Outcome \== inference_limit_exceeded),
          query_bag(Space, "!(reach a c)", Bag),
          assertion(Bag == [true,true]) ),
        spaces:metta_host_clear_space(Space)).

test(a_file_replacement_prepares_its_relation_before_the_first_query) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    Space = '&plunit_materialized_file',
    setup_call_cleanup(
        ( tmp_file_stream(text, File, Stream),
          format(Stream, '~s', [Source]), close(Stream) ),
        ( filereader:metta_host_load_file(File, Space, _),
          filereader:metta_host_load_file(File, Space, _),
          assertion(materialize:materialized_snapshot(Space, _, _, _, _)),
          query_bag(Space, "!(reach a c)", Bag),
          assertion(Bag == [true]) ),
        ( spaces:metta_host_clear_space(Space), delete_file(File) )).

test(a_postcommit_addition_invalidates_a_receipt_with_no_erased_clauses) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    Space = '&plunit_materialized_receipt',
    setup_call_cleanup(
        spaces:metta_host_clear_space(Space),
        ( metta_transaction(process_metta_string(Source, _, Space)),
          assertion(materialize:materialized_snapshot(Space, _, _, _, _)),
          spaces:metta_add_atom(Space, [edge,a,c], _),
          spaces:space_module(Space, Module),
          findall(Out, materialize:materialized_call(Space, Module, reach,
                                                    [a,c], Out), Bag),
          assertion(Bag == [true,true]),
          assertion(\+ materialize:materialized_snapshot(Space, _, _, _, _)) ),
        spaces:metta_host_clear_space(Space)).

test(a_transaction_receipt_detects_an_invisible_concurrent_addition) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    Space = '&plunit_materialized_concurrent',
    setup_call_cleanup(
        ( process_metta_string(Source, _, Space),
          materialize:discard_space(Space),
          message_queue_create(Ready), message_queue_create(Proceed) ),
        ( thread_create(
              metta_transaction((
                  thread_send_message(Ready, started),
                  thread_get_message(Proceed, build),
                  materialize:with_source_materialization(Space, [reach], true),
                  materialize:materialized_snapshot(Space, _, _, _, _) )),
              Writer, []),
          thread_get_message(Ready, started),
          spaces:metta_add_atom(Space, [edge,a,c], _),
          thread_send_message(Proceed, build),
          thread_join(Writer, Status), assertion(Status == true),
          spaces:space_module(Space, Module),
          findall(Out, materialize:materialized_call(Space, Module, reach,
                                                    [a,c], Out), Bag),
          assertion(Bag == [true,true]),
          assertion(\+ materialize:materialized_snapshot(Space, _, _, _, _)) ),
        ( message_queue_destroy(Ready), message_queue_destroy(Proceed),
          spaces:metta_host_clear_space(Space) )).

test(an_unmanaged_outer_transaction_keeps_the_original_bag) :-
    source_with_reach("(edge a b) (edge a b) (edge b c)\n", Source),
    Space = '&plunit_materialized_unmanaged',
    setup_call_cleanup(
        spaces:metta_host_clear_space(Space),
        ( transaction(process_metta_string(Source, _, Space)),
          assertion(\+ materialize:materialized_snapshot(Space, _, _, _, _)),
          query_bag(Space, "!(reach a c)", Bag),
          assertion(Bag == [true,true]) ),
        spaces:metta_host_clear_space(Space)).

test(overlapping_owned_publications_leave_one_image) :-
    source_with_reach("(edge a b) (edge a b) (edge b c)\n", Source),
    Space = '&plunit_materialized_two_writers',
    setup_call_cleanup(
        ( process_metta_string(Source, _, Space),
          materialize:discard_space(Space),
          message_queue_create(Ready), message_queue_create(Proceed) ),
        ( thread_create(
              metta_transaction(( thread_send_message(Ready, started),
                                  thread_get_message(Proceed, build),
                                  materialize:materialize_source(Space) )),
              Writer, []),
          thread_get_message(Ready, started),
          metta_transaction(materialize:materialize_source(Space)),
          thread_send_message(Proceed, build),
          thread_join(Writer, Status), assertion(Status == true),
          findall(Trie, materialize:materialized_snapshot(Space, _, Trie, _, _),
                  Images),
          assertion(Images = [_]),
          query_bag(Space, "!(reach a c)", Bag),
          assertion(Bag == [true,true]) ),
        ( message_queue_destroy(Ready), message_queue_destroy(Proceed),
          spaces:metta_host_clear_space(Space) )).

clear_materialized_space(clear, Space) :- spaces:metta_host_clear_space(Space).
clear_materialized_space(release, Space) :- spaces:metta_release_space(Space).

concurrent_materialization_clear(Order, Action) :-
    source_with_reach("(edge a b) (edge a b) (edge b c)\n", Source),
    Space = '&plunit_materialized_late_commit',
    setup_call_cleanup(
        ( process_metta_string(Source, _, Space),
          materialize:discard_space(Space),
          message_queue_create(Ready), message_queue_create(Proceed) ),
        ( (   Order == build_first
          ->  thread_create(
                  metta_transaction(( materialize:materialize_source(Space),
                                      thread_send_message(Ready, waiting),
                                      thread_get_message(Proceed, commit) )),
                  Writer, []),
              thread_get_message(Ready, waiting),
              metta_transaction(clear_materialized_space(Action, Space))
          ;   thread_create(
                  metta_transaction(( thread_send_message(Ready, waiting),
                                      thread_get_message(Proceed, commit),
                                      clear_materialized_space(Action, Space) )),
                  Writer, []),
              thread_get_message(Ready, waiting),
              materialize:materialize_source(Space)
          ),
          thread_send_message(Proceed, commit),
          thread_join(Writer, Status), assertion(Status == true),
          assertion(\+ materialize:materialized_snapshot(Space, _, _, _, _)),
          assertion(\+ spaces:get_native_atom(Space, [edge,_,_])) ),
        ( message_queue_destroy(Ready), message_queue_destroy(Proceed),
          spaces:metta_release_space(Space) )).

test(a_built_image_cannot_commit_after_owned_clear) :-
    concurrent_materialization_clear(build_first, clear).
test(a_built_image_cannot_commit_after_owned_release) :-
    concurrent_materialization_clear(build_first, release).
test(an_older_owned_clear_retires_a_concurrently_published_image) :-
    concurrent_materialization_clear(clear_first, clear).
test(an_older_owned_release_retires_a_concurrently_published_image) :-
    concurrent_materialization_clear(clear_first, release).

:- dynamic materialization_gc_tick/0.

collect_materialization_owners :-
    % An explicit collection can return while another collector owns CGC.
    % Stop and join that worker before asserting the post-collection state.
    % SWI V10.1.13 src/pl-proc.c:pl_garbage_collect_clauses and
    % boot/syspred.pl:set_prolog_gc_thread(false).
    %
    % One round is not a fixed point either: the atom pass that reclaims an
    % image blob can already have run when the clause pass drops the last
    % reference to it, so the image goes on the next round. A single round
    % left an image standing in one whole-suite run out of twenty; a retained
    % image survives all four.
    current_prolog_flag(gc_thread, GCThread),
    setup_call_cleanup(
        set_prolog_gc_thread(false),
        forall(between(1, 4, _),
               ( assertz(materialization_gc_tick, Tick), erase(Tick),
                 garbage_collect_clauses, garbage_collect,
                 garbage_collect_atoms )),
        set_prolog_gc_thread(GCThread)).

:- meta_predicate with_unmanaged_clear(+, 1).
% The `gc` thread is stopped for the whole window, so collect_materialization_
% owners/0 is the only collector in it. The stale clear erases the image's
% owner clause and clause collection is what retires the image, so whichever
% collector reaches it first wins; left to the background one, the goal's own
% precondition -- that the image survived the stale clear -- was already false
% when it looked, and the test FAILED rather than asserting. Measured at
% loadavg 107, run alone, 40 times each: 4 failures with engine/materialize.pl
% at db307494 and 3 with the standing-engine retirement, so the race is the
% collector's and not either version's, and 0 with the thread stopped.
with_unmanaged_clear(Action, Goal) :-
    source_with_reach("(edge a b) (edge a b) (edge b c)\n", Source),
    Space = '&plunit_materialized_unmanaged_clear',
    current_prolog_flag(gc_thread, GCThread),
    setup_call_cleanup(
        ( set_prolog_gc_thread(false),
          process_metta_string(Source, _, Space),
          materialize:discard_space(Space),
          message_queue_create(Ready), message_queue_create(Proceed) ),
        ( thread_create(
              transaction(( thread_send_message(Ready, waiting),
                            thread_get_message(Proceed, clear),
                            clear_materialized_space(Action, Space) )),
              Writer, []),
          thread_get_message(Ready, waiting),
          materialize:materialize_source(Space),
          thread_send_message(Proceed, clear),
          thread_join(Writer, Status), assertion(Status == true),
          call(Goal, Space) ),
        ( message_queue_destroy(Ready), message_queue_destroy(Proceed),
          spaces:metta_release_space(Space),
          set_prolog_gc_thread(GCThread) )).

collected_space_has_no_image(Space) :-
    once(materialize:materialized_snapshot(Space, _, Token, _, _)),
    assertion(materialize:materialized_dispatch_ref(Token, _)),
    collect_materialization_owners,
    assertion(\+ materialize:materialized_snapshot(Space, _, _, _, _)),
    assertion(\+ materialize:materialized_dispatch_ref(Token, _)).

test(an_unmanaged_stale_clear_retires_its_image_at_source_collection) :-
    with_unmanaged_clear(clear, collected_space_has_no_image).
test(an_unmanaged_stale_release_retires_its_image_at_source_collection) :-
    with_unmanaged_clear(release, collected_space_has_no_image).

collection_rollback_keeps_image_retired(Space) :-
    once(materialize:materialized_snapshot(Space, _, Token, _, _)),
    assertion(materialize:materialized_dispatch_ref(Token, _)),
    collect_materialization_owners,
    assertion(\+ materialize:materialized_snapshot(Space, _, _, _, _)),
    assertion(\+ materialize:materialized_dispatch_ref(Token, _)),
    fail.

collection_under_transaction_keeps_image_retired(Space) :-
    with_mutex('$metta_materialization',
        \+ transaction(collection_rollback_keeps_image_retired(Space))),
    assertion(\+ materialize:materialized_snapshot(Space, _, _, _, _)).

test(source_collection_inside_rollback_keeps_the_orphan_image_retired) :-
    current_prolog_flag(gc_thread, GCThread),
    setup_call_cleanup(
        set_prolog_gc_thread(false),
        with_unmanaged_clear(release,
                             collection_under_transaction_keeps_image_retired),
        set_prolog_gc_thread(GCThread)).

test(an_old_active_transaction_postpones_source_owner_collection) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    with_program(Source,
        setup_call_cleanup(
            ( message_queue_create(Ready), message_queue_create(Proceed) ),
            ( materialize:materialized_owner(Owner, '&plunit_materialized', Trie),
              thread_create(
                  transaction(( thread_send_message(Ready, waiting),
                                thread_get_message(Proceed, finish) )),
                  Reader, []),
              thread_get_message(Ready, waiting),
              % Native source erasure exercises the GC seam independently
              % of the ordinary clear hook, which retires rows immediately.
              erase(Owner), collect_materialization_owners,
              assertion(materialize:materialized_owner(
                            Owner, '&plunit_materialized', Trie)),
              thread_send_message(Proceed, finish), thread_join(Reader, Status),
              assertion(Status == true), collect_materialization_owners,
              assertion(\+ materialize:materialized_snapshot(
                               '&plunit_materialized', _, _, _, _)) ),
            ( message_queue_destroy(Ready), message_queue_destroy(Proceed) ))).

test(a_cleanup_engine_finds_an_owner_hidden_from_the_gc_callers_snapshot) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    Space = '&plunit_materialized_hidden_owner',
    current_prolog_flag(gc_thread, GCThread),
    setup_call_cleanup(
        ( set_prolog_gc_thread(false),
          message_queue_create(Ready), message_queue_create(Proceed) ),
        ( thread_create(
              transaction(( thread_send_message(Ready, waiting),
                            thread_get_message(Proceed, collect(Owner)),
                            assertion(\+ materialize:materialized_owner(
                                             Owner, Space, _)),
                            collect_materialization_owners )),
              Collector, []),
          thread_get_message(Ready, waiting),
          % This source is born after the collector's transaction began,
          % so that snapshot cannot pin its erased clauses or see its owner.
          process_metta_string(Source, _, Space),
          materialize:materialized_owner(Owner, Space, _),
          erase(Owner),
          % Advance the global generation here. The collector's transaction
          % can advance only its local generation, which cannot make this
          % just-erased source older than the global CGC start generation.
          assertz(materialization_gc_tick, Tick), erase(Tick),
          thread_send_message(Proceed, collect(Owner)),
          thread_join(Collector, Status), assertion(Status == true),
          assertion(\+ materialize:materialized_snapshot(Space, _, _, _, _)) ),
        ( message_queue_destroy(Ready), message_queue_destroy(Proceed),
          spaces:metta_release_space(Space), set_prolog_gc_thread(GCThread) )).

test(static_library_reconsult_preserves_materialized_answer_bags) :-
    source_with_reach("(edge a b) (edge a b) (edge b c)\n", Source),
    with_program(Source,
        ( assertion(materialize:materialized_snapshot(
                        '&plunit_materialized', _, _, _, _)),
          user:consult('../../lib/lib_memo/lib_memo.pl'),
          same_bag("!(reach a c)"),
          query_bag('&plunit_materialized', "!(reach a c)", Bag),
          assertion(Bag == [true,true]) )).

% erase/1 on a clause reference retires nothing physically, so the channel
% carries clause references only from collection; a record reference arrives
% immediately and can never own an image.
%
% The publication is what OPENS that channel: publish_materialization/6
% registers the listener with the first image rather than at load time, so a
% run of this test alone would otherwise ask a channel nobody is listening to
% and pass without touching source_owner_erased/1.
test(an_unrelated_record_erasure_does_not_reach_the_retirement_engine) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    with_program(Source,
        ( assertion(materialize:materialized_owner(
                        _, '&plunit_materialized', _)),
          collect_materialization_owners,
          recordz(materialization_nonowner, recorded, Record),
          % The standing engine is a Prolog thread, so its own inference
          % counter is the meter: a reference that reached it moves the count.
          % engines_created cannot be the meter any more, because the engine is
          % created once per process and no erase creates another.
          thread_statistics('$metta_source_owner_retirement', inferences, Before),
          \+ transaction(( erase(Record), fail )),
          thread_statistics('$metta_source_owner_retirement', inferences, After),
          assertion(After == Before) )).

% engine_create/3 and engine_destroy/1 wrap their work in PL_set_engine, whose
% detach_engine() memsets the CALLING thread's own pthread_t to zero and
% restores it on the way out. thread_join/2 reads that field once, with no
% has_tid test, and hands it to pthread_timedjoin_np, so a join landing in that
% window dereferences a null struct pthread and the process dies inside
% __pthread_clockjoin_ex [source: SWI-Prolog 10.1.13 src/pl-thread.c:7038
% detach_engine, called from PL_set_engine at :7056; '$engine_create'/3 at
% :4083 makes the pair at :4134 and :4148, destroy_interactor at :4164 the
% pair at :4168 and :4170, and thread_join at :2898 reads .tid at :2927;
% commit=81d05b34f938ff97f835ca1c00205220690cb6f0]. Clause collection is
% delivered to this file's erase listener, so an engine per collected clause
% put that window into any thread a program joins, at a point no program chose.
% tests/prolog/probes/engine_join_window.pl isolates the same window in plain
% SWI with no engine of ours involved.
:- dynamic collectable_clause/1.

% Erased BEFORE the transaction opens and after the global generation moves
% on, because clause collection skips a clause an active transaction can still
% see; that is the same ordering a_cleanup_engine_finds_an_owner_hidden_from_
% the_gc_callers_snapshot spells out for its own owner.
erased_clauses_to_collect(Count) :-
    forall(between(1, Count, N),
           ( assertz(collectable_clause(N), Ref), erase(Ref) )),
    assertz(materialization_gc_tick, Tick), erase(Tick).

collect_inside_transaction :-
    transaction(garbage_collect_clauses).

collect_inside_transaction(Ready) :-
    thread_send_message(Ready, collecting),
    collect_inside_transaction.

test(a_transactional_collection_creates_no_engine_on_the_collecting_thread) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    with_program(Source,
        ( collect_materialization_owners,
          erased_clauses_to_collect(2000),
          statistics(engines_created, Before),
          collect_inside_transaction,
          statistics(engines_created, After),
          assertion(After == Before) )).

% The join has to land WHILE the collector is collecting. Joining straight
% after thread_create/3 reads the pthread_t before the new thread has run its
% first goal, which is why an earlier form of this test passed on the parent
% commit: the collector announces itself, and the sleep puts the read a
% couple of milliseconds into a collection that runs for tens.
test(a_joined_thread_survives_clause_collection_inside_its_transaction) :-
    source_with_reach("(edge a b) (edge b c)\n", Source),
    current_prolog_flag(gc_thread, GCThread),
    with_program(Source,
        setup_call_cleanup(
            ( set_prolog_gc_thread(false), message_queue_create(Ready) ),
            forall(between(1, 40, _),
                   ( erased_clauses_to_collect(4000),
                     thread_create(collect_inside_transaction(Ready),
                                   Collector, []),
                     thread_get_message(Ready, collecting),
                     sleep(0.002),
                     thread_join(Collector, Status),
                     assertion(Status == true) )),
            ( message_queue_destroy(Ready),
              set_prolog_gc_thread(GCThread) ))).

% The pragma is the whole gate: without it a source boundary derives nothing
% and every admitted call keeps its compiled clauses.
test(preparation_is_declared_rather_than_the_default) :-
    source_with_reach("(edge a b) (edge a b) (edge b c)\n", Source),
    setup_call_cleanup(
        set_metta_pragma('materialize-source-relations', none),
        ( spaces:metta_host_clear_space('&plunit_materialized'),
          process_metta_string(Source, _, '&plunit_materialized'),
          assertion(\+ materialize:materialized_snapshot(
                            '&plunit_materialized', _, _, _, _)),
          query_bag('&plunit_materialized', "!(reach a c)", Bag),
          assertion(Bag == [true,true]) ),
        ( set_metta_pragma('materialize-source-relations', true),
          spaces:metta_host_clear_space('&plunit_materialized') )).

:- end_tests(function_free_materialization).
