% Purpose: load canonical library homes through import!'s existing ownership door.
% Assumes: filereader:parse_metta_source_summary/4 supplies manifest signatures.
% Guarantees: eager, background and lazy loads share source identity and reload
%   receipts; background and lazy admission names every effectful runnable.
%   Reference maps may enumerate read-only results; initializers must be
%   pureStructural
%   [tested: reference_loading; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
% Owns resources: a home owns its spawn future and loading wrappers until the
%   load settles or the home is released. Scoped lazy observers leave at exit.
% Guarded by: metta_source_singleflight/2 owns each canonical source; short
%   manifest publication precedes worker admission through the same key.
% Decides: a space defaults to identity mapping and eager loading. Waiting for
%   another worker follows thread_await/2's transaction refusal.

:- dynamic metta_reference_library_home/2, metta_reference_prolog_head/3.
:- dynamic metta_reference_manifest_head/3, metta_reference_manifest_row/2.
:- dynamic metta_reference_load_state/2, metta_reference_loading_head/3.
:- dynamic metta_reference_finish_ref/2, metta_reference_space_option/3.
:- dynamic metta_reference_admission_option/2.
:- dynamic finish_import_attempt/4.
:- dynamic metta_reference_namespace_watch/0.
:- volatile metta_reference_namespace_watch/0.
:- '$notransact'(metta_reference_namespace_watch/0).

metta_reference_option(Space, Key, Value) :-
    metta_reference_space_option(Space, Key, Held), !, Value = Held.
metta_reference_option(_, 'from-map', ['|->', [Head], Head]).
metta_reference_option(_, load, eager).

metta_reference_set_option(Key, Value) :-
    metta_reference_install_hooks,
    current_metta_space(Space),
    retractall(metta_reference_space_option(Space, Key, _)),
    ( Value == none -> true
    ; assertz(metta_reference_space_option(Space, Key, Value)) ).

metta_reference_source(_, Source, Source) :-
    metta_space_name(Source), !.
metta_reference_source(Space, Source, Home) :-
    metta_reference_source_path(Source, Path),
    atom_concat('&library:', Path, Home),
    metta_reference_option(Space, load, Policy),
    ( Policy == eager -> Manifest = none
    ; metta_reference_read_manifest(Home, Path, Manifest) ),
    metta_source_singleflight(Path,
        metta_reference_start(Home, Path, Policy, Manifest, Action)),
    metta_reference_complete_start(Action).

metta_reference_source_path(Source, Path) :-
    ( nonvar(Source), Source = [library|_]
    -> resolve_module_form(Source, File)
    ; library(Source, File) ),
    resolve_metta_import_path(File, Path).

metta_reference_read_manifest(Home, Path, manifest(Forms, Signatures)) :-
    filereader:read_source_text(Path, Source),
    filereader:parse_metta_source_summary(Source, Forms, Signatures, _),
    empty_assoc(Seen), metta_reference_check_manifest(Home, Path, Forms, Seen, _).

% The reader checks the text it actually read as well as the initial manifest.
% An edit between background submission and the worker's read cannot execute
% an initializer that was absent from the admitted snapshot.
metta_reference_admit_text(Home, Source) :-
    ( current_source_identity(file(Path), _) -> true
    ; metta_reference_library_home(Home, Path) ),
    filereader:parse_metta_source_summary(Source, Forms, _, _),
    empty_assoc(Seen), metta_reference_check_manifest(Home, Path, Forms, Seen, _).

metta_reference_check_manifest(Home, Path, Forms, Seen0, Seen) :-
    put_assoc(Path, Seen0, true, Entered),
    space_module(Home, Module),
    file_directory_name(Path, Directory),
    setup_call_cleanup(asserta(filereader:working_dir(Directory), Ref),
        metta_with_source_effect_program(Module, Forms,
            foldl(metta_reference_check_form(Home, Module, Path), Forms, Entered, Seen)),
        erase(Ref)).

metta_reference_check_form(Home, Module, Path, Parsed, Seen0, Seen) :-
    parsed_form_parts(Parsed, Kind, _, Original), copy_term(Original, Form),
    ( Kind == runnable
    -> metta_host_source_effect_plan(Module, Form, _, Effect),
       metta_reference_require_effect(Path, Original, Effect, pureStructural), Seen = Seen0
    ; Kind == function
    -> metta_host_source_compile_effect_plan(Module, Form, _, Effect),
       metta_reference_require_effect(Path, Original, Effect, pureStructural), Seen = Seen0
    ; nonvar(Form), Form = [from,Source|Maps]
    -> metta_reference_row_map(Home, Maps, Original, Map),
       metta_reference_map_effect(Module, Map, Effect),
       metta_reference_require_effect(Path, Original, Effect, nondeterministicReadOnly),
       metta_reference_check_dependency(Source, Seen0, Seen)
    ; Seen = Seen0 ).

metta_reference_check_dependency(Source, Seen, Seen) :- metta_space_name(Source), !.
metta_reference_check_dependency(Source, Seen0, Seen) :-
    metta_reference_source_path(Source, Path),
    ( get_assoc(Path, Seen0, _) -> Seen = Seen0
    ; atom_concat('&library:', Path, Home),
      filereader:read_source_text(Path, Text),
      filereader:parse_metta_source_summary(Text, Forms, _, _),
      metta_reference_check_manifest(Home, Path, Forms, Seen0, Seen) ).

% Maps receive a finished Symbol. The identity lambda returns that argument;
% other lambdas expose their body. Ordinary partial calls expose both their
% construction and application. A dynamically chosen callable stays oracleIO.
% An evaluated partial already holds its captured arguments as values. Plan
% its direct call, so a captured expression is not evaluated a second time.
metta_reference_map_effect(Module, Map, Effect) :-
    nonvar(Map), Map = partial(Name, Bound), atom(Name), is_list(Bound), !,
    append(Bound, [_, _], Args), Goal =.. [Name|Args],
    metta_host_goal_effect_plan(Module, Goal, _, Effect).
metta_reference_map_effect(Module, Map, Effect) :-
    metta_host_source_compile_effect_plan(Module, [=,[reference_mapper],Map], _, Compile),
    ( nonvar(Map), Map = ['|->',[Argument],Body]
    -> ( Body == Argument -> Runtime = pureStructural
       ; metta_host_source_effect_plan(Module, Body, _, Runtime) ),
       Classes = [Compile, Runtime]
    ; atom(Map)
    -> metta_host_source_effect_plan(Module, [Map,_], _, Runtime),
       Classes = [Compile,Runtime]
    ; is_list(Map), Map = [Name|_], atom(Name),
      \+ translator:metta_special_form(Name)
    -> metta_host_source_effect_plan(Module, Map, _, Construct),
       append(Map, [_], Applied),
       metta_host_source_effect_plan(Module, Applied, _, Runtime),
       Classes = [Compile,Construct,Runtime]
    ; Classes = [oracleIO] ),
    metta_effect_compose(Classes, Effect).

metta_reference_admission_scope(Home, Policy, enabled) :-
    !,
    asserta(metta_reference_space_option(Home, load, Policy), Ref),
    assertz(metta_reference_admission_option(Home, Ref)),
    filereader:metta_reference_source_reader(Home, enabled).
metta_reference_admission_scope(Home, _, disabled) :-
    filereader:metta_reference_source_reader(Home, disabled),
    forall(retract(metta_reference_admission_option(Home, Ref)), erase(Ref)).

% A map is an answer relation, including empty and multiple answers. Its
% read-only enumeration is part of row publication, not an initializer.
metta_reference_require_effect(_, _, Effect, Ceiling) :-
    metta_effect_covered(Effect, Ceiling), !.
metta_reference_require_effect(Path, Form, Effect, _) :-
    throw(error(metta_effectful_reference_load(Path, Form, Effect), none)).

metta_reference_start(Home, Path, Policy, Manifest, Action) :-
    metta_reference_load_state(Home, pending(Future)),
    metta_reference_thread_call(thread_settled, Future, true), !,
    catch(metta_reference_await(Home, Future), Error,
          ( metta_reference_load_state(Home, pending(_)) -> throw(Error) ; true )),
    metta_reference_start(Home, Path, Policy, Manifest, Action).
metta_reference_start(Home, _, Policy, _, Action) :-
    metta_reference_load_state(Home, pending(Future)), !,
    ( Policy == background -> Action = ready ; Action = await(Home, Future) ).
metta_reference_start(Home, Path, _, _, ready) :-
    import_cache_current(Home, Path), !.
metta_reference_start(Home, Path, Policy, Manifest, ready) :-
    metta_reference_forget_settled_future(Home),
    ( metta_reference_library_home(Home, Path) -> true
    ; assertz(metta_reference_library_home(Home, Path)) ),
    metta_reference_watch(Home),
    ( Policy == background
    -> catch(metta_reference_background(Home, Path, Manifest), Error,
             (metta_reference_release_loader(Home), throw(Error)))
    ; Policy == lazy
    -> setup_call_cleanup(
           ( metta_reference_admission_scope(Home, lazy, enabled),
             filereader:metta_reference_lazy_reader(Home, enabled),
             spaces:metta_reference_lazy_equations(Home, enabled) ),
           importer_helper(Home, Path),
           ( spaces:metta_reference_lazy_equations(Home, disabled),
             filereader:metta_reference_lazy_reader(Home, disabled),
             metta_reference_admission_scope(Home, lazy, disabled) ))
    ; importer_helper(Home, Path) ).

metta_reference_complete_start(ready).
metta_reference_complete_start(await(Home, _)) :-
    metta_reference_wait(Home).

metta_reference_background(Home, Path, manifest(Forms, Signatures)) :-
    metta_require_platform('background library load', concurrency),
    ( current_transaction(_)
    -> throw(error(metta_wait_in_transaction('background library load'), none))
    ; true ),
    library('lib_thread.pl', ThreadLibrary), use_module(ThreadLibrary, []),
    metta_reference_admission_scope(Home, background, enabled),
    retractall(metta_reference_manifest_head(Home, _, _)),
    retractall(metta_reference_manifest_row(Home, _)),
    sort(Signatures, Heads),
    forall(member(Name-Arity, Heads),
           assertz(metta_reference_manifest_head(Home, Name, Arity))),
    forall(( member(Parsed, Forms),
             parsed_form_parts(Parsed, expression, _, Row) ),
           assertz(metta_reference_manifest_row(Home, Row))),
    metta_reference_install_finish(Home, Path),
    space_module(Home, Module),
    forall(member(Name-Arity, Heads),
           ( compiled_function_name(Name, Predicate), functor(Head, Predicate, Arity),
             Module:dynamic(Predicate/Arity),
             wrap_predicate(Module:Head, metta_reference_loading, Original,
                            (metta_reference_wait(Home), call(Original))),
             assertz(metta_reference_loading_head(Home, Name, Arity)) )),
    metta_reference_thread_call(thread_spawn, ['import!', Home, Path], Future),
    assertz(metta_reference_load_state(Home, pending(Future))),
    metta_reference_update_namespace_watch.

% A manifest need not know names supplied by its own from rows. A failed
% namespace lookup must settle pending homes before deciding the name is data.
% CPython's LazyLoader retains its attribute interception through publication:
% https://github.com/python/cpython/blob/v3.14.0/Lib/importlib/util.py
% The wrappers exist only while a home is unfinished; successful lookups and
% name enumeration keep their ordinary path. Refresh and a worker's own source
% do not wait for themselves. No publication mutex is held across an await.
metta_reference_update_namespace_watch :-
    with_mutex(metta_loader,
        ( metta_reference_loading(_)
        -> ( metta_reference_namespace_watch -> true
           ; wrap_predicate(metta_engine:fun_here(Name), metta_reference_namespace,
                            Original,
                 ( ( var(Name) -> call(Original)
                   ; call(Original) -> true
                   ; current_metta_module(Module),
                     metta_reference_wait_namespace(Module), call(Original) ) )),
             wrap_predicate(metta_engine:metta_host_function_callable_from(Module, Name),
                            metta_reference_namespace, Callable,
                 ( ( var(Name) -> call(Callable)
                   ; call(Callable) -> true
                   ; metta_reference_wait_namespace(Module), call(Callable) ) )),
             assertz(metta_reference_namespace_watch) )
        ; ( retract(metta_reference_namespace_watch)
          -> unwrap_predicate(metta_engine:fun_here(_), metta_reference_namespace),
             unwrap_predicate(metta_engine:metta_host_function_callable_from(_, _),
                              metta_reference_namespace)
          ; true ) )).

metta_reference_wait_namespace(Module) :-
    \+ metta_reference_refreshing,
    metta_module_space(Module, Space),
    findall(Home, metta_reference_pending_namespace(Space, [], Home), Homes0),
    sort(Homes0, Homes), Homes \== [],
    forall(member(Home, Homes), metta_reference_wait(Home)),
    metta_reference_refresh.

metta_reference_pending_namespace(Space, Seen, Home) :-
    \+ memberchk(Space, Seen),
    ( metta_reference_loading(Space),
      \+ ( metta_reference_library_home(Space, Path), thread_self(Thread),
           metta_source_flight(Path, Thread, _) ), Home = Space
    ; metta_reference_row(Space, _, Next, _),
      metta_reference_pending_namespace(Next, [Space|Seen], Home) ).

metta_reference_loading(Home) :-
    metta_reference_load_state(Home, pending(_)).
metta_reference_loading(Home) :-
    metta_reference_load_state(Home, failed(_, _)).

metta_reference_wait(Home) :-
    (   metta_reference_library_home(Home, Path),
        thread_self(Thread), metta_source_flight(Path, Thread, _)
    ->  true
    ;   metta_reference_load_state(Home, failed(Error, _))
    ->  throw(Error)
    ;   metta_reference_load_state(Home, pending(Future))
    ->  metta_reference_await(Home, Future)
    ;   true
    ).

% These names belong to an optional library loaded before the first future
% exists. Resolve them at that boundary rather than importing it at engine
% boot; reference_loading and lib-autoload check the loaded implementation.
metta_reference_thread_call(Name, Input, Output) :-
    compound_name_arguments(Goal, Name, [Input, Output]),
    call(lib_thread:Goal).

% A worker can be cancelled before importer_helper enters its cleanup frame.
% import! always produces an answer on success, so an empty settled future is
% cancellation. A refused wait is not a failed load and must not publish one.
metta_reference_await(_, Future) :-
    current_transaction(_), !,
    once(metta_reference_thread_call(thread_await, Future, _)).
metta_reference_await(Home, Future) :-
    catch(( once(metta_reference_thread_call(thread_await, Future, _))
          -> metta_reference_finish(Home, exit)
          ; throw(error(metta_reference_load_failed(Home, cancelled), none)) ),
          Error,
          ( metta_reference_finish(Home, exception(Error)), throw(Error) )).

metta_reference_install_finish(Home, Path) :-
    ( metta_reference_finish_ref(Home, _) -> true
    ; findall((finish_import_attempt(Home, Path, Prior, Catcher) :-
                   Body, metta_reference_finish(Home, Catcher)),
               ( clause(finish_import_attempt(Home, Path, Prior, Catcher),
                        Body, Original),
                 \+ metta_reference_finish_ref(_, Original) ), Clauses),
      reverse(Clauses, Reversed),
      forall(member(Clause, Reversed),
             ( asserta(Clause, Ref),
               assertz(metta_reference_finish_ref(Home, Ref)) )) ).

metta_reference_finish(Home, Catcher) :-
    (   retract(metta_reference_load_state(Home, pending(Future)))
    ->  metta_reference_admission_scope(Home, background, disabled),
        (   Catcher == exit
        ->  assertz(metta_reference_load_state(Home, ready(Future))),
            metta_reference_remove_loading_wrappers(Home),
            retractall(metta_reference_manifest_head(Home, _, _)),
            retractall(metta_reference_manifest_row(Home, _))
        ;   ( Catcher = exception(Error) -> true
            ; Error = error(metta_reference_load_failed(Home, Catcher), none) ),
            assertz(metta_reference_load_state(Home, failed(Error, Future)))
        ),
        metta_reference_refresh,
        metta_reference_update_namespace_watch
    ;   true
    ).

metta_reference_remove_loading_wrappers(Home) :-
    space_module(Home, Module),
    forall(retract(metta_reference_loading_head(Home, Name, Arity)),
           ( compiled_function_name(Name, Predicate), functor(Head, Predicate, Arity),
             unwrap_predicate(Module:Head, metta_reference_loading) )).

metta_reference_forget_settled_future(Home) :-
    (   metta_reference_load_state(Home, ready(Future))
    ;   metta_reference_load_state(Home, failed(_, Future))
    ), !,
    metta_release_space(Future),
    retractall(metta_reference_load_state(Home, _)),
    metta_reference_remove_loading_wrappers(Home).
metta_reference_forget_settled_future(_).

metta_reference_release_loader(Home) :-
    (   metta_reference_load_state(Home, State)
    ->  ( State = failed(_, Future) -> true ; arg(1, State, Future) ),
        metta_reference_thread_call(thread_cancel, Future, _),
        metta_release_space(Future)
    ;   true
    ),
    metta_reference_admission_scope(Home, _, disabled),
    metta_reference_remove_loading_wrappers(Home),
    retractall(metta_reference_load_state(Home, _)),
    retractall(metta_reference_manifest_head(Home, _, _)),
    retractall(metta_reference_manifest_row(Home, _)),
    retractall(metta_reference_library_home(Home, _)),
    retractall(metta_reference_prolog_head(Home, _, _)),
    retractall(metta_reference_space_option(Home, _, _)),
    forall(retract(metta_reference_finish_ref(Home, Ref)), erase(Ref)),
    metta_reference_update_namespace_watch.

metta_reference_prolog_context(Home, Module) :-
    current_metta_space(Home), metta_reference_library_home(Home, _),
    space_module(Home, Module).

metta_reference_register_prolog(Home, Module, Name, Arity) :-
    metta_reference_prolog_arities(Module, Name, Arity, Arities),
    metta_reference_prolog_owner(Module, Name, Owner),
    forall(member(A, Arities),
           ( ( Owner == Module -> true
             ; Owner:export(Name/A), Module:import(Owner:Name/A) ),
             register_arity(Name, A),
             ( metta_reference_prolog_head(Home, Name, A) -> true
             ; assertz(metta_reference_prolog_head(Home, Name, A), Ref),
               record_source_assertion(Ref) ) )),
    register_fun_in(Module, Name),
    spaces:announce_function_changed(Module, Name),
    metta_reference_changed(Home).

metta_reference_prolog_arities(Module, Name, Arity, Arities) :-
    ( metta_reference_prolog_owner(Module, Name, Owner) -> true ; Owner = Module ),
    findall(A,
            ( current_predicate(Owner:Name/A), A > 0,
              ( Arity == scan -> true ; A =:= Arity ) ), Found),
    sort(Found, Arities),
    ( Arities == []
    -> throw(error(existence_error(procedure, Module:Name/Arity),
                   context(import_prolog_functions/2,
                           'the library home has no predicate with this name')))
    ; true ).

metta_reference_prolog_owner(Module, Name, Owner) :-
    default_module(Module, Owner), current_predicate(Owner:Name/_), !.

metta_reference_check_prolog_source(File) :-
    metta_source_declarations(File, Declarations),
    forall(member(requires(Capability), Declarations),
           metta_require_platform(File, Capability)).

% SWI skips directives when a module is already loaded. Re-read only its
% export declarations for the new home, through the same declaration recorder.
metta_reference_register_exports(File) :-
    absolute_file_name(File, Path, [file_type(prolog), access(read)]),
    ( pending_metta_export(Path, _, _) -> true
    ; ( module_property(Owner, file(Path)) -> true
      ; current_metta_module(Owner) ),
      setup_call_cleanup(open(Path, read, In),
                         metta_reference_read_exports(In, Path, Owner), close(In)) ),
    register_pending_exports.

metta_reference_read_exports(In, File, Owner) :-
    read_term(In, Term, [module(Owner)]),
    ( Term == end_of_file -> true
    ; ( Term = (:- metta_export(Text))
      -> parse_metta_source(Text, Forms),
         forall(member(Parsed, Forms), record_metta_export(File, Parsed))
      ; true ),
      metta_reference_read_exports(In, File, Owner) ).

:- multifile prolog:error_message//1.
prolog:error_message(metta_effectful_reference_load(Path, Form, Effect)) -->
    [ '~w has load-time form ~q with effect ~w; use eager loading'-
      [Path, Form, Effect] ].
prolog:error_message(metta_reference_load_failed(Home, Catcher)) -->
    [ 'loading ~w ended with ~q; a later from row may retry'-[Home, Catcher] ].
