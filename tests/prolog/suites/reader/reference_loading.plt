% Purpose: verify canonical homes, deferred compilation and background outcomes.
% Owns resources: fixtures release receivers and library homes, join callers,
%   remove loader instrumentation and delete their temporary source files.
% Guarantees: background coordination uses queues, never sleeps or deadlines
%   [tested: reference_loading; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
% Guarantees: fixtures read the loader's live home instead of deriving a
%   reusable address from its source path [tested: reference_loading;
%   commit=WORKTREE].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap)).

:- begin_tests(reference_loading).
:- dynamic loading_gate/1, loading_caller/1, loading_auxiliary/1.

loading_setup(Text) :-
    metta_host_set_silent(true),
    tmp_file(metta, Stem), atom_concat(Stem, '.metta', Path),
    loading_write(Path, Text), metta_engine:metta_reference_home(Path, Home),
    gensym('&reference-loading-', A), gensym('&reference-loading-', B),
    space_module(A, _), space_module(B, _),
    nb_setval(reference_loading_fixture, fixture(Path, Home, A, B)).
loading_fixture(Path, Home, A, B) :-
    nb_getval(reference_loading_fixture, fixture(Path, Home, A, B)).
loading_write(Path, Text) :-
    setup_call_cleanup(open(Path, write, Out, [encoding(utf8)]),
                       format(Out, '~s', [Text]), close(Out)).
loading_cleanup :-
    loading_fixture(Path, Home, A, B),
    maplist(metta_release_space, [B, A, Home]),
    forall(loading_auxiliary(Extra),
           ( ( metta_engine:metta_reference_library_home(ExtraHome, Extra)
             -> metta_release_space(ExtraHome) ; true ),
             ( file_name_extension(_, pl, Extra) -> unload_file(Extra) ; true ),
             delete_file(Extra) )),
    retractall(loading_auxiliary(_)), delete_file(Path),
    nb_delete(reference_loading_fixture), metta_host_set_silent(false).
loading_option(Space, Key, Value) :-
    space_module(Space, Module),
    with_metta_module(Module, 'pragma!'(Key, Value, _)).
loading_answers(Space, Call, Bag) :-
    findall(R, evalc(Call, Space, R), Results), msort(Results, Bag).

test(two_receivers_share_the_canonical_home_and_receipt,
     [setup(loading_setup("(= (loading-value) 42)\n(data stays)\n")),
      cleanup(loading_cleanup)]) :-
    loading_fixture(Path, Home, A, B),
    metta_add_atom(A, [from, Path], _),
    metta_engine:import_receipt(Home, Path, Load, Digest),
    file_directory_name(Path, Dir), file_base_name(Path, Base),
    atomic_list_concat([Dir, '/./', Base], Alias),
    metta_add_atom(B, [from, Alias], _),
    findall(L-D, metta_engine:import_receipt(Home, Path, L, D), Receipts),
    assertion(Receipts == [Load-Digest]),
    loading_answers(A, ['loading-value'], [42]),
    loading_answers(B, ['loading-value'], [42]),
    assertion(\+ get_native_atom(A, [data, stays])).

test(a_digest_change_updates_existing_receivers,
     [setup(loading_setup("(= (loading-value) old)\n")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, Home, A, B), metta_add_atom(A, [from, Path], _),
    metta_engine:import_receipt(Home, Path, Before, _),
    loading_write(Path, "(= (loading-value) new)\n(= (loading-added) 7)\n"),
    metta_add_atom(B, [from, Path], _),
    metta_engine:import_receipt(Home, Path, After, _), assertion(Before \== After),
    loading_answers(A, ['loading-value'], [new]),
    loading_answers(A, ['loading-added'], [7]).

test(lazy_keeps_equations_deferred_until_the_first_call_including_self,
     [setup(loading_setup("(= (loading-self) &self)\n(= (loading-value $x) (+ $x 1))\n")),
      cleanup(loading_cleanup)]) :-
    loading_fixture(Path, Home, A, _), loading_option(A, load, lazy),
    metta_add_atom(A, [from, Path], _),
    assertion(spaces:deferred_metta_function('loading-self', _, Home, _, _, _)),
    assertion(spaces:deferred_metta_function('loading-value', _, Home, _, _, _)),
    loading_answers(A, ['loading-self'], [Home]),
    loading_answers(A, ['loading-value', 41], [42]),
    assertion(\+ spaces:deferred_metta_function('loading-value', _, Home, _, _, _)).

test(lazy_aliases_and_a_union_force_the_defining_head,
     [setup(loading_setup("(= (loading-value) source)\n")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, Home, A, B), loading_option(A, load, lazy),
    metta_add_atom(A, [=, ['renamed-value'], owned], _),
    metta_add_atom(A, [from, Path, [rename, [['loading-value', 'renamed-value']]]], _),
    assertion(spaces:deferred_metta_function('loading-value', _, Home, _, _, _)),
    metta_add_atom(B, [from, A], _),
    loading_answers(B, ['renamed-value'], Bag), assertion(Bag == [owned,source]).

test(demand_keeps_the_compiler_goal_static_and_retires,
     [forall(member(Finish, [call,withdraw,rollback])),
      setup(loading_setup("(= (loading-value) source)\n")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, _, A, _), loading_option(A, load, lazy),
    Row = [from,Path,[prefix,'q.']],
    Check = ( assertion(predicate_property(spaces:metta_ensure_compiled(_), static)),
              assertion(current_predicate_wrapper(spaces:metta_ensure_compiled(_),
                                                   metta_reference_demand, _, _)),
              catch(metta_add_atom(A,[=,[metta_ensure_compiled],captured],_), Error, true),
              assertion(nonvar(Error)),
              assertion(Error = error(metta_engine_goal_redefinition(metta_ensure_compiled,0,A),_)) ),
    ( Finish == rollback
    -> \+ transaction((metta_add_atom(A,Row,_), call(Check), fail))
    ; metta_add_atom(A,Row,_), call(Check),
      ( Finish == call -> loading_answers(A,['q.loading-value'],[source])
      ; once(metta_remove_atom(A,Row,_)) ) ),
    assertion(\+ metta_engine:metta_reference_demand('q.loading-value')),
    assertion(\+ current_predicate_wrapper(spaces:metta_ensure_compiled(_),
                                           metta_reference_demand, _, _)).

test(compiled_head_names_remain_behind_their_type_answer_boundary,
     [setup(loading_setup("(= (get-type (loading-tag)) LoadingType)\n")),
      cleanup(loading_cleanup)]) :-
    loading_fixture(Path, _, A, _), loading_option(A, load, lazy),
    metta_add_atom(A, [from, Path], _),
    loading_answers(A, ['get-type', ['loading-tag']], Bag),
    assertion(memberchk('LoadingType', Bag)).

test(a_lazy_alias_publishes_the_arity_of_a_partial_application_body,
     [setup(loading_setup("(= (loading-partial $x) (+ $x))\n")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, _, A, _), loading_option(A, load, lazy),
    metta_add_atom(A,[from,Path,[prefix,'q.']],_),
    loading_answers(A,['q.loading-partial',2,3],Bag), assertion(Bag == [5]).

test(an_eager_alias_and_native_import_keep_eta_expansion,
     [setup(loading_setup("(= (loading-partial $x) (+ $x))\n")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, Home, A, B),
    metta_add_atom(A, [from,Path,[prefix,'q.']], _),
    loading_answers(A, ['q.loading-partial',2,3], Bag), assertion(Bag == [5]),
    metta_add_atom(B, [from,Path], _),
    space_module(Home, HM), space_module(B, BM),
    assertion(predicate_property(BM:'loading-partial'(_,_,_), imported_from(HM))),
    assertion(\+ metta_engine:metta_reference_demand('q.loading-partial')).

test(a_native_alias_call_forces_a_capturing_lambda_before_retry,
     [setup(loading_setup("(= (loading-closure $x) (|-> ($y) (pair $x $y)))\n")),
      cleanup(loading_cleanup)]) :-
    loading_fixture(Path, _, A, _), loading_option(A, load, lazy),
    metta_add_atom(A, [from,Path,[prefix,'q.']], _), space_module(A, Module),
    findall(R, Module:'q.loading-closure'(2,3,R), Bag),
    assertion(Bag == [[pair,2,3]]),
    loading_answers(A, [['q.loading-closure',4],5], PartialBag),
    assertion(PartialBag == [[pair,4,5]]).

test(map_and_load_pragmas_belong_to_the_current_space,
     [setup(loading_setup("(= (loading-value) 42)\n")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, _, A, B), loading_option(A, 'from-map', [prefix, 'a.']),
    loading_option(A, load, lazy),
    space_module(B, BM),
    assertion(with_metta_module(BM, metta_engine:metta_pragma(load, eager))),
    metta_add_atom(A, [from, Path], _), metta_add_atom(B, [from, Path], _),
    loading_answers(A, ['a.loading-value'], [42]),
    loading_answers(B, ['loading-value'], [42]),
    loading_option(A, 'from-map', none),
    space_module(A, AM),
    assertion(with_metta_module(AM,
                  metta_engine:metta_pragma('from-map', ['|->', [H], H]))).

test(the_evaluated_pragma_accepts_partial_and_captured_lambda_maps,
     [forall(member(Map, [[prefix,'a.'],
                         [let,P,'a.',['|->',[H],[atom_concat,P,H]]]])),
      setup(loading_setup("(= (loading-value) 42)\n")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, _, A, _),
    evalc(['pragma!', 'from-map', Map], A, []),
    metta_add_atom(A, [from, Path], _),
    loading_answers(A, ['a.loading-value'], [42]).

test(an_evaluated_selection_keeps_the_internal_name_refusal,
     [setup(loading_setup("(internal loading-value)\n(= (loading-value) 42)\n")),
      cleanup(loading_cleanup)]) :-
    loading_fixture(Path, Home, A, _),
    evalc(['pragma!', 'from-map', [only,['loading-value']]], A, []),
    catch(metta_add_atom(A,[from,Path],_),Error,true),
    assertion(Error = error(metta_internal_reference(Home,'loading-value'),_)).

test(non_eager_admission_reads_an_already_evaluated_default_map,
     [forall((member(Policy,[lazy,background]),
              member(Map,[[prefix,'a.'],[let,P,'a.',['|->',[H],[atom_concat,P,H]]]]))),
      setup(loading_setup("")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, Home, A, B),
    metta_add_atom(B,[=,['loading-value'],42],_),
    format(string(Text),"(from ~w)\n",[B]), loading_write(Path,Text),
    evalc(['pragma!','from-map',Map],Home,[]), loading_option(A,load,Policy),
    metta_add_atom(A,[from,Path],_), loading_answers(A,['a.loading-value'],[42]).

test(non_eager_admission_refuses_an_effectful_evaluated_default_map,
     [forall(member(Policy,[lazy,background])),
      setup(loading_setup("")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, Home, A, B),
    metta_add_atom(B,[=,['loading-value'],42],_),
    format(string(Text),"(from ~w)\n",[B]), loading_write(Path,Text),
    Map = [let,P,forbidden,['|->',[H],[progn,['println!',P],H]]],
    evalc(['pragma!','from-map',Map],Home,[]), loading_option(A,load,Policy),
    with_output_to(string(Output),catch(metta_add_atom(A,[from,Path],_),Error,true)),
    assertion(Error = error(metta_effectful_reference_load(Path,[from,B],_),_)),
    assertion(Output == "").

test(prolog_libraries_own_their_heads_and_every_explicitly_imported_arity,
     [setup(loading_setup("")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, HomeA, A, B),
    loading_aux_file(pl, "'loading-prolog'(a).\n'loading-prolog'(X, a(X)).\n", PA),
    loading_aux_file(pl, "'loading-prolog'(b).\n'loading-prolog'(X, b(X)).\n", PB),
    loading_prolog_source(PA, SourceA), loading_write(Path, SourceA),
    loading_prolog_source(PB, SourceB), loading_aux_file(metta, SourceB, Other),
    metta_add_atom(A,[=,['loading-prolog-caller'],['loading-prolog']],_),
    metta_add_atom(A,[from,Path,[only,['loading-prolog']]],_),
    metta_add_atom(B,[from,Other,[only,['loading-prolog']]],_),
    loading_answers(A,['loading-prolog-caller'], CallerBag), assertion(CallerBag == [a]),
    loading_answers(B,['loading-prolog'], BBag), assertion(BBag == [b]),
    loading_answers(A,['loading-prolog',7], OneA), assertion(OneA == [a(7)]),
    loading_answers(B,['loading-prolog',7], OneB), assertion(OneB == [b(7)]),
    space_module(HomeA, HomeModule), space_module(A, Receiver),
    assertion(predicate_property(Receiver:'loading-prolog'(_),imported_from(HomeModule))),
    metta_self_module(Self), assertion(\+ fun_in(Self,'loading-prolog')),
    metta_add_atom(A,[from,Other,[only,['loading-prolog']]],_),
    loading_answers(A,['loading-prolog'],Union), assertion(Union == [a,b]).

loading_aux_file(Extension, Text, Path) :-
    tmp_file(reference_auxiliary, Stem), file_name_extension(Stem, Extension, Path),
    loading_write(Path, Text), assertz(loading_auxiliary(Path)).
loading_prolog_source(Prolog, Source) :-
    format(string(Source),
           "!(import! &self (library lib_import))~n!(import_prolog_functions_from_file \"~w\" (loading-prolog))~n",
           [Prolog]).

test(a_refused_home_registration_keeps_a_shared_prolog_provider_loaded,
     [setup(loading_setup("")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, _, A, B),
    gensym(reference_provider_, Provider),
    format(string(Code), ":- module(~q, ['loading-prolog'/1]).~n'loading-prolog'(kept).~n", [Provider]),
    loading_aux_file(pl, Code, Prolog), loading_prolog_source(Prolog, Source),
    loading_write(Path, Source), metta_add_atom(A, [from,Path], _),
    loading_aux_file(metta,"(= (loading-marker) marker)\n",Other),
    metta_add_atom(B,[from,Other],_), metta_engine:metta_reference_library_home(HomeB, Other),
    space_module(HomeB, Module),
    with_metta_module(Module, metta_engine:use_module_global(Prolog)),
    catch(with_metta_module(Module,
              metta_engine:register_declared_exports([Prolog-'loading-prolog'-arity(55)])),
          Error, true),
    assertion(Error = error(existence_error(procedure,_),_)),
    loading_answers(A,['loading-prolog'],After), assertion(After == [kept]),
    assertion(\+ fun_in(Module,'loading-prolog')).

test(every_non_eager_policy_names_an_effectful_load_form,
     [setup(loading_setup("!(println! forbidden)\n(= (loading-value) 42)\n")),
      cleanup(loading_cleanup)]) :-
    loading_fixture(Path, Home, A, _),
    forall(member(Policy, [lazy,background]),
           ( loading_option(A, load, Policy),
             catch(metta_add_atom(A, [from, Path], _), Error, true),
             assertion(Error = error(metta_effectful_reference_load(
                                          Path, ['println!',forbidden], _), _)),
             assertion(\+ metta_engine:import_receipt(Home, Path, _, _)),
             assertion(\+ get_native_atom(A, [from|_])) )).

test(candidate_definitions_are_read_before_an_initializer_can_run,
     [forall(member(Policy,[lazy,background])),
      setup(loading_setup("(= (loading-init) (println! forbidden))\n!(loading-init)\n")),
      cleanup(loading_cleanup)]) :-
    loading_fixture(Path,Home,A,_), loading_option(A,load,Policy),
    with_output_to(string(Output),
        catch((metta_add_atom(A,[from,Path],_),Outcome=admitted),
              Error,Outcome=rejected(Error))),
    assertion(Outcome = rejected(error(metta_effectful_reference_load(
                                          Path,['loading-init'],_),_))),
    assertion(Output == ""),
    assertion(\+ metta_engine:import_receipt(Home,Path,_,_)).

test(nested_reference_rows_preflight_the_dependency_before_loading_it,
     [forall(member(Policy,[lazy,background])),
      setup(loading_setup("")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path,Home,A,_),
    loading_aux_file(metta,"!(println! forbidden)\n",Dependency),
    format(string(Source),"(from \"~w\")\n",[Dependency]), loading_write(Path,Source),
    loading_option(A,load,Policy),
    with_output_to(string(Output),
        catch((metta_add_atom(A,[from,Path],_),Outcome=admitted),
              Error,Outcome=rejected(Error))),
    assertion(Outcome = rejected(error(metta_effectful_reference_load(
                                          Dependency,['println!',forbidden],_),_))),
    assertion(Output == ""),
    assertion(\+ metta_engine:import_receipt(Home,Path,_,_)).

test(a_reference_rows_mapper_is_load_time_work,
     [forall(member(Policy,[lazy,background])),
      setup(loading_setup("")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path,_,A,B), metta_add_atom(B,[=,['loading-map-source'],42],_),
    format(string(Source),
           "(from ~w (|-> ($head) (progn (println! forbidden) $head)))\n",[B]),
    loading_write(Path,Source), loading_option(A,load,Policy),
    with_output_to(string(Output),
        catch((metta_add_atom(A,[from,Path],_),Outcome=admitted),
              Error,Outcome=rejected(Error))),
    assertion(Outcome = rejected(error(metta_effectful_reference_load(
                                          Path,[from,B,_],_),_))),
    assertion(Output == "").

test(non_eager_admission_keeps_pure_initializers_and_masked_data,
     [forall(member(Policy,[lazy,background])),
      setup(loading_setup("(: loading-literal (-> Atom Atom))\n(= (loading-literal $x) $x)\n(= (loading-inc $x) (+ $x 1))\n!(loading-literal (println! forbidden))\n!(loading-inc 41)\n")),
      cleanup(loading_cleanup)]) :-
    loading_fixture(Path,Home,A,_), loading_option(A,load,Policy),
    metta_add_atom(A,[from,Path],_), metta_engine:metta_reference_wait(Home),
    loading_answers(A,['loading-inc',41],[42]),
    assertion(\+ metta_engine:metta_reference_admission_option(Home,_)),
    assertion(\+ filereader:metta_reference_admission_ref(Home,_)),
    assertion(\+ metta_engine:metta_effect_source_program(_,_)).

test(non_eager_rows_accept_each_map_and_follow_nested_references,
     [forall((member(Policy,[lazy,background]),loading_pure_map(Map,Head))),
      setup(loading_setup("")),cleanup(loading_cleanup)]) :-
    loading_fixture(Path,Home,A,_),
    loading_aux_file(metta,"(= (loading-value) 42)\n",Dependency),
    format(string(Source),"(from \"~w\" ~w)\n",[Dependency,Map]),
    loading_write(Path,Source), loading_option(A,load,Policy),
    metta_add_atom(A,[from,Path],_), metta_engine:metta_reference_wait(Home),
    loading_answers(A,[Head],[42]).

loading_pure_map("(only (loading-value))",'loading-value').
loading_pure_map("(except ())",'loading-value').
loading_pure_map("(prefix p.)",'p.loading-value').
loading_pure_map("(rename ((loading-value renamed)))",renamed).
loading_pure_map("(qualified q)",'q.loading-value').
loading_pure_map("(|-> ($head) $head)",'loading-value').

test(a_suspended_background_qualified_query_survives_release,
     [forall(between(1,20,_)),
      setup(loading_setup("")),cleanup(loading_cleanup)]) :-
    loading_fixture(Path,Home,A,_),
    loading_aux_file(metta,"(= (loading-value) 42)\n",Dependency),
    format(string(Source),"(from \"~w\" (qualified q))\n",[Dependency]),
    loading_write(Path,Source), loading_option(A,load,background),
    setup_call_cleanup(
        engine_create(ready,
            ( metta_add_atom(A,[from,Path],_),
              metta_engine:metta_reference_wait(Home),
              loading_answers(A,['q.loading-value'],[42]),
              engine_yield(ready) ), Engine),
        engine_next(Engine,ready),
        engine_destroy(Engine)).

test(non_eager_maps_preserve_zero_and_multiple_names,
     [forall(member(Policy,[lazy,background])),
      setup(loading_setup("")),cleanup(loading_cleanup)]) :-
    loading_fixture(Path,Home,A,_),
    loading_aux_file(metta,"(= (loading-value) 42)\n",Dependency),
    format(string(Source),
           "(from \"~w\" (|-> ($head) (empty)))\n(from \"~w\" (|-> ($head) (superpose (left right))))\n",
           [Dependency,Dependency]),
    loading_write(Path,Source), loading_option(A,load,Policy),
    metta_add_atom(A,[from,Path],_), metta_engine:metta_reference_wait(Home),
    loading_answers(A,[left],[42]), loading_answers(A,[right],[42]),
    loading_answers(A,['loading-value'],[['loading-value']]).

test(candidate_shadowing_does_not_inherit_the_old_builtin_mask,
     [forall(member(Policy,[lazy,background])),
      setup(loading_setup("(= (quote $x) $x)\n!(quote (println! forbidden))\n")),
      cleanup(loading_cleanup)]) :-
    loading_fixture(Path,_,A,_), loading_option(A,load,Policy),
    catch((metta_add_atom(A,[from,Path],_),Outcome=admitted),
          Error,Outcome=rejected(Error)),
    assertion(Outcome = rejected(error(metta_effectful_reference_load(
                           Path,[quote,['println!',forbidden]],_),_))).

test(oversaturated_candidate_lambdas_expose_their_runtime_effect,
     [forall(member(Policy,[lazy,background])),
      setup(loading_setup("(= (loading-lambda $x) (|-> ($y) (println! forbidden)))\n!(loading-lambda 1 2)\n")),
      cleanup(loading_cleanup)]) :-
    loading_fixture(Path,_,A,_), loading_option(A,load,Policy),
    catch((metta_add_atom(A,[from,Path],_),Outcome=admitted),
          Error,Outcome=rejected(Error)),
    assertion(Outcome = rejected(error(metta_effectful_reference_load(
                           Path,['loading-lambda',1,2],_),_))).

test(candidate_arrow_products_keep_evaluated_operands,
     [forall(member(Policy,[lazy,background])),
      setup(loading_setup("(: loading-constant (-[det,pureStructural]-> %Undefined% Bool))\n(= (loading-constant $x) True)\n!(loading-constant (println! forbidden))\n")),
      cleanup(loading_cleanup)]) :-
    loading_fixture(Path,_,A,_), loading_option(A,load,Policy),
    with_output_to(string(Output),
        catch((metta_add_atom(A,[from,Path],_),Outcome=admitted),
              Error,Outcome=rejected(Error))),
    assertion(Outcome = rejected(error(metta_effectful_reference_load(
                        Path,['loading-constant',['println!',forbidden]],_),_))),
    assertion(Output == "").

test(non_eager_file_cycles_preserve_both_defining_homes,
     [forall(member(Policy,[lazy,background])),
      setup(loading_setup("")),cleanup(loading_cleanup)]) :-
    loading_fixture(Path,Home,A,_),
    format(string(Dependent),"(= (loading-child) 7)\n(from \"~w\")\n",[Path]),
    loading_aux_file(metta,Dependent,Dependency),
    format(string(Source),"(= (loading-parent) 42)\n(from \"~w\")\n",[Dependency]),
    loading_write(Path,Source), loading_option(A,load,Policy),
    metta_add_atom(A,[from,Path],_), metta_engine:metta_reference_wait(Home),
    loading_answers(A,['loading-parent'],[42]),
    loading_answers(A,['loading-child'],[7]).

test(a_space_released_before_its_first_from_forgets_its_pragmas,
     [setup(loading_setup("(= (loading-value) 42)\n")), cleanup(loading_cleanup)]) :-
    loading_fixture(_, _, A, _), loading_option(A, load, lazy),
    space_module(A, Before),
    assertion(\+ with_metta_module(Before, metta_engine:metta_pragma(load, eager))),
    metta_release_space(A), space_module(A, Module),
    assertion(with_metta_module(Module, metta_engine:metta_pragma(load, eager))).

test(rows_only_are_admitted_by_both_non_eager_policies,
     [setup(loading_setup("(data retained)\n")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, Home, A, B),
    loading_option(A, load, lazy), metta_add_atom(A, [from, Path], _),
    assertion(get_native_atom(Home, [data, retained])),
    metta_engine:metta_unimport(Home, Path),
    loading_option(B, load, background), metta_add_atom(B, [from, Path], _),
    metta_engine:metta_reference_wait(Home),
    assertion(get_native_atom(Home, [data, retained])),
    assertion(\+ get_native_atom(B, [data, retained])).

test(background_returns_before_loading_and_a_call_waits_for_publication,
     [condition(current_prolog_flag(threads,true)),
      setup(loading_setup("(= (loading-value) 42)\n")), cleanup(loading_cleanup)]) :-
    loading_controlled_background(succeed, Outcome), assertion(Outcome == [42]).

test(a_background_namespace_of_only_references_waits_before_deciding_a_name_is_data,
     [condition(current_prolog_flag(threads,true)),
      setup(loading_setup("")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, _, _, B), metta_add_atom(B,[=,['loading-value'],42],_),
    format(string(Text),"(from ~w)\n",[B]), loading_write(Path,Text),
    loading_controlled_background(succeed, Outcome), assertion(Outcome == [42]),
    assertion(\+ metta_engine:metta_reference_namespace_watch).

test(concurrent_transactions_keep_each_others_rollback_listener,
     [condition(current_prolog_flag(threads,true)),
      setup(loading_setup("(= (loading-value) 42)\n")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path,_,A,B),
    metta_add_atom(A,[from,Path],_), metta_add_atom(B,[from,Path],_),
    setup_call_cleanup(
        maplist(message_queue_create,[EnteredA,EnteredB,ReleaseA,ReleaseB]),
        ( setup_call_cleanup(
              thread_create(loading_rollback_reference(A,Path,EnteredA,ReleaseA),TA,[]),
              ( thread_get_message(EnteredA,entered),
                setup_call_cleanup(
                    thread_create(loading_rollback_reference(B,Path,EnteredB,ReleaseB),TB,[]),
                    ( thread_get_message(EnteredB,entered),
                      thread_send_message(ReleaseA,continue),
                      thread_get_message(EnteredA,rolled_back),
                      thread_send_message(ReleaseB,continue),
                      thread_get_message(EnteredB,rolled_back) ),
                    ( thread_send_message(ReleaseB,continue), thread_join(TB,true) )) ),
              ( thread_send_message(ReleaseA,continue), thread_join(TA,true) )),
          loading_answers(A,['loading-value'],[42]),
          loading_answers(B,['loading-value'],[42]) ),
        maplist(message_queue_destroy,[EnteredA,EnteredB,ReleaseA,ReleaseB])).

loading_rollback_reference(Space,Path,Entered,Release) :-
    \+ transaction(( once(metta_remove_atom(Space,[from,Path],true)),
                     thread_send_message(Entered,entered),
                     thread_get_message(Release,continue), fail )),
    thread_send_message(Entered,rolled_back).

test(background_failure_reaches_callers_and_a_later_row_retries,
     [condition(current_prolog_flag(threads,true)),
      setup(loading_setup("(= (loading-value) 42)\n")), cleanup(loading_cleanup)]) :-
    loading_controlled_background(raise, Outcome),
    loading_fixture(Path, Home, A, B),
    assertion(Outcome == raised(error(reference_fixture_failure,
                             context(Path, 'while loading MeTTa file')))),
    assertion(\+ metta_engine:import_receipt(Home, Path, _, _)),
    metta_add_atom(B, [from, Path], _),
    loading_answers(A, ['loading-value'], [42]).

test(background_rechecks_the_text_read_after_submission,
     [condition(current_prolog_flag(threads,true)),
      setup(loading_setup("(= (loading-value) 42)\n")),cleanup(loading_cleanup)]) :-
    loading_controlled_background(replace("!(println! forbidden)\n(= (loading-value) 42)\n"),Outcome),
    loading_fixture(Path,Home,_,B),
    assertion(Outcome = raised(error(metta_effectful_reference_load(
                                       Path,['println!',forbidden],_),_))),
    assertion(\+ metta_engine:import_receipt(Home,Path,_,_)),
    assertion(\+ metta_engine:metta_reference_admission_option(Home,_)),
    assertion(\+ filereader:metta_reference_admission_ref(Home,_)),
    loading_write(Path,"(= (loading-value) 42)\n"),
    metta_add_atom(B,[from,Path],_), loading_answers(B,['loading-value'],[42]).

test(cancellation_before_source_entry_settles_and_a_later_row_retries,
     [condition(current_prolog_flag(threads,true)),
      setup(loading_setup("(= (loading-value) 42)\n")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, Home, A, B),
    setup_call_cleanup(
        ( message_queue_create(Started), message_queue_create(Release),
          wrap_predicate(metta_engine:importer_helper(Space,File),
                         reference_early_cancel, Import,
                         ( ( Space == Home, File == Path
                           -> thread_send_message(Started,entered),
                              thread_get_message(Release,continue)
                           ; true ), call(Import) )) ),
        ( loading_option(A,load,background), metta_add_atom(A,[from,Path],_),
          thread_get_message(Started,entered),
          metta_engine:metta_reference_load_state(Home,pending(Future)),
          lib_thread:thread_cancel(Future,true) ),
        ( unwrap_predicate(metta_engine:importer_helper(_,_),reference_early_cancel),
          message_queue_destroy(Started), message_queue_destroy(Release) )),
    catch(transaction(metta_engine:metta_reference_start(Home,Path,eager,none,_)),
          WaitError,true),
    assertion(WaitError = error(metta_wait_in_transaction(_),_)),
    assertion(metta_engine:metta_reference_load_state(Home,pending(_))),
    catch((metta_engine:metta_reference_wait(Home) -> Observed = returned
          ; Observed = failed), Error, Observed = raised(Error)),
    assertion(Observed = raised(error(metta_reference_load_failed(Home,cancelled),_))),
    metta_add_atom(B,[from,Path],_),
    loading_answers(A,['loading-value'],Bag), assertion(Bag == [42]).

test(prolog_export_properties_belong_to_the_home_and_leave_with_its_source,
     [setup(loading_setup("")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, HomeA, A, B),
    loading_declared_source(volatile,det,one,PA),
    loading_declared_source(immutable,nondet,two,PB),
    format(string(SourceA),"!(import! &self (library lib_import))~n!(import_prolog_functions_from_file \"~w\" ())~n",[PA]),
    format(string(SourceB),"!(import! &self (library lib_import))~n!(import_prolog_functions_from_file \"~w\" ())~n",[PB]),
    loading_write(Path,SourceA), loading_aux_file(metta,SourceB,Other),
    metta_engine:metta_reference_home(Other,HomeB),
    metta_add_atom(A,[from,Path],_), metta_add_atom(B,[from,Other],_),
    assertion(metta_head_property(HomeA,'loading-declared',[volatility,volatile])),
    assertion(metta_head_property(HomeB,'loading-declared',[volatility,immutable])),
    assertion(metta_head_property(A,'loading-declared',[determinism,det])),
    assertion(metta_head_property(B,'loading-declared',[determinism,nondet])),
    assertion(\+ metta_function_volatility('loading-declared',_)),
    assertion(\+ metta_function_determinism('loading-declared',_)),
    space_module(A,ModuleA), space_module(B,ModuleB),
    assertion(\+ metta_function_cacheable(ModuleA,'loading-declared')),
    assertion(metta_function_cacheable(ModuleB,'loading-declared')),
    loading_answers(A,['loading-declared'],One), assertion(One == [one]),
    loading_answers(B,['loading-declared'],Two), assertion(Two == [two]),
    metta_engine:metta_unimport(HomeA,Path),
    assertion(\+ metta_head_property(HomeA,'loading-declared',[volatility,_])),
    assertion(metta_head_property(HomeB,'loading-declared',[volatility,immutable])).

loading_declared_source(Volatility, Determinism, Answer, Path) :-
    format(string(Code),
           ":- metta_export(\"(export loading-declared 0) (volatility loading-declared ~w) (determinism loading-declared ~w)\").~n'loading-declared'(~w).~n",
           [Volatility,Determinism,Answer]),
    loading_aux_file(pl,Code,Path).

test(an_already_loaded_prolog_module_registers_its_declarations_in_each_home,
     [setup(loading_setup("")), cleanup(loading_cleanup)]) :-
    loading_fixture(Path, _, A, B), gensym(reference_declared_,Provider),
    format(string(Code),
           ":- module(~q,['loading-shared'/1]).~n:- metta_export(\"(export loading-shared 0) (volatility loading-shared immutable) (determinism loading-shared det)\").~n'loading-shared'(shared).~n",
           [Provider]),
    loading_aux_file(pl,Code,Prolog),
    format(string(Source),"!(import! &self (library lib_import))~n!(import_prolog_functions_from_module \"~w\" ())~n",[Prolog]),
    loading_write(Path,Source), loading_aux_file(metta,Source,Other),
    metta_add_atom(A,[from,Path],_), metta_add_atom(B,[from,Other],_),
    loading_answers(A,['loading-shared'],BagA), assertion(BagA == [shared]),
    loading_answers(B,['loading-shared'],BagB), assertion(BagB == [shared]),
    assertion(metta_head_property(B,'loading-shared',[volatility,immutable])).

% Pause the real source reader after the background worker has claimed its
% source. The file is pure; the fixture controls scheduling outside its forms.
loading_controlled_background(Mode, Outcome) :-
    loading_fixture(Path, Home, A, _),
    setup_call_cleanup(
        loading_gate_setup(Path, Home, Mode, Started, Release, Calling, Done),
        ( loading_option(A, load, background), metta_add_atom(A, [from, Path], _),
          thread_get_message(Started, reading),
          assertion(metta_engine:metta_reference_load_state(Home, pending(_))),
          thread_create(loading_background_caller(A, Done), Caller, []),
          assertz(loading_caller(Caller)), thread_get_message(Calling, waiting),
          message_queue_property(Done, size(Count)), assertion(Count == 0),
          thread_send_message(Release, continue), thread_get_message(Done, Outcome) ),
        loading_gate_cleanup(Started, Release, Calling, Done)).

loading_gate_setup(Path, Home, Mode, Started, Release, Calling, Done) :-
    message_queue_create(Started), message_queue_create(Release),
    message_queue_create(Calling), message_queue_create(Done),
    assertz(loading_gate(Path)),
    wrap_predicate(filereader:read_source_text(File, _Text), reference_test_read, Read,
                   (loading_pause_read(File, Path, Mode, Started, Release), call(Read))),
    wrap_predicate(metta_engine:metta_reference_wait(Space), reference_test_wait, Wait,
                   ( ( Space == Home -> thread_send_message(Calling, waiting) ; true ),
                     call(Wait) )).

loading_pause_read(File, Path, Mode, Started, Release) :-
    ( File == Path, filereader:active_source_load(_), retract(loading_gate(Path))
    -> thread_send_message(Started, reading), thread_get_message(Release, continue),
       ( Mode == raise -> throw(error(reference_fixture_failure, none))
       ; Mode = replace(Text) -> loading_write(Path,Text)
       ; true )
    ; true ).
loading_background_caller(Space, Done) :-
    catch(loading_answers(Space, ['loading-value'], Bag), Error, Bag = raised(Error)),
    thread_send_message(Done, Bag).
loading_gate_cleanup(Started, Release, Calling, Done) :-
    thread_send_message(Release, continue),
    forall(retract(loading_caller(Caller)), thread_join(Caller, _)),
    unwrap_predicate(filereader:read_source_text(_, _), reference_test_read),
    unwrap_predicate(metta_engine:metta_reference_wait(_), reference_test_wait),
    retractall(loading_gate(_)),
    maplist(message_queue_destroy, [Started, Release, Calling, Done]).

:- end_tests(reference_loading).
