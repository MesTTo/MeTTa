% Purpose: provide MeTTa's Prolog runtime, builtins, type system, evaluator,
%   imports, function registration, and named-space execution context.
% Guarantees: metta_space_registered/1 exposes existing namespace owners
%   [tested: run_tests(space_registration); commit=a8e3fc42306377adf7cae0a331f3d92fbf190304].
% Guarantees: both trailed context scopes are published host services
%   [tested: reference_scopes:both_scope_doors_are_published_host_services;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: metta_after_foreign/2 retains one reconciliation attempt through
%   native parents and foreign completion before observation delivery
%   [tested: transaction_completion; commit=37d417bd059b4636f3fe603863a2e738e1f9aeda].
% Guarantees: engine/host_transactions.pl supplies the documented host rollback
%   workaround before runtime declarations load [tested:
%   host_transactions, test_class_declaration_rollback; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: occurrence-output writes and result-aware transactions are
%   exported through their owning runtime modules
%   [tested: spaces_tokens, classes_transaction_results; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees:
%   - metta_operation_parameters/4 exposes the joint argument types and
%     origins used by constructor compilation and runtime admission
%     [tested: translator_constructors, engine_layering; commit=2398951d3272ad02b2c2d7b1e2b610c8e332c1f5].
%   - broken extension entries raise through loading_loudly/1 with their
%     diagnostic instead of allowing boot to report success
%     [tested: tests/shell/test_packaged_cli.sh; commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d].
%   - materialize.pl loads before source processing and shares the engine's
%     runtime context [tested: function_free_materialization; commit=3c64e2e24787362a5a5081513bc24b880711a1d7].
%   - The engine/metta/ units compile into metta_engine in source
%     order. Engine and library definitions stay in their owning modules;
%     designated SWI protocol hooks live in user.
%     [tested: engine_modules; commit=b7866b4d874879ff0cb212eb1c6af60dddaa39c6].
%   - A built-in call covered by the effects cluster whose declared operand
%     types already conflict is refused before operand evaluation; shallow
%     compile-time checks inspect literals and declared return types without
%     binding source variables
%     [tested: operation_answers, test_a_repeated_eval_does_not_recompile_and_the_effects_cluster_conforms; commit=8d0027a3942000c799daccb45bf0abe1b46b10aa].
%   - repr/2, println!/2, format-args, test/3 and assert/2 presentation retain
%     host display text through sdisplay/2 without weakening swrite/2's
%     reader-inverse contract [tested: parser_display,
%     a_value_prints_according_to_its_default_reading,
%     a_partial_application_remains_visible_in_test_output; commit=0c1bd4c2faadc1c4fc97cc9d2caa084907d20072].
%   - import! loads a MeTTa source that is new or that has been edited, and
%     skips one that is neither, which is SWI's if(changed); a Python source
%     keeps if(not_loaded) [tested 2026-08-19:
%     test_an_unchanged_repeat_import_does_not_run_the_source_again,
%     test_an_edited_import_is_not_skipped,
%     filereader_source_reload:an_unchanged_file_is_not_loaded_again].
%   - the builtin type surface and engine prelude are decoded as UTF-8 rather
%     than through the process locale [tested:
%     filereader_source_reload:a_source_is_utf8_independent_of_the_locale;
%     commit=18b1135167d60396c41e63e42ded2f66d0eb1900].
%   - metta_handles_route/5 routes a query by the most specific matching
%     (handles ...) entry in &metta, where specificity is pattern
%     subsumption first and adornment-set inclusion between renaming-equal
%     patterns, disagreeing maximal ties throw metta_contract_conflict/4
%     naming both entries and the query, and a context with no entries
%     fails in one indexed probe [tested 2026-08-17: metta_handles_route]
%     [measured 2026-08-17: 15 inferences per undeclared-context miss].
%   - get-type/2 returns each derived type once, while has_type/2 uses one
%     witness for a fixed expected type [tested 2026-08-15:
%     metta_type_answers, translator_typed_checks].
%   - a child execution module resolves parent equations before the shared
%     &self and builtin tiers [tested:
%     test_a_child_space_reads_through_its_parent_and_writes_locally;
%     commit=755330de329ece49eddcfb7d6db3061c3350a0ca].
%   - restricted modules resolve only their local equations and curated
%     builtin surface [tested: spaces_restricted_modules;
%     commit=6a08901f4125c2536f5b4032daac9937f793870f].
%   - expression-named spaces are SpaceType values, select their own execution
%     modules, and report their exact ground identifier through context-space
%     [tested: test_two_instances_of_a_parametric_space_answer_independently;
%     commit=3c7bcde6a0670ec5c563584b26977b41cc727580].
%   - reporting observers type the empty expression as unit `(->)` while
%     internal classifier paths retain their gradual empty-expression result
%     [tested: test_the_empty_expressions_type_follows_the_arbiters_ruling; commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3].
%   - the include refusal's self/top pair records the arbiter-owned module
%     bases explicitly, so the inventory's exemption remains checkable
%     [tested: test_a_planted_closed_policy_list_is_reported_by_the_inventory_lane;
%     commit=42b5d28232e75c32b20a1d5bf1f740fec134938d].
%   - a hook handler whose call remains unreduced has not supplied a verdict;
%     the hook door reports its existing stuck state instead of treating the
%     residual call as a malformed verdict [tested:
%     hooks:an_unclaimed_request_is_a_stuck_state_that_says_so,
%     hooks:a_post_stuck_state_undoes_the_write; commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3].
%   - support_graph.pl loads before the specializer and file reader that publish
%     derived artifact edges [tested:
%     support_graph:test_a_derived_fact_is_invalidated_forward_from_what_it_supports;
%     commit=7ade2b90e2631451fd6ffc23d22dd8c2d4a7a7aa].
%   - lib_memo.pl is resident before user source compiles, explain reports its
%     automatic decision, and the effect walk follows its transparent cache
%     dispatcher to the underlying source function [tested:
%     test_a_doubly_branching_recursion_is_tabled_automatically_and_a_tail_recursion_is_not,
%     test_an_impure_function_is_never_cached_automatically; commit=ccad9f6d588270ec2f0810fc56c30e9e59207e7c].
%   - Integers inside signed i64 report Number and integers outside it report
%     BigInt; a Number parameter admits either while a BigInt parameter admits
%     only BigInt, and arithmetic may cross the boundary in either direction
%     without changing its exact SWI value [tested 2026-08-20:
%     bigint_number, test_bigint_and_number_type_the_numeric_tower,
%     test_integer_type_follows_the_signed_i64_boundary,
%     test_number_parameters_accept_bigint_without_retyping_number].
%   - A successful named-space import commits one receipt tying the source
%     path and digest to its exact load and stored-output references. Reuse
%     requires that receipt to remain current, so any public removal rebuilds
%     the missing source contribution without duplicating survivors
%     [tested: filereader_import_lifecycle,
%     test_public_import_rebuilds_when_a_receipt_dependency_disappears,
%     test_repeat_import_reuses_one_current_receipt_without_duplication;
%     commit=b77e3ce5233e5f6032cfc8546ff83ecf4dc3de87].
%   - Host failures from builtins retain their ISO error class and name the
%     written MeTTa operation [tested 2026-08-15:
%     metta_operation_errors, translator_evaluation_errors]. Integer
%     arithmetic pays nothing for this and float arithmetic pays one
%     inference per call, because only the integer pair takes the guarded
%     fast path [measured 2026-08-15: 300,000 and 400,000 inferences per
%     100,000 calls, against 300,000 unguarded]; division's integer pair
%     pays the catch too, because a non-divisible pair converts its result
%     to float and can overflow doing it. Whole-corpus cost is
%     +2.1% instructions on examples/ch18-performance/18-01-larger-workloads/01-scale.metta
%     [measured 2026-08-15].
%   - Python operation registration reaches the canonical `(effect Name Class)`
%     atom consumed by operation reflection; exactly pureStructural projects
%     to seam:pure_operation/1 [tested:
%     test_structural_registration_reflects_an_effect_atom,
%     effects_lattice:only_pure_structural_projects_to_the_cache_purity_seam;
%     commit=3cfbe0d7417b1c453c2dc12d47e2e47e7de461f7].
%   - the final boot pass materializes one catalog visibility row for every
%     callable after the prelude has registered its equations [tested:
%     catalog_self_description:every_shipped_callable_has_one_visibility;
%     commit=8779452fed89853c3f77c3469f7a6ec7b12e9efa].
%   - StateMonad cells use one process-shared non-backtrackable store, so main
%     evaluation and held answer engines observe the same writes without
%     losing their parameterized held-value type [tested:
%     test_state_cells_are_shared_across_answer_engines,
%     test_state_retires_three_state_function_strings; commit=18b1135167d60396c41e63e42ded2f66d0eb1900].
%   - A result past binary64 saturates to the IEEE value on the engine's
%     operations, agreeing with the reader's saturating literals, and an
%     infinity a literal produced carries through further arithmetic; the
%     same recovery answers the whole IEEE family when a float operand is
%     present, a float zero divides to the signed infinity and the NaN
%     class answers NaN, while integer division and remainder by zero answer
%     a contained DivisionByZero Error atom; raw
%     is/2 keeps every flag's error mode [tested 2026-08-20:
%     engine_operations_saturate_where_raw_is_still_raises,
%     a_read_infinity_survives_further_arithmetic,
%     a_twice_faulting_compound_saturates_all_the_way,
%     test_integer_division_by_zero_answers_what_d1_decides,
%     test_arithmetic_overflow_agrees_with_the_literal_side,
%     test_float_zero_division_and_nan_agree_with_the_arbiter;
%     commit=ecd792eacbfe1810645434ce406f79be3a9e03d1].
%   - is-alpha-member/3 tests unifiability without retaining bindings in its
%     arguments [tested 2026-08-15: metta_alpha_membership].
%   - alpha-unique-atom/2 confirms identity inside each term-hash bucket, so a
%     hash collision cannot remove an inequivalent term [tested 2026-08-15:
%     metta_alpha_unique].
%   - get-metatype/2 classifies every Prolog term used as a MeTTa value, and
%     classifies a NAME by the arbiter's grounded-token table gated on this
%     engine holding the operation, so a token nothing here answers to reports
%     Symbol as an unknown name does [tested 2026-08-20: metta_metatypes].
%   - metta_transaction/1 answers everything its body answers, and every
%     answer's writes commit or roll back together [tested 2026-08-19:
%     extensions/python/tests/ch15_writing_transactions_and_worlds/test_atomic_forms.py::test_a_transaction_preserves_every_answer_of_its_body].
%   - Every guarded_input_position/3 refuses an unbound argument and names the
%     MeTTa operation, so no builtin binds the caller's variable, invents an
%     answer, runs away or reports a host predicate [tested 2026-08-19:
%     builtin_input_guards:every_builtin_refuses_an_unbound_input_by_name,
%     extensions/python/tests/ch10_errors_and_refusals/test_builtin_inputs.py::test_a_raising_builtin_names_the_metta_operation_not_the_host_predicate].
%   - ==/3 and !=/3 refuse two operands of known and different types and
%     answer for every other pair, at no cost on two numbers [tested
%     2026-08-19:
%     extensions/python/tests/ch03_atoms_and_expressions/test_equality.py::test_cross_kind_equality_answers_false]
%     [measured 2026-08-19: 4487.45 inferences per thousand-iteration loop,
%     unchanged].
%   - %Undefined% is consistent with every type in both directions, so a call
%     site refuses only a PROVEN conflict, while has_declared_type/2 demands a
%     witness for a contract [tested 2026-08-19:
%     extensions/python/tests/ch09_types/test_gradual_typing.py::test_an_unknown_type_is_consistent_with_every_declared_type,
%     extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_admission_types_the_pool].
%   - An expression no arrow types reads element-wise, and the tuple it reads
%     is %Undefined% as soon as one member's type is [tested 2026-08-19:
%     metta_type_answers:a_tuple_with_an_untyped_member_is_undefined].
%   - get-type/2 and get-type-space/3 answer from declarations without running
%     the inspected expression, so inspection has no effects of its own
%     [tested 2026-08-19:
%     extensions/python/tests/ch09_types/test_type_inspection.py::test_get_type_does_not_run_its_arguments_effects].
%   - get-type-space/3 reads only the selected space, and the upstream doc
%     family builds @doc-formal answers from that scoped type and prose
%     [tested 2026-08-20:
%     extensions/python/tests/repository/test_doc_family.py::test_the_doc_family_answers_what_upstream_answers].
%   - seam:builtin_type_declaration/2 rows are the union of lib_builtin_types.metta
%     and the prelude's, with each row written once and evicted only by the
%     register that wrote it [tested 2026-08-19:
%     metta_builtin_type_surface:a_shared_declaration_is_evicted_only_from_the_register_that_wrote_it].
%   - External Prolog libraries extend seam:builtin_type_declaration/2 without
%     replacing the engine's rows, and unloading retires only their own clauses
%     [tested: test_a_library_types_its_own_blob_without_destroying_the_table;
%     commit=6f06e918c8f3382e8e1c8ccd8d120c6d809999a5].
%   - The prelude loads exactly three form shapes: a declaration, an equation,
%     and `!(add-translator-rule! NAME)` for a name it defines itself, which
%     is how a DERIVED form ships. A program that defines such a name in any
%     execution module takes the whole form over, so the global registration
%     is withdrawn with the clauses
%     [tested: prelude_derived_forms; commit=d1318d20b5d89d33079c49d0e94aa29e12685664].
%   - add-translator-rule! REFUSES a protected_core_head/1 name and puts that
%     name in the error term, and records what an accepted registration took
%     over from in translator_rule_override/2, so a rule going ahead of a
%     special form or a builtin is stated rather than silent
%     [tested: test_overriding_a_protected_name_is_refused_with_the_name;
%     commit=9330b5d7ebf607e34a85be950bb226fce65f45c0].
%   - Test assertions distinguish no answer from one empty-expression answer
%     [tested 2026-08-14: translator_test_answers].
%   - pragma! validates keys against the closed registry and values before
%     they can replace a working setting: an unknown key is refused, max-time
%     requires a positive number, max-inferences requires a positive integer,
%     none explicitly disables either bound, max-stack-depth answers the
%     arbiter's error atom for a non-count, and the HE spellings type-check
%     and interpreter stay accepted, NOT enforced
%     [tested: test_pragma_validates_values_and_refuses_only_unknown_keys,
%     interpreter_pragmas; commit=e8270f8551083f236ce5134ca299adf5347d6898].
%   - stack-limit scopes SWI's per-thread byte ceiling and restores the exact
%     previous value after success, failure, exception, and nested scopes;
%     max-stack-depth remains branch-local reduction fuel [tested:
%     scoped_stack_limit,
%     test_janus_stack_scope_restores_on_all_exits; commit=81c50d3ae4c03ddfd70ed3f1ff70e085cfee3978].
%   - metta_assertion_failure/4 classifies the three assertion formals, so a
%     harness tells a false claim from a broken engine by TYPE rather than by
%     reading the message [tested 2026-08-19:
%     extensions/python/tests/ch12_testing/test_assertion_failures.py::test_a_failing_assertion_is_a_different_exception_from_an_engine_fault].
%   - Runtime builtins reject prebound outputs that they would not produce
%     [tested 2026-08-14: metta_builtin_outputs].
%   - Function registration performed by a source load participates in that
%     load's rollback [tested 2026-08-14: filereader_source_rollback].
%   - metta_host_function_generation/1 exposes the sum of the process-global
%     SWI database generations of fun/1, fun_in/2, fun_scoped/1 and
%     metta_exec_module_parent/2, which advances on committed catalogue
%     changes, including a second space defining an already-registered name,
%     and on no ordinary evaluation or data write
%     [tested: function_catalogue_generation; commit=1f32a7c85d5c3bcbd8797218694ae5550c362e9a].
%   - Prolog registration refuses every head the translator compiles before
%     function dispatch, including heads added through translator_rule/1
%     [tested: test_registering_any_translator_compiled_head_is_refused_by_name].
%   - Python source imports restore sibling modules and sys.path after setup
%     or execution errors [tested 2026-08-14:
%     metta_python_import_cleanup].
%   - Every seam:grounded_extra_type/2 clause is consulted whether or not a host
%     bridge answers seam:grounded_type_names/2, so a (py-atom f Type)
%     declaration survives the Python library being loaded [tested 2026-08-18:
%     extensions/python/tests/ch11_python_as_a_notation/test_ops.py::test_a_declared_type_survives_the_library_being_loaded]
%     [measured 2026-08-18: +2 inferences per get-type on a Python object and
%     0 on every other value].
%   - register-token! and unregister-token! are ordinary registered builtins,
%     so source programs and host APIs reach the same reader-token mapping
%     [tested: test_a_registered_token_class_parses_like_a_shipped_one;
%     commit=2c741dda928a30d0ce1c7e1fcf0b263b4d1bb97b].
%   - The engine loads and runs the full examples/ corpus with
%     set_prolog_flag(autoload, false) already in effect: the
%     directory_file_path/3 directive below needs library(filesex) before
%     the rest of this section's use_module block would otherwise supply
%     it, and next_lambda_name/1 (translator.pl) needs library(gensym) for
%     every foldl-atom/map-atom/filter-atom/'|->' compile, both silently
%     supplied by autoload before now [measured 2026-08-18: NO_AUTOLOAD=1
%     sh test.sh, 200/200 examples; run.sh's own header has the mechanism].
%     Cost: +1.50% instructions:u on a bare boot (swipl -s engine/metta.pl,
%     no seats), +0.54% with the seats loaded too, +0.14% over a full
%     example run that also exercises the opt-in libraries' own fixes
%     (lib/lib_constraints/lib_constraints.pl, lib/lib_memo/lib_memo.pl) [measured 2026-08-18:
%     interleaved min-of-3, perf stat -e instructions:u, spread under
%     0.003% within each side].
%   - library(thread), library(time), library(process), library(crypto) and
%     library(redis) are optional: a build without one records the capability
%     absent through metta_platform/4 and loads without an error. A dependent
%     operation refuses by name, except the five SHA hashes that library(sha)
%     still supplies without crypto [tested: platform_capabilities,
%     platform_capabilities_reduced;
%     commit=59792b524568755a2fbfe1c5f7cdb571bd78a3bf]. The original three-row
%     census cost between +0.25% and +0.44% instructions:u on a boot, the range
%     being the
%     measurement's own layout sensitivity, which an inert padding block that
%     neither side executes moves by about the same amount [measured
%     2026-08-27: 1,062,764,116 -> 1,067,395,694 unpadded, 1,064,396,538 ->
%     1,067,019,910 with five inert rules, 1,063,925,775 -> 1,067,710,574 with
%     ten; interleaved min-of-5, perf stat -e instructions:u, swipl -q -g halt
%     -t halt -s engine/main.pl on twelve-character paths; boot inferences
%     688,190 -> 690,780 and examples/ch07-control-flow/07-01-if-and-booleans/09-xor.metta identical at 9,289;
%     commit=87d998c24278fc7f020ccb0e408ebcd9332b63eb].
% Open Obligations:
%   To Do: None. check.sh runs the no-autoload lane through test.sh
%     [source: check.sh no-autoload lane; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720].
%   Hacks: None
%   Future Enhancements: None

% The core owns its predicates; user holds the host's registrations and imports.
% Execution resolves through &self, prelude, metta_engine, user and system.
% Keeping user below the core preserves consulted host predicates while local
% equations shadow the inherited implementation only in their execution module.
% [tested: engine_modules:the_chain_is_self_then_prelude_then_engine_then_user,
% engine_modules:removing_a_local_shadow_restores_a_library_export; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
%
% Modules own their helper names and autoload tables. The boundary suite also
% loads plain-file controls that demonstrate both collisions without modules.
% [tested: engine_modules; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
%
% Exports cover cross-subsystem calls, generated goals, registered builtin heads
% and the host's query strings. Subsystems set their base before compilation so
% goal_expansion/2 is visible while their clauses are read.
% [tested: sh check.sh layering prolog-static; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]

:- module(metta_engine,
            % The LANGUAGE: builtin heads the host tier, the prelude tier and the
            % test suites call BY NAME. A MeTTa program reaches these through its
            % space's own chain instead, so this list is about Prolog callers.
          [ '=alpha'/3,
            'assert-answers'/5,
            'assert-includes-answers'/5,
            'car-atom'/2,
            'cdr-atom'/2,
            'decons-atom'/2,
            'get-metatype'/2,
            'get-type'/2,
            'import!'/3,
            'index-atom'/3,
            'is-alpha-member'/3,
            'is-space'/2,
            'map-atom'/3,
            'new-space'/1,
            'read-form!'/1,
            'require-extension!'/2,
            'size-atom'/2,
            'subtraction-atom'/3,
            (#<)/3,
            (#=)/3,
            (#>)/3,
            (#\=)/3,
            % Publish division so a host lookup cannot select yall's lambda.
            % [tested: relational_arithmetic; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
            (/)/3,
            (==)/3,
            call_goals_in/2,
            call_goals_in_/2,
            catch_recover/2,
            eval/2,
            'eval-one'/2,
            'on-unwind'/3,
            evalc/3,
            has_type/2,
            metta/4,
            metta_eval_step/2,
            metta_predicate_goal/2,
            metta_run_with_fuel/3,
            metta_speculate/1,
            or/3,
            repr/2,
            %
            % Export the module queries for callers outside the expansion chain.
            % [source: engine/metta.pl:goal_expansion/2; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
            current_metta_module/1,
            metta_self_module/1,
            metta_exec_module_prefix/1,
            current_metta_space/1,
            metta_reference_declare/3,
            metta_reference_admit_text/2,
            metta_reference_changed/1,
            metta_reference_restored/2,
            metta_reference_retired/2,
            metta_reference_definition_changed/1,
            metta_reference_face_wave/0,
            metta_reference_prepare/3,
            metta_source_singleflight/2,
            metta_graded_pair/5,
            'get-property'/2,
            metta_head_property/3,
            metta_head_claims/3,
            metta_head_origins/3,
            metta_form_unevaluated_variable_paths/3,
            metta_argument_admitted/3,
            forget_registered_function/1,
            fun_here/1,
            fun_here_in/2,
            metta_emits/2,
            metta_function_cacheable/1,
            metta_function_cacheable/2,
            metta_grounded_token/1,
            metta_shared_registry/1,
            register_arity/2,
            register_fun/1,
            register_fun_in/2,
            unregister_fun_everywhere/1,
            unregister_fun_in/2,
            with_metta_module/2,
            %
            % TYPES: the declaration tables, the normalizers and the witnesses. The
            % typing RULES are engine/type_rules.pl's; these are the core's tables.
            check_argument_type/3,
            check_argument_type_under_live_policy/3,
            declared_type_for_check/2,
            definition_type_declaration_in/3,
            enable_type_alias_scope/1,
            governing_type_chains_in/4,
            governing_type_declaration/2,
            governing_type_declaration_in/3,
            has_declared_type/2,
            metatype_argument_admitted/4,
            metta_argument_type_origins/2,
            metta_arrow_type_shape/5,
            metta_refined_type/3,
            metta_refined_union_type/1,
            metta_runtime_type/2,
            metta_shipped_types_match/2,
            metta_typed_dispatch_applies/2,
            metta_types_match_in/3,
            normalize_callable_type_in/3,
            normalize_cast_type/3,
            normalize_source_type_declarations/3,
            normalize_type_in/3,
            normalize_type_in/4,
            normalized_self_type_declaration/2,
            raw_definition_type_declaration_in/3,
            raw_governing_type_declaration_in/4,
            retire_type_alias_scope/1,
            runtime_type_guarded/1,
            throw_metta_type_error/3,
            type_alias_lookup_changed/2,
            type_alias_lookups_changed/2,
            type_alias_scope_module/2,
            type_alias_scope_space/2,
            type_annotation_support/3,
            type_declaration/2,
            type_declaration_in/3,
            type_position_modifier/3,
            type_witness_in/3,
            typing_union_decision/7,
            untypable_declarations/2,
            validate_type_alias_declaration/3,
            %
            % EFFECTS, ALGEBRA AND ANNOTATIONS: the classification a planner reads
            % and the carrier a host installs around a query.
            metta_algebra_one/2,
            metta_algebra_order/2,
            metta_annotation/2,
            metta_annotated_operation_effect/2,
            metta_annotations/2,
            metta_annotations_order/2,
            metta_annotations_ordered/1,
            metta_apply_algebra_operation/5,
            metta_apply_algebra_negation/4,
            metta_algebra_claim/3,
            metta_algebra_fixpoint/4,
            'match-under'/4,
            metta_formula_clear/0,
            metta_formula_model_count/3,
            metta_formula_variables/2,
            metta_formula_witnesses/2,
            metta_current_algebra/3,
            metta_effect_compose/2,
            metta_effect_construct/2,
            metta_effect_covered/2,
            metta_effect_rank/2,
            metta_effect_walk/3,
            metta_effective_algebra/2,
            metta_evaluation_context/1,
            metta_k_extend/4,
            metta_operation_effect/2,
            metta_with_evaluation_context/2,
            metta_with_under/2,
            %
            % FUEL, BUDGETS, TRANSACTIONS AND WORLDS.
            metta_call_with_inference_bound/2,
            metta_forget_world_coverage/1,
            metta_fuel_budget_configured/0,
            metta_fuel_note_chargeless/1,
            metta_fuel_step_goal/3,
            metta_host_hold/3,
            metta_host_hold_chunk/3,
            metta_host_hold_close/1,
            metta_host_hold_next/2,
            metta_host_hold_post/3,
            metta_host_inference_budget/3,
            metta_host_stack_charge/3,
            metta_host_time_budget/3,
            metta_host_with_stack_limit/2,
            metta_in_user_transaction/0,
            metta_discarded_inferences/1,
            %The three join doors below are exported at a measured price: their
            %names in this list move every seat row measured in a fresh process
            %(engine/metta/control.pl, above the doors), and the seam's laws
            %require it, a library calling only published services and a
            %published service being exported.
            metta_join_discarding/2,
            metta_join_measured/3,
            metta_discard_inferences/1,
            metta_negation_world_guard/1,
            metta_transaction/1,
            metta_transaction/2,
            metta_transaction_notified/3,
            metta_after_foreign/2,
            metta_foreign_completion/2,
            metta_with_state_write_fence/1,
            metta_with_trailed/3,
            metta_with_trailed_enumeration/3,
            metta_with_trailed_push/3,
            metta_world_effect_coverage/2,
            %
            % ERRORS AND REFUSALS: the vocabulary every tier raises and every host reads.
            guarded_input_position/3,
            metta_assertion_failure/6,
            metta_bad_argument_error/3,
            metta_bad_argument_reason/3,
            metta_operation_parameters/4,
            metta_error_answer/3,
            metta_error_atom/4,
            metta_error_context/3,
            metta_host_error_kind/3,
            metta_host_error_kind_row/3,
            metta_host_operation_error/5,
            metta_host_refusal/6,
            metta_host_refusal_row/4,
            metta_on_error_mode/3,
            metta_record_error/1,
            metta_refinement_violation/3,
            metta_shallow_call_refused/2,
            metta_transport_failure/1,
            refuse_unbound_input/2,
            refuse_untypable_declaration/2,
            rethrow_metta_operation_error/2,
            throw_missing_import/1,
            %
            % Shared native policies: presentation and IEEE arithmetic recovery.
            metta_console_text/2,
            metta_saturating_recover/4,
            %
            % IMPORTS, SOURCES AND EXTENSIONS: what a MeTTa source pulls in, where a
            % host loader puts it, and the seat census behind require-extension!.
            check_prolog_function_names/3,
            consult_global/1,
            consult_string_global/2,
            metta_load_source/2,
            current_working_dir/1,
            import_file_string/2,
            import_prolog_function/2,
            import_prolog_functions/2,
            import_when/4,
            metta_enlist_foreign/1,
            metta_ensure_source_observation/0,
            metta_extension_controls/2,
            metta_host_source_compile_effect_plan/4,
            metta_host_source_effect_plan/4,
            metta_host_source_runtime_effect_plan/4,
            metta_import_record/2,
            metta_install_bridges/0,
            metta_load_extension/1,
            metta_platform/4,
            metta_require_events/2,
            metta_require_platform/2,
            metta_source/2,
            metta_source_declarations/2,
            metta_source_guard/1,
            metta_source_reset/1,
            metta_unimport/2,
            register_metta_library_path/3,
            resolve_existing_import_path/3,
            unregister_metta_extension/1,
            use_module_global/1,
            use_module_global/2,
            %
            % HOST DOORS: the rest of what a binding's transport calls, every one of
            % them declared kind(..., host_service) in engine/ext_points.pl.
            metta_host_adopt_function/4,
            metta_host_control_signal_info/3,
            metta_host_control_signal_line/2,
            metta_host_drop_function/2,
            metta_host_forget_function/1,
            metta_host_function_callable_from/2,
            metta_host_reference_names/2,
            metta_host_function_generation/1,
            metta_host_goal_effect_plan/4,
            metta_host_goal_repeatable/2,
            metta_host_open_function/3,
            %
            % THE PRELUDE TIER'S DOORS, and the hook, contract, token, pragma and
            % catalog tables a subsystem, a library or a seat reads.
            evict_prelude_declaration/2,
            evict_prelude_definition/1,
            host_process_tier_loader/3,
            metta_admission_claim/2,
            metta_arguments_match_in/4,
            metta_call_accepted/2,
            metta_contract_fact/1,
            metta_cost_declaration/4,
            metta_declare_hook/3,
            metta_deprecation/3,
            metta_event_capability/3,
            metta_explain/2,
            metta_foreign_writes_lost/2,
            metta_handles_coherent/1,
            metta_handles_route/4,
            metta_handles_route/5,
            metta_hook_claim_idle/1,
            metta_hook_drop_compiled/2,
            metta_hook_eval/6,
            metta_live_state_cell/1,
            metta_merge_route/2,
            metta_presented_arrow_chain/3,
            metta_restore_token_snapshot/3,
            metta_string_declarations/2,
            metta_string_registrations/2,
            metta_substitute_self/3,
            metta_token/2,
            metta_token_snapshot/2,
            metta_undeclare_hook/2,
            metta_vocabulary_claim/3,
            metta_writes/2,
            read_form_step/4,
            retire_metta_tokens_in/1,
            retract_prelude_declarations/1,
            rewrite_parsed_form/5,
            set_metta_pragma/2,
            substitute_bound_tokens/2,
            %
            % These heads also occur in generated or host-supplied goals.
            % [tested: sh engine/test.sh; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
            '!='/3,
            'Predicate'/2,
            'abs-math'/2,
            'acos-math'/2,
            'alpha-unique-atom'/2,
            'cons-atom'/3,
            'format-args'/3,
            'get-doc-function'/4,
            'get-type-space'/3,
            'intersection-atom'/3,
            'isinf-math'/2,
            'log-math'/3,
            'max-atom'/2,
            'min-atom'/2,
            'new-state'/2,
            'pow-math'/3,
            'pragma!'/3,
            'println!'/2,
            'sin-math'/2,
            'sort-strings'/2,
            'sqrt-math'/2,
            'union-atom'/3,
            (+)/3,
            (-)/3,
            (<)/3,
            (>)/3,
            (>=)/3,
            (xor)/3,
            alpha_bucket_insert/5,
            and/3,
            application_arrow_declared/1,
            builtin_described_name/1,
            builtin_fun/1,
            builtin_implementation/2,
            builtin_implementation_coverage_inventory/1,
            builtin_registration_coverage_inventory/1,
            builtin_surface_name/1,
            builtin_surface_predicate/2,
            builtin_tree_defined_arity/2,
            check_argument_type_in/4,
            check_argument_type_under_policy/3,
            claim_function_name/3,
            control_exception/1,
            empty/1,
            exp/2,
            fun_in/2,
            get_function_type/2,
            get_function_type_in/3,
            has_type_under_policy/3,
            implies/3,
            import_receipt/4,
            include/2,
            install_engine_prelude/0,
            library/2,
            library/3,
            list_shaped/1,
            max/3,
            metatype_of/2,
            metta_adorn_strip/3,
            metta_adorn_strip/4,
            metta_algebra_descriptor/9,
            metta_annotation/1,
            metta_arrow_type_chain/2,
            metta_discharge_reset/0,
            metta_discharges_verified/0,
            metta_effect_join/3,
            metta_engine_module/1,
            metta_export/1,
            metta_extension/2,
            metta_extension_api_version/2,
            metta_extension_loaded/1,
            metta_extension_unmet/2,
            metta_finish_foreign/3,
            metta_function_determinism/2,
            metta_function_origin/3,
            metta_grounded_type/2,
            metta_hook_claim/4,
            metta_inferences/3,
            metta_math_operation/2,
            metta_open_fuel_scope/0,
            metta_operation_answer/3,
            metta_operation_plan_effect/2,
            metta_platform_absent/1,
            metta_platform_load/2,
            metta_pragma/2,
            metta_refinement_head/1,
            metta_refinement_holds/2,
            metta_refinement_violated/3,
            metta_registration_names/2,
            metta_requires/1,
            metta_residual_check/3,
            metta_restore_pragmas/2,
            metta_timeout/3,
            metta_with_pragmas/3,
            min/3,
            not/2,
            prelude_cost_claim/1,
            prelude_declaration/2,
            prelude_doc_atom/2,
            prelude_document/2,
            prelude_head/2,
            prelude_owned/1,
            prelude_rule_registration/2,
            prelude_shipped_equation/2,
            prelude_translator_rule/1,
            prelude_type_declaration/2,
            record_metta_export/2,
            register_builtin_fun/1,
            release_function_name/1,
            resolve_metta_import_path/2,
            retract_unrelated_system_arities/0,
            shallow_argument_types/2,
            shallow_declared_type/2,
            test/3,
            test_answer_value/2,
            tuple_positions_witness/3,
            type_alias_gate_ref/2,
            type_witness_candidate_matches/3,
            unguarded_input_position/2,
            unrelated_system_predicate/2,
            validate_builtin_exemptions/0,
            'bind!'/3,
            'cos-math'/2,
            'get-doc-params'/4,
            'get-doc-single-atom'/3,
            'pretty-atom'/2,
            'test-no-answer'/2,
            (*)/3,
            builtin_implementation_hook_exists/2,
            claimed_export_name/2,
            cons/3,
            declared_predicate_arity/2,
            exists_file/2,
            get_type_candidate/2,
            import_receipt_current/2,
            imported_metta_source/2,
            metta_algebra_law/2,
            metta_close_fuel_scope/0,
            metta_compensation/2,
            metta_discharge_coverage/1,
            metta_evaluation_fuel/1,
            metta_extension_info/3,
            metta_extension_member/2,
            metta_file_export/2,
            metta_fuel_exhausted/1,
            metta_function_volatility/2,
            metta_reaction/4,
            metta_semantic_effect/2,
            metta_shape_route/5,
            metta_state_cell/1,
            pending_metta_export/3,
            prelude_wrote_builtin_type/2,
            register_prolog_arities/1,
            validate_builtin_registration_coverage/0,
            verified_discharge/3,
            '%'/3,
            'change-state!'/3,
            'tan-math'/2,
            metta_builtin_effect_override/2,
            metta_discharge_report/0,
            validate_builtin_implementation_coverage/0,
            'asin-math'/2,
            metta_builtin_structural/1,
            validate_builtin_registry/0,
            'atan-math'/2,
            declare_function_volatility/2,
            %
            % Registered builtin heads are part of the public language surface.
            % assert/2 and exists_file/1 keep explicit core qualification because
            % user already imports SWI's predicates under those indicators.
            % [tested: engine_modules:every_core_builtin_head_is_exported;
            % commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
            (#+)/3,
            (#=<)/3,
            (#>=)/3,
            (#*)/3,
            argv/2,
            assertaPredicate/2,
            assertzPredicate/2,
            'atom-subst'/4,
            'bit-and'/3,
            'bit-not'/2,
            'bit-or'/3,
            'bit-shift-left'/3,
            'bit-shift-right'/3,
            'bit-xor'/3,
            callPredicate/2,
            'ceil-math'/2,
            'context-space'/1,
            'current-time'/1,
            'declare-post-add!'/3,
            'declare-pre-add!'/3,
            decons/2,
            'defined-name'/1,
            '#div'/3,
            documented/1,
            'documented-space'/2,
            'exclude-item'/3,
            'exp-math'/2,
            'filter-atom'/3,
            first/2,
            'first-from-pair'/2,
            'floor-div'/3,
            'floor-math'/2,
            'foldl-atom'/4,
            'format-time'/2,
            'get-doc'/2,
            'get-doc'/3,
            'get-doc-atom'/3,
            'get-doc-space'/3,
            'get-state'/2,
            'help!'/2,
            id/2,
            'if-decons-expr'/6,
            'is-expr'/2,
            'is-ground'/2,
            'is-member'/3,
            'isnan-math'/2,
            'is-var'/2,
            '#max'/3,
            member/3,
            'metta-thread'/4,
            '#min'/3,
            '#mod'/3,
            'new-space'/2,
            'new-space'/3,
            noeval/2,
            parse/2,
            'parse-command'/2,
            'random-float'/3,
            'random-float'/4,
            'random-int'/3,
            'random-int'/4,
            'readln!'/1,
            repra/2,
            retractPredicate/2,
            'round-math'/2,
            'second-from-pair'/2,
            sleep/2,
            'sort-atom'/2,
            superpose/2,
            'trunc-math'/2,
            'undeclare-post-add!'/2,
            'undeclare-pre-add!'/2,
            undocumented/1,
            'undocumented-space'/2,
            'unique-atom'/2,
            metta_engine_operator/1,
            <= / 3,
            install_prelude_rule/2,
            metta_hook_apply/6,
            refuse_other_tiers_name/2,
            run_under_pragmas/1,
            validate_builtin_exemption_liveness/0,
            validate_builtin_exemption_schema/0,
            validate_builtin_implementation_hooks/0,
            validate_builtin_implementation_schema/0,
            validate_builtin_implementation_unique/0,
            (=)/3,
            '=?'/3,
            '#-'/3,
            '#//'/3
          ]).

%%%%%%%%%% Dependencies %%%%%%%%%%
%directory_file_path/3 is library(filesex)'s, not a built-in, and the
%directive a few lines down calls it immediately at load time to compute
%standard_library_path/1, before the rest of this section's use_module
%block would otherwise supply it. Autoload papers over the ordering when
%it is on; with autoload=false the directive fails on an unknown
%procedure and standard_library_path/1 is never asserted, which then
%aborts the boot at load_builtin_type_surface's first (library ...) call.
%So this one import has to come first, ahead of even the section header's
%own first clause.
:- encoding(utf8).
:- use_module(library(filesex)).
%A shipped library lives in its own DIRECTORY under lib/, named for the
%library: lib/lib_memo/lib_memo.metta beside lib/lib_memo/lib_memo.pl and
%lib/lib_memo/lib_memo_doc.md. A library is a MeTTa surface, the Prolog it
%rides on and the prose that explains it, and a flat lib/ scattered those
%three across an alphabetical listing of nearly sixty files.
%
%So a spec with no directory component gets one: `lib_memo` resolves to
%lib/lib_memo/lib_memo and `lib_builtin_types.metta` to
%lib/lib_builtin_types/lib_builtin_types.metta. A spec that already names a
%directory is taken as written, which is what keeps builtin_mods/skel.metta,
%the engine's own shipped-module spelling, resolving unchanged.
library(X, Path) :- standard_library_path(Base),
                    library_within(X, Relative),
                    directory_file_path(Base, Relative, Path).

%A string reaches here from MeTTa source, `(library "builtin_mods/skel.pl")`,
%and an atom from Prolog, so both spellings are normalised before the test.
%file_name_extension/3 answers Stem=Name and Ext='' for a name with no
%extension, which is why the extension-bearing and bare cases are one clause.
library_within(Spec, Relative) :-
    ( atom(Spec) -> Name = Spec ; atom_string(Name, Spec) ),
    (   sub_atom(Name, _, _, _, '/')
    ->  Relative = Name
    ;   file_name_extension(Stem, _, Name),
        directory_file_path(Stem, Name, Relative)
    ).
%A named library directory, git-fetched or registered. A library that
%pip-installs is under neither: standard_library_path/1 is one directory,
%<src>/../lib, so (library fast.pl) cannot reach a package's own files and a
%downstream library has to pass absolute paths, which is what
%lib/minimal_metta_lib/minimal_metta_lib.py does with os.path.dirname(os.path.abspath(__file__)).
%
%SWI already owns the answer. file_search_path/2 is a "dynamic multifile hook
%predicate used to specify path aliases ... called by absolute_file_name/3 to
%search files specified as Alias(Name)" [source: SWI-Prolog 10.1 Reference
%Manual, section 4.36], it composes (the second argument may be another
%alias), and every SWI tool that understands an alias understands one
%registered here. So a package registers its directory once and
%(library pettorch fast.pl) resolves
%[tested: a_registered_library_path_resolves].
library(X, Y, Path) :- git_library_path(X, Base), !,
                       directory_file_path(Base, Y, Path).
library(X, Y, Path) :- Spec =.. [X, Y],
                       (   absolute_file_name(Spec, Resolved,
                                              [access(read), file_errors(fail)])
                       ->  Path = Resolved
                       ;   refuse_unresolved_library(X, Y)
                       ).

%An alias that resolves to nothing RAISES rather than failing, and the
%distinction is CPython's: returning None from find_spec means "not mine, keep
%looking" and raising means "definitively absent", because "the latter
%indicates that the meta path search should continue, while raising an
%exception terminates it immediately" [source: CPython, the import system,
%finders and loaders].
%
%Failing was the keep-looking signal with nothing left to look with, so
%(import! &self (library imp3 plain)) with the extension forgotten answered
%the empty set, imported nothing, and left every name from that file
%undefined. That surfaces much later as an expression evaluating to itself,
%which is the hardest failure in this language to trace back to its cause. A
%plain path that is absent already raised and named itself; this is the same
%rule reaching the alias form
%[tested: an_unresolvable_library_alias_raises].
refuse_unresolved_library(Alias, File) :-
    findall(Directory, file_search_path(Alias, Directory), Directories),
    throw(error(metta_unresolved_library(Alias, File, Directories),
                context(library/3, 'no readable file of that name'))).

prolog:error_message(metta_unresolved_library(Alias, File, [])) -->
    [ '(library ~w ~w) does not resolve: nothing is registered under the \c
       alias ~w. Register the directory with register_metta_library_path, or \c
       import the file by path.'-[Alias, File, Alias] ].
prolog:error_message(metta_unresolved_library(Alias, File, Directories)) -->
    [ '(library ~w ~w) does not resolve: no readable ~w under ~w. Check the \c
       spelling, and that the file carries its extension.'
      -[Alias, File, File, Directories] ].

%Register a directory under a name, so a Python package can point MeTTa at
%the Prolog and MeTTa files it ships beside itself. Idempotent, and a
%directory that is not there is refused where the caller can still act on it
%rather than at the first import that needs it.
register_metta_library_path(Alias, Directory0, true) :-
    must_be(atom, Alias),
    ( atom(Directory0) -> Directory = Directory0 ; atom_string(Directory, Directory0) ),
    (   exists_directory(Directory)
    ->  true
    ;   throw(error(existence_error(directory, Directory),
                    context(register_metta_library_path/3,
                            'a library path must be a directory that exists')))
    ),
    (   user:file_search_path(Alias, Directory)
    ->  true
    ;   assertz(user:file_search_path(Alias, Directory))
    ).
:- prolog_load_context(directory, Source),
   directory_file_path(Source, '..', Parent),
   directory_file_path(Parent, 'lib', LibPath),
   asserta(standard_library_path(LibPath)).
:- autoload(library(uuid)).
:- use_module(library(random)).
:- use_module(library(error)).
:- use_module(library(listing)).
%That import is why the guards below exist. library(listing) loads
%library(settings) (listing.pl:46, its five layout settings), which loads
%library(arithmetic) (settings.pl:54-56, env/1 and env/2), which installs an
%UNGUARDED process-global hook, `system:goal_expansion(Math, MathGoal) :-
%math_goal_expansion(Math, MathGoal)` (arithmetic.pl:319-320). system: is
%consulted while compiling EVERY module, and the expander's one raise site is
%a COMPILE-time type_error(evaluable, F) (do_expand_function/3's final clause,
%arithmetic.pl:233-234) for an expression SWI itself compiles and raises on at
%RUN time. A raising expansion does not just misreport: SWI drops the whole
%term expansion in flight, so a host clause holding
%`catch(_ is foo + 1, E, true)` vanished silently, and for a plunit test the
%dropped expansion is BOTH the registration and the body --
%tests/prolog/suites/evaluation/metta.plt:402 registered 233 tests instead of 234 in every
%configuration [measured 2026-08-26]. The repair keeps the hook and removes
%only that compile-time judgment: an unknown evaluable defers to run time,
%where SWI's own error and message answer (metta.plt's metta_operation_errors
%unit pins them). What the hook is FOR survives, arithmetic_function/1
%functions still expand and evaluate, and nothing new is folded:
%do_expand_function/3 maps function symbols and never evaluates, and an
%identity expansion is discarded by boot/expand.pl's no-change rule
%[measured 2026-08-26: with the guard, V is twice(21) answers 42 and
%expand_goal leaves `_ is foo + 1` unchanged]. The guard runs twice over:
%once now, for the chain the import above just loaded, and from a
%prolog_listen/2 watcher for every later install -- a reload under make/0, or
%a host that loaded library(arithmetic) before the engine and reloads it
%after. system:goal_expansion/2 is dynamic, the watcher fires inside the
%installing assert, and erasing the event's own clause there works
%[measured 2026-08-26 on SWI 10: repaired-in-event, one guarded clause
%standing, and the hazardous bare clause compiles]. The watcher must never
%throw: an exception from a listener blocks the assert it observes, which
%would silently strip the hook from a library legitimately installing it
%[measured 2026-08-26: an arity-mismatched listener left
%system:goal_expansion/2 with 0 clauses after loading library(arithmetic)].
%tests/prolog/static_checks.pl holds the class canary, expanding
%`_ is foo + 1` neither throws nor rewrites, proved against a planted
%throwing expander, and check.sh's plunit lane fails any suite that prints
%ERROR while loading, so a NEW compile-time refuser from any library fails
%the gate even though this watcher knows only arithmetic's clause. A host
%that wants upstream's compile-time diagnostic back can re-assert the
%original clause after boot; the engine's contract is that an expression's
%meaning is decided when it runs.
guard_arithmetic_goal_expansion :-
    forall(( clause(system:goal_expansion(A, B), Body, Ref),
             unguarded_math_expansion_body(Body, A, B) ),
           guard_arithmetic_goal_expansion_clause(Ref)).

guard_arithmetic_goal_expansion(Action, Ref) :-
    % policy-inventory-exempt: mechanism-internal; reason=the two clause-adding actions prolog_listen/2 reports are SWI's own event vocabulary rather than a knob an operator chooses between, and every other action it delivers is a retract or an erase, which cannot install the hook this watcher repairs; evidence=engine/metta.pl:guard_arithmetic_goal_expansion/2
    catch(( (   memberchk(Action, [assertz, asserta]),
                clause(system:goal_expansion(A, B), Body, Ref),
                unguarded_math_expansion_body(Body, A, B)
            ->  guard_arithmetic_goal_expansion_clause(Ref)
            ;   true
            ) ),
          _,
          true).

%The asserting context wraps a cross-module clause body, so the hook's body
%arrives as arithmetic:math_goal_expansion/2 when arithmetic.pl loads it and
%as user:arithmetic:math_goal_expansion/2 when a host's assertz re-installs
%it [measured 2026-08-26: portrayed both from one process]. The guarded
%replacement below arrives wrapped the same way, user:catch(...), and
%unwrapping stops at a goal that is not math_goal_expansion/2, so the guard
%never matches itself.
unguarded_math_expansion_body(arithmetic:math_goal_expansion(A, B), A, B) :- !.
unguarded_math_expansion_body(_:Inner, A, B) :-
    unguarded_math_expansion_body(Inner, A, B).

guard_arithmetic_goal_expansion_clause(Ref) :-
    erase(Ref),
    assertz(( system:goal_expansion(Math, MathGoal) :-
                  catch(arithmetic:math_goal_expansion(Math, MathGoal),
                        error(type_error(evaluable, _), _),
                        fail) )).

% The first listener the engine registers, so the door loads here; every later
% engine file reaches metta_listen/2 through the engine's module.
:- use_module(host_listeners, [metta_listen/2]).
:- guard_arithmetic_goal_expansion,
   metta_listen(system:goal_expansion/2, guard_arithmetic_goal_expansion).
:- use_module(library(aggregate)).
%sub_term/2, which the saturating recovery uses to ask whether an erroring
%arithmetic expression holds a float operand at all.
:- use_module(library(occurs)).
%dif/2 is a goal the ENGINE writes into compiled bodies: engine/duals.pl
%builds it as the negation of an equality when it generates a dual. A goal
%the engine emits has to live in the engine's own module, because that is
%where protect_engine_emitted/1 imports every space's copy from. It used to
%arrive here by accident, through engine/duals.pl's own import into the one
%namespace everything shared, and under NO_AUTOLOAD=1 with duals in a module
%of its own a compiled dual raised
%existence_error(procedure, '$metta_exec:&self':dif/2)
%[measured 2026-08-22, on examples/ch22-a-reasoner-you-can-serve/22-01-logic-programs/03-constructive_negation.metta].
:- use_module(library(dif), [dif/2]).
%The HOST TIER's Prolog predicates. A MeTTa program reaches Prolog through
%callPredicate/2 and import_prolog_function/2, and both resolve in the space's
%module, whose base chain ends here, so what this module holds is what a
%program can call. These two arrived by accident until now: engine/filereader.pl
%loaded library(pcre) and library(readutil) into the one namespace everything
%shared, and examples/ch20-extending-the-engine/20-03-prolog-underneath/02-prologimport.metta imports re_replace/4 and
%calls read_file_to_string/3 through that leak. Cutting the loader into a module
%of its own would have withdrawn both from every MeTTa program without saying
%so, which is a language change and not a refactoring, so they are imported
%here deliberately instead [measured 2026-08-22: the example raised "no
%predicate named re_replace is loaded" the moment the loader stopped sharing].
%re_replace/4 is the other one and it moved into the census block below, since
%library(pcre) is optional and the re-export has to be too.
:- use_module(library(readutil), [read_file_to_string/3, read_line_to_string/2]).
%The engine's own uses of the standard libraries, which autoload used to supply
%into the one namespace every subsystem shared: alpha_list_to_set/2 buckets
%alpha-variants through an assoc, metta_shape_stricter/2 compares two shapes'
%sorted key sets, and metta_trace_source/4 reads the values off a pairs list.
%Under NO_AUTOLOAD=1 each is an existence error at the first call rather than at
%load, so the corpus finds them one example at a time; the complete list is what
%list_undefined/0 reports with autoload off [measured 2026-08-22: six names over
%engine/metta.pl and engine/tracer.pl, zero after these three lines and
%engine/tracer.pl's own]. The import lists are narrow, so the space modules
%below this one gain exactly these names and nothing else.
:- use_module(library(assoc), [empty_assoc/1, get_assoc/3, put_assoc/4]).
:- use_module(library(ordsets), [ord_subtract/3]).
%distinct/2, which 'defined-name'/1 and 'undocumented-space'/2 call to
%dedupe function names read off a space's own equation atoms
%[measured 2026-08-18: examples/ch08-data/08-03-the-shipped-libraries/08-doc_lib.metta under
%NO_AUTOLOAD=1, existence_error(procedure,distinct/2)].
:- use_module(library(solution_sequences)).

%%%%%%%%%% What this platform carries %%%%%%%%%%
%
%Some of the loads in this block are OPTIONAL, and a build without them is a
%real build rather than a broken one: SWI compiled to WebAssembly, which is
%what the browser playground and the Node binding run on, ships no threads, no
%alarms and no subprocesses. An unconditional use_module there fails, SWI
%prints an ERROR pair, the load carries on, and the only record of what was
%lost is that text. A host then has to recover the census by parsing the
%engine's stderr, which extensions/node does, and every next host on a reduced
%platform would write its own regex for the same knowledge.
%
%The same is true of the SWI PACKAGES the engine loads, which are built
%against system libraries and can be left out of a build one at a time: pcre,
%zlib, fastrw and memfile were each unconditional here, and withholding pcre
%alone printed four ERROR pairs -- engine/metta.pl, engine/parser.pl,
%engine/filereader.pl and lib/lib_regex/lib_regex.pl, one per unguarded load
%-- while an (import! &self (library lib_regex)) came back wrapped in a
%transcript of SWI's own source_sink error [measured 2026-08-28 through
%tests/prolog/reduced_platform.pl's extra-withheld set]. They are rows here
%now, so the kernel's platform dependencies are a list a host can READ rather
%than prose in a comment. Rows, not eight of them: a capability is the thing a
%USER loses, so the two libraries the fast cache needs are one row.
%
%So the census is the rule extensions/cmetta/extension.pl and
%extension.pl already state for a SEAT, aimed at the platform:
%NOT PRESENT IS NOT AN ERROR, HALF PRESENT IS. A capability whose library is
%there loads exactly as before, through the same directive in the same place;
%one whose library is absent is RECORDED absent, and the forms resting on it
%refuse by name saying what the absence costs instead of raising
%existence_error(procedure, call_with_time_limit/2) from the interior.
%
%What a row costs is not always a REFUSAL. concurrency, deadlines, subprocess
%and regex each name forms a program cannot run at all without them, so those
%forms refuse. compressed-sources costs one FILE FORMAT: a .gz program refuses
%naming the file, and the same program uncompressed loads, which is CPython's
%answer for the same absence [source: CPython 3.14.4
%tarfile.TarFile.gzopen, `except ImportError: raise CompressionError("gzip
%module is not available") from None`, rather than letting the missing import
%error out of the interior]. fast-cache costs no MeTTa form at all: the
%engine's own loading never reads a cache, so a build without it boots, runs,
%and reparses every source exactly as a build with it does when no cache was
%written. Its two doors still refuse by name rather than half-working, because
%a binary payload only fastrw can read has nothing to fall back TO -- what
%degrades is the engine, not the door.
%
%The guard is a directive rather than SWI's :- if/:- endif conditional
%compilation, and the difference is load-bearing under .qlf: a conditional
%compilation block is decided while the file COMPILES and only the taken
%branch reaches the .qlf, so a .qlf built where a library exists would carry a
%bare use_module and no census at all. A directive is stored in the .qlf and
%re-run on every load, census included [measured 2026-08-27: a directive's
%assertz reappears from a .qlf whose source file has been moved away]. The
%import lands where the bare directive's did, because use_module/1 imports
%into the module its CALLER's clause belongs to and that is this file's
%[measured 2026-08-27: consulted into a module of its own, call_with_time_limit/2
%imported_from(time) there and absent from user].
%
%And the guard is the LOAD ITSELF rather than a question asked before it.
%exists_source/1 in front of use_module/1 is the shape the two seat deciders
%use, it was written that way first, and it resolves the same file name twice
%on every build that HAS the library: a resolution walks every directory on
%the library search path against four file-type extensions, and the three
%probes cost 6,271,103 instructions, 0.37% of a bare boot, for an answer the
%load was about to compute anyway [measured 2026-08-27: 64,860,419
%instructions:u for a process that runs the three probes against 58,589,316
%for the same process without them; command=perf stat -e instructions:u swipl
%-q -g true -t halt; fixture=/tmp/capprobe/cost.pl]. use_module/1 raises
%existence_error(source_sink, Spec) for exactly the missing spec and prints
%nothing when it is caught, so the recovery IS the census row and a present
%capability pays nothing at all.
%
%One row per capability: its name, the platform library it rests on, and what
%a build without it cannot do. The cost text is what a refused user reads, so
%it names MeTTa forms rather than the Prolog predicates behind them. These
%names are the PLATFORM's, and deliberately not the restricted-space grants of
%engine/spaces/lifecycle.pl (file, process, network), which answer the other
%question: whether a space is ALLOWED to do something this build can do.
metta_platform_capability(concurrency, library(thread),
                          '(hyperpose ...), and lib_thread\'s par-map, spawn, \c
                           await, channels, pools and blocking take-atom; \c
                           this build evaluates on one thread').
metta_platform_capability(deadlines, library(time),
                          '(timeout N Expr) and (pragma! max-time N); a \c
                           wall-clock bound has to come from the host \c
                           instead').
metta_platform_capability(subprocess, library(process),
                          '(git-import! ...), and anything else that starts \c
                           a program').
% HTTP's optional TLS transport does not remove plain HTTP when SSL is absent.
% [tested: lib_http:http_capabilities_are_separate; commit=0f22b69cfca5c108e4126bdd56ab9bb2e493744d].
metta_platform_capability(http,
                          [library(http/http_open), library(http/thread_httpd),
                           library(http/http_client), library(socket), library(uri)],
                          'lib_http client requests, response streams and local servers').
metta_platform_capability(https,
                          [library(http/http_ssl_plugin), library(ssl)],
                          'HTTPS client requests; plain HTTP remains available').
% URI percent encoding is supplied by the native clib provider.
% [tested: lib_uri:uri_capability_is_declared; commit=24b96f8ec8468bc97cec35e1d71ce689ede7fdcf].
metta_platform_capability(uri, library(uri),
                          'lib_uri percent encoding and URI reference operations').
% Sockets use the native clib transport and the shared File handle owner.
% [tested: lib_socket:socket_capability_is_declared; commit=781ee98e188c23ea7ef9298636d6e5e6c7fdc727].
metta_platform_capability(socket, library(socket),
                          'lib_socket TCP, UDP and socket readiness').
metta_platform_capability(regex, library(pcre),
                          'lib_regex, so (re-match ...), (re-find ...), \c
                           (re-captures ...), (re-split ...), \c
                           (re-replace ...) and (re-replace-all ...); \c
                           (register-token! ...) for a reader class of your \c
                           own; and importing re_replace as a Prolog \c
                           function. lib_text''s plain string forms still \c
                           work').
%library(unicode) is SWI's ext/utf8proc pack rather than its core, and is absent
%from swipl-wasm, so a build can be complete without it. Nothing else provides
%normalization or the character database: code_type/2 answers the classes and
%string_upper/2 the case conversions, both of which stay.
%library(unix) is SWI's ext/clib pack, absent from swipl-wasm. environ/1 is the
%only name any of this tree's code wants out of it, and it is the only way to
%enumerate the whole environment: getenv/2 answers one variable a caller can
%already name.
metta_platform_capability('environment-listing', library(unix),
                          'lib_system\'s (env-all ...), which lists every \c
                           variable; (env-get ...), (env-set! ...) and \c
                           (env-unset! ...) name one variable each and still work').
%library(sgml) and library(xpath) are SWI's ext/sgml pack, absent from
%swipl-wasm. Nothing else parses XML or HTML here.
metta_platform_capability(markup, [library(sgml), library(sgml_write), library(xpath)],
                          'lib_markup, so (markup-parse-xml ...), \c
                           (markup-parse-html ...), (markup-write ...), \c
                           (markup-select ...), (markup-attribute ...) and \c
                           (markup-text ...); lib_json and lib_yaml still read \c
                           their own formats').
%library(yaml) is SWI's ext/yaml pack over libyaml, absent from swipl-wasm and
%from a build without the C library. Nothing else reads YAML here; lib_json's
%doors read the format a YAML document can always be converted to.
metta_platform_capability(yaml, library(yaml),
                          'lib_yaml, so (yaml-decode ...), (yaml-encode ...), \c
                           (yaml-read! ...) and (yaml-write! ...); lib_json\'s \c
                           own doors still read and write JSON').
metta_platform_capability(unicode, library(unicode),
                          'lib_unicode, so (unicode-normalize ...), \c
                           (unicode-casefold ...), (unicode-map ...), \c
                           (unicode-property ...), (unicode-graphemes ...) and \c
                           the Unicode version; lib_string\'s (string-upper ...), \c
                           (string-lower ...) and (string-chars ...) still work').
metta_platform_capability('compressed-sources', library(zlib),
                          'lib_compression gzip/zlib operations and reading \c
                           or writing a .gz program or space file; \c
                           the same content uncompressed still loads').
% [tested: lib_compression; commit=7b42d5ee5cecb82709617b7ed08dfa2c1441f268].
metta_platform_capability('memory-files', library(memfile),
                          'lib_compression byte encoding through owned memory streams').
metta_platform_capability(archive, library(archive),
                          'lib_compression archive metadata, entry reads and extraction').
% [tested: lib_database; commit=060bea3199e9f504c6d425f60841f229fc96e861].
metta_platform_capability(persistency, [library(persistency),library(shlib)],
                          'lib_database independent journals and owned file locks').
%One capability over two libraries, because engine/filereader.pl imports both
%and the cache is what a user loses when either goes. The row is CONSERVATIVE
%about fastrw and deliberately so: fast_read/2 and fast_write/2 are SWI core
%builtins that library(fastrw) only re-exports, so a build missing fastrw.pl
%alone would still have the machinery [measured 2026-08-28: with the engine
%loaded and autoload off, filereader:fast_read/2 reports
%imported_from(system), and /usr/lib/swi-prolog/library/fastrw.pl defines
%only the /1 wrappers and fast_write_to_string/3]. The engine's load is what
%the census speaks for, and the engine loads both.
%library(json) is SWI's ext/json pack rather than its core, so a build can be
%complete and still not have it; the Windows runner is such a build. The C
%implementation engine/build.sh produces from json_codec.c serves the same
%forms when it is present, which is why this is a capability rather than a
%hard requirement.
metta_platform_capability(json, library(json),
                          'converting between MeTTa atoms and JSON text, \c
                           unless engine/json_codec.so was built from \c
                           json_codec.c, which answers the same forms').
%library(crypto) is not part of swipl-wasm. library(sha) is, and supplies the
%five SHA algorithms byte-for-byte identically, so losing crypto costs only
%secure randomness and the algorithms the SHA library does not implement.
metta_platform_capability(crypto, library(crypto),
                          'cryptographically secure (crypto-random-hex ...), \c
                           and non-SHA algorithms of (crypto-hash ...); \c
                           SHA-1, SHA-224, SHA-256, \c
                           SHA-384 and SHA-512 still work through library(sha)').
%library(redis) is absent from swipl-wasm too. Unlike crypto there is no local
%provider for any part of this library, so its source declares the requirement
%and the import door refuses before consulting it.
metta_platform_capability(redis, library(redis),
                          'lib_redis, so (redis-attach ...), Redis-backed \c
                           shared spaces and cross-process subscriptions').
metta_platform_capability('fast-cache', [library(fastrw), library(memfile)],
                          'saving a space in the fast binary format and \c
                           loading one back; every load reads its source \c
                           and parses it, which is what a load without a \c
                           cache does anyway, so nothing else changes').

%What the boot found missing. Empty on a full platform, which is what makes
%every read below one failing call on a dynamic predicate with no clauses.
:- dynamic metta_platform_absent/1.

%A name a capability would have published and could not. Recorded from the
%import list the load asked for, so it needs no second list to fall out of
%date, and read by the one door a MeTTa program reaches a Prolog predicate
%through: import_prolog_function/2 used to answer "no predicate named
%re_replace is loaded", which is true and says nothing about why.
:- dynamic metta_platform_absent_name/2.

%The load and the census in one act, so the two cannot disagree: what is
%recorded absent is exactly what failed to import. The catch is narrow, on the
%spec it just tried, so a library that IS there and breaks while loading still
%raises and stops the boot, which is the half-present half of the rule.
%
%The import lands in the module being LOADED rather than in this file's,
%because the census now serves engine/parser.pl and engine/filereader.pl too
%and each needs the names where its own calls are [measured 2026-08-28, with
%autoload off so a resolution is an import and not the index answering: a bare
%use_module/1 inside this clause puts pcre in THIS module and the calling
%module reaches it only by inheritance, while Into:use_module/2 puts it in the
%caller's]. Outside a load there is no such module and the engine's own is the
%only sensible target; nothing calls these at run time today.
metta_platform_load(Capability) :-
    metta_platform_load(Capability, except([])).

%except([]) rather than a separate import-everything clause: SWI reads it as
%"every exported name minus none", which is what use_module/1 does [measured
%2026-08-28: re_replace/4, re_match/2 and re_compile/3 all imported]. A narrow
%list belongs to a single-library capability; a capability resting on several
%libraries takes them whole.
metta_platform_load(Capability, Imports) :-
    metta_platform_capability(Capability, Requires, _),
    (   prolog_load_context(module, Into)
    ->  true
    ;   metta_engine_module(Into)
    ),
    forall(metta_platform_spec(Requires, Spec),
           metta_platform_admit(Capability, Into, Spec, Imports)).

%An EMPTY import list asks whether the platform HAS the library, and takes no
%name from it. use_module answers that by compiling and linking the whole
%thing, which is the most expensive way to learn a yes: library(redis) costs
%26,939 inferences to load and 2,804 to look up, and the engine imports
%nothing from it. So the census probes for the presence-only case and loads
%only where a caller named something it needs.
metta_platform_admit(Capability, _, Spec, []) :- !,
    (   exists_source(Spec)
    ->  true
    ;   metta_platform_lost(Capability, [])
    ).
metta_platform_admit(Capability, Into, Spec, Imports) :-
    catch(Into:use_module(Spec, Imports),
          error(existence_error(source_sink, Spec), _),
          metta_platform_lost(Capability, Imports)).

%A row names one library or several. The walk is this file's own rather than
%member/2, because the first census directive runs above this file's
%use_module(library(lists)) and would then need autoload to supply it, which
%is the one thing the NO_AUTOLOAD=1 lane exists to catch; engine/qlf_boot.pl
%carries qlf_member/2 for the same reason.


%A row names one library or several. The walk is this file's own rather than
%member/2, because the first census directive runs above this file's
%use_module(library(lists)) and would then need autoload to supply it, which
%is the one thing the NO_AUTOLOAD=1 lane exists to catch; engine/qlf_boot.pl
%carries qlf_member/2 for the same reason.
metta_platform_spec(Requires, Spec) :-
    (   is_list(Requires)
    ->  metta_platform_member(Requires, Spec)
    ;   Spec = Requires
    ).

metta_platform_member([Spec|_], Spec).
metta_platform_member([_|Rest], Spec) :-
    metta_platform_member(Rest, Spec).

%Idempotent because a reload under make/0 runs the directives again.
metta_platform_lost(Capability) :-
    (   metta_platform_absent(Capability)
    ->  true
    ;   assertz(metta_platform_absent(Capability))
    ).

%except([]) holds no Name/Arity pairs, so a whole-library load records the
%capability and no names, which is right: nothing published them by name.
metta_platform_lost(Capability, Imports) :-
    metta_platform_lost(Capability),
    forall(metta_platform_member(Imports, Name/_),
           (   metta_platform_absent_name(Name, Capability)
           ->  true
           ;   assertz(metta_platform_absent_name(Name, Capability))
           )).

%!  metta_platform(?Capability, ?Status, ?Requires, ?Costs) is nondet.
%
%   The census a host reads: every capability, whether this build has it, the
%   platform library it rests on, and what its absence costs. Enumerable, so a
%   host asks for the whole set in one call, and unifiable, so
%   metta_platform(C, absent, R, Costs) is exactly the loss list a binding
%   used to recover from the boot transcript.
metta_platform(Capability, Status, Requires, Costs) :-
    metta_platform_capability(Capability, Requires, Costs),
    (   metta_platform_absent(Capability)
    ->  Status = absent
    ;   Status = present
    ).

%What a form that cannot work without a capability calls before it tries.
%Form is the MeTTa spelling or the source the user wrote, because that is the
%only part of the failure they can act on.
metta_require_platform(Form, Capability) :-
    (   metta_platform_absent(Capability)
    ->  metta_platform_capability(Capability, Requires, Costs),
        throw(error(metta_platform_required(Form, Capability, Requires, Costs),
                    none))
    ;   true
    ).

:- multifile prolog:error_message//1.
prolog:error_message(metta_platform_required(Form, Capability, Requires,
                                             Costs)) -->
    [ '~w is refused: this build does not have the ~w capability, because ~w \c
       is absent. What that costs: ~w.'-[Form, Capability, Requires, Costs] ].

%library(thread), for concurrent_and/3 under (hyperpose ...).
:- metta_platform_load(concurrency).
%library(time), for call_with_time_limit/2, which metta_timeout/3 wraps around
%a findall so a bounded goal keeps every answer; engine/metta/runtime.pl's own
%block records why raw alarm/4 was rejected there.
:- metta_platform_load(deadlines).
%wrap_predicate/4, for making the pragma bound free when no bound is set.
:- use_module(library(prolog_wrap)).
%AND its own deferred import, resolved here rather than wherever the engine
%first happens to need it. prolog_wrap declares `:- autoload(library(lists),
%[member/2])` and current_predicate_wrapper/4 is the only body that calls
%member/2, reached only once a predicate actually HAS a wrapper
%[source: SWI-Prolog 10.1.13 library/prolog_wrap.pl, its autoload directive
%and current_predicate_wrapper/4]. So the resolution lands wherever the first such
%query lands, and in this engine that is inside SWI's own assertz, re-entered
%from `sig_atomic(with_mutex(metta_deferred_translation, ...))` while a
%deferred function compiles. There it raises
%`existence_error(procedure, prolog_wrap:member/2)`, and every later
%derivation in the process raises the same thing: 29 tests in one file
%[measured 2026-09-07: `-p randomly --randomly-seed=3222813221
%tests/ch14_seeing_your_program` answers 29 failed, 347 passed, and touching
%prolog_wrap:member/2 once from the top level beforehand answers 376 passed].
%Why SWI declined that one resolution was established on 2026-09-11: the
%inference-limited derivation before it cut the resolution itself, and SWI's
%trap installs the undefined supervisor on a predicate whose resolution
%query raised (engine/metta/limits.pl; docs/host-workarounds.md,
%swi-autoload-cut-installs-the-undefined-supervisor). That file finishes a
%cut resolution now, so the lazy path is safe; this import stays because it
%is the cheaper resolution of a predicate every boot reaches, the same
%reasoning as the library(option) and library(gensym) blocks below, and the
%same policy the rest of this section holds, which is that nothing the
%engine needs resolves lazily.
%Only member/2, not pairs_keys/2: that one is reached from
%predicate_property/2's `wrapped(List)` property, which nothing here asks for,
%and resolving it would load library(pairs) at every boot for nothing.
%import/1 rather than a wrap-and-unwrap round trip that exercises the real
%path: the round trip resolves the same import and costs 27,606 boot
%inferences doing it, where this costs 12
%[measured 2026-09-07: engine/bench.py --counter-only boot, three identical
%samples per tree; 249,726 with this line removed, 277,329 with the round trip
%in its place and 249,738 with this one, against 249,723 on an unchanged
%worktree of the same commit].
%library(lists) is already loaded above, so this is a module-table import and
%not a file load.
:- ignore(catch(prolog_wrap:import(lists:member/2), _, true)).
%library(thread) does not declare its own dependency on option/2, and nothing
%else loaded here pulls library(option) in, so jobs/2 resolved it by autoload
%on the first concurrent_and/3 call [verified 2026-08-15: swi_option is absent
%until something touches option/2]. Loading it up front keeps lazy loading off
%the concurrent path. An `Unknown procedure: thread:option/2` was reported once
%under concurrent hyperpose; a race was NOT reproduced in 12 runs of 24 workers
%entering concurrent_and/2 on a barrier, so treat this as cheap hardening and
%not as a diagnosed fix.
:- use_module(library(option)).
:- use_module(library(lists)).
:- use_module(library(yall), except([(/)/3])).
:- use_module(source_loading, [loading_loudly/1]).
:- use_module(library(apply)).
:- use_module(library(apply_macros)).
%next_lambda_name/1 (translator.pl) calls gensym/2 to name every compiled
%closure: '|->' itself and, through collection_closure/3, every inline body
%argument of foldl-atom, map-atom and filter-atom. Nothing else loaded here
%pulls library(gensym) in, so today it resolves by autoload on the first
%such compile. With autoload=false that call raises
%existence_error(procedure,gensym/2) from inside the engine's own prelude
%(the prelude's type-cast-holds is the one form of that vocabulary that uses
%foldl-atom with an inline body), and SWI's OWN initialization-error
%reporting then masks that primary error: building a source-location
%diagnostic for it calls into library(prolog_clause)'s
%inlined_unification/7, which has its own undeclared, autoload-only
%dependency on nth1/3, so THAT is the only message that ends up printed.
%The visible symptom is "Unknown procedure: prolog_clause:nth1/3" from
%deep inside SWI's shipped library; the actual missing dependency is this
%one, in the engine's own source, and fixing it here removes the secondary
%failure too because the primary error it was papering over never occurs.
:- use_module(library(gensym)).
%library(process). Nothing in the engine calls into it; lib/lib_gitimport/lib_gitimport.pl
%does, and it loads later in this file, so the census row has to be decided
%here where the rest of the platform's is.
:- metta_platform_load(subprocess).
%library(crypto) and library(redis). Neither publishes names into the engine's
%module at boot; these empty imports only decide their census rows. Their own
%libraries import what they use into the space module that loads them.
%Redis is probed here because NOTHING else in the engine mentions it, so
%without this the census could not answer for a capability it declares until
%lib_redis happened to load. Crypto needs no probe of its own: engine/
%filereader.pl asks for crypto_data_hash/3 by name, which records the same
%status, and every reader of that status runs after it - the two digest
%providers in that file and lib_crypto on import. Probing it twice cost 697
%inferences at every boot for an answer already established
%[tested: platform_capabilities_reduced:sha_hashing_survives_without_crypto,
%platform_capabilities_reduced:crypto_only_operations_refuse_by_name_without_crypto,
%both on a genuinely reduced build; commit=96c4df52838ef5ee3a19af4bbe99a28f73445c46].
:- metta_platform_load(redis, []).
%library(pcre), the HOST TIER re-export the block above this file's imports
%describes: re_replace/4 and nothing else, so a MeTTa program's
%(import_prolog_function re_replace) finds a predicate. The import list is
%what makes the absence say so by name -- metta_platform_lost/2 records
%re_replace against the regex capability, and refuse_absent_prolog_function/1
%reads that instead of answering "no predicate named re_replace is loaded"
%[tested: platform_capabilities:a_re_export_lost_with_its_capability_refuses_by_name].
:- metta_platform_load(regex, [re_replace/4]).
%pcre.pl declares four local :- autoload/2 lines (apply, error, dcg/basics,
%lists) but reads its own Options list with option/2 (library(option))
%without declaring THAT one, so it too resolves by global autoload today
%[measured 2026-08-18: examples/ch08-data/08-03-the-shipped-libraries/04-regex_lib.metta under
%NO_AUTOLOAD=1, existence_error(procedure,pcre:option/2)]. Same trap as
%ugraphs.pl and clpb.pl (lib/lib_constraints/lib_constraints.pl has both), same
%fix. It sat in engine/filereader.pl beside a pcre import that file never
%called into; the patch belongs with the load that actually brings pcre in,
%and it is conditional because on a build without pcre there is no such module
%to patch and naming one would create an empty module of that name.
:- (   metta_platform(regex, present, _, _)
   ->  pcre:use_module(library(option), [option/2])
   ;   true
   ).

%Which module the ENGINE's own predicates live in, asked of SWI at load time
%rather than written down. Two different jobs were both spelled `user` and
%only one of them is about the engine:
%
%  - `user` is the HOST module. SWI resolves file_search_path/2 and
%    thread_message_hook/3 there, consult/1 puts a consulted file there, and
%    janus resolves goal text there [source: SWI-Prolog 10.1 Reference
%    Manual, section 6.11 and its footnote "Unfortunately some hooks are
%    traditionally defined in the user module"]. Those sites go on naming
%    `user`, because that is the name of the thing they mean.
%  - THIS is where the engine's own clauses are, which is wherever this file
%    was consulted. Every wrap_predicate/4 target and every clause/2 read of
%    the engine's own compilation tables follows it.
%
%The two answers COINCIDED until the module declaration at the top of this
%file, and every site that had to tell them apart was already written this way
%when they stopped: the answer is `metta_engine` now and `user` means only the
%host. It stays asked rather than written because reading it is what makes the
%distinction checkable -- a site that means the engine and one that means the
%host are two different reads, and only one of them moved
%[tested: metta_engine_module].
:- dynamic metta_engine_module/1.
:- prolog_load_context(module, EngineModule),
   (   metta_engine_module(EngineModule) -> true
   ;   assertz(metta_engine_module(EngineModule))
   ).

%The module the base tier compiles into, written ONCE and read everywhere:
%current_metta_module/1's default, reduce/3's dispatch, fun_here_in/2's shared
%tier and the type family's &self clause all ask for it.
%
%Declared here, before the files that read it are compiled, so the expansion
%below applies to them. spaces.pl owns the mapping this is the '&self' case of
%and asserts the same answer into its cache; the plunit test named below is
%what keeps the two from drifting
%[tested: spaces_execution_modules:the_written_self_module_is_the_mapped_one].
metta_self_module('$metta_exec:&self').

%And the prefix atomic-name mappings are built from, written once for the same
%reason and read the same way. space_module/2 uses it for atomic spaces;
%parametric spaces use their separately prefixed canonical term encoding.
metta_exec_module_prefix('$metta_exec:').

%!  metta_engine_operator(+Name) is semidet.
%
%   Read the engine's operator table explicitly. The unqualified current_op/3
%   spelling reads user and misses operators imported only into metta_engine.
%   Registration, reduction and callable_as_written/2 share this guard.
%   [tested: engine_modules:an_operator_lent_name_is_seen_in_the_engines_own_namespace;
%   commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
metta_engine_operator(Name) :- current_op(_, _, metta_engine:Name).

%And read for FREE. A one-clause fact still costs an inference per call, and
%these are the hottest paths in the engine: reduce/3 reads it on every
%dispatch and current_metta_module/1 on every compile and every runnable form.
%goal_expansion/2 replaces the call with the unification it performs, which
%SWI folds into the clause, so the name stays written in one place and the
%read costs nothing [measured 2026-08-19: annotated-relation 483,019 -> 479,523
%inferences, back to its pre-Phase-11 baseline; py-method-call
%1,696,849,495 -> 1,657,043,976 instructions:u].
%
%A unification rather than `true` with the argument bound at expansion time,
%because most callers use this as a TEST on a module they already hold
%(`metta_self_module(Module), !` selects the &self clause of the type family)
%and binding their variable at compile time would make every module answer
%yes.
goal_expansion(metta_self_module(Module), Module = '$metta_exec:&self').
goal_expansion(metta_exec_module_prefix(Prefix), Prefix = '$metta_exec:').
% Fold the operator guard at its call sites to avoid a predicate call per
% registered-predicate reduction. Keep metta_engine_operator/1 for other callers.
% [tested: prolog_interface:a_registered_predicate_costs_no_more_than_a_metta_function;
% commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
goal_expansion(metta_engine_operator(Name), current_op(_, _, metta_engine:Name)).

%The seam module loads FIRST and with an EMPTY import list. First because
%every file below declares or asks a seam; empty because `seam:` is the whole
%point of it. Importing the handler seams here would put atom_added/2,
%foreign_match/3 and forty-odd others back in the engine's own namespace,
%where an extension could reach them unqualified again and where each one is a
%name a MeTTa program can no longer have.
:- use_module(ext_points, []).

%%%% The core registries a subsystem WRITES %%%%
%
%A base module makes a name VISIBLE to a subsystem; it does not make a write
%land on it. assertz/1 or retractall/1 in a module that can only SEE a
%predicate creates a predicate of that name in the WRITING module and the
%write goes there, silently, where nothing reads it. Measured on this tree:
%engine/spaces.pl's retractall(fun(F)) and engine/specializer.pl's
%retractall(arity(Name, _)) each made a second, private registry the moment
%their files declared modules, and removing every clause of a function then
%left the function REGISTERED, so a call to it compiled as a call and raised
%existence_error(procedure, '$metta_exec:&self':f/2) where the language says
%the term is simply unreduced [measured 2026-08-22, on
%examples/ch05-equations-and-evaluation/05-02-changing-the-equations/02-functionremoval.metta].
%
%So the four registries a subsystem writes are IMPORTED into every subsystem
%module rather than inherited, which is what makes a write land on the one
%predicate. The list is short on purpose: it is the coupling P11.7 exists to
%make visible, and the layering lane fails on any OTHER name held by two
%engine modules at once, so a fifth cannot arrive quietly
%[tested: engine_layering:test_the_engine_layering_contract_holds_and_a_violation_is_named].
metta_shared_registry(fun/1).
metta_shared_registry(arity/2).
metta_shared_registry(metta_shape_fact/4).
metta_shared_registry(metta_shape_declared/2).
%engine/spaces.pl clears a space's import bookkeeping with the space, and pins
%the restricted dispatch names; both tables are the core's.
metta_shared_registry(import_life/3).
metta_shared_registry(fun_scoped/1).

:- dynamic fun/1, arity/2, metta_shape_fact/4, metta_shape_declared/2,
            import_life/3, fun_scoped/1.
:- forall(metta_shared_registry(Registry), export(Registry)).

%!  metta_import_shared_registries is det.
%
%   Import the four into the CALLING module. A subsystem that writes one calls
%   this from a directive of its own, which is where the coupling is visible;
%   the import has to happen while that file is loading, because a write
%   compiled before it would already have made the subsystem a predicate of
%   its own and import/1 then refuses with a name clash.
metta_import_shared_registries(Subsystem) :-
    metta_engine_module(Engine),
    forall(metta_shared_registry(Registry),
           Subsystem:import(Engine:Registry)).

%WHERE THE ENGINE'S OWN SOURCE LIVES, recorded before any unit loads because
%a unit CANNOT compute it. prolog_load_context(directory, D) answers the
%directory of the file being loaded, and a unit consulted into an umbrella has
%its directives stored in the UMBRELLA's .qlf, so the same directive in
%engine/translator/runtime.pl answered engine/translator/ on a source boot and
%engine/ once translator.qlf served it. That is how the C branch-return
%analyzer came to be looked for at engine/translator/mbr.so, found missing, and
%silently replaced by the Prolog pass on every cold tree, which made its
%differential suite skip rather than fail [measured 2026-08-31: metta_c_mbr_active
%false and metta_mbr_artifact naming engine/translator/mbr.so on a purged tree,
%true and naming engine/mbr.so after one boot warmed the .qlf set;
%tested: tests/prolog/static_checks.pl, no_unit_computes_its_own_directory;
%commit=c530ccb8fb7d0a5b2aa53df6e9f981ada9f81be8]. That check refuses the shape for every unit below this
%directory and self-tests against a planted occurrence, so a clean result is
%not a vacuous one.
%
%This file is the umbrella, so ITS load context is engine/ in both modes, and
%that is the whole reason the fact is asserted here rather than beside each
%consumer. engine/translator.pl, an umbrella in engine/ that the Python shim
%loads without this file, records it the same way; engine/spaces.pl does not,
%because no load reaches it without this file. The guard keeps a fact already
%recorded, which is also what lets an embedded engine name its own tree.
:- dynamic metta_engine_src_dir/1.
:- prolog_load_context(directory, Dir),
   (   metta_engine_src_dir(_) -> true
   ;   assertz(metta_engine_src_dir(Dir))
   ).

:- consult('metta/algebra_operations.pl').
:- consult('metta/algebra_formula.pl').
:- consult('metta/algebra_polynomial.pl').
:- consult('metta/algebra_fixpoint.pl').
:- ensure_loaded([atom_index, parser, type_rules, translator, translator_rules,
                  support_graph, specializer, materialize, filereader,
                  '../lib/lib_gitimport/lib_gitimport', spaces, tracer,
                  duals, kernel, '../lib/lib_memo/lib_memo',
                  '../lib/minimal_metta_lib/minimal_metta_lib']).


% The host imports this facade. Re-export subsystem operations used by host
% clauses, query strings and generated goals, keeping implementation ownership
% in each subsystem. Declared services are checked even without static callers.
% [tested: engine_modules:every_declared_service_is_exported_to_the_host,
% engine_modules:the_service_census_sees_a_declared_private_predicate; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]

% Temporary indexes retain original term values under their caller's trail.
% [tested: atom_index; commit=dfd348d37d4cbe3d42d877bd6dcf415b54f82179].
metta_engine_reexport(atom_index, metta_atom_index_new/1).
metta_engine_reexport(atom_index, metta_atom_index_bind/4).
metta_engine_reexport(atom_index, metta_atom_index_get/3).

%engine/filereader.pl: reading and running a MeTTa source: the loader's own doors,
%which every seat's `run this text` crossing lands on.
% silent/1 remains filereader's single shared flag through this re-export.
% [source: engine/filereader.pl:metta_host_set_silent/1; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
metta_engine_reexport(filereader, metta_host_fast_header/1).
metta_engine_reexport(filereader, metta_static_import_image/2).
metta_engine_reexport(filereader, metta_restore_static_import/3).
metta_engine_reexport(filereader, active_source_program/1).
metta_engine_reexport(filereader, recompile_function_impl/1).
metta_engine_reexport(filereader, recompile_function_impl_in/2).
metta_engine_reexport(filereader, run_with_loading_marker/2).
metta_engine_reexport(filereader, silent/1).
metta_engine_reexport(filereader, load_metta_file/2).
metta_engine_reexport(filereader, load_metta_source_groups/3).
metta_engine_reexport(filereader, metta_answer_term/2).
metta_engine_reexport(filereader, metta_host_digest/2).
metta_engine_reexport(filereader, metta_host_load_fast/2).
metta_engine_reexport(filereader, metta_host_load_file/3).
metta_engine_reexport(filereader, metta_host_read_forms/2).
metta_engine_reexport(filereader, metta_host_run_source/4).
metta_engine_reexport(filereader, metta_host_run_source_status/3).
metta_engine_reexport(filereader, metta_host_save_fast/3).
metta_engine_reexport(filereader, metta_host_source_atoms/2).
metta_engine_reexport(filereader, metta_host_program_source/2).
metta_engine_reexport(filereader, metta_host_set_silent/1).
metta_engine_reexport(filereader, metta_host_substitute/3).
metta_engine_reexport(filereader, parse_metta_source/2).
metta_engine_reexport(filereader, parsed_form_parts/4).
metta_engine_reexport(filereader, process_metta_string/2).
metta_engine_reexport(filereader, process_metta_string/3).

%engine/parser.pl: the reader and the writer, which a seat needs because a
%backend's atoms cross an FFI boundary as bytes and a host prints answers.
% The host binding registers its listeners through the engine's one door.
metta_engine_reexport(host_listeners, metta_listen/2).
metta_engine_reexport(parser, metta_reader_token_class/3).
metta_engine_reexport(parser, metta_host_register_reader_token/2).
metta_engine_reexport(parser, metta_host_unregister_reader_token/1).
metta_engine_reexport(parser, metta_name_pairs/2).
metta_engine_reexport(parser, metta_reader_token_source/2).
metta_engine_reexport(parser, metta_symbol_writable/1).
metta_engine_reexport(parser, metta_token_boundary/2).
metta_engine_reexport(parser, metta_unwritable_symbol/2).
metta_engine_reexport(parser, sdisplay/2).
metta_engine_reexport(parser, sdisplay_with_names/3).
metta_engine_reexport(parser, sread/2).
metta_engine_reexport(parser, sread_command/2).
metta_engine_reexport(parser, sread_with_names/3).
metta_engine_reexport(parser, swrite/2).
metta_engine_reexport(parser, swrite_with_names/3).

%engine/spaces.pl: the space surface: the atom doors, the matcher, the module
%mapping and the lifecycle a host drives.
metta_engine_reexport(spaces, metta_effect_class_canonical/2).
metta_engine_reexport(spaces, watch_catalog_rows/1).
metta_engine_reexport(spaces, unwatch_catalog_rows/1).
metta_engine_reexport(spaces, metta_vocabulary_values/2).
metta_engine_reexport(spaces, 'add-atom'/3).
metta_engine_reexport(spaces, 'add-atom'/4).
metta_engine_reexport(spaces, 'remove-atom'/3).
metta_engine_reexport(spaces, 'subtract-atom'/3).
metta_engine_reexport(spaces, add_sexp/2).
metta_engine_reexport(spaces, clear_native_atoms/1).
metta_engine_reexport(spaces, ensure_native_storage_module/2).
metta_engine_reexport(spaces, function_still_defined/1).
metta_engine_reexport(spaces, get_native_atom/2).
metta_engine_reexport(spaces, match/4).
metta_engine_reexport(spaces, match_foreign/5).
metta_engine_reexport(spaces, match_stored/4).
metta_engine_reexport(spaces, metta_add_atom/3).
metta_engine_reexport(spaces, metta_add_atoms/2).
metta_engine_reexport(spaces, metta_add_program_atoms/2).
metta_engine_reexport(spaces, metta_assert_space_releasable/1).
metta_engine_reexport(spaces, metta_catalog_row/1).
metta_engine_reexport(spaces, metta_claim_space/2).
metta_engine_reexport(spaces, metta_clear_space_for_release/1).
metta_engine_reexport(spaces, metta_declare_parametric_space/1).
metta_engine_reexport(spaces, metta_declare_restricted_space/2).
metta_engine_reexport(spaces, metta_declare_space_equation_home/2).
metta_engine_reexport(spaces, metta_declare_space_parent/2).
metta_engine_reexport(spaces, metta_disclaim_space/2).
metta_engine_reexport(spaces, metta_ensure_compiled/1).
metta_engine_reexport(spaces, metta_forget_derived/0).
metta_engine_reexport(spaces, metta_host_clear_defined/1).
metta_engine_reexport(spaces, metta_host_clear_space/1).
metta_engine_reexport(spaces, metta_host_explain_match/3).
metta_engine_reexport(spaces, metta_host_native_fact/4).
metta_engine_reexport(spaces, metta_host_remove_reported/3).
metta_engine_reexport(spaces, metta_host_space_capability_error/4).
metta_engine_reexport(spaces, metta_host_stored/2).
metta_engine_reexport(spaces, metta_module_space/2).
metta_engine_reexport(spaces, metta_ordered_match_limit/6).
metta_engine_reexport(spaces, metta_release_space/1).
metta_engine_reexport(spaces, metta_release_space/2).
% The owned-record host services declared in engine/ext_points.pl: a host reads
% them through query strings, so a declared service is published whether or not
% a Prolog clause reaches it [tested: engine_modules:every_declared_service_is_exported_to_the_host].
metta_engine_reexport(spaces, metta_native_pair/4).
metta_engine_reexport(spaces, metta_owned_clause/2).
metta_engine_reexport(spaces, metta_owned_record_occurrences/3).
metta_engine_reexport(spaces, metta_remove_atom/3).
metta_engine_reexport(spaces, metta_require_algebra_value/3).
metta_engine_reexport(spaces, metta_require_foreign_capability/2).
metta_engine_reexport(spaces, metta_seq_query_plan/2).
metta_engine_reexport(spaces, metta_space_name/1).
metta_engine_reexport(spaces, metta_space_names/1).
metta_engine_reexport(spaces, metta_space_registered/1).
metta_engine_reexport(spaces, metta_vocabulary_value/2).
metta_engine_reexport(spaces, native_storage_module/2).
metta_engine_reexport(spaces, remove_equation/6).
metta_engine_reexport(spaces, remove_sexp/2).
metta_engine_reexport(spaces, space_module/2).
metta_engine_reexport(spaces, unstore_atom/3).

%engine/support_graph.pl: forgetting what a withdrawn source supported.
metta_engine_reexport(support_graph, support_record/2).
metta_engine_reexport(support_graph, support_memo_take_change/2).
metta_engine_reexport(support_graph, support_memo_sccs/2).
metta_engine_reexport(support_graph, support_forget/1).
metta_engine_reexport(support_graph, support_forget_module/1).

%engine/tracer.pl: the trace and debug session doors a host opens around its own work.
metta_engine_reexport(tracer, metta_debug_run/3).
metta_engine_reexport(tracer, metta_debug_begin/2).
metta_engine_reexport(tracer, metta_debug_end/0).
metta_engine_reexport(tracer, metta_trace_begin/3).
metta_engine_reexport(tracer, metta_trace_end/0).
metta_engine_reexport(tracer, metta_trace_harvest/2).
metta_engine_reexport(tracer, metta_trace_source/5).
metta_engine_reexport(tracer, metta_trace_start_clock/0).

%engine/translator.pl: compiling a form, and the dispatch metadata a seat reads back.
metta_engine_reexport(translator, clear_fun_meta/2).
metta_engine_reexport(translator, clear_translation_cache/0).
metta_engine_reexport(translator, compiled_function_name/2).
metta_engine_reexport(translator, drop_fun_meta/4).
metta_engine_reexport(translator, eval_metta_in_module/3).
metta_engine_reexport(translator, lift_pattern_modifiers/4).
metta_engine_reexport(translator, metta_host_dispatch_proof_step/6).
metta_engine_reexport(translator, metta_reducible_head/2).
metta_engine_reexport(translator, metta_special_form_head/1).
metta_engine_reexport(translator, reduce/2).
metta_engine_reexport(translator, reduce/3).
metta_engine_reexport(translator, translate_cached_expr/3).
metta_engine_reexport(translator, translate_clause/2).
metta_engine_reexport(translator, translate_clause/3).
metta_engine_reexport(translator, translate_expr/3).
metta_engine_reexport(translator, translate_runnable_expr/3).
metta_engine_reexport(translator, translate_tracked_clause/2).

%engine/translator_rules.pl: the rule registry's own MeTTa spellings.
metta_engine_reexport(translator_rules, 'add-translator-rule!'/3).
metta_engine_reexport(translator_rules, 'remove-translator-rule!'/2).
metta_engine_reexport(translator_rules, translator_rule/1).
metta_engine_reexport(translator_rules, translator_rule_extra_variables_exempt/2).

%engine/type_rules.pl: the typing-rule registry's MeTTa spellings and its readback.
metta_engine_reexport(type_rules, 'add-typing-rule!'/6).
metta_engine_reexport(type_rules, 'remove-typing-rule!'/2).
metta_engine_reexport(type_rules, registered_typing_rule/7).

%The rows the walk could not see, for the same reason as the core's own
%computed-goal block above: a suite that assembles the goal. Found by
%running the battery against the measured list and reading the existence
%errors [tested: sh engine/test.sh; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720].
metta_engine_reexport(duals, metta_dual_goal/2).
metta_engine_reexport(filereader, load_imported_metta_file/3).
metta_engine_reexport(kernel, 'has-declared-type'/3).
metta_engine_reexport(kernel, 'space-contains'/3).
metta_engine_reexport(parser, swrite_pretty/2).
metta_engine_reexport(spaces, 'get-atoms'/2).
metta_engine_reexport(spaces, 'owned-record-read'/2).
metta_engine_reexport(spaces, add_sexp/3).
metta_engine_reexport(spaces, add_sexp/4).
metta_engine_reexport(spaces, metta_add_atom/4).
metta_engine_reexport(spaces, metta_add_program_atoms/4).
metta_engine_reexport(spaces, metta_actor/1).
metta_engine_reexport(spaces, metta_token_order/3).
metta_engine_reexport(spaces, metta_token_parts/3).
metta_engine_reexport(spaces, metta_token_portable/2).
metta_engine_reexport(spaces, metta_token_receive/2).
metta_engine_reexport(spaces, metta_generation_receive/1).
metta_engine_reexport(spaces, metta_storage_term/4).
metta_engine_reexport(spaces, metta_host_blame/3).
metta_engine_reexport(spaces, foreign_provides/2).
metta_engine_reexport(spaces, foreign_pushdown_class/3).
metta_engine_reexport(spaces, metta_capacity_count/2).
metta_engine_reexport(spaces, metta_exec_module_generation/2).
metta_engine_reexport(spaces, metta_exec_module_known/2).
metta_engine_reexport(spaces, metta_exec_module_parent/2).
metta_engine_reexport(spaces, metta_match_atoms/2).
metta_engine_reexport(spaces, metta_policy_members/3).
metta_engine_reexport(spaces, metta_space_claim/2).
metta_engine_reexport(spaces, metta_space_operand/1).
metta_engine_reexport(spaces, native_atom_clause/4).
metta_engine_reexport(spaces, native_storage_module_cache/2).
metta_engine_reexport(spaces, native_storage_module_ready/2).
metta_engine_reexport(spaces, space_atom_count/2).
metta_engine_reexport(spaces, space_operation_capability/2).
metta_engine_reexport(spaces, space_parametric/1).
metta_engine_reexport(spaces, space_parent/2).
metta_engine_reexport(spaces, space_restricted/2).
metta_engine_reexport(specializer, ho_specialization/3).
metta_engine_reexport(specializer, maybe_specialize_call/4).
metta_engine_reexport(support_graph, support_invalidate/1).
metta_engine_reexport(support_graph, support_invalidate_many/1).
metta_engine_reexport(support_graph, supports/2).
metta_engine_reexport(translator, constrain_args/3).
metta_engine_reexport(translator, fun_meta_clauses/3).
metta_engine_reexport(translator, fun_meta_module/3).
metta_engine_reexport(translator, head_pattern_note/5).
metta_engine_reexport(translator, maybe_print_compiled_clause/3).
metta_engine_reexport(translator, metta_special_form/1).
metta_engine_reexport(translator, metta_translated_head/1).
metta_engine_reexport(translator, symbol_head/2).
metta_engine_reexport(translator_rules, 'add-translator-rule!'/2).
metta_engine_reexport(translator_rules, protected_core_head/1).
metta_engine_reexport(translator_rules, translator_rule/3).
metta_engine_reexport(translator_rules, translator_rule_snapshot/3).
metta_engine_reexport(type_rules, raw_registered_typing_rule/7).
metta_engine_reexport(type_rules, typing_rule_accepts/4).
metta_engine_reexport(type_rules, typing_rule_expected/3).
metta_engine_reexport(type_rules, typing_rule_refusal/6).
metta_engine_reexport(filereader, translated_from/2).
metta_engine_reexport(kernel, 'space-atom-count'/2).
metta_engine_reexport(spaces, match_foreign/4).
metta_engine_reexport(spaces, native_storage_functor/2).
metta_engine_reexport(spaces, protect_metta_exec_modules/0).
metta_engine_reexport(spaces, refuse_autoload_into_exec_modules/0).
metta_engine_reexport(spaces, stored_atom_of_ref/4).
metta_engine_reexport(translator_rules, restore_translator_rule_snapshot/3).
metta_engine_reexport(translator_rules, translator_rule_home/2).
metta_engine_reexport(translator_rules, translator_rule_override/2).
metta_engine_reexport(translator_rules, translator_rule_refusal/3).
metta_engine_reexport(translator_rules, translator_rule_current/3).

%engine/metta.pl's ensure_loaded/1 list carries three shipped libraries, so
%their exports arrive here rather than in `user` and the host tier reaches
%them through this table like any subsystem's.
metta_engine_reexport(lib_memo, memo_size_limit/1).
metta_engine_reexport(lib_memo, memo_answer_limit/1).
metta_engine_reexport(lib_memo, memo_aggregate_mode/1).
metta_engine_reexport(lib_memo, memo_function_removed/1).
metta_engine_reexport(lib_memo, memo_dispatch_call/4).
metta_engine_reexport(lib_memo, memo_withdraw_removed_definition/2).
metta_engine_reexport(lib_memo, metta_memo_total_bytes/1).
metta_engine_reexport(parser, 'register-token!'/3).
metta_engine_reexport(spaces, clear_foreign_atoms/1).

:- forall(metta_engine_reexport(_, PredicateIndicator), export(PredicateIndicator)).

%The prelude tier is LOADED WITHOUT IMPORTING, which is the whole difference
%between it and the list above. Its heads include union/3 and intersection/3,
%which this module already imports from library(lists), so importing the tier's
%would be refused; and importing them is not what makes them reachable anyway.
%A space's execution module resolves through this module's base chain with the
%tier spliced in below it, so every space sees MeTTa's union and this module
%goes on seeing the list one [source: engine/spaces/lifecycle.pl,
%metta_exec_module_base/2].
:- use_module(prelude, []).

% Shipped subsystems declare metta_engine as their base before compilation.
% This census also bases subsystems a harness loaded before the engine.
% Their unqualified calls resolve through the core's published exports.
% [source: engine/metta.pl:metta_base_engine_subsystems/1; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]


%A predicate rather than the bare directive it used to be, because a
%subsystem that is NOT loaded at boot still has to inherit the same base when
%something later asks for it. metta_ensure_source_observation/0 below is the
%one such caller today.
metta_base_engine_subsystems(EngineSource) :-
    atom_concat(EngineSource, '/', EngineDirectory),
    metta_engine_module(Engine),
    forall(( source_file(SubsystemFile),
             sub_atom(SubsystemFile, 0, _, _, EngineDirectory),
             module_property(Subsystem, file(SubsystemFile)),
             Subsystem \== Engine ),
           set_module(Subsystem:base(Engine))).

:- prolog_load_context(directory, EngineSource),
   metta_base_engine_subsystems(EngineSource).

%engine/source_observation.pl is deliberately NOT in the load list above.
%Nothing an ordinary program does needs it: the engine announces a constructed
%Error through metta_record_error/1 (engine/metta/terms.pl), whose sink lives
%in the observation buffer, so no engine clause names a predicate of that
%file. Loading it at boot cost 3,696 inferences, and the
%prolog:prolog_exception_hook/5 clause it left resident cost another 119 on
%the engine's translate case and 2 on every compiled host request, which is
%3,998 across foreign-match's 2,000 runs [measured 2026-09-05: boot 536,337
%against 532,641, translate 362,516 against 362,397, evaluate 558,643 against
%558,636, foreign-match 788,827 against 784,829; command=engine/bench.py and
%extensions/python/bench.py --counter-only; three identical samples per arm
%with the .qlf set cleared and warmed for each; commit=b96e1a15260b7538a8e42be613bcc5dd0dddd136].
%
%So whoever wants an observation loads it, through here. The pass above is
%re-run because a module loaded after that directive would otherwise keep
%SWI's default base of `user`, and this one resolves metta_engine_module/1 and
%current_metta_module/1 through the engine.
%
%What the asker pays: 20,818 inferences on the first call in a process whose
%boot governs artifacts and 1 on every call after it, against 67,349 for the
%first small observation itself and 59,624 for the next; the one process that
%writes engine/source_observation.qlf pays 105,493, where consulting the
%source cost 94,661 in every process before the unit loaded through
%metta_load_source/2 [measured 2026-09-09; command=statistics(inferences)
%either side of this predicate, one swipl per arm that consulted
%engine/qlf_boot.pl and engine/metta.pl; the observation costs measured
%2026-09-05 the same way on two source_observation:observe_source/4 calls on
%`(= (o $x) (+ $x 2)) !(o 3)`; commit=f26de01fbf3e0e3c64bb691c66a59fa959fee7f3]. Until 2026-09-09 this door
%consulted the source by its .pl path, and the reading that qcompile(auto)
%"reaches the files a loaded file loads and not the file the goal names" was
%SWI's rule seen from that spec: a spec that names its extension compiles from
%source whatever option travels with it, and only a bare stem reaches the
%artifact rule, which is what metta_load_source/2 hands it.
metta_ensure_source_observation :-
    (   current_predicate(source_observation:observe_source/4)
    ->  true
    ;   metta_engine_src_dir(EngineSource),
        atomic_list_concat([EngineSource, '/source_observation.pl'], File),
        metta_load_source(File, [if(not_loaded), imports([])]),
        metta_base_engine_subsystems(EngineSource)
    ).


%%%% Extensions: the control file, its vocabulary, and the loader %%%%
%
%A seat is a folder under extensions/ carrying an extension.pl, a
%control file of FACTS the engine READS and never consults -- PostgreSQL's
%control-file model, which this codebase already follows for runtime imports
%(engine/metta/interop.pl reads a source's manifest without running it and says
%so in those words). Each seat used to carry a decider.pl instead, twelve lines
%of imperative Prolog whose whole body was one hand-rolled needs check; the
%checks are the engine's now, so a refusal is named uniformly, an unmet
%prerequisite is a queryable record rather than a silent `; true` branch, and
%`metta list` can answer without loading anything.
%
%The vocabulary, validated at read time -- a fact outside it refuses loudly
%naming the file and the term, because a control file that can smuggle a
%directive is a script with extra steps:
%
%   title(Atom)              what this seat is, one line
%   needs(artefact(Rel))     a build product, relative to the seat's folder
%   needs(prolog_library(L)) exists_source(library(L))
%   needs(predicate(N/A))    current_predicate(N/A): a host marker the way the
%                            C seat registers '$cmetta_present'/0 before it
%                            consults the engine, or a platform door the way
%                            the WASM build lacks open_shared_object/3
%   needs(extension(Other))  that seat loaded first
%   entry(engine, Rel)       the engine consults it here, at boot
%   entry(host, Rel)         the seat's own runtime consults it; recorded so
%                            tooling can derive the transport list, loaded by
%                            the host and never by this glob
%
%Every need met -> every entry(engine, _) is loaded, in the control file's
%order, and the seat is recorded loaded. Any need unmet -> nothing loads,
%nothing prints, and the unmet need is recorded: not built is not an error,
%and half built still is, because a met-needs entry that raises still raises.
:- dynamic metta_extension_loaded/1.
:- dynamic metta_extension_unmet/2.

metta_extension_control_term(title(Title)) :- atom(Title).
metta_extension_control_term(needs(Need)) :- metta_extension_need_shape(Need).
metta_extension_control_term(entry(Role, File)) :-
    % policy-inventory-exempt: mechanism-internal; reason=the two entry roles are the control file's own vocabulary, validated at read time like title/1 and needs/1, and not a value an operator chooses between: which of them a file carries says who does the loading, and the loader below consults exactly the engine ones and never the host ones; evidence=engine/metta.pl:metta_load_extension/1
    memberchk(Role, [engine, host]),
    atom(File).

metta_extension_need_shape(artefact(Relative)) :- atom(Relative).
metta_extension_need_shape(prolog_library(Library)) :- atom(Library).
metta_extension_need_shape(predicate(Name/Arity)) :- atom(Name), integer(Arity).
metta_extension_need_shape(extension(Name)) :- atom(Name).

%The same read-without-running shape interop.pl's manifest scan uses, with the
%opposite policy on a bad term: the import scan goes quiet because the consult
%behind it reports properly, and there is no consult behind this one, so HERE
%the reader is the only thing that will ever speak.
metta_extension_controls(File, Controls) :-
    setup_call_cleanup(open(File, read, In),
                       metta_extension_read(In, File, Controls),
                       close(In)).

metta_extension_read(In, File, Controls) :-
    read_term(In, Term, [variable_names(_)]),
    (   Term == end_of_file
    ->  Controls = []
    ;   (   metta_extension_control_term(Term)
        ->  true
        ;   throw(error(domain_error(extension_control_term, Term),
                        context(File, 'an extension.pl holds only title/1, \c
                                       needs/1 and entry/2 facts')))
        ),
        Controls = [Term|Rest],
        metta_extension_read(In, File, Rest)
    ).

metta_extension_need_met(_, prolog_library(Library)) :-
    exists_source(library(Library)).
metta_extension_need_met(_, predicate(Name/Arity)) :-
    current_predicate(Name/Arity).
metta_extension_need_met(Directory, artefact(Relative)) :-
    directory_file_path(Directory, Relative, Artefact),
    exists_file(Artefact).
metta_extension_need_met(_, extension(Name)) :-
    metta_extension_loaded(Name).

metta_load_extension(Control) :-
    file_directory_name(Control, Directory),
    file_base_name(Directory, Name),
    metta_extension_controls(Control, Controls),
    findall(Need, ( member(needs(Need), Controls),
                    \+ metta_extension_need_met(Directory, Need) ),
            Unmet),
    (   Unmet == []
    ->  forall(member(entry(engine, Relative), Controls),
               ( directory_file_path(Directory, Relative, Entry),
                 % Seat definitions belong to the host tier, whose imports
                 % reach this facade without replacing its implementations.
                 % [source: engine/metta.pl:metta_publish_host_tier/0; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
                 % A printed include error or failed directive is a failed
                 % seat, even when SWI's ensure_loaded/1 succeeds.
                 loading_loudly(user:ensure_loaded(Entry)) )),
        (   metta_extension_loaded(Name) -> true
        ;   assertz(metta_extension_loaded(Name))
        )
    ;   forall(member(Need, Unmet),
               (   metta_extension_unmet(Name, Need) -> true
               ;   assertz(metta_extension_unmet(Name, Need))
               ))
    ).

metta_load_extensions(Pattern) :-
    expand_file_name(Pattern, Found),
    msort(Found, Controls),
    forall(member(Control, Controls), metta_load_extension(Control)).

%One glob and one argv token for every seat, whatever role it plays. There were
%two of each until 2026-08-28, one folder of seats loading unconditionally and
%a second folder behind a token of its own, and the split said that who DRIVES
%the engine and what the engine CONSULTS are different kinds of thing. They are
%not: they are two roles a seat holds, and entry/2 already names them, so the
%Python seat holds both while the Node seat holds only host and MORK only
%engine. One folder, one glob, one token.
%
%A tokenless boot is therefore the pure kernel: no seat is read and none is
%recorded, which is a configuration the engine ships in and the plunit lane
%runs. `extensions` is what run.sh, the packaged CLI, the Python library, the
%C host and the Node host all pass.
%
%Seats load here, before the standard library and the registry directive, so a
%seat's declared builtins and seams exist by the time anything reads them. The
%order within the glob is msort's, and a seat that needs another names it with
%needs(extension(Other)) rather than relying on it.
%
%One backend used to be named here instead, twice: MORK's morkspaces.pl by path
%in a second copy of the whole load list, and its three builtin names in a
%second argv test further down. So a second native backend could not be added
%without editing this file, which is the one thing EXTENDING.md promises an
%extension author never has to do, and MORK was reaching the engine through a
%door no other provider had. It goes through the seam now like everyone else.
%
%A seat that is not built loads nothing and says nothing, and one that is built
%and broken raises, which is the split every host wants and none of them should
%have to implement. That is the control file's business rather than this
%file's: what a seat pulls in, where its build artefacts are, and whether they
%are present at all is its own declaration, and this only reads it.
%
%A native provider's position is fixed rather than its own: seats load after
%everything else the engine defines, because a provider is reached through
%seam:foreign_space/1 and not through clause order. That was true before this
%change and is what made it safe [verified 2026-08-16: moved, whole gate green
%including the MORK tests].
%Where the seats live, recorded once at load time because a RUNTIME reader has
%no load context to compute it from and the require door below is one: the
%diagnosis has to tell "there is no seat by that name" from "this boot read no
%seat at all", and only the directory answers that. The same shape
%standard_library_path/1 uses for lib/ further up this file, and the glob below
%reads the fact rather than repeating the path.
:- dynamic metta_extensions_path/1.
:- prolog_load_context(directory, Src),
   directory_file_path(Src, '../extensions', Extensions),
   asserta(metta_extensions_path(Extensions)).

%!  metta_publish_host_tier is det.
%
%   Publish defined exports before loading seats: their directives run before
%   SWI's end-of-load import. MORK's metta_claim_space/2 directive needs this.
%   Later definitions arrive through the ordinary end-of-load import.
%   [source: extensions/mork/mork_ffi/morkspaces.pl:metta_claim_space/2;
%   commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
metta_publish_host_tier :-
    module_property(metta_engine, exports(Exports)),
    forall(( member(PredicateIndicator, Exports),
             current_predicate(metta_engine:PredicateIndicator) ),
           user:import(metta_engine:PredicateIndicator)).

:- metta_publish_host_tier.

:- current_prolog_flag(argv, Argv),
   (   memberchk(extensions, Argv)
   ->  metta_extensions_path(Directory),
       directory_file_path(Directory, '*/extension.pl', Pattern),
       metta_load_extensions(Pattern)
   ;   true
   ).

%%%% require-extension!: the named refusal for the half that is missing %%%%
%
%A `lib/` module that rests on a seat states it here, and the engine answers by
%NAME when the seat is not there. lib/lib_mm2/lib_mm2.metta is the case: five
%operators over `&mork` calling MORK's own builtins, with no presence check, so
%on a tree where the FFI was never built each of them failed at call time with
%nothing naming the cause.
%
%PostgreSQL has the identical two-half split and the identical failure, and it
%answers by name: pg_stat_statements is a preloaded C module (the hooks, in
%shared_preload_libraries) plus a per-database CREATE EXTENSION (the views),
%and running the second half without the first raises
%`pg_stat_statements must be loaded via shared_preload_libraries`, SQLSTATE
%55000, object_not_in_prerequisite_state
%[source: postgresql.org/docs/current/pgstatstatements.html, "The module must
%be loaded by adding pg_stat_statements to shared_preload_libraries"; the
%message text and its SQLSTATE quoted verbatim in
%github.com/lesovsky/pgcenter/issues/104].
%
%Two things this says that Postgres's message does not, because needs/1 is
%DATA here and a preload list is not:
%
%  - the cause is TRANSITIVE. metta_extension_unmet/2 holds the seat's own
%    unmet need, and a need of kind extension(Other) is followed into Other's
%    diagnosis, so mm2 -> mork -> the absent artefact is one message rather
%    than three sessions. The walk carries a seen list, so a needs cycle
%    reports rather than loops. This is `nix why-depends` and apt's recursive
%    `Depends: X but it is not going to be installed` in the small.
%  - it ends in the REMEDY, the seat's own build.sh where the seat has one.
%
%What it deliberately does NOT do is name the requiring side in its own text.
%The file loader already composes that around any error whose context is
%`none`, and measuring it is what settled the shape: a form raising
%error(probe_reason(deep), none) inside an imported file renders as
%`'ai-tmp/probe_inner.metta': probe reason deep (while loading MeTTa file)`
%[measured 2026-08-28, engine/filereader/source_lifecycle.pl's
%rethrow_metta_file_error/2, which rethrows a CONTEXTED error unchanged and
%wraps an uncontexted one in the file]. So the inner message names what is
%missing and the frame names who asked, which is PostgreSQL's own MESSAGE and
%CONTEXT split and Node's `Cannot find module` plus `Require stack`. Naming the
%file inside the message too would print it twice, and a require typed at a
%REPL has no requiring file to name at all.
metta_require_extension(Name) :-
    (   metta_extension_loaded(Name)
    ->  true
    ;   metta_extension_cause(Name, Cause),
        throw(error(metta_extension_required(Name, Cause), none))
    ).

%Why a seat is not loaded, in one term. The records answer first, because the
%loader wrote them; the filesystem answers only what no record can, which is
%whether a seat by that name exists at all.
%
%  unmet(Needs)  the loader read the control file and these needs failed
%  unread        the control file is there and this boot never read it, which
%                is the tokenless pure kernel rather than anything missing
%  unknown       no extensions/<Name>/extension.pl exists
metta_extension_cause(Name, unmet(Needs)) :-
    findall(Need, metta_extension_unmet(Name, Need), Needs),
    Needs = [_|_], !.
metta_extension_cause(Name, Cause) :-
    metta_extension_seat_file(Name, 'extension.pl', Control, _),
    (   exists_file(Control)
    ->  Cause = unread
    ;   Cause = unknown
    ).

%A file inside a seat, both ways: the path to open, and the path to SAY. The
%said one is written from the recorded directory's own basename rather than
%from the word `extensions`, so the engine names no seat folder of its own and
%the message follows a rename of the folder
%[tested: test_the_tree_partitions_by_seam].
metta_extension_seat_file(Name, Relative, Path, Said) :-
    metta_extensions_path(Directory),
    directory_file_path(Directory, Name, Seat),
    directory_file_path(Seat, Relative, Path),
    file_base_name(Directory, Root),
    atomic_list_concat([Root, Name, Relative], '/', Said).

%The cause as text. Seen carries the seats already being explained, so the
%extension arm below can follow a need into its own cause without looping.
metta_extension_cause_text(_, Name, unread, Text) :-
    metta_extension_seat_file(Name, 'extension.pl', _, Said),
    format(atom(Text),
           '~w is there and no seat was read on this boot, because the engine \c
            reads the seats only when its argv carries the `extensions` token',
           [Said]).
metta_extension_cause_text(_, Name, unknown, Text) :-
    metta_extension_seat_file(Name, 'extension.pl', _, Said),
    format(atom(Text), 'there is no ~w', [Said]).
metta_extension_cause_text(Seen, Name, unmet(Needs), Text) :-
    findall(Reason,
            ( member(Need, Needs),
              metta_extension_need_reason(Seen, Name, Need, Reason) ),
            Reasons),
    atomic_list_concat(Reasons, ', and ', Text).

%One unmet need of Seat, said with the remedy that clears it. The paths are
%tree-relative rather than absolute because they are what the reader types.
%needs(extension(Other)) is the recursive arm and the reason this is a walk at
%all: Other's own cause is read the same way, under Seen.
metta_extension_need_reason(_, Seat, artefact(Relative), Reason) :-
    metta_extension_seat_file(Seat, Relative, _, Said),
    metta_extension_build_remedy(Seat, Remedy),
    format(atom(Reason), 'artefact ~w is absent~w', [Said, Remedy]).
metta_extension_need_reason(_, _, prolog_library(Library), Reason) :-
    format(atom(Reason),
           'the Prolog library ~w is not on this build\'s library search path',
           [Library]).
metta_extension_need_reason(_, _, predicate(Indicator), Reason) :-
    format(atom(Reason),
           'the predicate ~w is not defined in this process, so whatever \c
            registers it has not run here',
           [Indicator]).
metta_extension_need_reason(Seen, _, extension(Other), Reason) :-
    (   memberchk(Other, Seen)
    ->  format(atom(Reason),
               'extension ~w, which is already being explained above: the \c
                needs graph has a cycle',
               [Other])
    ;   metta_extension_loaded(Other)
    ->  format(atom(Reason),
               'extension ~w, which IS loaded, so the record is stale',
               [Other])
    ;   metta_extension_cause(Other, Cause),
        metta_extension_cause_text([Other|Seen], Other, Cause, Inner),
        format(atom(Reason), 'extension ~w, which is not loaded because ~w',
               [Other, Inner])
    ).

%The seat's own build script, when it ships one, so the message ends where the
%reader can act. Refinement R1 of ai-plan-component-self-containment.md pairs
%this with each build.sh verifying the artefact needs it declares, which is
%what keeps the two from naming different paths.
metta_extension_build_remedy(Seat, Remedy) :-
    metta_extension_seat_file(Seat, 'build.sh', Script, Said),
    (   exists_file(Script)
    ->  format(atom(Remedy), ' (run ~w)', [Said])
    ;   Remedy = ''
    ).

:- multifile prolog:error_message//1.
prolog:error_message(metta_extension_required(Name, Cause)) -->
    { metta_extension_cause_text([Name], Name, Cause, Text) },
    [ 'extension ~w is required and not loaded: ~w'-[Name, Text] ].

%A MeTTa head in an error context is the program's name for the operation, an
%atom or an expression, never a predicate indicator. SWI-Prolog 10.1.14 renders
%every callable context as Name/Arity, so the engine renders its own
%[tested: tests/prolog/suites/evaluation/metta.plt; commit=c17a00e9c97d830aaca08f48dced515f14d4553a].
:- multifile prolog:message_location//1.
prolog:message_location(context(Head, _)) -->
    { metta_context_head(Head) },
    [ '~p: '-[Head] ].

metta_context_head(Head) :- atom(Head), !.
metta_context_head(Head) :- is_list(Head).

%The MeTTa spelling. It answers the unit `[]` like every other builtin whose
%point is what it lets the rest of the file assume, and its first argument is
%guarded because a declared Symbol position is [tested:
%builtin_input_guards:every_builtin_refuses_an_unbound_input_by_name].
'require-extension!'(Name, _) :- var(Name), !,
                                 refuse_unbound_input('require-extension!', 1).
'require-extension!'(Name, []) :- metta_require_extension(Name).

:- use_module(host_transactions, []).
:- consult('metta/terms.pl').
:- consult('metta/operators.pl').
:- consult('metta/input_guards.pl').
:- consult('metta/types.pl').
:- consult('metta/refinements.pl').
:- consult('metta/effects.pl').
:- consult('metta/completion.pl').
:- consult('metta/space_hooks.pl').
:- consult('metta/runtime.pl').
:- consult('metta/control.pl').
:- consult('metta/limits.pl').

%The environment half of verify-discharges is materialised HERE, not beside its
%own predicates in metta/terms.pl, because metta_pragma/2 belongs to
%metta/control.pl and that file is consulted after terms.pl: read any earlier
%and the boot raises `Unknown procedure: metta_pragma/2`. The pragma half
%refreshes on write in set_metta_pragma/2.
:- initialization(metta_refresh_discharge_verification).
%Specialization verification is selected while calls compile, but its coverage
%is accumulated while those calls run. The environment door therefore starts
%the tally after control.pl has made metta_pragma/2 available, and process exit
%finishes the run that has no closing pragma.
:- initialization(specializer:metta_refresh_specialization_verification).
:- at_halt(specializer:metta_finish_specialization_verification).
:- consult('metta/interop.pl').
:- consult('metta/properties.pl').
:- consult('metta/registration.pl').
:- consult('metta/references.pl').
:- consult('metta/reference_sources.pl').
:- consult('metta/reference_refresh.pl').
:- consult('metta/reference_loading.pl').
%%%%%%%%%% The engine's own type surface %%%%%%%%%%
%
%Without this, `get-type` misreported the engine to every tool that reads it.
%`!=` IS a builtin, IS registered and IS declared (: != (-> $a $b Bool)) in
%lib/lib_builtin_types/lib_builtin_types.metta, but with nothing loading that file
%`(get-type !=)` answered %Undefined% for an operation that works. Nothing was
%missing; the type surface was simply not connected, and a reader like the
%metta-lsp port has no way to tell "this has no type" from "this has a type
%nobody loaded".
%
%FACTS RATHER THAN ATOMS IN &self, and that is the whole design decision.
%Loading the file into &self was tried first and it changes what every program
%SEES OF ITS OWN SPACE: `(match &self (: $what $type) ...)` then answers 41
%engine declarations alongside the program's own, which broke
%tests/fixtures/repro3_failed_specialization_self_leak.metta immediately.
%The engine's types belong where the type system reads them and nowhere a
%program enumerating its own atoms can trip over them.
%
%LAST, so a user wins. get_type_candidate/2 tries the intrinsic types, the
%function's arrow, the element-wise reading and &self's own declarations
%before reaching here, so `(: + (-> Foo Bar))` written by a program is
%answered ahead of the engine's and this only ever fills a gap.
%
%ONE SOURCE OF TRUTH: the facts are built by parsing lib_builtin_types.metta
%at boot, so the file a program can still import explicitly and the table the
%engine answers from cannot drift apart.
:- multifile seam:builtin_type_declaration/2.
:- dynamic seam:builtin_type_declaration/2.

load_builtin_type_surface :-
    library('lib_builtin_types.metta', Path),
    exists_file(Path),
    !,
    read_file_to_string(Path, Text, [encoding(utf8)]),
    parse_metta_source(Text, Forms),
    forall(( member(parsed(expression, _, [':', Name, Type]), Forms),
             atom(Name) ),
           ( seam:builtin_type_declaration(Name, Type)
             -> true
             ;  assertz(seam:builtin_type_declaration(Name, Type)) )),
    %The same file's (cost ...) rows, for the same reason its (: ...) rows are
    %here: a claim about a builtin belongs where the builtin's surface is
    %declared, and it has to be LOADED to be worth anything. Explain and the
    %Python docstring answer from &metta, so a row reachable only through an
    %explicit import! would be a claim nobody sees. These go through the
    %ordinary catalog door, so the engine's own rows meet the same checker a
    %program's do.
    forall(member(parsed(expression, _, [cost, Witness|Fields]), Forms),
           ensure_shipped_cost_row([cost, Witness|Fields], _)),
    %Derived from the surface just loaded rather than by a separate
    %initialization, because two initialization/1 goals do not reliably order
    %against each other and an empty index is a silent loss: a constructor like
    %Error would quietly evaluate the argument it exists to carry.
    index_builtin_masks.
load_builtin_type_surface :- index_builtin_masks.

%A shipped cost row lands in '&metta' through add_sexp/3, the door every
%native catalog write passes, so the kind check that refuses a program's
%malformed row refuses the engine's. Skipping a head that already has a row
%keeps the boot idempotent and leaves an earlier row standing, which is the
%order every other engine declaration keeps: the engine fills a gap and never
%overwrites.
%Wrote is what the caller needs to know and not a courtesy: the prelude
%remembers the rows IT put in so eviction can take them out again, and a row
%that was already standing when the prelude reached its own copy belongs to
%whoever wrote it.
ensure_shipped_cost_row([cost, Witness|Fields], Wrote) :-
    nonvar(Witness),
    Witness = [Head|_],
    atom(Head),
    !,
    (   metta_cost_row(Head, _, _, _)
    ->  Wrote = false
    ;   add_sexp('&metta', [cost, Witness|Fields], _),
        Wrote = true
    ).
ensure_shipped_cost_row(Row, _) :-
    throw(error(domain_error(cost_row, Row),
                context(ensure_shipped_cost_row/2,
                        'a cost row names a call, as in (cost (nrev $n) quadratic)'))).

%%%%%%%%%% The engine's prelude %%%%%%%%%%
%
%The standard vocabulary, reachable with no import!. Its Prolog bodies are
%engine/prelude.pl, a module the execution chain resolves through between this
%one and '&self', and its registers, its declarations, its documents, its cost
%rows and its eviction door are engine/metta/prelude.pl, consulted below.
%
%Boot used to PARSE and TRANSLATE 783 lines of MeTTa here, once per process,
%for clauses no .qlf ever held. install_engine_prelude/0 writes the registers
%from tables the artifact carries instead [measured 2026-09-07: boot 272,323 to
%248,271 inferences, -8.83%; command=swipl -q -g "metta_bench:bench_run(boot)"
%-t halt engine/bench.pl; fixture=warm .qlf, three identical samples per arm].
:- consult('metta/prelude.pl').

%fun/1, fun_in/2, fun_scoped/1 and metta_exec_module_parent/2 are the exact
%mutable inputs the host catalogues read: metta_py_builtins/1 reads the first,
%and the per-space metta_py_builtins/2 reads all four, because a second space
%defining an already-registered name asserts fun_in/2 without touching fun/1
%and a cache stamped by fun/1 alone would go on answering the old set for it.
%SWI maintains a dynamic predicate's last_modified_generation for cache
%validation, including transaction commit and rollback semantics, so no
%listener or generic write-door flag exists and every mutation route keeps
%its original cost; the sum of four monotone generations is monotone.
%Keep this read-only host service after the loader predicates it does not call:
%its clause layout then cannot perturb the save-load-metta hot path [measured 2026-08-23:
%save-load-metta 9,223,648 inferences; command=METTA_BENCHMARK_COUNTERS=1
%PYTHONPATH=extensions/python python -m pytest
%-q extensions/python/benchmarks/test_benchmarks.py::test_save_load_metta;
%fixture=deterministic benchmark harness; commit=fc08223618651c122c7e3bfa9f269d03ff1c0932].
metta_host_function_generation(Generation) :-
    predicate_property(fun(_), last_modified_generation(Functions)),
    predicate_property(fun_in(_, _), last_modified_generation(Homes)),
    predicate_property(fun_scoped(_), last_modified_generation(Scopes)),
    predicate_property(spaces:metta_exec_module_parent(_, _),
                       last_modified_generation(Parents)),
    Generation is Functions + Homes + Scopes + Parents.

%One initialization goal for all of them, in this order, because
%initialization/1 goals do not reliably order against each other (the note
%above) and the prelude's bodies mention constructors like Error whose Atom
%masking reads the surface loaded first. The seam sweep runs first and for the
%same reason engine/ext_points.pl's own directive cannot be the whole of it: a
%seam is declared there before the file that defines it is loaded, so the
%export the declaration promises can only be made once every engine file has
%been [tested: metta_published_surface:every_declared_seam_that_exists_is_exported].
:- initialization((seam:publish_declared, protect_metta_exec_modules,
                   refuse_autoload_into_exec_modules,
                   load_builtin_type_surface, install_engine_prelude,
                   spaces:metta_publish_builtin_visibility,
                   spaces:metta_publish_every_vocabulary_type,
                   retract_unrelated_system_arities,
                   snapshot_builtin_function_sources)).
