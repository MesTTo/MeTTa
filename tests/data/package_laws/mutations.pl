% Purpose: prove every package-law test detects removal of its policy.
% Guarantees: each witness first passes in a fresh process, then fails with
% one installed mutation; unassigned or nonexistent tests refuse the run.
% [tested: main/0; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
% Owns resources: child processes are joined; their separate logs stay under
% this battery's ai-tmp/package-mutations. No source file is edited.

:- module(package_mutations, [main/0]).
:- user:ensure_loaded('../../prolog/suites/seams/package_laws.plt').
:- user:ensure_loaded('../../prolog/suites/seams/packages.plt').
:- use_module(library(prolog_wrap)).
:- use_module(library(process)).
:- use_module(library(filesex)).
:- initialization(main, main).

main :-
    catch(main_checked(Status), Error, (print_message(error, Error), Status=2)),
    halt(Status).

main_checked(Status) :-
    current_prolog_flag(argv, Arguments),
    ( Arguments = [Unit, Test, Mutation]
    -> ( Mutation == control -> true ; install(Mutation) ),
       ( run_tests(Unit:Test) -> Status=0 ; Status=1 )
    ; Arguments == []
    -> coverage,
       source_file(package_mutations:main, Self), file_directory_name(Self, Here),
       directory_file_path(Here, '../../../ai-tmp/package-mutations', Scratch),
       make_directory_path(Scratch),
       findall(Unit-Test-Mutation, witness(Unit, Test, Mutation), Witnesses),
       maplist(run_witness(Self, Scratch), Witnesses),
       length(Witnesses, Count), format('mutation_witnesses\t~d\tpassed~n', [Count]), Status=0
    ; throw(error(domain_error(mutation_arguments, Arguments), none)) ).

coverage :-
    forall(plunit:current_test(package_laws, Name, _, _, _),
           ( witness(package_laws, Name, _) -> true
           ; throw(error(existence_error(disabling_mutation, Name), none)) )),
    forall(witness(Unit, Name, _),
           ( plunit:current_test(Unit, Name, _, _, _) -> true
           ; throw(error(existence_error(mutation_witness, Unit:Name), none)) )).

run_witness(Self, Scratch, Unit-Test-Mutation) :-
    run_case(Self, Scratch, Unit, Test, control, Before),
    ( Before == exit(0) -> true
    ; throw(error(mutation_control_failed(Unit:Test, Before), none)) ),
    run_case(Self, Scratch, Unit, Test, Mutation, After),
    ( After == exit(1) -> true
    ; throw(error(mutation_not_detected(Unit:Test, Mutation, After), none)) ),
    format('~w\t~w\tcontrol=0\tmutant=1~n', [Test, Mutation]).

run_case(Self, Scratch, Unit, Test, Mutation, Status) :-
    atomic_list_concat([Unit, Test, Mutation, log], '.', Name),
    directory_file_path(Scratch, Name, Log),
    setup_call_cleanup(open(Log, write, Stream),
        ( process_create(path(swipl), ['-q','-s',Self,'--',Unit,Test,Mutation],
                         [stdout(stream(Stream)),stderr(stream(Stream)),process(Pid)]),
          process_wait(Pid, Status) ), close(Stream)).

install(Mutation) :-
    ( replacement(Mutation, Head, Wrapped, Body)
    -> wrap_predicate(Head, package_mutation, Wrapped, Body)
    ; throw(error(existence_error(package_mutation, Mutation), none)) ).

replacement(no_coverage, packages:package_coverage(_,_,_,_,_), _, true).
%The guard removed, leaving the question that RESOLVES its head. Asking
%whether a head is already loaded then defines it, because resolving an
%undefined predicate fires the undefined-procedure hook and the engine
%answers that by translating the name -- from inside the registration that
%has not yet recorded the arity the equation's own body calls.
replacement(resolving_head_source,
            packages:package_head_source(Module, Head, File), _,
            predicate_property(Module:Head, file(File))).
replacement(no_claim_bootstrap, packages:package_register_claims, Wrapped,
            (nb_current('$package_mutant_claims_ready',true) -> true
            ; call(Wrapped), nb_setval('$package_mutant_claims_ready',true))).
replacement(no_selection, packages:package_head_seen(_,_), _, fail).
replacement(perform_available, packages:package_perform_rows(Path,Space,_,Selections), Wrapped,
            (forall(member(available(Row),Selections),
                    packages:package_perform(Path,Space,backing,Row)), call(Wrapped))).
replacement(no_home, metta_engine:metta_package_perform(_,Expression,Result), _,
            metta_engine:evalc(Expression, '&metta', Result)).
replacement(no_pattern, packages:package_heads_pattern(_,_,Names), _, Names=[]).
replacement(no_arrow_check, packages:package_agree_type(_,_,_), _, true).
replacement(no_equation_collision, packages:package_source_equation(_,_,_,_), _, fail).
replacement(no_merge, packages:package_merge_answer(_,_,_), _, true).
replacement(no_installed_heads, packages:package_installed_heads(_,_), _, true).
replacement(no_receipts, spaces:metta_add_atom(_Space,Row,Result), Wrapped,
            (nonvar(Row), Row=[performed,_,_] -> Result=true ; call(Wrapped))).
replacement(no_available, spaces:metta_add_atom(_Space,Row,Result), Wrapped,
            (nonvar(Row), Row=[available,_] -> Result=true ; call(Wrapped))).
replacement(no_release, packages:package_release_loads(_,_), _, true).
replacement(no_boot_validation, packages:package_validate_boots(_,_), _, true).
replacement(no_failure_cleanup, packages:package_loading(_,_,Goal), _, call(Goal)).
replacement(no_eager_admission, packages:package_boot_admission(_,_,_), _, true).
replacement(no_manifest_admission, packages:package_manifest(_,_,_,_,_,Goal), _, call(Goal)).
replacement(import_runs_setup, packages:package_default(Path,Space,Rows), Wrapped,
            (packages:package_prepare(Path,Space,Rows), call(Wrapped))).
replacement(no_version_check, packages:package_versions(_), _, true).
replacement(no_requires, packages:package_require(_,_,_), _, true).
replacement(no_internal, metta_engine:metta_reference_internal(_Space,Name), Wrapped,
            (Name==package -> fail ; call(Wrapped))).
replacement(no_setup_remedy, packages:package_native_path(_,_,Locator,_), _,
            throw(error(existence_error(source_sink,Locator),context(package,missing)))).
replacement(no_claim_reflection, packages:'get-property'(Subject,Key,_), Wrapped,
            (Subject==perform, Key==claims -> fail ; call(Wrapped))).
replacement(no_interpreter, packages:package_load(Path,Space,Rows), _,
            packages:package_default(Path,Space,Rows)).
replacement(no_setup_reuse, packages:package_setup_current(_,_,_,_,_,_), _, fail).
replacement(stale_receipt, packages:package_setup_current(_,_,_,Receipt,_,Performed), _,
            (exists_file(Receipt), packages:package_read_rows(Receipt,Performed))).
replacement(no_artifact_check, packages:package_setup_artifacts(_,_,_), _, true).
replacement(no_setup, packages:'setup!'(_,Result), _, Result=true).
replacement(no_lock_rows, packages:package_collect_requirement(_,_), _, true).
replacement(release_dependencies, packages:package_loading_finish(_Path,_Space,_Before,Outcome), Wrapped,
            (call(Wrapped), (Outcome==exit -> true ; packages:package_close_all))).
replacement(no_withdrawal, filereader:withdraw_source_load(_,_,Count), _, Count=0).
replacement(first_answer_only, metta_engine:metta_package_reduce(_,_,_,_), Wrapped, once(Wrapped)).
replacement(no_reads_ceiling, metta_engine:metta_package_refuse_above_ceiling(_,_), _, true).
replacement(no_read_forms, metta_engine:metta_package_reads_runtime(_), _, fail).
replacement(no_directory_lock, packages:package_with_directory_lock(_,Goal), _, call(Goal)).
replacement(no_catalog_add, seam:foreign_add(Space,_), Wrapped,
            (Space=='&catalogs' -> true ; call(Wrapped))).
replacement(refuse_equal_alias, packages:package_same_identity(Name,_,_,_), _,
            throw(error(permission_error(resolve,package_identity,Name),none))).
replacement(no_identity_check, packages:package_same_identity(_,_,_,_), _, true).
replacement(no_pin_check, packages:package_check_pin(_,_), _, true).
replacement(no_pending_requirements, packages:package_pending_requirement(_,_), _, fail).
replacement(no_export_boundary, packages:package_native_manifest(File,Declared,Inferred), _,
            (Declared=[], package_mutations:infer_every_arity(File,Inferred))).
replacement(no_native_admission, packages:package_native_admission(_,_,_,_,_), _, true).
replacement(no_native_reuse, packages:package_open_head(_,_,Row,Name,Arity), _,
            (Row=[Token|_],metta_engine:metta_host_open_function(Name,Token,Arity))).
replacement(import_every_native_head, packages:package_load_native(File,Owner), _,
            (metta_engine:current_metta_space(Home),metta_engine:space_module(Home,Module),
             load_files(Module:File,[if(changed)]),
             (source_file_property(File,module(Owner)) -> true ; Owner=Module))).
replacement(process_registration, metta_engine:metta_reference_register_prolog(Home,_,Name,Arity), Wrapped,
            (Home=='&self' -> metta_engine:register_process_function(Name,[Arity]) ; call(Wrapped))).
replacement(no_declared_contracts, packages:package_native_exports(_,Names), _, Names=[]).
replacement(first_contract_only, packages:package_native_manifest(File,Declared,Inferred), _,
            (package_mutations:infer_every_arity(File,[First|_]),Declared=[First],Inferred=[])).
replacement(no_generic_contracts, packages:package_contract(_,_,Row,_,_,_), Wrapped,
            (Row=[Token|_],Token=='lp-contract-symbol' -> fail ; call(Wrapped))).
replacement(empty_generic_signature, packages:package_contract(_,_,Row,Pattern,Names,Contracts), Wrapped,
            (Row=[Token|_],Token\==prolog,var(Pattern)
             -> Pattern=[],Names=[],Contracts=[] ; call(Wrapped))).
replacement(no_contract_requirement, packages:package_contract(_,_,Row,Pattern,Names,Contracts), Wrapped,
            (Row=[Token|_], Token\==prolog -> Names=Pattern, Contracts=[] ; call(Wrapped))).
replacement(no_backing_shape, packages:package_backing_info(_,_,Row,Info), _,
            Info=info(Row,unclaimed,[],[])).
%The half loaded the way it was before the door: load_files/2 on the .pl path,
%which reads the source whatever artifact the claim would have written.
replacement(native_load_bypasses_the_claim, packages:package_load_native(File,Owner), _,
            (( source_file_property(File,module(Context)) -> true
             ; atom_concat('$metta_package:',File,Context),
               set_module(Context:base(metta_engine)) ),
             load_files(Context:File,[expand(true),if(changed),imports([])]),
             (source_file_property(File,module(Owner)) -> true ; Owner=Context))).
%Every source claimed, the stamped set's boundary gone.
replacement(claim_every_source, seam:compiled_source(File), _,
            metta_qlf_boot:qlf_compile_aside(File)).
%get-property's three policies, each put back the way it was before: the
%second subject rule that read every spelling but (library ...) as a file, the
%home answering a row's stored body, and a plain import's rows read nowhere.
%The fourth removes the one test deciding which rows need no home.
replacement(second_subject_rule, packages:package_subject_source(_,Subject,Path), _,
            (( nonvar(Subject), Subject = [library|_]
             -> metta_engine:resolve_module_form(Subject,File) ; File = Subject ),
             packages:package_existing_source(Subject,File,Path))).
replacement(stored_body_at_home, packages:package_home_property(Home,Key,Value), _,
            ( Key == available -> metta_engine:metta_host_stored(Home,[available,Value])
            ; metta_engine:metta_host_stored(Home,['=',[package,Key],Value]) )).
replacement(no_manifest_read, packages:package_source_property(_,_,_,_), _, fail).
replacement(computed_rows_as_written, packages:package_literal(_), _, true).

% Discard export declarations while retaining the artifact's actual clauses.
% The witness then observes the internal arity that an unrestricted scan leaks.
infer_every_arity(File, Inferred) :-
    setup_call_cleanup(open(File,read,Stream),
        packages:package_native_terms(Stream,[],_,[],Heads),close(Stream)),
    sort(Heads,Inferred).

witness(package_laws, Name, Mutation) :- group(Mutation, Names), member(Name, Names).
witness(packages, an_uncovered_backing_without_a_claimant_refuses, no_coverage).
witness(packages, a_row_that_answers_nothing_refuses_by_name, no_backing_shape).
witness(packages, a_backing_row_installs_the_head_its_artifact_exports, no_home).
witness(packages, importing_a_backed_library_leaves_the_package_head_alone, no_home).
witness(packages, a_computed_row_normalises_and_then_performs, no_home).
witness(packages, a_requirement_loads_before_the_file_that_declares_it, no_requires).
witness(packages, the_package_head_is_internal_in_every_space, no_internal).
witness(packages, a_subject_names_what_a_from_source_names, second_subject_rule).
witness(packages, setup_names_its_subject_by_the_same_rule, second_subject_rule).
witness(packages, a_subject_resolves_or_refuses_by_name, second_subject_rule).
witness(packages, a_plain_import_is_read_from_its_manifest, no_manifest_read).
witness(packages, a_computed_row_is_answered_only_in_a_home, stored_body_at_home).
witness(packages, a_computed_row_is_answered_only_in_a_home, computed_rows_as_written).
witness(packages, the_literal_rows_are_the_rows_the_normaliser_passes_through, computed_rows_as_written).

group(no_claim_bootstrap, [default_claim_recovers_after_withdrawal_and_failed_activation]).
group(no_coverage, [uncovered_backing_refuses_by_head]).
group(resolving_head_source,
      [a_backing_row_registers_before_the_equations_calling_it_translate]).
group(perform_available, [unclaimed_backing_is_skipped_when_equations_cover_it]).
group(no_selection, [first_claimed_backing_wins_and_alternative_remains_visible,
                     an_unused_native_alternative_need_not_exist,
                     partially_overlapping_backings_only_merge_their_unselected_heads,
                     metta_fixture_predicts_first_claimed_backings]).
group(no_home, [backing_lives_and_retires_in_its_home,
                backing_repairs_preceding_equations_before_the_next_runnable]).
group(process_registration, [backing_in_self_retires_registration_without_unloading_the_host]).
group(no_pattern, [variable_heads_take_the_export_declaration,
                   segment_heads_require_the_prefix_and_take_remaining_exports]).
group(no_arrow_check, [contracts_refuse_before_native_directives]).
group(no_equation_collision, [equation_and_backing_at_the_same_arity_refuse,
                             equation_and_native_arities_share_a_head_without_colliding]).
group(no_merge, [backing_answer_spaces_merge_through_from]).
group(no_installed_heads, [a_claimed_backing_cannot_succeed_without_installing_its_heads]).
group(no_receipts, [backing_receipts_retain_the_actual_answer,
                   every_performer_answer_is_receipted_and_released]).
group(no_release, [boot_runs_in_source_order_and_releases_in_reverse,
                   one_release_failure_does_not_abandon_other_handles,
                   space_release_closes_its_package_handles,
                   package_lifetime_sweeps_lengths_and_failure_positions,
                   successful_replacement_retires_the_old_handles_after_activation]).
group(no_boot_validation, [all_boot_rows_are_validated_before_any_effect,
                           boot_types_are_checked_before_effects]).
group(no_failure_cleanup, [boot_failure_releases_every_successful_acquisition,
                           failed_replacement_preserves_the_previous_source_and_handles]).
group(no_eager_admission, [boot_refuses_lazy_admission]).
group(no_manifest_admission, [from_refuses_boot_before_lazy_or_background_submission]).
group(import_runs_setup, [import_never_runs_setup]).
group(no_version_check, [computed_versions_refuse]).
group(no_requires, [relative_requirements_are_loaded_before_boot,
                    requirement_cycles_refuse_with_the_path, offline_git_requires_a_lock,
                    setup_dependencies_supply_computed_rows_without_booting]).
group(no_setup_remedy, [missing_artifact_names_setup_as_the_remedy]).
group(no_claim_reflection, [claims_are_reflected_by_the_two_input_property_door]).
group(no_interpreter, [a_required_library_can_replace_the_interpreter]).
group(no_setup_reuse, [setup_receipts_reuse_unchanged_work,setup_reuses_receipts_with_multiple_answers]).
group(stale_receipt, [changed_setup_rows_invalidate_receipts,
                      duplicate_setup_rows_remain_distinct_and_invalidate_on_removal]).
group(no_artifact_check, [missing_backing_artifacts_invalidate_receipts]).
group(no_setup, [failed_setup_does_not_publish_a_receipt,
                 setup_pins_git_and_a_fresh_import_spawns_nothing]).
group(no_lock_rows, [setup_lock_contains_transitive_resolved_requirements]).
group(release_dependencies, [a_failed_parent_preserves_a_successful_dependency]).
group(no_withdrawal, [failure_with_a_failed_release_still_withdraws_the_source]).
group(first_answer_only, [computed_rows_preserve_every_answer]).
group(no_reads_ceiling, [normalisation_refuses_state_writes_before_they_happen,
                       space_read_bodies_cannot_hide_state_writes]).
group(no_read_forms, [normalisation_allows_space_reads_and_checks_the_match_body]).
group(no_directory_lock, [setup_holds_an_os_lock_until_its_claimant_finishes]).
group(no_catalog_add, [catalog_rows_and_catalog_spaces_resolve_requirements]).
group(refuse_equal_alias, [catalog_aliases_with_equal_digests_load_once]).
group(no_identity_check, [catalog_aliases_with_different_digests_refuse]).
group(no_pin_check, [two_requirers_cannot_pin_different_revisions_of_one_name]).
group(no_pending_requirements, [pending_requirements_expose_cycles_outside_their_transaction]).
group(no_export_boundary, [native_export_declarations_do_not_leak_hidden_arities,
                          native_export_declarations_refuse_unexported_names]).
group(no_available, [partially_overlapping_backings_only_merge_their_unselected_heads]).
group(import_every_native_head, [unselected_native_exports_leave_equation_heads_free]).
group(no_contract_requirement, [backings_must_supply_contracts_for_the_heads_they_name]).
group(no_native_admission, [native_names_owned_by_a_requirement_refuse_before_directives]).
group(no_native_reuse, [an_already_loaded_artifact_can_register_its_own_heads]).
group(no_declared_contracts, [explicit_export_arities_are_native_contracts]).
group(first_contract_only, [each_declared_arrow_matches_its_native_arity]).
group(no_backing_shape, [empty_export_declarations_are_valid_signatures]).
group(no_generic_contracts, [ordinary_contract_equations_describe_an_attached_claimant]).
group(native_load_bypasses_the_claim, [a_backing_row_loads_its_half_through_the_claim]).
group(claim_every_source, [an_unclaimed_backing_loads_from_source_and_leaves_no_artifact]).
group(empty_generic_signature, [ordinary_contract_equations_describe_an_attached_claimant]).
