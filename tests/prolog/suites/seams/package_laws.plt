% Purpose: prove package laws 6-13 through the ordinary load and setup doors.
% Guarantees: effects, callable results, files and source retirement are the
% observations; mutations.pl disables each subject and reruns its witnesses.
% [tested: tests/data/package_laws/mutations.pl; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
% Owns resources: fixtures stay under this battery's ai-tmp; each home and its
% source lifetime are independent of the other test cases.
% Guarantees: native overloads repair self-calls under eager and deferred
% loading, including alias-aware dependency recording [tested:
% a_backing_row_registers_before_the_equations_calling_it_translate;
% commit=WORKTREE].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- use_module('../../../../engine/metta.pl').
:- use_module('../../../data/package_laws/support.pl').
:- use_module(library(filesex)).
:- prolog_load_context(directory, Here),
   directory_file_path(Here, '../../../../ai-tmp/package-laws', Scratch),
   assertz(lp_scratch(Scratch)).
:- prolog_load_context(directory, Here),
   directory_file_path(Here, '../../../data/package_laws', Data),
   assertz(lp_data(Data)).

:- begin_tests(package_laws, [setup(lp_install)]).

lp_package(Name, Text, Path, Home) :-
    lp_scratch(Scratch), gensym(Name, Unique),
    directory_file_path(Scratch, Unique, Directory),
    ( exists_directory(Directory) -> delete_directory_and_contents(Directory) ; true ),
    make_directory_path(Directory),
    directory_file_path(Directory, 'main.metta', Raw), absolute_file_name(Raw, Path),
    lp_write(Path, Text), metta_engine:metta_reference_home(Path, Home), lp_reset.

lp_write(Path, Text) :-
    setup_call_cleanup(open(Path, write, Out, [encoding(utf8)]),
                       format(Out, '~s', [Text]), close(Out)).

lp_adjacent(Path, Name, Text, File) :-
    file_directory_name(Path, Directory), directory_file_path(Directory, Name, File),
    lp_write(File, Text).

lp_import(Path, Home) :- once(metta_engine:importer_helper(Home, Path)).
lp_answers(Home, Expression, Answers) :- findall(V, eval([evalc, Expression, Home], V), Answers).
lp_events(Events) :- findall(E, lp_event(E), Events).

%The executable MeTTa statement of the policy engine/packages.pl implements.
%It moved out of the library tree with the laws themselves, so it is resolved
%from this file's own directory: library/2 answers only for installed
%libraries, and the package laws are no longer one.
lp_policy(Home) :-
    lp_data(Data), directory_file_path(Data, 'policy.metta', Raw),
    absolute_file_name(Raw, Path),
    metta_engine:metta_reference_home(Path, Home), lp_import(Path, Home).

:- meta_predicate lp_throws(0, ?).
lp_throws(Goal, Formal) :-
    catch((call(Goal), Outcome = succeeded), error(Error, _), Outcome = raised(Error)),
    assertion(Outcome = raised(Formal)).

test(default_claim_recovers_after_withdrawal_and_failed_activation) :-
    Claim = ['=', [perform, [prolog, File, Names]], ['package-prolog', File, Names]],
    metta_remove_atom('&metta', Claim, true),
    lp_package(bootstrap_failure,
        "(= (package backing) (prolog \"absent.pl\" (lp_bootstrap_missing)))", Bad, BadHome),
    lp_throws(lp_import(Bad, BadHome), existence_error(source_sink, _)),
    lp_package(bootstrap,
        "(= (package backing) (prolog \"native.pl\" (lp_bootstrap_native)))", Path, Home),
    lp_adjacent(Path, 'native.pl', "lp_bootstrap_native(42).", _),
    lp_import(Path, Home), lp_answers(Home, [lp_bootstrap_native], [42]),
    spaces:metta_native_pair('&metta', Claim, _, Ref),
    \+ filereader:source_load_assertion(_, stored, Ref).

test(uncovered_backing_refuses_by_head) :-
    lp_package(uncovered, "(= (package backing) (lp-absent missing (lp-uncovered)))", Path, Home),
    lp_throws(lp_import(Path, Home), existence_error(package_backing, ['lp-uncovered'])),
    \+ filereader:metta_source_load(Path, Home, _, _).

test(unclaimed_backing_is_skipped_when_equations_cover_it) :-
    lp_package(covered,
        "(= (lp-covered $x) $x)\n(= (package backing) (lp-absent missing (lp-covered)))", Path, Home),
    lp_import(Path, Home), lp_answers(Home, ['lp-covered', 42], [42]),
    metta_host_stored(Home, [available, ['lp-absent', missing, ['lp-covered']]]).

test(first_claimed_backing_wins_and_alternative_remains_visible) :-
    'new-space'(First), 'new-space'(Second),
    metta_add_atom(First, [=, ['lp-choice'], 42], _),
    metta_add_atom(Second, [=, ['lp-choice'], 43], _),
    format(string(Source), '(= (package backing) (lp-space ~w (lp-choice)))\n\c
                           (= (package backing) (lp-space ~w (lp-choice)))', [First,Second]),
    lp_package(first, Source, Path, Home), lp_import(Path, Home),
    lp_answers(Home, ['lp-choice'], [42]),
    metta_host_stored(Home, [available, ['lp-space', Second, ['lp-choice']]]).

test(an_unused_native_alternative_need_not_exist) :-
    lp_package(alternative,
        "(= (package backing) (prolog \"first.pl\" (lp_native_alternative)))\n\c
         (= (package backing) (prolog \"absent.pl\" (lp_native_alternative)))", Path, Home),
    lp_adjacent(Path, 'first.pl', "lp_native_alternative(42).", _),
    lp_import(Path, Home), lp_answers(Home, [lp_native_alternative], [42]).

test(backing_lives_and_retires_in_its_home) :-
    lp_package(home, "(= (package backing) (prolog \"native.pl\" (lp_native_home)))", Path, Home),
    lp_adjacent(Path, 'native.pl', "lp_native_home(X,Y) :- Y is X*2.", _),
    lp_import(Path, Home),
    metta_engine:metta_reference_prolog_head(Home, lp_native_home, 2),
    lp_answers(Home, [lp_native_home, 21], [42]),
    metta_unimport(Home, Path), lp_answers(Home, [lp_native_home, 21], Values),
    \+ memberchk(42, Values), metta_engine:space_module(Home, Module),
    call(Module:lp_native_home(21, 42)).

test(backing_in_self_retires_registration_without_unloading_the_host) :-
    lp_package(self_backing,"(= (package backing) (prolog \"native.pl\" (lp_native_self)))",Path,_),
    lp_adjacent(Path,'native.pl',
        ":- module(lp_native_self,[lp_native_self/1]).\nlp_native_self(42).",_),
    lp_import(Path,'&self'),lp_answers('&self',[lp_native_self],[42]),
    metta_unimport('&self',Path),lp_answers('&self',[lp_native_self],Values),
    \+ memberchk(42,Values),lp_native_self:lp_native_self(42).

test(variable_heads_take_the_export_declaration) :-
    lp_package(variable, "(= (package backing) (prolog \"native.pl\" $heads))", Path, Home),
    lp_adjacent(Path, 'native.pl',
        ":- module(lp_native_variable, [lp_native_variable/1]).\nlp_native_variable(42).", _),
    lp_import(Path, Home), lp_answers(Home, [lp_native_variable], [42]).

test(segment_heads_require_the_prefix_and_take_remaining_exports) :-
    lp_package(segment,
        "(= (package backing) (prolog \"native.pl\" (lp_native_segment (:seg $rest))))", Path, Home),
    lp_adjacent(Path, 'native.pl',
        ":- module(lp_native_segment, [lp_native_segment/1, lp_native_rest/1]).\n\c
         lp_native_segment(42).\nlp_native_rest(43).", _),
    lp_import(Path, Home), lp_answers(Home, [lp_native_segment], [42]),
    lp_answers(Home, [lp_native_rest], [43]).

test(contracts_refuse_before_native_directives) :-
    lp_package(contract,
        "(: lp_native_contract (-> String String))\n\c
         (= (package backing) (prolog \"native.pl\" (lp_native_contract)))", Path, Home),
    lp_adjacent(Path, 'native.pl',
        ":- module(lp_native_contract, [lp_native_contract/2]).\n\c
         :- metta_export(\"(: lp_native_contract (-> Number Number))\").\n\c
         :- package_laws_support:lp_acquire(native_directive, _).\n\c
         lp_native_contract(X,X).", _),
    lp_throws(lp_import(Path, Home), type_error(package_backing_arrow(lp_native_contract, _), _)),
    lp_events([]).

test(equation_and_backing_at_the_same_arity_refuse) :-
    lp_package(collision,
        "(= (lp_native_collision $x) $x)\n\c
         (= (package backing) (prolog \"native.pl\" (lp_native_collision)))", Path, Home),
    lp_adjacent(Path, 'native.pl', "lp_native_collision(X,X).", _),
    lp_throws(lp_import(Path, Home), permission_error(register, package_tier_collision, lp_native_collision/1)).

test(backing_answer_spaces_merge_through_from) :-
    'new-space'(Returned), metta_add_atom(Returned, ['=', ['lp-returned'], 42], _),
    format(string(Text), '(= (package backing) (lp-space ~w ()))', [Returned]),
    lp_package(returned, Text, Path, Home), lp_import(Path, Home),
    lp_answers(Home, ['lp-returned'], [42]).

test(backing_receipts_retain_the_actual_answer) :-
    lp_package(receipt, "(= (package backing) (lp-resource receipt ()))", Path, Home),
    lp_import(Path, Home),
    metta_host_stored(Home, [performed, ['lp-resource', receipt, []], [handle, receipt]]).

test(boot_runs_in_source_order_and_releases_in_reverse) :-
    lp_package(order,
        "(= (package boot) (lp-resource first ()))\n\c
         (= (package boot) (lp-resource second ()))", Path, Home),
    lp_import(Path, Home),
    metta_host_stored(Home, [performed, ['lp-resource', second, []], [handle, second]]),
    metta_unimport(Home, Path),
    lp_events([acquire(first), acquire(second), release(second), release(first)]).

test(all_boot_rows_are_validated_before_any_effect) :-
    lp_package(validate,
        "(= (package backing) (lp-resource backing ()))\n\c
         (= (package boot) (lp-resource first ()))\n\c
         (= (package boot) (lp-unknown later ()))", Path, Home),
    lp_throws(lp_import(Path, Home), existence_error(package_claim, _)), lp_events([]).

test(boot_types_are_checked_before_effects) :-
    lp_package(types,
        "(: lp-resource (-> Number Expression Atom))\n\c
         (= (package boot) (lp-resource \"wrong\" ()))", Path, Home),
    lp_throws(lp_import(Path, Home), type_error(package_boot_signature('lp-resource', _), _)),
    lp_events([]).

test(boot_failure_releases_every_successful_acquisition) :-
    lp_package(failure,
        "(= (package boot) (lp-resource first ()))\n\c
         (= (package boot) (lp-resource fail ()))", Path, Home),
    lp_throws(lp_import(Path, Home), lp_acquire_failed),
    lp_events([acquire(first), acquire(fail), release(first)]),
    \+ filereader:metta_source_load(Path, Home, _, _).

test(one_release_failure_does_not_abandon_other_handles) :-
    lp_package(release,
        "(= (package boot) (lp-resource first ()))\n\c
         (= (package boot) (lp-resource release_fail ()))", Path, Home),
    lp_import(Path, Home),
    lp_throws(metta_unimport(Home, Path), package_release_errors(exit, _)),
    lp_events([acquire(first), acquire(release_fail), release(release_fail), release(first)]).

test(failed_replacement_preserves_the_previous_source_and_handles) :-
    lp_package(replace, "(= (package boot) (lp-resource old ()))", Path, Home),
    lp_import(Path, Home),
    lp_write(Path, "(= (package boot) (lp-resource new ()))\n(= (package boot) (lp-resource fail ()))"),
    lp_throws(lp_import(Path, Home), lp_acquire_failed),
    metta_host_stored(Home, [performed, ['lp-resource', old, []], [handle, old]]),
    lp_events([acquire(old), acquire(new), acquire(fail), release(new)]),
    metta_unimport(Home, Path), lp_event(release(old)).

test(boot_refuses_lazy_admission) :-
    lp_package(lazy, "(= (package boot) (lp-resource lazy ()))", Path, Home),
    assertz(metta_engine:metta_reference_space_option(Home, load, lazy)),
    lp_throws(lp_import(Path, Home), permission_error(lazy, package_boot, Path)), lp_events([]).

test(from_refuses_boot_before_lazy_or_background_submission) :-
    forall(member(Policy,[lazy,background]),
        ( lp_package(from_boot,"(= (package boot) (lp-resource forbidden ()))",Path,_),
          'new-space'(Receiver),metta_engine:space_module(Receiver,Module),
          metta_engine:with_metta_module(Module,metta_engine:'pragma!'(load,Policy,_)),
          lp_throws(metta_add_atom(Receiver,[from,Path],_),permission_error(non_eager,package_boot,Path)),
          lp_events([]),metta_engine:metta_release_space(Receiver) )).

test(import_never_runs_setup) :-
    lp_package(offline, "(= (package setup) (lp-resource setup ()))", Path, Home),
    lp_import(Path, Home), lp_events([]).

test(computed_versions_refuse) :-
    lp_package(version, "(= (package version) (+ 1 2))", Path, Home),
    lp_throws(lp_import(Path, Home), domain_error(package_constant_version, [+,1,2])).

test(relative_requirements_are_loaded_before_boot) :-
    lp_package(relative,
        "(= (package requires) \"dependency.metta\")\n(= (package boot) (lp-resource parent ()))", Path, Home),
    lp_adjacent(Path, 'dependency.metta',
        "(= (package boot) (lp-resource dependency ()))", _),
    lp_import(Path, Home), lp_events([acquire(dependency), acquire(parent)]).

test(requirement_cycles_refuse_with_the_path) :-
    lp_package(cycle, "(= (package requires) \"dependency.metta\")", Path, Home),
    lp_adjacent(Path, 'dependency.metta', "(= (package requires) \"main.metta\")", _),
    lp_throws(lp_import(Path, Home), permission_error(load, package_cycle, _)).

test(pending_requirements_expose_cycles_outside_their_transaction) :-
    lp_package(pending,"(= (package requires) \"child.metta\")",Path,Home),
    lp_adjacent(Path,'child.metta',"(= (package boot) (lp-wait pending_cycle))",Child),
    message_queue_create(Ready),message_queue_create(Continue),
    assertz(package_laws_support:lp_gate(pending_cycle,Ready,Continue),Gate),
    setup_call_cleanup(
        thread_create(transaction(lp_import(Path,Home)),Worker,[]),
        (thread_get_message(Ready,entered),
         lp_throws(packages:package_check_cycle(Child,Path),permission_error(load,package_cycle,_))),
        (thread_send_message(Continue,continue),thread_join(Worker,Status),erase(Gate),
         message_queue_destroy(Ready),message_queue_destroy(Continue))),
    Status == true,\+ packages:package_pending_requirement(Path,_).

test(missing_artifact_names_setup_as_the_remedy) :-
    lp_package(missing, "(= (package backing) (prolog \"absent.pl\" (lp_missing)))", Path, Home),
    catch(lp_import(Path, Home), Error, true), nonvar(Error),
    Error = error(existence_error(source_sink, _), context(_, Remedy)),
    once(sub_atom(Remedy, _, _, _, 'setup!')).

test(offline_git_requires_a_lock) :-
    lp_package(git,
        "(= (package requires) (git \"https://example.invalid/package.git\" \"1111111111111111111111111111111111111111\"))", Path, Home),
    lp_throws(lp_import(Path, Home), existence_error(package_requirement, [git,_,_])),
    file_directory_name(Path, Directory), directory_file_path(Directory, repos, Repos),
    \+ exists_directory(Repos).

test(claims_are_reflected_by_the_two_input_property_door) :-
    findall(Claim, eval(['get-property', perform, claims], Claim), Claims),
    memberchk([prolog,_,_], Claims), memberchk(['lp-resource',_,_], Claims).

test(a_required_library_can_replace_the_interpreter) :-
    lp_package(interpreter,
        "(= (package requires) \"interpreter.metta\")\n\c
         (= (package boot) (lp-unknown ignored ()))", Path, Home),
    lp_adjacent(Path, 'interpreter.metta',
        "(= (package-load $path $home $rows) (add-atom $home (custom-interpreter)))", _),
    lp_import(Path, Home), metta_host_stored(Home, ['custom-interpreter']).

lp_setup_fixture(Name, Text, Path, Home, Output) :-
    lp_package(Name, "", Path, Home),
    file_directory_name(Path, Directory), directory_file_path(Directory, 'output.pl', Artifact),
    atom_string(Artifact, Output),
    format(string(Source), '(= (package setup) (lp-prepare ~q ~q))', [Output, Text]),
    lp_write(Path, Source).

test(setup_receipts_reuse_unchanged_work) :-
    lp_setup_fixture(reuse, "ready", Path, _, Output),
    packages:'setup!'(Path, true), packages:'setup!'(Path, true),
    lp_events([prepare(Output, "ready")]),
    file_directory_name(Path, Directory), directory_file_path(Directory, 'performed.metta', Receipt),
    packages:package_read_rows(Receipt, [[performed, ['lp-prepare', Output, "ready"], done]]).

test(changed_setup_rows_invalidate_receipts) :-
    lp_setup_fixture(changed, "first", Path, _, Output),
    packages:'setup!'(Path, true),
    format(string(Next), '(= (package setup) (lp-prepare ~q "second"))', [Output]),
    lp_write(Path, Next), packages:'setup!'(Path, true),
    lp_events([prepare(Output,"first"), prepare(Output,"second")]).

test(missing_backing_artifacts_invalidate_receipts) :-
    lp_setup_fixture(artifact, "lp_setup_artifact(42).", Path, _, Output),
    format(string(Source), '(= (package setup) (lp-prepare ~q "lp_setup_artifact(42)."))\n\c
                           (= (package backing) (prolog ~q (lp_setup_artifact)))', [Output,Output]),
    lp_write(Path, Source), packages:'setup!'(Path, true), delete_file(Output),
    packages:'setup!'(Path, true),
    lp_events([prepare(Output,_), prepare(Output,_)]), exists_file(Output).

test(failed_setup_does_not_publish_a_receipt) :-
    lp_setup_fixture(setup_fail, "fail", Path, _, _),
    lp_throws(packages:'setup!'(Path, _), lp_prepare_failed),
    file_directory_name(Path, Directory), directory_file_path(Directory, 'performed.metta', Receipt),
    \+ exists_file(Receipt).

test(setup_lock_contains_transitive_resolved_requirements) :-
    lp_package(lock, "(= (package requires) \"dependency.metta\")", Path, _),
    lp_adjacent(Path, 'dependency.metta', "(= (package requires) \"leaf.metta\")", Dependency),
    lp_adjacent(Path, 'leaf.metta', "(= (package version) \"1\")", Leaf),
    packages:'setup!'(Path, true),
    file_directory_name(Path, Directory), directory_file_path(Directory, 'lock.metta', Lock),
    packages:package_read_rows(Lock, Rows),
    memberchk([requires,"dependency.metta",Dependency], Rows),
    memberchk([requires,"leaf.metta",Leaf], Rows).

test(a_failed_parent_preserves_a_successful_dependency) :-
    lp_package(dependency_lifetime,
        "(= (package requires) \"dependency.metta\")\n\c
         (= (package boot) (lp-resource fail ()))", Path, Home),
    lp_adjacent(Path, 'dependency.metta', "(= (package boot) (lp-resource dependency_alive ()))", Child),
    lp_throws(lp_import(Path, Home), lp_acquire_failed),
    lp_events([acquire(dependency_alive), acquire(fail)]),
    filereader:metta_source_load(Child, Home, _, _),
    metta_unimport(Home, Child), lp_event(release(dependency_alive)).

test(failure_with_a_failed_release_still_withdraws_the_source) :-
    lp_package(cleanup_failure,
        "(= (package boot) (lp-resource release_fail ()))\n\c
         (= (package boot) (lp-resource fail ()))", Path, Home),
    lp_throws(lp_import(Path, Home), package_release_errors(exception(error(lp_acquire_failed,_)), _)),
    \+ filereader:metta_source_load(Path, Home, _, _), lp_event(release(release_fail)).

test(space_release_closes_its_package_handles) :-
    lp_package(space_release, "(= (package boot) (lp-resource space_lifetime ()))", Path, Home),
    lp_import(Path, Home), metta_engine:metta_release_space(Home),
    lp_events([acquire(space_lifetime), release(space_lifetime)]).

test(computed_rows_preserve_every_answer) :-
    lp_package(union,
        "(= (lp-union-row) (lp-resource union_first ()))\n\c
         (= (lp-union-row) (lp-resource union_second ()))\n\c
         (= (package boot) (lp-union-row))", Path, Home),
    lp_import(Path, Home), lp_events([acquire(union_first), acquire(union_second)]).

test(normalisation_refuses_state_writes_before_they_happen) :-
    lp_package(no_writes,
        "(= (lp-write-row) (let $_ (add-atom &self (lp-illegal-write)) (lp-resource never ())))\n\c
         (= (package boot) (lp-write-row))", Path, Home),
    lp_throws(lp_import(Path, Home), permission_error(normalise, package_row, _)),
    \+ metta_host_stored(Home, ['lp-illegal-write']), lp_events([]).

test(normalisation_allows_space_reads_and_checks_the_match_body) :-
    lp_package(reads,
        "(lp-read-fact 42)\n\c
         (= (lp-read-row) (match &self (lp-read-fact $n) (lp-resource $n ())))\n\c
         (= (package boot) (lp-read-row))", Path, Home),
    lp_import(Path, Home), lp_events([acquire(42)]).

test(setup_dependencies_supply_computed_rows_without_booting) :-
    lp_setup_fixture(computed_setup, "prepared", Path, _, Output),
    format(string(Dependency), '(= (lp-setup-row) (lp-prepare ~q "prepared"))\n\c
                              (= (package boot) (lp-resource must_not_boot ()))', [Output]),
    lp_adjacent(Path, 'dependency.metta', Dependency, _),
    lp_write(Path, "(= (package requires) \"dependency.metta\")\n(= (package setup) (lp-setup-row))"),
    packages:'setup!'(Path, true), lp_events([prepare(Output,"prepared")]).

test(duplicate_setup_rows_remain_distinct_and_invalidate_on_removal) :-
    lp_setup_fixture(duplicates, "twice", Path, _, Output),
    read_file_to_string(Path, One, []), string_concat(One, "\n", Line),
    string_concat(Line, One, Two), lp_write(Path, Two),
    packages:'setup!'(Path, true), packages:'setup!'(Path, true),
    lp_events([prepare(Output,"twice"), prepare(Output,"twice")]),
    lp_write(Path, One), packages:'setup!'(Path, true),
    lp_events([prepare(Output,"twice"), prepare(Output,"twice"), prepare(Output,"twice")]).

test(setup_holds_an_os_lock_until_its_claimant_finishes) :-
    lp_package(os_lock, "", Path, _), file_directory_name(Path, Directory),
    atom_string(Directory, Text),
    format(string(Source), '(= (package setup) (lp-lock ~q))', [Text]), lp_write(Path, Source),
    eval(['setup!', Path], true), lp_events([os_lock(locked)]),
    lp_probe_lock(Directory, unlocked).

test(catalog_rows_and_catalog_spaces_resolve_requirements) :-
    lp_package(catalog, "(= (package requires) lp_catalog_child)", Path, Home),
    lp_adjacent(Path, 'child.metta', "(= (lp-catalog-value) 42)", Child),
    'new-space'(Catalog), metta_add_atom(Catalog, [package,lp_catalog_child,Child], _),
    metta_add_atom('&catalogs', [catalog,Catalog], _),
    setup_call_cleanup(true,
        (lp_import(Path,Home), lp_answers(Home,['lp-catalog-value'],[42])),
        metta_engine:'remove-atom'('&catalogs',[catalog,Catalog],_)).

test(catalog_aliases_with_equal_digests_load_once) :-
    lp_package(alias, "(= (package requires) lp_catalog_alias)", Path, Home),
    lp_adjacent(Path, 'one.metta', "(= (package boot) (lp-resource alias_once ()))", One),
    lp_adjacent(Path, 'two.metta', "(= (package boot) (lp-resource alias_once ()))", Two),
    metta_add_atom('&catalogs', [package,lp_catalog_alias,One], _),
    metta_add_atom('&catalogs', [package,lp_catalog_alias,Two], _),
    lp_import(Path,Home), lp_events([acquire(alias_once)]).

test(catalog_aliases_with_different_digests_refuse) :-
    lp_package(alias_conflict, "(= (package requires) lp_catalog_conflict)", Path, Home),
    lp_adjacent(Path, 'one.metta', "(= (lp-conflict-value) 1)", One),
    lp_adjacent(Path, 'two.metta', "(= (lp-conflict-value) 2)", Two),
    metta_add_atom('&catalogs', [package,lp_catalog_conflict,One], _),
    metta_add_atom('&catalogs', [package,lp_catalog_conflict,Two], _),
    lp_throws(lp_import(Path,Home), permission_error(resolve,package_identity,lp_catalog_conflict)).

lp_git_seed(Path, Url, Revision) :-
    file_directory_name(Path, Directory), gensym(lp_git_repository_, Name),
    directory_file_path(Directory, Name, Repository), make_directory(Repository),
    % A checkout is entered through pkg.metta, like every other package. This
    % seeded <repository-name>.metta, which package_checkout_entry/4 accepted
    % as a second candidate until the manifest became the one way in; it now
    % throws existence_error(package_manifest, _) and both git tests failed
    % on a fixture rather than on the behaviour they name.
    File = 'pkg.metta', directory_file_path(Repository, File, Source),
    lp_write(Source, "(= (lp-git-value) 42)"),
    lp_process(path(git), ['-C',Repository,init,'-q'], _),
    lp_process(path(git), ['-C',Repository,add,'--',File], _),
    lp_process(path(git), ['-C',Repository,'-c','user.name=Package fixture',
                          '-c','user.email=a.mesto@student.unsw.edu.au',
                          commit,'-q','-m','Package fixture'], _),
    lp_process(path(git), ['-C',Repository,'rev-parse', 'HEAD'], Sha),
    normalize_space(atom(Revision), Sha), atom_string(Repository, Url).

test(setup_pins_git_and_a_fresh_import_spawns_nothing) :-
    lp_package(git_setup, "", Path, _), lp_git_seed(Path, Url, Revision),
    atom_string(Revision, Sha),
    format(string(Source), '(= (package requires) (git ~q ~q))', [Url,Sha]), lp_write(Path, Source),
    eval(['setup!',Path],true),
    file_directory_name(Path, Directory), directory_file_path(Directory,'lock.metta',Lock),
    packages:package_read_rows(Lock, Rows), memberchk([requires,[git,Url,Sha],Locked],Rows), exists_file(Locked),
    source_file(package_laws_support:lp_install, Support),
    format(atom(Goal),
        'use_module(~q),use_module(library(prolog_wrap)),use_module(library(process)),filereader:metta_host_set_silent(true),wrap_predicate(process:process_create(A,B,C),forbid_spawn,_,throw(error(unexpected_package_spawn,A-B-C))),metta_engine:''import!''(''&self'',~q,_),findall(V,metta_engine:eval([''lp-git-value''],V),Vs),writeln(Vs)',
        [Support,Path]),
    lp_process(path(swipl), ['-q','-g',Goal,'-t',halt], Output),
    once(sub_string(Output,_,_,_,"[42]")).

test(two_requirers_cannot_pin_different_revisions_of_one_name) :-
    lp_package(pin_conflict, "", Path, _), lp_git_seed(Path, Url, Revision),
    atom_string(Revision,Sha),
    lp_adjacent(Path,'a.metta',"", A), lp_adjacent(Path,'b.metta',"", B),
    format(string(First),'(= (package requires) (git ~q ~q))',[Url,Sha]), lp_write(A,First),
    format(string(Second),'(= (package requires) (git ~q "1111111111111111111111111111111111111111"))',[Url]), lp_write(B,Second),
    lp_write(Path,"(= (package requires) \"a.metta\")\n(= (package requires) \"b.metta\")"),
    catch(eval(['setup!',Path],_),Error,true), nonvar(Error),
    Error = error(domain_error(conflicting_package_pin,_), context(_,pins(A-_-_,B-_-_))).

test(native_export_declarations_do_not_leak_hidden_arities) :-
    lp_package(arity, "(= (package backing) (prolog \"native.pl\" (lp_native_arity)))",Path,Home),
    lp_adjacent(Path,'native.pl',
        ":- module(lp_native_arity,[lp_native_arity/1]).\n\c
         lp_native_arity(42).\nlp_native_arity(_,43).",_),
    lp_import(Path,Home), lp_answers(Home,[lp_native_arity],[42]),
    lp_throws(lp_answers(Home,[lp_native_arity,9],_),domain_error(function_input_arities(lp_native_arity,[0]),1)).

test(native_export_declarations_refuse_unexported_names) :-
    lp_package(private_export,
        "(= (package backing) (prolog \"native.pl\" (lp_private_native)))", Path, Home),
    lp_adjacent(Path, 'native.pl',
        ":- module(lp_private_native,[lp_public_native/1]).\n\c
         lp_public_native(42).\nlp_private_native(99).", _),
    lp_throws(lp_import(Path, Home), existence_error(procedure, lp_private_native)).

test(unselected_native_exports_leave_equation_heads_free) :-
    forall(member(Kind, [module, plain]),
        ( lp_package(selective,
              "(= (package backing) (prolog \"native.pl\" (lp_selected_native)))", Path, Home),
          ( Kind == module
          -> Header = ":- module(lp_selective_native,[lp_selected_native/1,lp_unused_native/1]).\n"
          ; Header = "" ),
          string_concat(Header, "lp_selected_native(42).\nlp_unused_native(99).", Native),
          lp_adjacent(Path, 'native.pl', Native, _), lp_import(Path, Home),
          metta_add_atom(Home, ['=', [lp_unused_native], 43], _),
          lp_answers(Home, [lp_selected_native], [42]),
          lp_answers(Home, [lp_unused_native], [43]) )).

test(backings_must_supply_contracts_for_the_heads_they_name) :-
    lp_package(no_contract,"(= (package backing) (lp-resource no_contract (lp_not_exported)))",Path,Home),
    lp_throws(lp_import(Path,Home),existence_error(package_export_contract,_)),lp_events([]).

test(native_names_owned_by_a_requirement_refuse_before_directives) :-
    lp_package(taken,
        "(= (package requires) \"child.metta\")\n\c
         (= (package backing) (prolog \"second.pl\" (lp_native_taken)))",Path,Home),
    lp_adjacent(Path,'child.metta',
        "(= (package backing) (prolog \"first.pl\" (lp_native_taken)))",_),
    lp_adjacent(Path,'first.pl',"lp_native_taken(42).",First),
    lp_adjacent(Path,'second.pl',
        ":- package_laws_support:lp_acquire(forbidden_directive,_).\nlp_native_taken(43).",_),
    lp_throws(lp_import(Path,Home),metta_name_owned_by_source(lp_native_taken,First)),
    lp_events([]),lp_answers(Home,[lp_native_taken],[42]).

test(an_already_loaded_artifact_can_register_its_own_heads) :-
    lp_package(native_reuse,"(= (package backing) (prolog \"native.pl\" (lp_native_reuse)))",Path,Home),
    lp_adjacent(Path,'native.pl',
        ":- module(lp_native_reuse,[lp_native_reuse/1]).\nlp_native_reuse(42).",File),
    metta_engine:metta_self_module(Base), Base:use_module(File),
    lp_import(Path,Home),lp_answers(Home,[lp_native_reuse],[42]).

test(explicit_export_arities_are_native_contracts) :-
    lp_package(export_arity,"(= (package backing) (prolog \"native.pl\" $heads))",Path,Home),
    lp_adjacent(Path,'native.pl',
        ":- metta_export(\"(export lp_native_explicit 0)\").\nlp_native_explicit(42).",_),
    lp_import(Path,Home),lp_answers(Home,[lp_native_explicit],[42]).

test(each_declared_arrow_matches_its_native_arity) :-
    lp_package(overloaded,
        "(: lp_native_overloaded (-> Number))\n\c
         (: lp_native_overloaded (-> Number Number))\n\c
         (= (package backing) (prolog \"native.pl\" (lp_native_overloaded)))",Path,Home),
    lp_adjacent(Path,'native.pl',
        ":- module(lp_native_overloaded,[lp_native_overloaded/1,lp_native_overloaded/2]).\n\c
         lp_native_overloaded(42).\nlp_native_overloaded(X,X).",_),
    lp_import(Path,Home),lp_answers(Home,[lp_native_overloaded],[42]),
    lp_answers(Home,[lp_native_overloaded,43],[43]).

test(equation_and_native_arities_share_a_head_without_colliding) :-
    lp_package(mixed_arity,
        "(: lp_native_mixed (-> Number))\n(= (lp_native_mixed) 41)\n\c
         (: lp_native_mixed (-> Number Number))\n\c
         (= (package backing) (prolog \"native.pl\" (lp_native_mixed)))",Path,Home),
    lp_adjacent(Path,'native.pl',"lp_native_mixed(X,X).",_),
    lp_import(Path,Home),lp_answers(Home,[lp_native_mixed],[41]),
    lp_answers(Home,[lp_native_mixed,42],[42]).

test(backing_repairs_preceding_equations_before_the_next_runnable) :-
    lp_package(late_backing,
        "!(import! &self \"child.metta\")\n!(test (lp-late-wrapper 21) 42)",Path,Home),
    lp_adjacent(Path,'child.metta',
        "(= (lp-late-wrapper $x) (lp_late_native $x))\n\c
         (= (package backing) (prolog \"native.pl\" (lp_late_native)))",_),
    lp_adjacent(Path,'native.pl',"lp_late_native(X,Y) :- Y is X*2.",_),
    lp_import(Path,Home),lp_answers(Home,['lp-late-wrapper',21],[42]).

test(empty_export_declarations_are_valid_signatures) :-
    lp_package(empty_exports,"(= (package backing) (prolog \"native.pl\" $heads))",Path,Home),
    lp_adjacent(Path,'native.pl',":- module(lp_native_empty,[]).",_),
    lp_import(Path,Home),metta_host_stored(Home,[performed,[prolog,_,[]],true]).

test(partially_overlapping_backings_only_merge_their_unselected_heads) :-
    'new-space'(First),'new-space'(Second),
    metta_add_atom(First,[=,['lp-overlap'],42],_),
    metta_add_atom(Second,[=,['lp-overlap'],43],_),
    metta_add_atom(Second,[=,['lp-fresh'],44],_),
    format(string(Source),'(= (package backing) (lp-space ~w (lp-overlap)))\n\c
                           (= (package backing) (lp-space ~w (lp-overlap lp-fresh)))',[First,Second]),
    lp_package(overlap,Source,Path,Home),lp_import(Path,Home),
    lp_answers(Home,['lp-overlap'],[42]),lp_answers(Home,['lp-fresh'],[44]),
    metta_host_stored(Home,[available,['lp-space',Second,['lp-overlap']]]).

test(ordinary_contract_equations_describe_an_attached_claimant) :-
    'new-space'(Artifact),metta_add_atom(Artifact,[=,['lp-contract-equation'],42],_),
    metta_add_atom(Artifact,[=,['lp-contract-private'],43],_),
    format(string(Claims),
        '(= (package-contract (lp-contract-symbol fixture $heads)) (quote ((: lp-contract-equation (-> Number)))))\n\c
         (= (perform (lp-contract-symbol fixture $heads)) ~w)',[Artifact]),
    filereader:process_loader_string(Claims,_,'&metta'),
    lp_package(contract_equation,
        "(= (package backing) (lp-contract-symbol fixture $heads))",Path,Home),
    lp_import(Path,Home),lp_answers(Home,['lp-contract-equation'],[42]),
    lp_answers(Home,['lp-contract-private'],Private), \+ memberchk(43,Private).

test(a_claimed_backing_cannot_succeed_without_installing_its_heads) :-
    filereader:process_loader_string(
        "(= (package-contract (lp-empty-backing fixture $heads)) (quote ((: lp-missing-export (-> Number)))))\n\c
         (= (perform (lp-empty-backing fixture $heads)) true)", _, '&metta'),
    lp_package(empty_backing,
        "(= (package backing) (lp-empty-backing fixture (lp-missing-export)))", Path, Home),
    lp_throws(lp_import(Path, Home), existence_error(package_export, 'lp-missing-export')),
    \+ filereader:metta_source_load(Path, Home, _, _).

test(successful_replacement_retires_the_old_handles_after_activation) :-
    lp_package(successful_replace,"(= (package boot) (lp-resource previous ()))",Path,Home),
    lp_import(Path,Home),lp_write(Path,"(= (package boot) (lp-resource replacement ()))"),
    lp_import(Path,Home),lp_events([acquire(previous),acquire(replacement),release(previous)]),
    metta_unimport(Home,Path),lp_event(release(replacement)).

test(every_performer_answer_is_receipted_and_released) :-
    filereader:process_loader_string(
        "(= (perform (lp-many)) (superpose ((lp_acquire many_first) (lp_acquire many_second))))\n\c
         (= (release (lp-many) (handle $id)) (lp_release $id (handle $id)))",_,'&metta'),
    lp_package(many,"(= (package boot) (lp-many))",Path,Home),lp_import(Path,Home),
    findall(Row,metta_host_stored(Home,[performed,['lp-many'],Row]),Answers),
    lp_policy(Policy),lp_answers(Policy,['package-fixture-record',['lp-many'],Answers],[Expected]),
    findall([performed,['lp-many'],Answer],metta_host_stored(Home,[performed,['lp-many'],Answer]),Expected),
    Answers=[[handle,many_first],[handle,many_second]],
    metta_unimport(Home,Path),
    lp_events([acquire(many_first),acquire(many_second),release(many_second),release(many_first)]).

test(setup_reuses_receipts_with_multiple_answers) :-
    filereader:process_loader_string(
        "(= (perform (lp-many-setup)) (superpose ((lp_acquire setup_first) (lp_acquire setup_second))))",_,'&metta'),
    lp_package(many_setup,"(= (package setup) (lp-many-setup))",Path,_),
    packages:'setup!'(Path,true),packages:'setup!'(Path,true),
    lp_events([acquire(setup_first),acquire(setup_second)]),
    file_directory_name(Path,Directory),directory_file_path(Directory,'performed.metta',Receipt),
    packages:package_read_rows(Receipt,
        [[performed,['lp-many-setup'],[handle,setup_first]],[performed,['lp-many-setup'],[handle,setup_second]]]).

test(space_read_bodies_cannot_hide_state_writes) :-
    lp_package(match_write,
        "(lp-match-fact 42)\n\c
         (= (lp-match-write) (match &self (lp-match-fact $n) (add-atom &self (lp-forbidden $n))))\n\c
         (= (package boot) (lp-match-write))",Path,Home),
    lp_throws(lp_import(Path,Home),permission_error(normalise,package_row,_)),
    \+ metta_host_stored(Home,['lp-forbidden',_]).

test(metta_fixture_predicts_first_claimed_backings) :-
    lp_policy(Policy),
    forall((member(T1,['lp-space','lp-absent']),member(T2,['lp-space','lp-absent'])),
        ( 'new-space'(First),'new-space'(Second),
          metta_add_atom(First,[=,['lp-fixture-value'],41],_),
          metta_add_atom(Second,[=,['lp-fixture-value'],42],_),
          Rows=[[T1,First,['lp-fixture-value']],[T2,Second,['lp-fixture-value']]],
          lp_answers(Policy,['package-fixture-choice','lp-fixture-value',Rows,['lp-space']],[Choice]),
          maplist(swrite,Rows,Texts),Texts=[A,B],
          format(string(Source),'(= (package backing) ~s)\n(= (package backing) ~s)',[A,B]),
          lp_package(fixture,Source,Path,Home),
          ( Choice == absent
          -> lp_throws(lp_import(Path,Home),existence_error(package_backing,['lp-fixture-value']))
          ; Choice=[_,Chosen,_],lp_import(Path,Home),
            lp_answers(Chosen,['lp-fixture-value'],Expected),lp_answers(Home,['lp-fixture-value'],Expected) ) )).

test(package_lifetime_sweeps_lengths_and_failure_positions) :-
    lp_policy(Policy),
    forall(between(0,7,N),
        forall(between(0,N,FailAt),
            ( findall(I,between(1,N,I),All),
              ( FailAt == 0 -> Ids = All, Kept = All
              ; Before is FailAt-1, length(Kept,Before), append(Kept,_,All), append(Kept,[fail],Ids) ),
              findall(Line,(member(Id,Ids),format(string(Line),'(= (package boot) (lp-resource ~w ()))',[Id])),Lines),
              atomics_to_string(Lines,"\n",Source), lp_package(sweep,Source,Path,Home),
              ( FailAt == 0 -> lp_import(Path,Home),metta_unimport(Home,Path)
              ; lp_throws(lp_import(Path,Home),lp_acquire_failed) ),
              findall(acquire(Id),member(Id,Ids),Acquired),
              lp_answers(Policy,['package-fixture-reverse',Kept,[]],[Reverse]),
              findall(release(Id),member(Id,Reverse),Released), append(Acquired,Released,Expected), lp_events(Expected) ))).

% The unary equation calls a binary overload supplied by its native backing.
% Silent loading defers translation; verbose loading compiles before the
% backing arrives and therefore needs its self-call dependency repaired.
% Aliases install a separate dependency recorder, which owes the same edge.
% Fresh names keep the global arity registry from letting one case mask another.
% The deferred marker also proves the backing's ownership probe did not force
% translation; repaired answers alone cannot detect that probe's side effect.
test(a_backing_row_registers_before_the_equations_calling_it_translate,
     [forall((member(Silent, [false, true]), member(Aliased, [false, true]))),
      setup(filereader:silent(Previous)),
      cleanup(filereader:metta_host_set_silent(Previous))]) :-
    gensym('lp-native-pair-', Name),
    ( Aliased == true
    -> Prefix = "(: PairNumber (Alias Number))\n", Type = 'PairNumber'
    ; Prefix = "", Type = 'Number' ),
    format(string(Source),
        "~s(: ~w (-> ~w ~w))\n\c
         (= (~w $v) (~w $v 1))\n\c
         (= (package backing) (prolog \"native.pl\" (~w)))\n\c
         (: ~w (-> ~w ~w ~w))\n",
        [Prefix, Name, Type, Type, Name, Name, Name, Name, Type, Type, Type]),
    lp_package(reentrant, Source, Path, Home),
    format(string(Native), '~q(X, Y, Z) :- Z is X + Y.', [Name]),
    lp_adjacent(Path, 'native.pl', Native, _),
    setup_call_cleanup(
        filereader:metta_host_set_silent(Silent),
        ( lp_import(Path, Home),
          space_module(Home, Module),
          ( Silent == true
          -> assertion(spaces:deferred_metta_function(Name, Module, Home, 1, _, 1))
          ; true ),
          findall(A, metta_engine:arity(Name, A), Arities),
          sort(Arities, Known), assertion(Known == [2,3]),
          forall(between(-3, 3, X),
                 ( Expected is X + 1,
                   lp_answers(Home, [Name, X], [Expected]),
                   lp_answers(Home, [Name, X, 1], [Expected]) )) ),
        metta_release_space(Home)).

:- end_tests(package_laws).
