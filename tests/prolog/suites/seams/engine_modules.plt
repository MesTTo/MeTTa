% Purpose: the module boundary itself -- that the engine core, its subsystems
%   and every shipped library are modules, that `user` holds nothing the engine
%   defines, and that each module owns its own autoload table.
% Assumes:
%   - the working directory is tests/prolog, which is where engine/test.sh runs
%     every suite from, because the fixtures are named relative to it
% Guarantees:
%   - assertzPredicate/2, assertaPredicate/2 and retractPredicate/2 keep host
%     clauses in user, where consult_global/1 loads plain host files
%     [tested: asserted_host_clauses_keep_the_host_module; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
%   - two libraries may define a helper of ONE name without replacing each
%     other, and neither helper is visible outside its own module
%     [tested: two_libraries_may_define_one_helper_name; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
%   - that is not vacuous: the same two files WITHOUT module declarations,
%     consulted into one module, leave exactly one helper -- the second file's
%     [tested: a_plain_pair_still_replaces_one_helpers_clauses; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
%   - engine/metta.pl's autoload(library(uuid)) and
%     lib/lib_tabling/lib_tabling.pl's autoload(library(wfs), [call_delays/2])
%     are two tables in two modules and neither replaces the other, and a third
%     library declaring one of its own disturbs neither
%     [tested: the_engines_autoload_table_survives_a_librarys,
%     a_librarys_autoload_table_is_its_own; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
%   - that is not vacuous either: two plain files consulted into one module
%     leave one table, the second file's
%     [tested: a_plain_pair_still_replaces_one_autoload_table; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
%   - `user` holds no predicate any file under engine/ or lib/ DEFINES
%     [tested: user_holds_nothing_the_engine_defines; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
%   - the engine core exports every MeTTa builtin head it implements, bar the
%     two SWI already has in `user`
%     [tested: every_core_builtin_head_is_exported; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
%   - no shipped module holds a predicate of its own under a name the engine
%     owns, except the module-local names recorded in shadow_by_design/2
%     [tested: no_shipped_module_shadows_a_name_the_engine_owns,
%     the_shadow_census_sees_a_planted_library_definition; commit=32650f9ff4d1c4aa0749d8eb8b153e5bb448ee5c]
%   - the operator guards read the ENGINE's namespace, so a name a library lent
%     the engine at one or two arguments is still told from a MeTTa call
%     [tested: an_operator_lent_name_is_seen_in_the_engines_own_namespace; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
%   - the execution chain is the one the design settled
%     [tested: the_chain_is_self_then_prelude_then_engine_then_user; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

% Load every shipped Prolog half for the ownership and export census. Empty
% import lists preserve each module's interface without collecting its exports
% into this test file's namespace.
:- initialization(load_module_boundary_libraries).

load_module_boundary_libraries :-
    expand_file_name('../../lib/*/*.pl', Files),
    forall(member(File, Files), user:use_module(File, [])).

shipped_library(File, Module) :-
    expand_file_name('../../lib/*/*.pl', Files),
    member(Relative, Files),
    absolute_file_name(Relative, File),
    source_file_property(File, module(Module)).

%A fixture path, from tests/prolog, spelled once.
module_fixture(Name, Path) :-
    atomic_list_concat(['module_fixtures/', Name], Path).

%A scratch module to consult the plain controls into, so the collision they
%prove happens somewhere the rest of the process does not read. A fresh name
%per test, because SWI keeps a module once it exists and a second consult of
%the same file into the same module is a RELOAD rather than the first load the
%control is about.
plain_control_module(Tag, Module) :-
    atom_concat('plunit_module_control_', Tag, Module).

:- begin_tests(engine_modules).

test(asserted_host_clauses_keep_the_host_module) :-
    setup_call_cleanup(
        true,
        ( assertzPredicate('$metta_module_host_clause'(last), true),
          assertaPredicate('$metta_module_host_clause'(first), true),
          assertion((predicate_property(user:'$metta_module_host_clause'(_), defined),
                     predicate_property(user:'$metta_module_host_clause'(_),
                                        implementation_module(user)))),
          findall(X, user:'$metta_module_host_clause'(X), [first, last]),
          retractPredicate('$metta_module_host_clause'(first), true),
          findall(Y, user:'$metta_module_host_clause'(Y), [last]) ),
        ( abolish(user:'$metta_module_host_clause'/1),
          abolish(metta_engine:'$metta_module_host_clause'/1) )).

test(every_shipped_prolog_half_has_its_own_module) :-
    expand_file_name('../../lib/*/*.pl', Files),
    assertion(Files \== []),
    forall(member(File, Files),
           assertion((source_file_property(File, module(Module)),
                      atom_concat(lib_, _, Module)))),
    findall(Module, shipped_library(_, Module), Modules),
    sort(Modules, Unique),
    length(Files, Count),
    assertion(length(Unique, Count)).

% Declarations publish callable services even when no Prolog clause reaches
% them: Python also calls engine predicates through query strings.
test(every_declared_service_is_exported_to_the_host) :-
    findall(PI, unpublished_service(PI), Missing),
    assertion(Missing == []).

unpublished_service(Name/Arity) :-
    seam:kind(Name/Arity, Kind),
    memberchk(Kind, [service, host_service]),
    functor(Head, Name, Arity),
    predicate_property(metta_engine:Head, defined),
    \+ ( predicate_property(metta_engine:Head, exported),
         predicate_property(user:Head, defined) ).

test(the_service_census_sees_a_declared_private_predicate) :-
    module_fixture('private_service.pl', Fixture),
    setup_call_cleanup(
        user:use_module(Fixture, []),
        assertion(unpublished_service('$metta_module_private_service'/0)),
        unload_file(Fixture)).

% system has no engine base. Only explicit owners in the returned conjunction
% can reach these helpers, while the caller's own member/2 keeps its context.
test(returned_budgets_keep_their_private_helpers) :-
    metta_host_time_budget(member(X, [a, b]), 60, Timed),
    findall(X, system:Timed, [a, b]),
    metta_host_inference_budget(member(Y, [a, b]), 1000000, Counted),
    findall(Y, system:Counted, [a, b]),
    assertion(\+ current_predicate(user:metta_time_budget_spent/2)),
    assertion(\+ current_predicate(user:metta_inference_budget_spent/3)).

test(every_metta_registration_has_a_library_export) :-
    findall(File-Name,
            ( shipped_library(File, Module),
              file_name_extension(Stem, pl, File),
              file_name_extension(Stem, metta, MettaFile),
              exists_file(MettaFile),
              read_file_to_string(MettaFile, Source, []),
              module_property(Module, exports(Exports)),
              unexported_registration(Source, Exports, Name) ),
            Missing),
    assertion(Missing == []).

unexported_registration(Source, Exports, Name) :-
    metta_string_registrations(Source, Rows),
    member([Name, _], Rows),
    \+ builtin_fun(Name),
    \+ memberchk(Name/_, Exports),
    module_property(metta_engine, exports(Core)),
    \+ memberchk(Name/_, Core).

test(the_registration_census_sees_a_private_registered_helper) :-
    module_fixture('alpha.pl', Alpha),
    user:use_module(Alpha, []),
    module_property(plunit_module_alpha, exports(Exports)),
    assertion(unexported_registration(
                  "!(import_prolog_function plunit_module_helper)",
                  Exports, plunit_module_helper)),
    assertion(\+ unexported_registration(
                       "!(import_prolog_function plunit_module_answer)",
                       Exports, _)).

% Capture the actual worker-exit option before any Redis connection is used.
% The exit callback is private, so the option must retain its defining module.
test(redis_subscription_exit_names_its_owning_library) :-
    setup_call_cleanup(
        wrap_predicate(redis:redis_subscribe(_, _, _, Options),
                       '$metta_test_redis_exit', _Wrapped,
                       throw('$metta_test_exit_options'(Options))),
        ( catch(lib_redis:redis_space_register_ready_subscription(
                    space, conn, subconn, listener, key, channel, ready, queue),
                '$metta_test_exit_options'(Captured), true),
          assertion(nonvar(Captured)),
          memberchk(at_exit(Exit), Captured),
          assertion(Exit == lib_redis:redis_space_subscription_exit(subconn)),
          assertion(predicate_property(Exit, defined)),
          assertion(\+ current_predicate(user:redis_space_subscription_exit/1)) ),
        unwrap_predicate(redis:redis_subscribe/4, '$metta_test_redis_exit')).

test(two_libraries_may_define_one_helper_name) :-
    module_fixture('alpha.pl', Alpha),
    module_fixture('beta.pl', Beta),
    %Empty import lists: the question is what each MODULE holds, and importing
    %the two exports of one name into `user` is a different question SWI
    %answers with a permission error.
    user:use_module(Alpha, []),
    user:use_module(Beta, []),
    plunit_module_alpha:plunit_module_answer(A),
    plunit_module_beta:plunit_module_answer(B),
    assertion(A == alpha),
    assertion(B == beta),
    %Each helper is the module's own, with one clause, and neither is an
    %import of the other's.
    assertion(\+ predicate_property(plunit_module_alpha:plunit_module_helper(_),
                                    imported_from(_))),
    assertion(\+ predicate_property(plunit_module_beta:plunit_module_helper(_),
                                    imported_from(_))),
    %And the helper reaches no further than its own module.
    assertion(\+ current_predicate(user:plunit_module_helper/1)),
    assertion(\+ current_predicate(metta_engine:plunit_module_helper/1)).

% The compiled caller must follow both the local override and its withdrawal.
% Importing the library into this space exercises its actual MeTTa entry.
test(removing_a_local_shadow_restores_a_library_export) :-
    Space = '&plunit_module_library_shadow',
    Local = [=, ['string-upper', _], local],
    setup_call_cleanup(
        true,
        ( 'import!'(Space, [library, lib_string], true),
          metta_add_atom(Space,
                         [=, ['plunit-module-forward', X], ['string-upper', X]],
                         true),
          space_module(Space, Module),
          findall(Before, Module:'plunit-module-forward'("hello", Before),
                  ["HELLO"]),
          metta_add_atom(Space, Local, true),
          findall(Shadow, Module:'plunit-module-forward'("hello", Shadow),
                  [local]),
          metta_remove_atom(Space, Local, true),
          findall(After, Module:'plunit-module-forward'("hello", After),
                  ["HELLO"]),
          assertion(predicate_property(Module:'string-upper'(_, _),
                                       imported_from(lib_string))),
          lib_string:'string-upper'("hello", "HELLO") ),
        metta_release_space(Space)).

%The anti-vacuity half: the same pair with the module declarations removed,
%which is how every shipped library's Prolog half was written until this
%change. SWI reports `Redefined static procedure` and keeps ONE helper.
test(a_plain_pair_still_replaces_one_helpers_clauses) :-
    module_fixture('plain_alpha.pl', PlainAlpha),
    module_fixture('plain_beta.pl', PlainBeta),
    plain_control_module(helpers, Control),
    Control:ensure_loaded(PlainAlpha),
    Control:ensure_loaded(PlainBeta),
    findall(X, Control:plunit_module_plain_helper(X), Helpers),
    assertion(Helpers == [beta]),
    %Both answers now come from the survivor, which is the defect stated as an
    %observation rather than as a warning nobody reads.
    Control:plunit_module_plain_answer_alpha(FromAlpha),
    assertion(FromAlpha == beta).

test(the_engines_autoload_table_survives_a_librarys) :-
    assertion(metta_engine:'$autoload'(library(uuid), _, _)),
    assertion(lib_tabling:'$autoload'(library(wfs), _, _)),
    %Two tables, in two modules, and neither module holds the other's row.
    assertion(\+ metta_engine:'$autoload'(library(wfs), _, _)),
    assertion(\+ lib_tabling:'$autoload'(library(uuid), _, _)).

test(a_librarys_autoload_table_is_its_own) :-
    module_fixture('autoload_module.pl', Fixture),
    user:use_module(Fixture, []),
    assertion(plunit_module_autoload:'$autoload'(library(sha), _, _)),
    %and the two shipped declarations are exactly where they were
    assertion(metta_engine:'$autoload'(library(uuid), _, _)),
    assertion(lib_tabling:'$autoload'(library(wfs), _, _)).

%The anti-vacuity half of the autoload pair: '$autoload'/3 is ONE predicate per
%module, so two plain files consulted into one module leave one table.
test(a_plain_pair_still_replaces_one_autoload_table) :-
    module_fixture('plain_autoload_a.pl', PlainA),
    module_fixture('plain_autoload_b.pl', PlainB),
    plain_control_module(autoload, Control),
    Control:ensure_loaded(PlainA),
    assertion(Control:'$autoload'(library(sha), _, _)),
    Control:ensure_loaded(PlainB),
    assertion(Control:'$autoload'(library(base64), _, _)),
    assertion(\+ Control:'$autoload'(library(sha), _, _)).

%The objective in one question. A DEFINITION, not an import: `user` goes on
%holding imports of what the engine exports, which is how a host and a plunit
%suite call the engine at all.
test(user_holds_nothing_the_engine_defines) :-
    findall(File-Name/Arity,
            ( current_predicate(_, user:Head),
              functor(Head, Name, Arity),
              \+ predicate_property(user:Head, imported_from(_)),
              predicate_property(user:Head, file(File)),
              tree_owned_file(File),
              \+ swi_hook_in_user(Name/Arity, _) ),
            Held),
    assertion(Held == []),
    %and every exemption names a predicate SWI itself declares multifile in
    %`user`, which is what makes it a hook rather than a name somebody put
    %there. The engine's clause of one may or may not be loaded in this
    %process -- source_observation.pl installs its trace interception on
    %demand -- so the check is about the HOOK and not about the clause.
    findall(PI,
            ( swi_hook_in_user(PI, _),
              PI = HookName/HookArity,
              functor(HookHead, HookName, HookArity),
              predicate_property(user:HookHead, defined),
              \+ predicate_property(user:HookHead, multifile) ),
            NotHooks),
    assertion(NotHooks == []),
    %and the walk can see: the engine's own module holds plenty.
    findall(Name2/Arity2,
            ( current_predicate(_, metta_engine:Head2),
              functor(Head2, Name2, Arity2),
              \+ predicate_property(metta_engine:Head2, imported_from(_)),
              predicate_property(metta_engine:Head2, file(File2)),
              tree_owned_file(File2) ),
            Engine),
    length(Engine, Count),
    assertion(Count > 500).

%!  swi_hook_in_user(?PredicateIndicator, ?Why) is nondet.
%
%   Exempt SWI's hooks in user. The census checks their multifile declarations
%   and rejects every other engine or library definition in that module.
%   [tested: engine_modules:user_holds_nothing_the_engine_defines; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
swi_hook_in_user(exception/3,
                 'SWI calls user:exception(undefined_predicate, ...) before it \c
                  reports an unknown procedure, which is how a foreign space \c
                  materialises a predicate on demand').
swi_hook_in_user(thread_message_hook/3,
                 'SWI consults user:thread_message_hook/3 to intercept a \c
                  message in THIS thread, which is how a load reports a syntax \c
                  error the loader would otherwise only print').
swi_hook_in_user(prolog_trace_interception/4,
                 'SWI calls user:prolog_trace_interception/4 from the debugger \c
                  port, which is the source observer\'s whole mechanism').

%A file this repository ships under engine/ or lib/, which is what "ours"
%means here. The vendored upstream corpus under tests/conformance/petta/lib/
%is deliberately not: a conformance fixture consulted into `user` is a host
%file like any other.
tree_owned_file(File) :-
    absolute_file_name('../../engine', EngineDir),
    absolute_file_name('../../lib', LibDir),
    atom_concat(EngineDir, '/', EnginePrefix),
    atom_concat(LibDir, '/', LibPrefix),
    ( sub_atom(File, 0, _, _, EnginePrefix) ; sub_atom(File, 0, _, _, LibPrefix) ).

%A MeTTa builtin IS the published surface, so the core's export list has to
%carry every builtin head the core implements. assert/2 and exists_file/1 are
%the two exceptions the module declaration names: SWI has both in `user`
%already and an import over them is refused.
test(every_core_builtin_head_is_exported) :-
    module_property(metta_engine, exports(Exports)),
    findall(Name/Arity,
            ( builtin_fun(Name),
              current_predicate(metta_engine:Name/Arity),
              functor(Head, Name, Arity),
              predicate_property(metta_engine:Head, implementation_module(metta_engine)),
              predicate_property(metta_engine:Head, file(File)),
              core_file(File),
              \+ memberchk(Name/Arity, [assert/2, exists_file/1]),
              \+ memberchk(Name/Arity, Exports) ),
            Missing),
    assertion(Missing == []),
    %not vacuous: the join finds heads at all
    aggregate_all(count,
                  ( builtin_fun(N2), current_predicate(metta_engine:N2/A2),
                    functor(H2, N2, A2),
                    predicate_property(metta_engine:H2, file(F2)),
                    core_file(F2) ),
                  Found),
    assertion(Found > 100).

core_file(File) :-
    ( sub_atom(File, _, _, 0, '/engine/metta.pl')
    ; sub_atom(File, _, _, _, '/engine/metta/') ).

%The three guards that ask whether a name is an OPERATOR read the ENGINE's
%namespace, which is where the libraries the engine imports put theirs.
%current_op/3's third argument is module-sensitive and SWI resolves an
%unqualified one against `user`, so the bare form every one of them used to
%write answers about `user` and not about the caller.
test(an_operator_lent_name_is_seen_in_the_engines_own_namespace) :-
    %library(clpfd) arrives through engine/metta/operators.pl, so its
    %comparison operators are the engine module's.
    assertion(metta_engine_operator('#<')),
    assertion(current_op(_, _, metta_engine:'#<')),
    %and not `user`'s, which is what made the bare form stop guarding
    assertion(\+ current_op(_, _, user:'#<')),
    %the consequence the guard exists for: clpfd's own '#<'/2 is not a MeTTa
    %arity of the engine's '#<' builtin
    assertion(\+ arity('#<', 2)),
    assertion(arity('#<', 3)).

%A module boundary turns a name collision from a silent replacement into two
%separate predicates, which is the win; it also turns a `:- dynamic` line that
%was inert into a live SHADOW. lib/lib_memo/lib_memo.pl carried
%`:- dynamic arity/2.` for the engine's own registry: harmless while every
%library shared the engine's module, and an empty local predicate the moment
%it had one of its own, after which memo_resolved_owner/3 found no arity and
%`memoize-exact` recorded its declaration where no call would ever look.
test(no_shipped_module_shadows_a_name_the_engine_owns) :-
    findall(Module-PI, shipped_module_shadow(Module, PI), Shadows),
    assertion(Shadows == []),
    %and the walk can see: lib_tabling's own autoload table is one of the
    %shadows the exemption list carries, so a broken walk reports clean
    assertion(( current_predicate(lib_tabling:'$autoload'/3),
                current_predicate(metta_engine:'$autoload'/3) )).

% The census must see an actual library definition that hides an engine name.
test(the_shadow_census_sees_a_planted_library_definition) :-
    setup_call_cleanup(
        ( assertz(metta_engine:'$metta_module_shadow_plant'),
          assertz(lib_tabling:'$metta_module_shadow_plant') ),
        assertion(shipped_module_shadow(lib_tabling, '$metta_module_shadow_plant'/0)),
        ( abolish(lib_tabling:'$metta_module_shadow_plant'/0),
          abolish(metta_engine:'$metta_module_shadow_plant'/0) )).

shipped_module_shadow(Module, Name/Arity) :-
    current_module(Module),
    Module \== user,
    module_property(Module, file(File)),
    tree_owned_file(File),
    current_predicate(Module:Name/Arity),
    functor(Head, Name, Arity),
    \+ predicate_property(Module:Head, imported_from(_)),
    current_predicate(metta_engine:Name/Arity),
    predicate_property(metta_engine:Head, implementation_module(Owner)),
    Owner \== Module,
    \+ shadow_by_design(Name/Arity, _).

%!  shadow_by_design(?PredicateIndicator, ?Why) is nondet.
%
%   A name a shipped module holds of its own while the engine holds another,
%   deliberately, one line each with the reason.
shadow_by_design('$autoload'/3,
                 'SWI keeps one autoload table per module and that is the \c
                  point: engine/metta.pl declares library(uuid) and \c
                  lib/lib_tabling/lib_tabling.pl declares library(wfs), and \c
                  neither replaces the other any more').
% SWI's table/1 expansion emits these predicates into each declaring module.
% [source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/tabling.pl#L1220; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
shadow_by_design('$tabled'/2, 'SWI records table declarations per module').
shadow_by_design('$table_mode'/3, 'SWI records table modes per module').
% SWI applies each source module's hook before its inherited expansion hooks.
% [source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/expand.pl#L129; commit=32650f9ff4d1c4aa0749d8eb8b153e5bb448ee5c]
shadow_by_design(term_expansion/2,
                 'SWI expands source declarations through module-local hooks').
shadow_by_design(union/3,
                 'MeTTa\'s union is not library(lists)\'s, and the prelude \c
                  tier holding its own is what lets both spellings live \c
                  docs/journal/2026-09-07-the-prelude-in-prolog.md').
shadow_by_design(intersection/3,
                 'MeTTa\'s intersection, for the same reason as union/3').
shadow_by_design(metta_algebra_law_expansion/2,
                 'two different operations of one name: the catalog\'s \c
                  expands-to row in engine/metta/effects.pl and the alias \c
                  table in engine/spaces/catalog.pl, separate before this \c
                  change too because engine/spaces.pl was already a module').

%The chain the design settled, read off the module system rather than written
%down twice. spaces_execution_modules:the_chain_is_engine_then_prelude_then_self_then_space
%asks the same question of the top half; this is the whole of it, including the
%host tier `user` at the bottom, which is what keeps a MeTTa program's own
%consulted Prolog reachable from every space.
test(the_chain_is_self_then_prelude_then_engine_then_user) :-
    space_module('&self', Self),
    chain_from(Self, Chain),
    assertion(Chain == [prelude, metta_engine, user, system]).

chain_from(Module, [Base|Rest]) :-
    default_module(Module, Base),
    Base \== Module,
    !,
    ( Base == system -> Rest = [] ; chain_from(Base, Rest) ).
chain_from(_, []).

:- end_tests(engine_modules).
