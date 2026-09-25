% Guarantees: metta_import_record/2 exposes live source ownership and
%   metta_unimport/2 withdraws it transactionally [tested: lib_import_lifecycle; commit=4f2d6c0f8eb293b73f8dde30a1c84e24834f7393].
% Guarded by: metta_loader protects source-flight ownership, never user forms.
% Owns resources: each source owner destroys its queue on every exit; waiters
%   recheck receipts after waking [tested: loader_singleflight; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
% Guarantees: metta_host_probe_function/2 retires its probe at every swept
%   inference budget while preserving the static-predicate refusal
%   [tested: trailed_scopes; commit=40b71fc99571872ca5fc85cdaf7902b467166539].
% Guarantees: a package row reaches its claimant as the file wrote it, and a
%   file's rows perform for that file's own load and for no other load into the
%   same space
%   [tested: packages:a_backing_row_reaches_its_claimant_as_data,
%   packages:a_backing_row_performs_only_for_the_file_that_carries_it;
%   commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
%
% Guarantees: a package row is performed by the load that carried it and then
%   retired from every space but that path's own library home, so an importer
%   holds no `(package ...)` atom and no callable `(package ...)` equation
%   [tested: packages:a_manifest_row_does_not_reach_the_importing_space;
%   commit=d6e09995c40e18c295e626e7a7cb3486b9a3f4bd].
%
% Purpose: import Prolog predicates and MeTTa sources while preserving module and source-lifecycle boundaries
% Guarantees: process Prolog registrations and declared arrows belong to their
%   loaded host source, independently of the MeTTa source that imported them
%   [tested: lib_import_lifecycle:host_registration_outlives_the_importing_source;
%   commit=b039123616aa9ec9ede3ceec146660a49f4e6709].
% Guarantees: host adoption preserves process-owned function and arity claims
%   when the initiating MeTTa source fails
%   [tested: host_registration:an_adopted_operation_outlives_the_importing_source;
%   commit=b039123616aa9ec9ede3ceec146660a49f4e6709].
% Assumes: engine/source_loading.pl:loading_loudly/1 collects printed failures
%   and restores nested loader state [tested: source_loading; commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d].
% Guarantees: declared determinism is applied to the predicate's implementation
%   module, including plain host files reached through the core's base chain
%   [tested: test_a_declared_det_function_that_leaks_a_choice_point_raises,
%   test_the_declaration_is_reported_beside_the_redos; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720].
% Guarantees: assertzPredicate/2, assertaPredicate/2 and retractPredicate/2
%   modify host clauses in user, as consult_global/1 does
%   [tested: engine_modules:asserted_host_clauses_keep_the_host_module; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720].
% Guarantees: readying an extension's space checks every word its
%   seam:foreign_capability/2 clauses declare against the catalog's
%   (vocabulary provider-capability ...) row, which is the door a Prolog
%   library's own declarations pass through
%   [tested: catalog_vocabulary_words:an_unknown_capability_word_is_refused;
%   commit=7f9c810e5f4a2023ad98de34e848667dd72bc4a7].
% Guarantees: Export readers use metta_runtime_type/2 to recognise annotated
%   arrows and derive arity while retaining the declared type
%   [tested: run_tests(metta_arrow_projection); commit=cba149fe709e7e11b343d7c722ea81b81275a1a5].
% Assumes: engine/metta.pl consults this plain file while its owning module is the load context.
% Guarantees: every definition retains engine/metta.pl's implementation module and original load order;
%   a named-space MeTTa import is reusable only while its committed source receipt validates its life,
%   digest, source-load identity, and exact stored-output references;
%   a Prolog source declaring `:- metta_requires(Capability)` for a platform
%   capability this build does not have is refused before it loads, naming the
%   capability, its platform library and what the absence costs
%   [tested: platform_capabilities_reduced:a_library_that_declares_an_absent_capability_never_loads,
%   platform_capabilities:a_source_declaration_is_read_without_running_the_source;
%   commit=87d998c24278fc7f020ccb0e408ebcd9332b63eb].
% Guarantees: metta_registration_names/2 answers the head names one
%   registration FORM claims; metta_string_registrations/2 answers a whole
%   source's, each with the index of the form that claims it. Both READ and
%   never run, so a documentation reader sees a head published only through a
%   runnable `!(import_prolog_function ...)` form and asking cannot register
%   one [tested: prolog_interface_registrations:one_form_names_the_head_it_registers,
%   prolog_interface_registrations:every_importer_spelling_names_its_list,
%   prolog_interface_registrations:a_computed_name_list_claims_nothing,
%   prolog_interface_registrations:a_source_answers_its_registrations_with_form_indices,
%   prolog_interface_registrations:reading_a_registration_does_not_perform_it;
%   commit=ff4257005f562786e3ef7a5a37ce94b7d80e782d].
% Guarantees: the version an extension declares is part of what
%   metta_source_declarations/2 answers, so a reader asking what a library
%   states does not consult the file to learn it
%   [tested: prolog_interface_registrations:a_declared_version_is_part_of_what_a_source_declares;
%   commit=ff4257005f562786e3ef7a5a37ce94b7d80e782d].
% Fails when: loaded directly or from another module; internal state and unqualified meta-goals would acquire the wrong owner.
% [tested: tests/prolog/suites/evaluation/metta.plt, tests/prolog/static_checks.pl; commit=9a116762fb4372d55675e2ef64b7657092bc136d]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

%%% Prolog interop: %%%
argv(K, _) :- var(K), !, refuse_unbound_input(argv, 1).
argv(K, Arg) :- current_prolog_flag(argv, Argv), nth0(K, Argv, A), ( atom_number(A, N) -> Arg = N ; Arg = A ).
%A name with no predicate behind it is refused where the name is written.
%A registered name with no arity recorded compiles every call to it into a
%partial application rather than failing:
%!(import_prolog_functions_from_file "mylib.pl" (no-such-predicate)) reported
%success and !(no-such-predicate 1) answered (partial no-such-predicate (1)).
%A silent wrong answer is the worst outcome available here.
%
%The Python side refuses the same name in MeTTa.register_prolog for the same
%reason; this is the engine-level gate, so every route in gets it.
%
%register_fun_in(user, N), not register_fun/1: a registration that records no
%home module resolves only while NO named space has claimed the name, because
%fun_here/1's first clause is \+ fun_scoped(F). One named space defining an
%equation of the same name therefore turned every registered predicate into
%inert data in every space, with no error: !(rp-norm 3) answered (rp-norm 3).
%user is the module the clauses really are in, so this states where they live
%rather than adding a rule, and a named space that defines the name still
%shadows it, which is the behaviour that should happen
%[tested: a_registered_predicate_survives_a_named_space_claiming_its_name].
import_prolog_function(N, _) :- var(N), !,
                                refuse_unbound_input(import_prolog_function, 1).
import_prolog_function(N, true) :-
    import_prolog_function_at(N, scan).

%The DECLARED route knows the arity and registers that one, where the scan
%registers every arity current_predicate/1 can see. That difference is a
%defect when a declaration exists: `(: rc-scale (-> Number Number))` beside an
%internal `'rc-scale'/3` published BOTH, so `(rc-scale 3 7)` answered 21
%through a predicate the library never declared [reproduced 2026-08-16].
%
%The arity is already in hand at that moment. refuse_undeclared_arity/3
%computes it to check the predicate exists, so threading it out costs nothing
%and closes discovery on the route the whole metta_export design exists to
%make the good one. The scan stays for the legacy `names=` route, where
%nothing was declared and discovery is all there is
%[tested: a_declared_export_publishes_only_its_declared_arity].
import_prolog_function_at(N, Arity) :-
    metta_reference_prolog_context(Home, Module), !,
    must_be(atom, N),
    metta_reference_register_prolog(Home, Module, N, Arity).
import_prolog_function_at(N, Arity) :-
    must_be(atom, N),
    %ALREADY DONE is not a failure. The name is a builtin, the clauses behind
    %it are still the ones the engine booted with, and so the request -- make
    %this Prolog predicate callable from MeTTa -- is already satisfied; there
    %is nothing to register and nothing to refuse. Upstream's lib_import.metta
    %asks for (static-import! git-import! use-module!) in one call and this
    %engine ships git-import! itself, so the refusal below stopped a library
    %that asks for a superset of what it provides from loading at all
    %[measured 2026-08-30: examples/prologimport.metta stopped there with
    %every earlier test in the file already passing].
    %
    %Returning EARLY rather than falling through is the whole point: running
    %the registration again would call register_prolog_arities/1 a second
    %time, after retract_unrelated_system_arities/0 has already run, and put
    %back the system-lent arities that pass exists to drop -- `!(not)` would
    %abort the runnable again. A no-op does nothing
    %[tested: a_builtin_the_engine_still_backs_is_a_no_op].
    (   builtin_clauses_unchanged(N)
    ->  true
    ;   import_prolog_function_now(N, Arity)
    ).

import_prolog_function_now(N, Arity) :-
    refuse_reserved_registration(N),
    refuse_absent_prolog_function(N, Arity),
    prolog_function_source(N, Arity, Source),
    claim_function_name(N, prolog, Source),
    %The clauses are the HOST's, in whatever module consult_global/1 put them
    %(`user`), and every space reaches them through the base chain. What is
    %registered here is the base TIER's claim on the name, which is &self's
    %module: fun_home_in/3 reads that claim as "callable from every space
    %unless a space of its own claims the name", and it is the same claim
    %register_op/2 makes on the Python side.
    (   Arity == scan
    ->  findall(A, prolog_registration_arity(N, A), Arities)
    ;   Arities = [Arity]
    ),
    register_process_function(N, Arities).

%The file the clauses in the database RIGHT NOW came from, read off a clause
%rather than off the predicate. predicate_property(file(F)) is the wrong
%question here and answers the wrong thing: after a second library redefines a
%static predicate it still reports the FIRST library's file, which is exactly
%the case this has to detect. A registration made from source held in memory
%has no file, and says so.
prolog_function_source(N, Source) :-
    prolog_function_source(N, scan, Source).

%The declared arity, when the caller holds one, turns the name's arity
%enumeration into one indexed probe: a registration burst of a few hundred
%C-seat names spent about 14% of its whole example inside
%current_predicate/1's table iteration before the arity was threaded
%[measured 2026-08-30: htable_iter and pl_current_predicate1 in the
%c_extension example's span profile]. `scan` keeps the enumeration for the
%doors that genuinely do not know the arity.
prolog_function_source(N, DeclaredArity, Source) :-
    (   integer(DeclaredArity),
        functor(Head, N, DeclaredArity),
        nth_clause(Head, 1, Ref),
        clause_property(Ref, file(File))
    ->  Source = File
    ;   \+ integer(DeclaredArity),
        current_predicate(N/Arity),
        functor(Head, N, Arity),
        nth_clause(Head, 1, Ref),
        clause_property(Ref, file(File))
    ->  Source = File
    ;   Source = unknown
    ).

%Two names a registration must not take, both of which it used to take
%silently while reporting success.
%
%A builtin, because a consulted predicate REPLACES the engine's static one for
%the whole process: registering a predicate named + made !(+ 1 2) answer
%whatever the library said, and the only diagnostic was SWI's redefinition
%warning on stderr, which no caller sees. The equation route already refuses
%exactly this at spaces.pl through metta_builtin_redefinition/3, so this is
%the same rule reaching the other road in rather than a new one.
%
%A translated head, because translator rules and translate_special_dl/5 are
%tried BEFORE function dispatch, so the registration compiles nothing and can
%never be reached:
%registering a predicate named if left !(if True 1 2) answering 1 from the
%translator and the library's clauses dead, with nothing said at any point.
%Accepting a registration that cannot run is telling the author their code is
%installed when it is not
%metta_translated_head/1 is the translator's own registry, so a rule added at
%run time is covered without another hand-maintained list
%[tested: a_builtin_whose_clauses_moved_is_refused,
%a_reserved_name_is_refused_before_the_source_loads,
%a_special_form_name_is_refused,
%test_registering_any_translator_compiled_head_is_refused_by_name;
%commit=c530ccb8fb7d0a5b2aa53df6e9f981ada9f81be8].
refuse_reserved_registration(N) :-
    (   builtin_fun(N)
    ->  throw(error(permission_error(register, metta_builtin, N),
                    context(import_prolog_function/2,
                            'the engine defines this name')))
    ;   metta_translated_head(N)
    ->  throw(error(permission_error(register, metta_special_form, N),
                    context(import_prolog_function/2,
                            'the translator compiles this name')))
    ;   true
    ).

%Who put a function's clauses where they are. fun/1 says a name IS a function
%and fun_in/2 says which module its clauses live in; neither says which tier
%put them there, and without that a registration from one tier silently took
%a name another tier owned. Registering a Prolog predicate over a live Python
%operation replaced it, left metta_py_op_spec/3 still claiming the name, and
%wedged it for the life of the process: the operation could not be
%unregistered, because retractall/1 on what was now a static predicate raised,
%and could not be re-registered either.
%
%Equations are deliberately not recorded here. Their origin is already
%answerable, from the space that holds the atom and from fun_in/2, and one
%assertion per compiled equation is a cost on the hot path for a fact that is
%already derivable [tested: a_name_another_tier_owns_is_refused,
%test_a_python_operation_is_not_silently_replaced].
:- dynamic metta_function_origin/3.   %metta_function_origin(Name, Tier, Detail)

refuse_other_tiers_name(Name, Tier) :-
    (   metta_function_origin(Name, Other, OtherDetail), Other \== Tier
    ->  throw(error(permission_error(register, metta_function, Name),
                    context(refuse_other_tiers_name/2,
                            owned_by(Other, OtherDetail))))
    ;   true
    ).

%The same refusal for two PROLOG sources, asked where it can still be acted
%on: before the source that would take the name has been read.
%
%claim_function_name/3 asks the same question after the consult and has to,
%because that is the only place the clobber can be DETECTED. But detection
%after the fact told the wrong author: B was refused by name and A, which did
%nothing, silently answered B's implementation from then on
%[reproduced 2026-08-16: `A before B: 20`, `B refused`, `A after: 30`]. This
%is the check moved to where refusing still prevents something, which is
%exactly why check_prolog_function_names/3 exists for builtins ten lines
%down, and it is the same error term so one diagnostic covers both positions.
refuse_other_sources_name(Name, Source) :-
    (   metta_function_origin(Name, prolog, Owner),
        Owner \== unknown, Source \== unknown, Owner \== Source
    ->  throw(error(metta_name_owned_by_source(Name, Owner),
                    context(refuse_other_sources_name/2,
                            'two Prolog sources claim one name')))
    ;   true
    ).

%unknown is not an identity, it is prolog_function_source/2 saying it could
%not tell, which is what a predicate installed by use_foreign_library/1
%answers: it has no clause with a file behind it. Two of them are not the same
%source and one is not a different source either, so comparing them decides
%nothing and refusing on one refuses a library re-registering itself
%[tested: test_a_compiled_library_registers_from_python]. A C predicate cannot
%take a name this way in silence regardless, because installing over a static
%predicate raises from SWI rather than warning.

%What a source is CALLED, for comparing one against another. A file is
%recorded under SWI's canonical absolute path, since that is what
%clause_property(file(F)) answers, and a caller passes whatever they typed; a
%load from memory has no file and is recorded under the name it loaded as, so
%it passes through unchanged.
canonical_prolog_source(Source, Canonical) :-
    (   absolute_file_name(Source, Resolved, [file_errors(fail), access(read)])
    ->  Canonical = Resolved
    ;   Canonical = Source
    ).

%Re-registering under the same tier is replacement, which is what register_op
%does on every call. Two different PROLOG SOURCES claiming one name is not
%replacement, it is two libraries destroying each other's predicate, so that
%is refused and the source that owns it is named.
%
%This fires AFTER the consult, and it has to, which is the shape of the
%problem rather than a shortcut. SWI does warn about the redefinition, on
%stderr, and it does not throw: "Redefined static procedure 'shared-norm'/2"
%is printed and the load continues, so no catch/3 can see it and the only
%reliable check is a positive one afterwards, asking whether the name still
%resolves to what its owner loaded. CPython reaches the same answer for the
%same reason and does it by name as a matter of course
%[source: CPython, PyCapsule_Import, "a high degree of certainty that the
%Capsule they load contains the correct C API"]. The clobber has happened by
%the time this raises; what it buys is that the author hears about it instead
%of shipping a library silently bound to someone else's code, and
%unregister_metta_extension/1 is how they take it back out
%[tested: two_sources_cannot_claim_one_name].
claim_function_name(Name, Tier, Detail) :-
    (   metta_function_origin(Name, Owner, OwnerDetail)
    ->  claim_over(Name, Owner, OwnerDetail, Tier, Detail)
    ;   assertz(metta_function_origin(Name, Tier, Detail))
    ).

claim_over(Name, Owner, _, Tier, Detail) :-
    Owner == Tier, Owner \== prolog, !,
    retractall(metta_function_origin(Name, _, _)),
    assertz(metta_function_origin(Name, Tier, Detail)).
claim_over(Name, prolog, Detail, prolog, Detail) :- !,
    retractall(metta_function_origin(Name, _, _)),
    assertz(metta_function_origin(Name, prolog, Detail)).
claim_over(Name, prolog, OwnerDetail, prolog, _) :- !,
    throw(error(metta_name_owned_by_source(Name, OwnerDetail),
                context(claim_function_name/3,
                        'two Prolog sources claim one name'))).
claim_over(Name, _, _, Tier, _) :-
    refuse_other_tiers_name(Name, Tier).

release_function_name(Name) :- retractall(metta_function_origin(Name, _, _)).

%%%% The host registration lifecycle, four calls instead of seven %%%%
%
%A host registering an operation performs one protocol: prove the name is
%free, assert its own dispatch clause, then make the engine treat the name
%as a function. The protocol's steps were published one bookkeeping
%predicate at a time (refuse_other_tiers_name, the probe, register_fun_in,
%arity/2, function_changed, claim_function_name, and the release trio), so
%every binding had to restate the engine's registration invariants in order.
%These four carry the whole protocol; the fine-grained predicates stay as
%the internals they always were.
%
%OPEN runs before the host mutates anything, which is the probe's whole
%value: a taken name refuses here, naming its owner, while nothing has been
%asserted yet. The tier refusal comes first because its diagnostic names the
%owning tier and what to do about it, where the probe's names a Prolog
%predicate [tested: host_registration:a_taken_name_refuses_before_any_write].
metta_host_open_function(Name, Tier, PredArity) :-
    refuse_other_tiers_name(Name, Tier),
    metta_host_probe_function(Name, PredArity).

%ADOPT runs after the host asserted its dispatch clause at the base tier:
%the name becomes a function, its dependents refresh against the clause
%that is already in place, and the tier claim lands last, after any
%unregistration of prior arities has run its releases
%[tested: host_registration:an_adopted_name_is_a_function_and_claimed].
metta_host_adopt_function(Name, Tier, Kind, PredArity) :-
    metta_self_module(Base),
    %The arity row BEFORE register_fun_in: registering a fresh name repairs
    %stale mentions through register_fun/1's scheduler, and that recompile
    %compiles the mention as a call, which needs the arity to exist. Flip
    %this order and adopt fails
    %[tested: host_registration:a_forgotten_name_reads_as_data_again].
    register_process_function(Name, [PredArity]),
    announce_function_changed(Base, Name),
    claim_function_name(Name, Tier, Kind).

%DROP removes one arity: the base tier's clauses at that functor and the
%arity row. The host guards this with its own bookkeeping so it only drops
%arities it registered; equations live in their space's own modules, and
%the tier claim keeps a host operation and a base-tier equation from
%sharing a name in the first place.
metta_host_drop_function(Name, PredArity) :-
    metta_self_module(Base),
    functor(Head, Name, PredArity),
    retractall(Base:Head),
    retractall(arity(Name, PredArity)).

%FORGET runs when nothing defines the name at any arity: the engine stops
%treating it as a function everywhere, the tier claim releases, and the
%dependents that compiled mentions of it as calls recompile back to data
%[tested: host_registration:a_forgotten_name_reads_as_data_again].
metta_host_forget_function(Name) :-
    retractall(fun(Name)),
    retractall(arity(Name, _)),
    unregister_fun_everywhere(Name),
    release_function_name(Name),
    announce_function_removed(Name).

%The probe is the assert the registration will do, on a clause that can
%never run, so the engine's own permission error surfaces before any
%existing registration has been touched. predicate_property cannot stand in
%for it: autoloadable names report static yet accept clauses. The fresh-name
%clause first, because it is the case every ordinary registration takes and
%it skips the assert, the erase and the property calls [measured 2026-08-18:
%register-op 39907 -> 38830 over 100 registrations, -10.8 each, min of 3].
%
%built_in and nothing wider decides the refusal: a merely AUTOLOADABLE
%library predicate reports defined, imported_from and a home module before
%it has ever been loaded, and a library predicate really in use is a free
%MeTTa name now that operation clauses go into the base tier's own module,
%where defining one shadows it locally. Of the 428 names the engine imports,
%probing the base module refuses 7, 4, 2 and 1 at MeTTa arity 0 to 3: SWI's
%protected core, which no module may redefine, the protected core a rewrite
%system needs, obtained rather than implemented [measured 2026-08-19, one
%process per measurement and a fresh module per name].
metta_host_probe_function(Name, PredArity) :-
    metta_self_module(Base),
    \+ current_predicate(Base:Name/PredArity),
    !.
metta_host_probe_function(Name, PredArity) :-
    metta_self_module(Base),
    functor(Probe, Name, PredArity),
    % Both releases are try_erase/1: metta_host_drop_function/2 on another
    % thread retracts every clause of Base:Probe, the probe's with them, and a
    % probe that lost its clause that way has still proved the name writable
    % [tested 2026-09-25T19:33:07+10:00: erase_sites:a_probe_whose_clause_is_taken_still_proves_the_name_free].
    % Workaround: swi-cleanup-window - mask signals over the probe and retire it through catch-port deferral.
    catch(sig_atomic(( assertz((Base:Probe :- fail), Ref),
                       catch(host_transactions:try_erase(Ref), Ball,
                             (host_transactions:try_erase(Ref), throw(Ball))) )),
          error(permission_error(modify, static_procedure, _), _),
          metta_host_refuse_taken_name(Name, PredArity, Probe)).

metta_host_refuse_taken_name(Name, PredArity, Probe) :-
    metta_self_module(Base),
    (   predicate_property(Base:Probe, imported_from(Owner))
    ->  true
    ;   Owner = Base
    ),
    Arity is PredArity - 1,
    throw(error(metta_op_name_taken(Name, Arity, PredArity, Owner),
                context(metta_host_open_function/3, 'the name is not free'))).

:- multifile prolog:error_message//1.
prolog:error_message(metta_op_name_taken(Name, Arity, PredArity, Owner)) -->
    [ 'registering ~w at ~w MeTTa argument(s) would assert into Prolog\'s \c
       ~w/~w, which ~w already owns in this process'-[Name, Arity, Name,
                                                      PredArity, Owner], nl,
      '  a registered operation\'s clauses live in the base tier, so its \c
       name has to be free there: register it under another name (the \c
       binding\'s name= override), or write it as an equation in a named \c
       space, which compiles into a module of its own' ].

%%%% A library declares its own exports, in the file that implements them %%%%
%
%Registering one predicate took three statements in two languages: the name in
%a Python call, the arity discovered by scanning whatever current_predicate/1
%happened to hold, and the type in a third statement whose ordering against
%call-site compilation nothing checked. Nothing kept the three in agreement,
%and the arity was DISCOVERED rather than declared, so a library shipping a
%public 'vec-dot'/3 and an internal helper 'vec-dot'/2 published both.
%
%Every comparable runtime puts the export declaration in the file that
%implements it: PyMethodDef, R_CallMethodDef, ErlNifFunc, napi_property_
%descriptor, SWI's own module/2 export list. R had exactly this engine's
%mechanism, symbol discovery, and walked away from it, because "the use of
%registration allows R to ensure that code compiled into packages does not
%inadvertently call routines in other packages"
%[source: R Extensions manual, section 5.4].
%
%The declaration is MeTTa, in a string, rather than a new Prolog operator. The
%types are MeTTa types, the reader that parses them is the engine's own, and
%the MeTTa arity comes from the type chain, so the arity cannot disagree with
%the type it was written beside:
%
%    :- metta_extension(pettorch, [version('0.3.1')]).
%    :- metta_export("
%        (: vec-dot (-> Number Number Number))
%        (: shape-of (-> Atom Atom))
%        (export vec-helper 1)
%    ").
%
%(export Name Arity) is the form for a name whose type the author does not
%want to state; the arity is the MeTTa arity, one less than the predicate's.
%
%The directive records; the LOAD registers, once the file has finished and its
%predicates exist. consult_global/1 and its two siblings are the funnel every
%route enters through, so the MeTTa spelling, register_prolog and a bare
%consult all get this [tested: prolog_interface_exports].
:- thread_local pending_metta_export/3. %pending_metta_export(File, Name, Type)
:- dynamic metta_extension_info/3.     %metta_extension_info(Extension, File, Options)
:- dynamic metta_extension_member/2.   %metta_extension_member(Extension, Name)

%The version of the extension SEAM a library was written against. A library
%built on today's ext_points.pl will be loaded into a later engine, and with
%nothing to check against a removed or renamed hook shows up as silence.
%
%Erlang's NIF loader is the model for the check: the major version must match
%and the minor must not be newer than the runtime's, or the load fails. The
%rule here is the same and stated the same way, because a library that
%declares nothing is the common case and must keep working: a declaration is
%checked, silence is not.
%
%The number moves when a seam a library can SEE changes: a hook removed or
%renamed, a hook's arguments changed, a refusal added where none was. Adding
%a hook moves the minor.
%1-1: seam:route_cap/4 added, and metta_shape_route/5 published as a
%service (2026-08-20).
metta_extension_api_version(1, 1).

metta_extension(Name, Options) :-
    must_be(atom, Name),
    must_be(list, Options),
    check_extension_requirements(Name, Options),
    declaring_file(File),
    retractall(metta_extension_info(Name, File, _)),
    assertz(metta_extension_info(Name, File, Options)),
    schedule_extension_readying(Name, Options).

%The readying moment, the instant the Python tier has always had: at
%registration foreign.py derives a provider's capabilities from the
%protocols it implements and validates the base class, while a Prolog
%provider became live because its file was consulted, with nothing
%inspected, validated or recorded. The version check above and the
%ownership row are two of the four things the audit found wanting that
%instant; the spaces(...) option is the other two. An extension declaring
%`spaces([&name, ...])` has each space validated WHEN ITS FILE FINISHES
%LOADING (the directive conventionally sits above the hook clauses, so
%validating inline would read an empty provider): the space is registered,
%it declares at least one capability (declaring nothing provides nothing),
%and every declared capability's hook has clauses behind it. `check(true)`
%additionally runs the full conformance kit, lib/lib_conformance/lib_conformance.pl's
%metta_check_space_provider/2, loaded on demand.
schedule_extension_readying(Name, Options) :-
    (   memberchk(spaces(Spaces), Options)
    ->  must_be(list, Spaces),
        Deferred = ready_extension_spaces(Name, Options, Spaces),
        (   prolog_load_context(source, _)
        ->  initialization(Deferred)
        ;   call(Deferred)
        )
    ;   true
    ).

ready_extension_spaces(Name, Options, Spaces) :-
    forall(member(Space, Spaces),
           ready_extension_space(Name, Options, Space)).

ready_extension_space(Name, Options, Space) :-
    (   seam:foreign_space(Space)
    ->  true
    ;   throw(error(metta_extension_space_unregistered(Name, Space),
                    context(metta_extension/2,
                            'the extension names a space it never \c
                             registered: add a seam:foreign_space/1 \c
                             clause for it')))
    ),
    (   seam:foreign_capability(Space, _)
    ->  true
    ;   throw(error(metta_extension_space_undeclared(Name, Space),
                    context(metta_extension/2,
                            'declaring nothing provides nothing: give the \c
                             space its seam:foreign_capability/2 rows')))
    ),
    %Every word the space declares against the row that owns the set, which
    %is the door a provider contributing seam:foreign_capability/2 clauses in
    %Prolog arrives through; the Python and Node registration doors check
    %their own sets where they build them.
    forall(seam:foreign_capability(Space, Declared),
           metta_require_foreign_capability(Space, Declared)),
    forall(( extension_capability_hook(Capability, Hook),
             seam:foreign_capability(Space, Capability) ),
           ready_capability_hook(Name, Space, Capability, Hook)),
    (   memberchk(check(true), Options)
    ->  ensure_conformance_kit,
        lib_conformance:metta_check_space_provider(Space, _)
    ;   true
    ).

% The optional kit owns its entry point. Declaring that module's predicate
% keeps list_undefined clean before the kit loads, without creating an empty
% engine predicate that shadows the library's export. The clause-count guard
% in ensure_conformance_kit/0 still distinguishes a declaration from a loaded kit.
% [tested: lib_conformance; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
:- dynamic lib_conformance:metta_check_space_provider/2.

extension_capability_hook(match, seam:foreign_match/3).
extension_capability_hook(enumerate, seam:foreign_atoms/2).
extension_capability_hook(add, seam:foreign_add/2).
extension_capability_hook(remove, seam:foreign_remove/3).
extension_capability_hook(clear, seam:foreign_clear/1).

%Asked PER SPACE for the same reason the conformance kit asks it that way:
%the hook predicate having clauses is a receipt, and one clause whose head
%or ownership guard admits THIS space is the payload. A whole-predicate
%count answered yes for every extension the moment any provider implemented
%the hook, so a readying that declared a capability with nothing behind it
%stopped being refused. The seam's ownership-guard protocol
%(engine/ext_points.pl) makes the question decidable without performing the
%operation.
ready_capability_hook(Name, Space, Capability, Module:Pred/Arity) :-
    (   ready_hook_admits(Module:Pred/Arity, Space)
    ->  true
    ;   throw(error(metta_extension_no_hook(Name, Space, Capability,
                                            Module:Pred/Arity),
                    context(metta_extension/2,
                            'the declared capability has no hook clauses \c
                             behind it')))
    ).

%A clause that BINDS the space in its head has said which space it serves,
%so head unification decides. A clause that leaves it a variable decides in
%its body, whose leading goal the protocol fixes as the pure ownership test.
%Where the system forbids clause/2 on static code the count is the only
%answer available, and it is used only there.
ready_hook_admits(Module:Pred/Arity, Space) :-
    functor(Probe, Pred, Arity),
    (   ready_clause_access_denied(Module:Probe)
    ->  catch(predicate_property(Module:Probe, number_of_clauses(N)), _, fail),
        N > 0
    ;   ready_hook_clause_admits(Module:Pred/Arity, Space)
    ),
    !.

ready_clause_access_denied(Module:Probe) :-
    catch(( clause(Module:Probe, _) -> fail ; fail ),
          error(permission_error(_, _, _), _),
          true).

ready_hook_clause_admits(Module:Pred/Arity, Space) :-
    functor(Probe, Pred, Arity),
    clause(Module:Probe, Body),
    arg(1, Probe, Owner),
    (   var(Owner)
    ->  Owner = Space,
        ready_guard_admits(Body)
    ;   Owner == Space
    ),
    !.

ready_guard_admits(true) :- !.
ready_guard_admits((Guard, _)) :- !, catch(Guard, _, fail).
ready_guard_admits(Guard) :- catch(Guard, _, fail).

:- multifile prolog:error_message//1.
prolog:error_message(metta_extension_space_unregistered(Name, Space)) -->
    [ 'extension ~w names ~w in spaces(...) and never registered it: \c
       add a seam:foreign_space/1 clause for the space'-[Name, Space] ].
prolog:error_message(metta_extension_space_undeclared(Name, Space)) -->
    [ 'extension ~w readies ~w with no capability rows, and declaring \c
       nothing provides nothing: give the space its \c
       seam:foreign_capability/2 rows'-[Name, Space] ].
prolog:error_message(metta_extension_no_hook(Name, Space, Capability, PI)) -->
    [ 'extension ~w declares ~w for ~w and ~w has no clauses: implement \c
       the hook or drop the capability'-[Name, Capability, Space, PI] ].

ensure_conformance_kit :-
    %Clauses, not existence: the dynamic declaration above makes the
    %predicate EXIST with zero clauses so the static engine load is
    %clean, and an existence guard here would then never consult the
    %kit - the checker present as a receipt with no payload.
    %The path is spelled out: a bare library name resolves to the library's
    %pkg.metta since 33219ffa0, and consulting that manifest as Prolog raised
    %four syntax errors and left the checker with no clauses [measured
    %2026-09-24: clauses(0) after the call on a booted engine]. The kit is a
    %governed half, so it loads through the one door and reads its artifact
    %[tested: compiled_sources:the_conformance_kit_loads_through_the_door;
    %commit=0a81c782fd6ba00984c36e58e228f73bca810dee].
    (   predicate_property(lib_conformance:metta_check_space_provider(_, _),
                           number_of_clauses(N)),
        N > 0
    ->  true
    ;   library('lib_conformance/lib_conformance.pl', Kit),
        metta_load_source(user:Kit, [expand(true)])
    ).

check_extension_requirements(Name, Options) :-
    (   memberchk(requires(Major-Minor), Options)
    ->  refuse_incompatible_extension(Name, Major, Minor)
    ;   true
    ).

refuse_incompatible_extension(Name, Major, Minor) :-
    metta_extension_api_version(OurMajor, OurMinor),
    (   Major =:= OurMajor, Minor =< OurMinor
    ->  true
    ;   throw(error(metta_extension_api_mismatch(Name, Major-Minor,
                                                 OurMajor-OurMinor),
                    context(metta_extension/2,
                            'this engine does not offer the seam the \c
                             extension was written against')))
    ).

%What a Prolog source needs from the PLATFORM, declared in the file that needs
%it. lib/lib_thread/lib_thread.pl can do nothing at all without threads, and until now it
%said so by letting its own use_module fail and leaving SWI to print the
%wreckage: the MeTTa import that pulled it in raised a wrapped transcript of
%two source_sink errors rather than a refusal anyone could act on.
%
%The declaration is read the way an export is, out of the source and BEFORE
%the source runs (refuse_unloadable_source/2 below), which is the whole reason
%that scan exists: a directive that throws is reported and the load carries
%on. So a library that cannot work here never loads, and the import refuses
%naming the capability, the platform library behind it and what its absence
%costs. This is npm's `engines` field and Python's `Requires-Python`, read out
%of the metadata rather than discovered by running the package.
%
%The directive body is the same check again, for a source SWI consults
%directly, outside the engine's import door, where no scan runs.
metta_requires(Capability) :-
    must_be(atom, Capability),
    (   metta_platform_capability(Capability, _, _)
    ->  true
    ;   throw(error(existence_error(metta_platform_capability, Capability),
                    context(metta_requires/1,
                            'the engine declares no capability of that name')))
    ),
    declaring_file(File),
    metta_require_platform(File, Capability).

metta_export(Source) :-
    declaring_file(File),
    parse_metta_source(Source, ParsedForms),
    forall(member(Parsed, ParsedForms), record_metta_export(File, Parsed)).

%The file a directive is running in. prolog_load_context/2 answers it during a
%consult; outside one, which is how a test or an inline snippet reaches here,
%the exports are keyed on a name of their own so they still register.
declaring_file(File) :-
    ( prolog_load_context(source, Source) -> File = Source ; File = 'metta_inline' ).

record_metta_export(File, Parsed) :-
    parsed_form_parts(Parsed, _, Text, Term),
    (   Term = [':', Name, Type], atom(Name), is_list(Type),
        metta_runtime_type(Type, [->|_])
    ->  assertz(pending_metta_export(File, Name, Type))
    ;   Term = [export, Name, Arity], atom(Name), integer(Arity)
    ->  assertz(pending_metta_export(File, Name, arity(Arity)))
    %The two word lists are the catalog's volatility and determinism
    %vocabularies, consulted as data: a program that widens either row in
    %'&metta' widens what this parser accepts, one authority.
    ;   Term = [volatility, Name, Level], atom(Name),
        metta_vocabulary_value(volatility, Level)
    ->  ( metta_reference_prolog_context(Home, _)
        -> metta_reference_export_property(Home, volatility, Name, Level)
        ; declare_function_volatility(Name, Level) )
    ;   Term = [determinism, Name, Mode], atom(Name),
        metta_vocabulary_value(determinism, Mode)
    ->  ( metta_reference_prolog_context(Home, _)
        -> metta_reference_export_property(Home, determinism, Name, Mode)
        ; declare_function_determinism(Name, Mode) )
    ;   throw(error(metta_export_form(Text),
                    context(metta_export/1,
                            'an export is (: name (-> ...)), (export name arity), \c
                             (volatility name <a volatility vocabulary value>) or \c
                             (determinism name <a determinism vocabulary value>); \c
                             both vocabularies are (vocabulary ...) rows in &metta')))
    ).

metta_reference_export_property(Home, Key, Name, Value) :-
    Row = [Key, Name, Value],
    ( get_native_atom(Home, Row) -> true ; metta_add_atom(Home, Row, _) ).

%How much a caller may assume about a function's answers, and therefore what
%an optimiser or a cache is allowed to do with it. PostgreSQL's ladder,
%because purity is not a boolean and its three rungs are the ones that turn
%out to matter: VOLATILE "makes no assumptions", STABLE gives the same answer
%within one statement so repeated calls may fold to one, and IMMUTABLE gives
%the same answer forever so a call on constant arguments may be folded at
%plan time [source: PostgreSQL documentation, Function Volatility Categories].
%
%WHO IT ANSWERS. A declaration here reaches a cache that nobody asked for:
%lib_memo's automatic mode chooses a cache on its own initiative and reads this
%to decide, and `volatile` is how a library keeps its function out of that
%[source: lib/lib_memo/lib_memo.pl, memo_automatic_unsafe_reason/3]. It does
%not reach a WRITTEN (memoize f), which is the caller saying what to do with
%their own program; that declaration is carried out as written and a cache in
%the wrong place is a bug in the program that put it there (user ruling,
%2026-09-06) [tested: a_volatile_function_still_memoizes_on_the_declaration].
%
%SILENCE STAYS PERMISSION. PostgreSQL's default is the pessimistic rung and
%this one's is not, deliberately: an undeclared function that a library never
%said anything about is one the automatic mode judges by its body instead.
:- dynamic metta_function_volatility/2.

declare_function_volatility(Name, Level) :-
    retractall(metta_function_volatility(Name, _)),
    assertz(metta_function_volatility(Name, Level)).

%True when a cache MAY BE CHOSEN for this function without being asked for.
metta_function_cacheable(Name) :- \+ metta_function_volatility(Name, volatile).

% A declaration belongs to a function's defining namespace. PostgreSQL's
% function identity likewise includes its schema, not merely its spelling:
% https://www.postgresql.org/docs/18/sql-alterfunction.html
metta_function_cacheable(Module, Name) :-
    ( metta_module_space(Module, Space)
    -> \+ metta_head_property(Space, Name, [volatility, volatile])
    ; metta_function_cacheable(Name) ).

%How many answers a caller may expect. Only det is ENFORCED, by handing the
%predicate to SWI's own det/1, and it is worth having because a leaked choice
%point is invisible to the counter and expensive in reality: no-cut, cut and
%SSU dispatch all reported exactly 1,000,003 inferences while wall clock was
%0.1887, 0.0928 and 0.1128 [measured, ai-todo-fast-libraries.md B5]. Declaring
%it moves the failure to the library's own door instead of taxing every caller.
%
%Read det as EXACTLY one answer, not at most one: SWI raises "Deterministic
%procedure f/2 failed" as readily as it raises on a choice point, so a
%function whose empty answer set is a legitimate result is semidet and not det
%[measured 2026-08-16]. semidet and nondet are recorded rather than checked,
%because SWI has a directive for det alone; they are still read, by
%profile_extension, where they say whether a redo was intended.
:- dynamic metta_function_determinism/2.

declare_function_determinism(Name, Mode) :-
    retractall(metta_function_determinism(Name, _)),
    assertz(metta_function_determinism(Name, Mode)).

apply_declared_determinism(Name, Type) :-
    (   metta_function_determinism(Name, det)
    ->  declared_predicate_arity(Type, Arity),
        functor(Head, Name, Arity),
        predicate_property(Head, implementation_module(Module)),
        det(Module:Name/Arity)
    ;   true
    ).

%The pending list is emptied BEFORE anything is checked, so a declaration
%that raises leaves no residue for the next load to pick up: without that, a
%file whose declaration named an arity it did not define left its exports
%pending and the next unrelated consult failed on them.
register_pending_exports :-
    findall(File-Name-Type, pending_metta_export(File, Name, Type), Pending),
    retractall(pending_metta_export(_, _, _)),
    ( Pending == [] -> true ; register_declared_exports(Pending) ).

%Every name is checked before any is registered, which is import_prolog_
%functions/2's rule reaching this route too: a declaration with one bad entry
%registers nothing.
register_declared_exports(Pending) :-
    metta_reference_prolog_context(_, _), !,
    check_and_register_declared_exports(Pending).
register_declared_exports(Pending) :-
    % Global host clauses and their arrows have one lifetime. The reference
    % branch above instead records its declarations in the scoped library home.
    with_owning_source_load(none,
        catch(check_and_register_declared_exports(Pending), Error,
              ( undo_declared_exports(Pending), throw(Error) ))).

check_and_register_declared_exports(Pending) :-
    metta_reference_prolog_context(Home, Module), !,
    forall(member(_-Name-Type, Pending),
           ( declared_predicate_arity(Type, Arity),
             metta_reference_prolog_arities(Module, Name, Arity, _) )),
    forall(member(File-Name-Type, Pending),
           ( declared_predicate_arity(Type, Arity),
             metta_reference_register_prolog(Home, Module, Name, Arity),
             ( Type = arity(_) -> true
             ; metta_add_atom(Home, [':', Name, Type], _) ),
             ( metta_head_property(Home, Name, [determinism, det])
             -> functor(Head, Name, Arity),
                predicate_property(Module:Head, implementation_module(Owner)),
                det(Owner:Name/Arity)
             ; true ),
             record_extension_membership(File, Name) )).
check_and_register_declared_exports(Pending) :-
    forall(member(_-Name-_, Pending), refuse_reserved_registration(Name)),
    forall(member(_-Name-_, Pending), refuse_other_tiers_name(Name, prolog)),
    forall(member(File-Name-_, Pending),
           ( canonical_prolog_source(File, Source),
             refuse_other_sources_name(Name, Source) )),
    forall(member(_-Name-Type, Pending), refuse_undeclared_arity(Name, Type, _)),
    forall(member(File-Name-Type, Pending),
           ( refuse_undeclared_arity(Name, Type, Arity),
             import_prolog_function_at(Name, Arity),
             declare_export_type(Name, Type),
             apply_declared_determinism(Name, Type),
             record_extension_membership(File, Name) )).

%All or nothing, and "nothing" has to reach past the registrations to the
%SOURCE. Every refusal in here is post-load and cannot be otherwise, so every
%one of them needs the rollback: a file refused for a reserved name has
%already replaced the builtin's static predicate, and a file refused for a
%wrong arity has already brought in whatever else it defines.
%
%THE SHAPE: By the time anything here can fail the file's clauses are already in
%the database, and if one of them redefined a static predicate another library
%loaded, that library's clauses are gone: SWI prints "Redefined static
%procedure" and continues, so the damage lands before any check can speak.
%Leaving the file loaded after refusing it left the OTHER author's function
%silently answering this one's implementation.
%
%unload_file/1 is SWI's own way of taking a load back out, "Remove all clauses
%loaded from File" [source: SWI-Prolog 10.1 Reference Manual, unload_file/1],
%and it is what unregister_metta_extension/1 already uses for the same job.
%What it does NOT do is restore the incumbent's clauses, which nothing can:
%those were destroyed at compile time. What it buys is that the name is empty
%and loud rather than full and wrong, and the recovery is the documented one,
%re-registering the library that owned it
%[tested: a_computed_declaration_is_refused_and_its_source_unloaded].
%Release only what this source currently owns. A name it never reached has no
%origin to retract and a name another source owns is not this one's to release,
%so asking the registry who owns it now is both the test and the rollback list.
undo_declared_exports(Pending) :-
    forall(member(File-Name-_, Pending), undo_declared_export(File, Name)),
    findall(File, member(File-_-_, Pending), Files),
    sort(Files, Sources),
    forall(member(Source, Sources), unload_declared_source(Source)).

undo_declared_export(File, Name) :-
    canonical_prolog_source(File, Source),
    (   metta_function_origin(Name, prolog, Source)
    ->  forget_registered_function(Name)
    ;   true
    ).

%metta_inline is the name a declaration outside any load is keyed on, so there
%is no file to take back out.
unload_declared_source('metta_inline') :- !.
unload_declared_source(Source) :- catch(unload_file(Source), _, true).

%The MeTTa arity is the type chain's length less one, and the predicate's is
%one more than that: (-> Number Number Number) is two inputs and an output,
%so 'vec-dot'/3.
declared_predicate_arity(Raw, Arity) :-
    metta_runtime_type(Raw, [->|Types]), !, length(Types, Arity).
declared_predicate_arity(arity(MettaArity), Arity) :- Arity is MettaArity + 1.

%Answers the arity it checked, so the caller can register THAT rather than
%rediscovering every arity the predicate happens to have.
refuse_undeclared_arity(Name, Type, Arity) :-
    declared_predicate_arity(Type, Arity),
    (   current_predicate(Name/Arity)
    ->  true
    ;   throw(error(existence_error(procedure, Name/Arity),
                    context(metta_export/1,
                            'the declaration names an arity this file does not define')))
    ).

declare_export_type(_, arity(_)) :- !.
declare_export_type(Name, Type) :-
    Declaration = [':', Name, Type],
    ( get_native_atom('&self', Declaration) -> true
    ; 'add-atom'('&self', Declaration, _) ).

%Two records, per EXTENSION and per FILE, because the two answer different
%questions and only one of them was being asked.
%
%An extension is optional here by design, which is why this clause ends in
%`; true`. The Python side then read what a registration produced by walking
%extension MEMBERSHIP, so a file carrying `metta_export` and no
%`metta_extension`, which is the natural shape for a single-file library,
%registered everything correctly and then reported failure: `is_function` true
%and the call answering 10, beside `ValueError: register_prolog needs the
%names to register` [reproduced 2026-08-16]. The state was right and the
%report was wrong, which is I15's wedged registry and I25's partial state
%inverted.
%
%The file record makes the lookup exact and leaves extensions optional, which
%is what the Prolog side already intended
%[tested: a_declared_export_without_an_extension_reports_its_names].
:- dynamic metta_file_export/2.

record_extension_membership(File, Name) :-
    (   metta_file_export(File, Name) -> true
    ;   assertz(metta_file_export(File, Name)) ),
    (   metta_extension_info(Extension, File, _)
    ->  ( metta_extension_member(Extension, Name) -> true
        ; assertz(metta_extension_member(Extension, Name)) )
    ;   true
    ).

%Everything one extension installed, gone. PostgreSQL's rule, and its reason:
%"PostgreSQL will not let you drop an individual object contained in an
%extension, except by dropping the whole extension", which is what stops a
%registry keeping a claim on a name it can no longer release. unload_file/1 is
%SWI's own mechanism for taking a consulted file's clauses back out, so the
%predicates go with the registrations rather than being left callable through
%a name nothing records [tested: an_extension_unloads_whole].
unregister_metta_extension(Extension) :-
    must_be(atom, Extension),
    loaded_extension_file(Extension, File, unregister_metta_extension/1),
    findall(Name, metta_extension_member(Extension, Name), Names),
    forall(member(Name, Names), forget_registered_function(Name)),
    retractall(metta_extension_member(Extension, _)),
    %The per-file record goes with them, or a re-registration of the same file
    %would report names that are no longer there.
    retractall(metta_file_export(File, _)),
    retractall(metta_extension_info(Extension, File, _)),
    ( File == 'metta_inline' -> true ; catch(unload_file(File), _, true) ).

%The names one extension installed, asked for before a release so its caller
%can say what went. An extension no load declared is refused the way the
%release refuses it: answering [] would report one that exists and installed
%nothing, which is what a provider exporting no function answers
%[tested: prolog_registration_service].
metta_extension_members(Extension, Names) :-
    must_be(atom, Extension),
    loaded_extension_file(Extension, _, metta_extension_members/2),
    findall(Name, metta_extension_member(Extension, Name), Names).

%Its own predicate so the file is a head argument: read inline, the binding
%happens in one branch of an if-then-else whose other branch throws, and SWI's
%var_branches check cannot see that the other branch never returns.
loaded_extension_file(Extension, File, Caller) :-
    (   metta_extension_info(Extension, Recorded, _)
    ->  File = Recorded
    ;   throw(error(existence_error(metta_extension, Extension),
                    context(Caller, 'no extension of that name is loaded')))
    ).

forget_registered_function(Name) :-
    remove_sexp('&self', [':', Name, _]),
    metta_host_forget_function(Name).

%Ask whether a whole list of names may be registered from Source, BEFORE
%Source is loaded. Order is the whole point: consulting a file that defines a
%builtin's name has already replaced the engine's static predicate by the time
%any per-name refusal could fire, so refusing afterwards left !(+ 1 2)
%answering the library's answer while reporting the registration as refused
%[tested: a_reserved_name_is_refused_before_the_source_loads].
%
%The name another SOURCE owns is refused here for exactly that reason and it
%was not: claim_function_name/3 refused it after the consult, which told the
%wrong author. B heard "already registered from A" and A, which did nothing,
%answered B's implementation from then on
%[tested: a_name_another_source_owns_is_refused_before_the_load].
check_prolog_function_names(Names, Source, true) :-
    metta_reference_prolog_context(_, _), !,
    prolog_function_name_list(Names, check_prolog_function_names/3),
    canonical_prolog_source(Source, _).
check_prolog_function_names(Names, Source, true) :-
    prolog_function_name_list(Names, check_prolog_function_names/3),
    canonical_prolog_source(Source, Canonical),
    forall(member(N, Names), refuse_reserved_registration(N)),
    forall(member(N, Names), refuse_other_tiers_name(N, prolog)),
    forall(member(N, Names), refuse_other_sources_name(N, Canonical)).

%Register every name, or none. Validating inside the registration loop left a
%typo in the third name with the first two registered and callable, and the
%list of what had taken died inside the exception, so the caller could not
%learn what to undo. This is the shape metta_py_register_op_set already uses
%one file over: probe every name first, touch state only after
%[tested: a_typo_in_the_list_registers_nothing].
import_prolog_functions(Names, true) :-
    metta_reference_prolog_context(Home, Module), !,
    prolog_function_name_list(Names, import_prolog_functions/2),
    forall(member(N, Names), metta_reference_prolog_arities(Module, N, scan, _)),
    forall(member(N, Names), metta_reference_register_prolog(Home, Module, N, scan)).
import_prolog_functions(Names, true) :-
    prolog_function_name_list(Names, import_prolog_functions/2),
    forall(member(N, Names), refuse_reserved_registration(N)),
    forall(member(N, Names), refuse_absent_prolog_function(N)),
    forall(member(N, Names), import_prolog_function(N, _)).

prolog_function_name_list(Names, Context) :-
    (   is_list(Names)
    ->  forall(member(N, Names), must_be(atom, N))
    ;   throw(error(type_error(list, Names),
                    context(Context, 'the names to register')))
    ).

%%%% One registration sequence for every host %%%%
%
%The whole of what a host's "register this Prolog as MeTTa functions" runs, so
%PyMeTTa's register_prolog and tsmetta's registerProlog each cross here once
%and cannot drift apart. Origin is file(Spec) or text(Text). Names is [], a
%list of names, or a list of [From, To] renames, each importing a module
%file's export From under the name To. Registered is what registered: the
%names given, the renames' new names, or with no names the exports the source
%recorded for itself, [] for one that joins an extension and exports nothing.
%
%The order is the point, and each step is one the Python seat used to run
%across a crossing of its own [source: extensions/python/metta/_declare/prolog.py,
%register_prolog, at the Python seat's a0f697126]. The names are checked
%before the source loads, because a consulted builtin's name has replaced the
%builtin by the time a later refusal fires. A source registered without names
%says what it is before it loads, because discovering its names would register
%whatever else it defines. And the names register all or none
%[tested: prolog_registration_service].
metta_register_prolog(Origin, Names, Registered) :-
    prolog_registration_origin(Origin, Load, Source),
    prolog_registration_shape(Names, Load, Shape),
    prolog_registration(Shape, Load, Source, Registered).

%A file is named by the path it resolves to, the identity its load records
%clauses and exports under, and a missing one refuses before its declarations
%are read, since a scan of nothing declares nothing. Text loads under a module
%named for its content, so the same text registered again reloads that module
%rather than adding a second copy, and two texts never share one: the address
%a host once named it by went to the next string of the same size, and a
%library generating Prolog lost every registration but its last
%[source: extensions/python/metta/_spaces/handle.py, _inline_module_name, at
%the Python seat's a0f697126].
prolog_registration_origin(file(Spec), file(File), File) :-
    !,
    (   absolute_file_name(Spec, File,
                           [file_type(prolog), access(read), file_errors(fail)])
    ->  true
    ;   throw(error(existence_error(source_sink, Spec),
                    context(metta_register_prolog/3,
                            'no Prolog source is there, resolving a path \c
                             against the working directory')))
    ).
prolog_registration_origin(text(Text0), text(Module, Text), Module) :-
    !,
    text_to_string(Text0, Text),
    filereader:metta_text_digest(Text, Digest),
    atom_concat(metta_inline_, Digest, Module).
prolog_registration_origin(Origin, _, _) :-
    throw(error(domain_error(prolog_registration_origin, Origin),
                context(metta_register_prolog/3,
                        'an origin is file(Spec) or text(Text)'))).

%What the names ask for, read off their shape: none, names, or renames. A
%rename imports a module's export under another name and SWI's import list
%names a module by its file, so renames need a file origin, and the NEW names
%are the ones checked and registered.
prolog_registration_shape([], _, declared) :-
    !.
prolog_registration_shape(Names, Load, renames(Names, Tos)) :-
    is_list(Names),
    forall(member(Rename, Names), is_list(Rename)),
    !,
    (   Load = file(_)
    ->  maplist(renamed_to, Names, Tos)
    ;   prolog_registration_refused(
            'a rename imports a Prolog module\'s export under another name, \c
             and SWI\'s import list names a module by its file, so a rename \c
             cannot come from text',
            'a file origin, the path of the module file whose exports the \c
             renames name')
    ).
prolog_registration_shape(Names, _, named(Names)) :-
    prolog_function_name_list(Names, metta_register_prolog/3).

renamed_to(Rename, To) :-
    rename_pair(Rename, _, To0),
    metta_name_atom(To0, To).

prolog_registration(declared, Load, Source, Registered) :-
    prolog_origin_declarations(Load, Declarations),
    prolog_declared(Declarations, Declares),
    prolog_origin_load(Load),
    (   Declares == extension
    ->  Registered = []
    ;   findall(Name, metta_file_export(Source, Name), Exported),
        sort(Exported, Registered),
        (   Registered == []
        ->  prolog_registration_refused(
                'the source declares metta exports and loading it recorded \c
                 none, and discovering its names would silently register \c
                 whatever else it defines',
                'the names to register, or a :- metta_export("...") \c
                 declaration naming a function the source defines')
        ;   true
        )
    ).
prolog_registration(named(Names), Load, Source, Names) :-
    check_prolog_function_names(Names, Source, _),
    prolog_origin_load(Load),
    import_prolog_functions(Names, _).
prolog_registration(renames(Renames, Tos), file(File), File, Tos) :-
    check_prolog_function_names(Tos, File, _),
    use_module_global(File, Renames),
    import_prolog_functions(Tos, _).

%What a source registered without names says it is, decided in clause heads so
%the refusal's branch binds nothing SWI's var_branches check would miss: an
%export makes it a library of functions, an extension alone a provider.
prolog_declared(Declarations, exports) :-
    memberchk(export(_), Declarations),
    !.
prolog_declared(Declarations, extension) :-
    memberchk(extension(_), Declarations),
    !.
prolog_declared(_, _) :-
    prolog_registration_refused(
        'the source declares neither a function nor an extension, and \c
         discovering its names would silently register whatever else it \c
         defines',
        'the names to register, a :- metta_export("...") declaration for a \c
         source that defines functions, or a :- metta_extension(name, []) \c
         declaration for one that only contributes clauses to an extension \c
         point, such as a space provider').

prolog_origin_declarations(file(File), Declarations) :-
    metta_source_declarations(File, Declarations).
prolog_origin_declarations(text(_, Text), Declarations) :-
    metta_string_declarations(Text, Declarations).

prolog_origin_load(file(File)) :-
    consult_global(File).
prolog_origin_load(text(Module, Text)) :-
    consult_string_global(Module, Text).

%A registration its contract refuses crosses as a kind of its own,
%`registration`: Sentence says what was missing, and Requires what the caller
%has to supply, which the kind's catalog row in engine/spaces/catalog.pl cites
%the contract for and names in its remedy [tested 2026-09-25T05:48:07+10:00:
%prolog_registration_service:every_registration_refusal_names_what_to_supply].
prolog_registration_refused(Sentence, Requires) :-
    throw(error(metta_registration_refused(Sentence, Requires),
                context(metta_register_prolog/3, _))).

%The refusal renders as its sentence, whole: SWI's own layout would put the
%predicate indicator in front of it, which names the engine's door rather than
%the caller's call.
:- multifile prolog:message//1.
prolog:message(error(metta_registration_refused(Sentence, _), _)) -->
    [ '~w'-[Sentence] ].

%The head names one registration FORM claims, read from the form itself and
%never run. A library that publishes its surface through
%`!(import_prolog_function memoize)` says which heads it has in exactly this
%way, and a reader that cannot see those forms reports the library as empty:
%the generated library reference counted lib_memo at zero names while nine
%were registered and callable [measured 2026-09-07].
%
%One clause per spelling, HERE, beside the spellings themselves, so a sixth
%registration form is covered where it is added rather than in each host that
%reads them. The four importer spellings come from the translator's own
%published roster, which exists already because compilation has to keep their
%name list literal [source: engine/translator/special_forms.pl,
%prolog_function_importer/1].
%
%A form whose names are not literal atoms claims NOTHING here rather than
%guessing: `(import_prolog_functions (car $rest))` computes its list, and a
%reader that guessed would publish a variable as a head name.
metta_registration_names([import_prolog_function, Name], Named) :-
    !,
    ( atom(Name) -> Named = [Name] ; Named = [] ).
metta_registration_names([import_prolog_functions, Names], Named) :-
    !,
    literal_registration_names(Names, Named).
metta_registration_names([Importer, _File, Names], Named) :-
    atom(Importer),
    translator:prolog_function_importer(Importer),
    !,
    literal_registration_names(Names, Named).
%A BACKING ROW is a registration form too, and the fifth this relation covers:
%`(= (package backing) (<token> <file> (heads)))` publishes exactly the names
%the importer spelling published, so a reader that does not know it reports
%every migrated library as empty of its Prolog-backed heads. The reference page
%is what noticed: lib_reflect read 21 heads under the old spelling and 12 after
%the migration, the nine missing being its own backing row's list
%[measured 2026-09-20; tested: packages:a_backing_row_publishes_the_heads_it_names].
%
%The token is left OPEN rather than matched against `prolog`, because which
%tokens exist is the claimants' business and not this engine's: a row naming a
%token nobody claims still SAYS which heads it would publish, and a reader
%asking what a library declares wants that answer
%[source: docs/journal/2026-09-09-packages-are-equations.md, laws 4 and 5].
metta_registration_names(['=', [package, backing], Row], Named) :-
    nonvar(Row),
    %Law 6's shape exactly, `(<token> <artifact> <heads>)`, rather than taking
    %the last element of whatever length the row has: a row of another shape is
    %one this reader does not understand, and claiming its last element as the
    %head list would be a guess where the four spellings above make none.
    Row = [Token, _Artifact, Names],
    atom(Token),
    !,
    literal_registration_names(Names, Named).
metta_registration_names(_, []).

literal_registration_names(Names, Named) :-
    (   is_list(Names),
        forall(member(N, Names), atom(N))
    ->  Named = Names
    ;   Named = []
    ).

%A name the engine re-exports from an OPTIONAL platform library is absent for
%a reason, and "no Prolog predicate of that name is loaded" is true without
%being useful: it reads as a typo when the answer is that this build has no
%pcre. The census recorded which names its own load could not import, so this
%asks it before falling back to the general refusal, and every capability the
%engine re-exports names through gets the same answer without a second list
%[tested: platform_capabilities:a_re_export_lost_with_its_capability_refuses_by_name].
refuse_absent_prolog_function(N) :-
    refuse_absent_prolog_function(N, scan).

refuse_absent_prolog_function(N, Arity) :-
    (   integer(Arity)
    ->  (   current_predicate(N/Arity)
        ->  true
        ;   refuse_absent_prolog_function(N, scan)
        )
    ;   refuse_absent_prolog_function_scan(N)
    ).

refuse_absent_prolog_function_scan(N) :-
    (   current_predicate(N/_)
    ->  true
    ;   metta_platform_absent_name(N, Capability)
    ->  metta_require_platform(N, Capability)
    ;   throw(error(existence_error(procedure, N),
                    context(import_prolog_functions/2,
                            'no Prolog predicate of that name is loaded')))
    ).

%A Prolog library loaded from MeTTa belongs to the process, not to a space. Its
%predicates are builtins once loaded, register_fun/1 reads their arity out of
%user, and every space has to be able to call them. SWI loads a file into the
%module the load runs in, and under per-space equations a runnable form runs in
%its space's module, so a library imported inside a named space would define
%itself where register_fun/1 cannot see it: the arities never register and every
%call to it compiles to a partial application instead. In &self the load module
%already is user, so this states that behaviour rather than adding a rule.
consult_global(File) :- metta_reference_prolog_context(_, Module), !,
                        metta_reference_check_prolog_source(File),
                        loading_loudly(metta_load_source(Module:File, [expand(true)])),
                        metta_reference_register_exports(File).
consult_global(File) :- refuse_unloadable_source_file(File),
                        loading_loudly(metta_load_source(user:File, [expand(true)])),
                        register_pending_exports.
use_module_global(File) :- metta_reference_prolog_context(_, Module), !,
                           metta_reference_check_prolog_source(File),
                           loading_loudly(metta_load_source(Module:File,
                                           [if(not_loaded), must_be_module(true)])),
                           metta_reference_register_exports(File).
use_module_global(File) :- refuse_unloadable_source_file(File),
                           loading_loudly(metta_load_source(user:File,
                                                            [if(not_loaded), must_be_module(true)])),
                           register_pending_exports.
ensure_loaded_global(File) :- metta_reference_prolog_context(_, Module), !,
                             metta_reference_check_prolog_source(File),
                             loading_loudly(metta_load_source(Module:File, [if(not_loaded)])),
                             metta_reference_register_exports(File).
ensure_loaded_global(File) :- refuse_unloadable_source_file(File),
                              loading_loudly(metta_load_source(user:File, [if(not_loaded)])),
                              register_pending_exports.

%%%% Where a runtime-loaded Prolog source pays its compile %%%%
%
%A library's Prolog half is consulted on its first import in EVERY process,
%and the consult pays SWI's compile-time expansion of the whole file each
%time: lib/lib_thread/lib_thread.pl costs 278,309 inferences to consult,
%where the same unit read from the Quick Load Format artifact beside it
%costs 5,925, with the process that writes the artifact paying 281,792 once
%[measured 2026-09-09: one boot through engine/qlf_boot.pl per arm,
%statistics(inferences) around the load; commit=f26de01fbf3e0e3c64bb691c66a59fa959fee7f3]. The engine's own
%units already load that way under engine/qlf_boot.pl, and this door is how
%a unit loaded later reaches the same regime; the three loaders above, the
%catalog's vocabulary seed, metta_ensure_source_observation/0, a package's
%backing row (engine/packages.pl, package_load_native/2), setup!'s lib_file
%publication and the background loader's lib_thread all load through it, and
%no engine code loads a governed source at runtime any other way. A half's own
%use_module of another half names a stem, which SWI's rule loads from that
%half's artifact whenever one exists; the claim's child writes those too.
%
%SWI decides by the spec unless the call says otherwise. boot/init.pl's
%'$qlf_file'/5 loads a spec that names its .pl extension from source when
%only the process-wide qcompile flag is on, which keeps that flag from
%writing an artifact beside every file a program names by its path, and
%applies the artifact rule (load when fresh and compatible, recompile when
%stale and the directory is writable, source otherwise) to a stem and to a
%call that carries its own qcompile option (host ledger,
%swi-qlf-extension-spec). So a claimed source is loaded by its resolved
%path with the option; the observation of 2026-09-05 that "qcompile(auto)
%reaches the files a loaded file loads and not the file the goal names" was
%the flag seen from a spec that carried its .pl.
%
%Which sources may leave an artifact is the boot's decision, asked through
%seam:compiled_source/1: engine/qlf_boot.pl claims the sources whose
%artifacts it stamps (SWI version and encoding) and purges as one set, and
%nothing else, so a program's own Prolog file loads from source and gains no
%.qlf that could outlive the SWI or the locale that wrote it. A process that
%never loaded the boot claims nothing and loads everything from source. The
%claim also makes the artifact fresh: a stale or absent one is written by a
%child swipl the boot starts, so the process that asked reads the artifact
%and never pays the compile, the first importer included, which is what
%keeps every process's count of one import the same.
%
%The load's target module is the caller's, as load_files/2's own is, which
%is what lets consult_global/1 above keep the process tier as its target
%[tested: a_claimed_source_is_compiled_by_a_child_and_this_process_reads_the_artifact,
%an_unclaimed_source_loads_from_source_and_leaves_no_artifact,
%a_stale_artifact_is_recompiled,
%consult_global_loads_a_library_half_through_the_door; commit=f26de01fbf3e0e3c64bb691c66a59fa959fee7f3].
%A claimed source loads under qcompile(auto) by its resolved path: the
%artifact rule applies to a spec that names its .pl extension as it does to
%a stem (host ledger, swi-qlf-extension-spec).
%
%SWI's loader is handed only what the engine resolved. A PATH, written as
%text, is resolved here against the working directory, as upstream's consult
%resolves one, and loads by the file that answered or refuses by the spec it
%was given; an alias term such as library(x) keeps SWI's own resolution. The
%loader used to take any text this could not resolve, and a host's loader
%hooks answer such a spec in their own way: swipl-wasm's library(wasm) reads
%a relative one as a URL, autoloading wasm:sequence/5 from dcg/high_order
%under the engine's no-autoload boot, so an absent `./x.pl` raised an
%EngineError carrying a dict the Node wire cannot encode, where an absent
%absolute path raised the named existence error [measured 2026-09-24 by the
%TS corpus job on tsmetta 6663d06; tested:
%prolog_interface:a_missing_relative_file_is_refused_before_the_host_loader,
%prolog_interface:a_relative_file_reaches_the_host_loader_resolved].
:- meta_predicate metta_load_source(:, +).
metta_load_source(Module:Spec, Options) :-
    (   absolute_file_name(Spec, File,
                           [file_type(prolog), access(read), file_errors(fail)])
    ->  (   seam:compiled_source(File),
            file_name_extension(_, pl, File)
        ->  load_files(Module:File, [qcompile(auto)|Options])
        ;   load_files(Module:File, Options)
        )
    ;   ( atom(Spec) ; string(Spec) )
    ->  throw(error(existence_error(source_sink, Spec),
                    context(metta_load_source/2,
                            'no Prolog source is there, resolving a path \c
                             against the working directory')))
    ;   load_files(Module:Spec, Options)
    ).

%%%% Where a file a MeTTa program loads puts its predicates %%%%
%
%A host LOADER takes its target namespace from the CONTEXT MODULE of the call,
%and a MeTTa runnable's context module is its space's execution module. So a
%program that imported SWI's own loader and wrote (consult "x.pl") loaded x.pl
%into '$metta_exec:&self': the file's directives ran and the call succeeded, so
%the load looked like it had worked, while import_prolog_function/2 could not
%find the predicates the file had just defined and no other space could call
%them [measured 2026-08-30: the load context module was '$metta_exec:&self'
%here against user upstream, and a consulted noisy_marker/1 was findable in no
%module at all afterwards].
%
%A load is a PROCESS-tier event, and the scope the call happens to be made
%from does not get to decide where the definitions live. CPython installs an
%imported module into sys.modules whatever frame ran the import, Emacs Lisp's
%load and R's library() are global for the same reason, and SWI itself makes
%the target explicit rather than implicit wherever it matters, which is why
%load_files/2 takes a module option [source: SWI-Prolog 10 manual, section 4.3
%"Loading Prolog source files"]. The engine already holds that line for the
%other host-tier writer: assertaPredicate/2 puts an asserted clause in the
%host tier rather than in the space that asked for it.
%
%So the SWI spelling reaches the same funnel the MeTTa spelling does, which is
%what the export comment above already claims for "a bare consult". Only the
%ONE-FILE loaders are mapped. use_module/2's second argument is an import
%list rather than a result, so MeTTa's last-argument-is-the-output convention
%does not describe it and nothing here pretends otherwise; load_files/2 is
%already written with its target module named, as lib_tabling.metta does with
%(load_files user ((Predicate (stream $S))))
%[tested:
%prolog_interface_namespacing:a_host_loader_called_from_metta_loads_into_the_process_tier;
%commit=c530ccb8fb7d0a5b2aa53df6e9f981ada9f81be8].
host_process_tier_loader(consult, 1, consult_global).
host_process_tier_loader(use_module, 1, use_module_global).
host_process_tier_loader(ensure_loaded, 1, ensure_loaded_global).

%%%% Read the manifest before running the payload %%%%
%
%A source declares its exports INSIDE the file that implements them, which is
%the design the review argues for and the one that makes the arity and the
%type impossible to disagree. It also means the names are not known until the
%file has run, and by then a clause of the file has already replaced a static
%predicate another library loaded: SWI prints "Redefined static procedure" and
%CONTINUES, so the incumbent's clauses are gone before any refusal can speak.
%A directive cannot stop that either, because a directive that throws is
%reported and the load carries on [measured 2026-08-16: with the refusal in
%the metta_export/1 directive itself, `A AFTER refusal` still answered B's 30].
%
%So read the manifest out of the source WITHOUT running the source. This is
%PostgreSQL's control file, which the codebase already follows for the
%extension model: the file that says what an extension is gets read before the
%script that installs it. Python reads a package's entry points out of its
%metadata rather than by importing it, for the same reason.
%
%The scan is exact for a literal declaration, which is every one written by
%hand. It stops at the first term it cannot read, and does not run :- op/3, so
%a file that defines its own operators and declares exports below them is
%scanned only as far as the operator. Whatever the scan misses,
%register_declared_exports_or_undo/1 still catches after the load, with the
%rollback that is all that is left by then
%[tested: a_second_source_claiming_a_name_never_loads].
refuse_unloadable_source_file(Spec) :-
    (   absolute_file_name(Spec, File,
                           [file_type(prolog), access(read), file_errors(fail)])
    ->  setup_call_cleanup(open(File, read, In),
                           refuse_unloadable_source(In, File),
                           close(In))
    ;   true
    ).

refuse_unloadable_source_text(Name, Text) :-
    setup_call_cleanup(open_string(Text, In),
                       refuse_unloadable_source(In, Name),
                       close(In)).

%Two refusals off one read of the manifest. The PLATFORM one comes first: a
%source whose capability this build does not have cannot work at all, so
%whether its names are free is a question about a file that is never going to
%load [tested: platform_capabilities_reduced:a_library_that_declares_an_absent_capability_never_loads].
refuse_unloadable_source(In, File) :-
    canonical_prolog_source(File, Source),
    read_declarations(In, Declarations),
    forall(member(requires(Capability), Declarations),
           metta_require_platform(Source, Capability)),
    findall(Name, member(export(Name), Declarations), Names),
    forall(member(Name, Names), refuse_reserved_registration(Name)),
    forall(member(Name, Names), refuse_other_tiers_name(Name, prolog)),
    forall(member(Name, Names), refuse_other_sources_name(Name, Source)).

%Everything a source DECLARES, read without running it: export(Name) for each
%name it publishes, extension(Name) for each extension it joins, and
%requires(Capability) for each platform capability it cannot work without.
%Every consumer of the scan filters this rather than reading the file twice.
metta_source_declarations(Spec, Declarations) :-
    (   absolute_file_name(Spec, File,
                           [file_type(prolog), access(read), file_errors(fail)])
    ->  setup_call_cleanup(open(File, read, In),
                           read_declarations(In, Declarations),
                           close(In))
    ;   Declarations = []
    ).

metta_string_declarations(Text, Declarations) :-
    setup_call_cleanup(open_string(Text, In),
                       read_declarations(In, Declarations),
                       close(In)).

read_declarations(In, Declarations) :-
    (   read_one_declaration(In, Some)
    ->  read_declarations(In, Rest),
        append(Some, Rest, Declarations)
    ;   Declarations = []
    ).

%One term. quiet rather than dec10 on purpose: a syntax error here is not this
%predicate's to report, the consult that follows reports it properly and with
%the line, so the scan goes quiet and stops rather than printing a second copy.
read_one_declaration(In, Declarations) :-
    catch(read_term(In, Term, [syntax_errors(quiet), variable_names(_)]),
          _, fail),
    Term \== end_of_file,
    declaration_of(Term, Declarations).

%The extension's own version travels with its name, because the version is
%something the source DECLARES and this predicate answers everything a source
%declares. A reader asking what version a library states had to consult the
%file to learn it, which is what this scan exists to avoid.
declaration_of((:- metta_extension(Name, Options)), Declared) :-
    atom(Name), !,
    (   is_list(Options),
        memberchk(version(Version), Options)
    ->  Declared = [extension(Name), version(Version)]
    ;   Declared = [extension(Name)]
    ).
declaration_of((:- metta_requires(Capability)), [requires(Capability)]) :-
    atom(Capability), !.
declaration_of((:- metta_export(Text)), Names) :-
    ( string(Text) ; atom(Text) ),
    !,
    catch(parse_metta_source(Text, Forms), _, fail),
    findall(export(Name), claimed_export_name(Forms, Name), Names).
declaration_of(_, []).

%Every head name one MeTTa source's registration forms claim, each with the
%INDEX of the form that claims it, in the parsed-form list this engine's
%reader answers. The index rather than a line for the reason metta_py_origin/3
%answers one: the caller that wants a position already walks the source for
%it, and the walk is linear in the source where a second parse is not
%[source: extensions/python/metta/_binding/positions.py:90, positioned_forms/1; commit=cd62330ceacc8f1254eed9791c3f6203b48a1c9e].
%
%READ and never run, the promise the whole static-scan family above makes:
%a library whose Prolog half this build cannot load still says which heads it
%publishes, and asking cannot register one.
%
%The reader's own failure travels rather than being swallowed, unlike the
%export text above: that one is a fragment inside a Prolog directive whose
%consult reports it properly a moment later, while this IS the source, and a
%caller handing text the reader refuses has a defect to hear about.
metta_string_registrations(Source, Rows) :-
    parse_metta_source(Source, Forms),
    findall([Name, Index],
            ( nth0(Index, Forms, Parsed),
              parsed_form_parts(Parsed, _, _, Term),
              metta_registration_names(Term, Names),
              member(Name, Names) ),
            Rows).

%The two forms that CLAIM a name. volatility and determinism state a property
%of a name claimed elsewhere, so they are not a claim to refuse.
claimed_export_name(Forms, Name) :-
    member(Parsed, Forms),
    parsed_form_parts(Parsed, _, _, Term),
    ( Term = [':', Name, Raw], metta_runtime_type(Raw, [->|_])
    ; Term = [export, Name, Arity], integer(Arity) ),
    atom(Name).

%The same load, importing chosen exports under chosen names. SWI's own import
%list carries the renaming, so two libraries that both export norm/2 can both
%be present: the second arrives as mylib-norm and neither is rebound. Without
%it SWI refuses the second import, prints "No permission to import
%libb:'norm'/2 into user (already imported from liba)" and CONTINUES, which
%leaves the incumbent protected and the newcomer silently bound to the
%incumbent's code. That is the one collision a name refusal cannot fix, since
%neither library is wrong and neither can be asked to change.
%
%Loaded twice on purpose: with an empty import list first, so the module
%exists and can be asked what it exports, and then with the renames built from
%those arities. A caller therefore writes two names and no arity. Both loads
%are use_module/2's own options through the one door below, so a governed
%half renamed on import takes its artifact like any other.
use_module_global(File, Renames) :-
    %SWI reaches a plain file first and raises domain_error(module_header, _),
    %which says what is wrong and not what to do about it.
    catch(loading_loudly(metta_load_source(user:File,
                                           [if(not_loaded), must_be_module(true),
                                            imports([])])),
          error(domain_error(module_header, _), _),
          throw(error(metta_not_a_prolog_module(File),
                      context(use_module_global/2,
                              'renaming imports needs a module')))),
    module_exports_of(File, Module, Exports),
    maplist(renamed_import(Module, Exports), Renames, Imports),
    loading_loudly(metta_load_source(user:File,
                                     [if(not_loaded), must_be_module(true),
                                      imports(Imports)])),
    register_pending_exports.

module_exports_of(File, Module, Exports) :-
    absolute_file_name(File, Resolved,
                       [file_type(prolog), access(read), file_errors(fail)]),
    (   module_property(Module, file(Resolved))
    ->  module_property(Module, exports(Exports))
    ;   throw(error(metta_not_a_prolog_module(File),
                    context(use_module_global/2,
                            'renaming imports needs a module')))
    ).

%A name the module does not export cannot be imported under any name, and
%saying so with the export list is the difference between fixing a typo and
%guessing at one.
renamed_import(Module, Exports, Rename, Name/Arity as To) :-
    rename_pair(Rename, From0, To0),
    metta_name_atom(From0, Name),
    metta_name_atom(To0, To),
    (   memberchk(Name/Arity, Exports)
    ->  true
    ;   throw(error(metta_not_exported(Module, Name, Exports),
                    context(use_module_global/2,
                            'a rename names an export')))
    ).

%A rename is written From-To in Prolog and arrives as [From, To] from Python,
%since Janus carries a list and not a pair. Clauses rather than an
%if-then-else, so the two names are bound on every branch that reaches a use.
rename_pair(From-To, From, To) :- !.
rename_pair([From, To], From, To) :- !.
rename_pair(Rename, _, _) :-
    throw(error(type_error(metta_rename, Rename),
                context(use_module_global/2,
                        'a rename is From-To or [From, To]'))).

metta_name_atom(Name0, Name) :-
    ( atom(Name0) -> Name = Name0 ; atom_string(Name, Name0) ).

%The same load for source held in memory, which is how a library ships Prolog
%inline beside its Python. Name identifies the source location of the loaded
%clauses and is also what SWI removes clauses under when the same name is
%loaded again, so it has to be derived from the CONTENT: an address, which is
%what the caller used to pass, is reused by CPython the moment the string it
%named is freed, and the second registration then erased the first library's
%clauses [source: SWI-Prolog 10.1 Reference Manual, load_files/2, stream/1].
consult_string_global(Name, Text) :-
    refuse_unloadable_source_text(Name, Text),
    setup_call_cleanup(open_string(Text, In),
                       loading_loudly(user:load_files(Name, [stream(In)])),
                       close(In)),
    register_pending_exports.

%A predicate term headed by a space is a provider query, not a raw Prolog
%call into the module where native atoms happen to be stored. Other heads keep
%the Prolog interop constructor's original meaning.
metta_predicate_goal([Space|Pattern],
                     match(Space, Pattern, matched, matched)) :-
    metta_space_name(Space), !.
metta_predicate_goal([F|Args], Term) :- Term =.. [F|Args].

'Predicate'(Parts, _) :- var(Parts), !, refuse_unbound_input('Predicate', 1).
'Predicate'(Parts, Term) :- metta_predicate_goal(Parts, Term).
%Resolved in the CALLING space's module, which reaches both directions of this
%seam: a host Prolog predicate through the module's base chain, and a MeTTa
%function this space compiled, which lives in that module and nowhere else.
%Called unqualified it resolved in the engine's own module, so
%`(callPredicate (Predicate (myAddMeTTa 241 $x)))` over a function the program
%had just defined raised Unknown procedure
%[tested: examples/ch20-extending-the-engine/20-03-prolog-underneath/02-prologimport.metta].
%
%assertaPredicate/2 and its siblings deliberately do NOT follow: a clause a
%MeTTa program asserts is host Prolog, it belongs in the host tier where
%consult_global/1 puts a consulted file, and import_prolog_function/2 looks
%for it there.
callPredicate(G, true) :- current_metta_module(Module), call(Module:G).
assertzPredicate(G, true) :- user:assertz(G).
assertaPredicate(G, true) :- user:asserta(G).
retractPredicate(G, true) :- user:retract(G), !.
retractPredicate(_, false).

%%% Library / Import: %%%
ensure_metta_ext(Path, Path) :- file_name_extension(_, gz, Path), !.
ensure_metta_ext(Path, Path) :- file_name_extension(_, metta, Path), !.
ensure_metta_ext(Path, PathWithExt) :- file_name_extension(Path, metta, PathWithExt).

current_working_dir(Base) :- working_dir(Base), !.
current_working_dir(Base) :- absolute_file_name('.', Base, [file_type(directory)]).

import_file_string(File, SFile) :- string(File), !, SFile = File.
import_file_string(File, SFile) :- atom_string(File, SFile).


%TWO CANDIDATES FOR A RELATIVE PATH, in upstream's own order: the path AS
%WRITTEN first, resolved against the process's working directory, and only
%then the importing file's own directory. Upstream spells the pair
%`( Path = SFile ; atomic_list_concat([Base, '/', SFile], Path) )` and takes
%the first that exists [source: PeTTa@ae66fa8 src/metta.pl:283-289].
%
%This engine tried only the second, so `!(import! &self lib/lib_he)` from a
%file in examples/ looked for examples/lib/lib_he and refused, where upstream
%finds lib/lib_he beside the checkout it was launched from
%[measured 2026-08-30: examples/test_unify_eval_branches.metta and
%examples/python_import.metta both failed with
%`source_sink 'lib/lib_he' does not exist`].
resolve_existing_import_path(Base, RequestedPath, CanonPath) :-
    (   is_absolute_file_name(RequestedPath)
    ->  absolute_file_name(RequestedPath, CanonPath,
                           [access(read), file_errors(fail)])
    ;   absolute_file_name(RequestedPath, CanonPath,
                           [access(read), file_errors(fail)])
    ;   absolute_file_name(RequestedPath, CanonPath,
                           [relative_to(Base), access(read), file_errors(fail)])
    ),
    !.

throw_missing_import(File) :-
    throw(error(existence_error(source_sink, File), context('import!', File))).

resolve_metta_import_path(File, CanonPath) :-
    import_file_string(File, SFile),
    metta_module_path(SFile, Base, Relative),
    ensure_metta_ext(Relative, RequestedPath),
    (   resolve_existing_import_path(Base, RequestedPath, CanonPath)
    ->  true
    ;   resolve_package_manifest(Base, Relative, CanonPath)
    ->  true
    ;   throw_missing_import(File) ).

%A DIRECTORY imports through its `pkg.metta`, the package manifest, and that
%is the STANDARD way an external package is reached.
%
%Named by CONVENTION rather than after the thing it describes, which is what
%Cargo.toml, go.mod, package.json and flake.nix all are and for this reason: a
%git dependency previously had to carry a file named after its REPOSITORY,
%`repos/lib_json/lib_json.metta`, so renaming the repository broke every
%importer and a checkout directory that did not match the remote's name
%resolved to nothing.
%
%One rule here rather than one per requirement kind. A git checkout, a
%package-relative path and a `&catalogs` entry all reach this resolver, so all
%three inherit the manifest without any of them naming it.
%
%Tried AFTER the file candidates, so a plain `<name>.metta` beside a `<name>/`
%still wins. That ordering is the journal's one stated rule for this resolver,
%"a file on the search path wins over a package's advertisement of the same
%name" [source: docs/journal/2026-09-07-a-metta-file-is-a-python-module.md],
%and putting the manifest first broke it: with both present the manifest
%answered where the file should have.
%
%So this is purely ADDITIVE. The same journal decided a directory would also
%offer `<name>/<name>.metta`, and that candidate was never built here --
%`!(import! &self "./named")` with `named/named.metta` present answers
%`source_sink "./named" does not exist` [measured 2026-09-22] -- so before
%this, importing a directory through `import!` did not work at all, and after
%it a directory imports exactly when it carries a manifest.
resolve_package_manifest(Base, Relative, CanonPath) :-
    package_manifest_candidate(read, Base, Relative, Manifest),
    exists_file(Manifest),
    absolute_file_name(Manifest, CanonPath, [access(read), file_errors(fail)]),
    !.

%The manifest a directory is entered through, ENUMERATED rather than resolved,
%because import! and unimport! choose from the candidates differently and must
%choose from the SAME candidates: import! takes the first that exists and
%unimport! the first that was recorded, and where the two sets disagree a
%directory import cannot be undone by the name that made it.
%
%Access is a parameter because the two callers genuinely differ. import! needs
%the directory readable now. unimport! must work AFTER deletion, since the
%recorded path is an identity rather than a file it reopens, which is why it
%passes `none` and accepts a directory that is no longer there.
package_manifest_candidate(Access, Base, Relative, Manifest) :-
    (   Root = '.'
    ;   Root = Base
    ),
    catch(absolute_file_name(Relative, Directory,
                             [relative_to(Root), file_type(directory),
                              access(Access), file_errors(fail)]),
          _, fail),
    directory_file_path(Directory, 'pkg.metta', Manifest).

%`include` PASTES a module's source into the space that included it and
%answers what its LAST directive answered, where import! gives the file its
%own space and answers unit. A module with no directive answers nothing, and
%facts join the including space in order, each directive evaluating against
%the state built so far
%[assumed: the include dispatch and its `(-> Atom %Undefined%)` type line were
%adopted from an earlier reference semantics, not re-measured against upstream
%PeTTa, which has no include].
%
%`self` and `top` are BASES rather than modules, so including one is refused
%in upstream's own words, and so is a name that resolves to nothing
%[measured 2026-08-19 against the arbiter: `!(include nosuchfile)` answers
%`(Error (include nosuchfile) no module named nosuchfile is available)`].
include(Module, Answer) :-
    (   metta_include_refusal(Module, Reason)
    ->  metta_error_atom(include, [Module], Reason, Answer)
    ;   current_metta_space(Space),
        resolve_metta_import_path(Module, Path),
        load_metta_source_groups(Path, Space, Groups),
        last(Groups, Last),
        member(Carried, Last),
        metta_answer_term(Carried, Answer)
    ).

metta_include_refusal(Module, "include: the running context is not a module") :-
    % policy-inventory-exempt: arbiter-owned-language-law; reason=self and top denote module path bases and cannot themselves be included; evidence=engine/metta/interop.pl:metta_include_refusal/2
    memberchk(Module, [self, top]), !.
metta_include_refusal(Module, Reason) :-
    \+ catch(resolve_metta_import_path(Module, _), _, fail),
    format(string(Reason), "no module named ~w is available", [Module]).

%A module NAME may be a COLON PATH. `pkg:child` names pkg/child.metta beside
%the file that imports it, `top:` names the OUTERMOST module's directory and
%`self:` the importing module's own, which is also what a bare name means
%[assumed: the three path forms were adopted from an earlier reference
%semantics, not re-measured against upstream PeTTa].
%
%A name carrying a separator ALREADY is a path and is left alone, which is the
%whole guard: nothing that resolved before resolves somewhere else now
%[tested: module_colon_paths].
metta_module_path(SFile, Base, Relative) :-
    \+ sub_string(SFile, _, _, _, "/"),
    sub_string(SFile, _, _, _, ":"),
    split_string(SFile, ":", "", Segments0),
    module_path_base(Segments0, Which, Segments),
    Segments \== [],
    !,
    metta_import_base(Which, Base),
    atomic_list_concat(Segments, '/', Relative).
metta_module_path(SFile, Base, SFile) :- current_working_dir(Base).

module_path_base(["top"|Segments], top, Segments) :- !.
module_path_base(["self"|Segments], self, Segments) :- !.
module_path_base(Segments, self, Segments).

%working_dir/1 is a stack kept by asserta/1, so its FIRST solution is the file
%being loaded and its last is the module the load started from.
metta_import_base(self, Directory) :- current_working_dir(Directory).
metta_import_base(top, Directory) :-
    findall(Held, working_dir(Held), Directories),
    (   last(Directories, Directory)
    ->  true
    ;   current_working_dir(Directory)
    ).


:- dynamic imported_metta_source/2.
:- dynamic import_life/3.
:- dynamic import_receipt/4.
%Which loads a load caused, in one space. Recorded from the imports still in
%flight when a nested load begins, so it is the ANCESTOR relation rather than
%the parent one: a manifest names every source beneath it directly and the
%currency check below needs no recursion and no termination argument.
:- dynamic import_nested_source/3.
:- dynamic metta_source_flight/3.
:- volatile metta_source_flight/3.
:- '$notransact'(metta_source_flight/3).

%A committed receipt is a cache entry for one exact source load. The temporary
%loading pair stays separate, because it is a cycle breaker rather than proof
%that the load's payload remains usable. A receipt is current only while the
%space's import life remains loaded and the file reader validates its source
%row, digest, and stored-output references.
import_receipt_current(Space, CanonPath) :-
    import_life(Space, CanonPath, loaded),
    import_receipt(Space, CanonPath, LoadId, Digest),
    filereader:source_load_receipt_current(CanonPath, Space, LoadId, Digest).

import_cache_current(Space, CanonPath) :-
    imported_metta_source(Space, CanonPath),
    (   metta_space_name(Space)
    ->  ( import_life(Space, CanonPath, loading)
        ; import_receipt_current(Space, CanonPath),
          import_nested_sources_current(Space, CanonPath) )
    ;   true
    ).

%A load is current only while every load it caused is current too. Without this
%a library's manifest answered current forever: import! of (library L) resolves
%to L/pkg.metta, whose own receipt nothing invalidates, while the equations live
%in the L/lib.metta it requires, so removing one of those equations left the
%gate reading current and the re-import rebuilt nothing
%[tested: test_public_import_rebuilds_when_a_receipt_dependency_disappears].
%This is the invalidation every build system does over its dependency graph:
%a stale header rebuilds the objects that include it.
import_nested_sources_current(Space, CanonPath) :-
    forall(import_nested_source(Space, CanonPath, Nested),
           import_receipt_current(Space, Nested)).

% Import records are a live view of the loader's committed ownership rows.
% A stale digest still names a load that undo can withdraw; a cleared space
% has no load and therefore no record, even if an old cache marker remains.
metta_import_record(Space, CanonPath) :-
    imported_metta_source(Space, CanonPath),
    import_life(Space, CanonPath, loaded),
    filereader:metta_source_load(CanonPath, Space, _, _).

metta_unimport(Space0, File0) :-
    resolve_space_form(Space0, Space),
    metta_require_space_update_capability('unimport!', Space),
    resolve_module_form(File0, File),
    resolve_unimport_path(Space, File, CanonPath),
    metta_source_singleflight(CanonPath,
        ( (   import_life(Space, CanonPath, loading)
          ->  throw(error(permission_error(unimport, loading_source, CanonPath),
                          context('unimport!', 'wait until this source finishes loading')))
          ;   true
          ),
          call_cleanup(
              materialize:materialization_transaction(
                  unimport_source(Space, CanonPath)),
              metta_repair_emptied_shadows) )).

% The recorded path is an identity, so undo must also work after deletion.
% Existing imports choose the process directory before the current source's
% directory; prefer a recorded candidate from that same ordered pair.
resolve_unimport_path(Space, File, CanonPath) :-
    import_file_string(File, SFile),
    metta_module_path(SFile, Base, Relative),
    ensure_metta_ext(Relative, Requested),
    findall(Path,
            % policy-inventory-exempt: mechanism-internal; reason=the two roots are the import resolver's own search order, the process directory before the current source's, not a value a program chooses between; evidence=engine/metta/interop.pl:resolve_unimport_path/3
            ( member(Root, ['.', Base]),
              absolute_file_name(Requested, Path,
                                 [relative_to(Root), access(none), file_errors(error)]) ),
            Files),
    % The same directory manifests import! would have taken, from the same
    % enumerator, appended in the same order: file forms first, manifest last.
    % Without them a directory imported through its pkg.metta could not be
    % unimported by the name that imported it.
    findall(Manifest, package_manifest_candidate(none, Base, Relative, Manifest),
            Manifests),
    append(Files, Manifests, Candidates),
    (   member(Recorded, Candidates), imported_metta_source(Space, Recorded)
    ->  CanonPath = Recorded
    ;   Candidates = [CanonPath|_]
    ).

unimport_source(Space, CanonPath) :-
    (   filereader:metta_source_load(CanonPath, Space, _, _)
    ->  filereader:withdraw_source_load(CanonPath, Space, _),
        retractall(filereader:compiled_metta_source(CanonPath))
    ;   imported_metta_source(Space, CanonPath),
        import_life(Space, CanonPath, loaded)
    ->  throw(error(permission_error(unimport, unjournalled_source, CanonPath),
                    context('unimport!', 'this loader has no exact atom ownership journal')))
    ;   true
    ),
    clear_import_state(Space, CanonPath).

capture_import_state(Space, CanonPath, Terms) :-
    findall(Term,
            ( imported_metta_source(Space, CanonPath),
              Term = imported_metta_source(Space, CanonPath)
            ; import_life(Space, CanonPath, State),
              Term = import_life(Space, CanonPath, State)
            ; import_receipt(Space, CanonPath, LoadId, Digest),
              Term = import_receipt(Space, CanonPath, LoadId, Digest)
            ; import_nested_source(Space, Enclosing, CanonPath),
              Term = import_nested_source(Space, Enclosing, CanonPath)
            ), Terms).

%A space's import bookkeeping goes with the space, and both tables are the
%core's, so the clear lives HERE rather than in engine/spaces. A retractall
%from a module that only SEES a name creates a local predicate and silently
%clears nothing: import_nested_source/3 was cleared that way until the
%layering lane named it, which left an anonymous space's edges standing for
%the next space to draw that recycled name
%[tested: engine_layering:test_the_engine_layering_contract_holds_and_a_violation_is_named].
metta_forget_space_imports(Space) :-
    retractall(import_life(Space, _, _)),
    retractall(import_nested_source(Space, _, _)).

clear_import_state(Space, CanonPath) :-
    retractall(imported_metta_source(Space, CanonPath)),
    retractall(import_life(Space, CanonPath, _)),
    retractall(import_receipt(Space, CanonPath, _, _)),
    retractall(import_nested_source(Space, _, CanonPath)).

%The enclosing imports are read BEFORE this path's own loading marker goes in,
%so a load never records itself as its own ancestor.
begin_import_attempt(Space, CanonPath) :-
    findall(Enclosing,
            ( import_life(Space, Enclosing, loading), Enclosing \== CanonPath ),
            Enclosings),
    clear_import_state(Space, CanonPath),
    assertz(imported_metta_source(Space, CanonPath)),
    forall(member(Enclosing, Enclosings),
           assertz(import_nested_source(Space, Enclosing, CanonPath))),
    (   metta_space_name(Space)
    ->  assertz(import_life(Space, CanonPath, loading))
    ;   true
    ).

restore_import_state(Terms) :-
    forall(member(Term, Terms), assertz(Term)).

finish_import_attempt(Space, CanonPath, _, exit) :- !,
    (   metta_space_name(Space)
    ->  retractall(import_life(Space, CanonPath, _)),
        assertz(import_life(Space, CanonPath, loaded))
    ;   true
    ).
finish_import_attempt(Space, CanonPath, Previous, _) :-
    clear_import_state(Space, CanonPath),
    restore_import_state(Previous).

commit_import_receipt(Space, CanonPath) :-
    metta_space_name(Space), !,
    findall(LoadId-Digest,
            filereader:metta_source_load(CanonPath, Space, LoadId, Digest),
            Loads),
    (   Loads = [LoadId-Digest]
    ->  assertz(import_receipt(Space, CanonPath, LoadId, Digest))
    ;   throw(error(metta_import_receipt_source_load(CanonPath, Space, Loads),
                    context(import_when/4,
                            'a successful MeTTa import must publish exactly one source load before its receipt commits')))
    ).
commit_import_receipt(_, _).

run_import_attempt(Space, CanonPath, Goal) :-
    capture_import_state(Space, CanonPath, Previous),
    setup_call_catcher_cleanup(
        begin_import_attempt(Space, CanonPath),
        once(( call(Goal), commit_import_receipt(Space, CanonPath) )),
        Catcher,
        finish_import_attempt(Space, CanonPath, Previous, Catcher)).

% Assert both destination markers before loading to break same-owner cycles.
% Source ownership is separate from a receipt: a failed owner releases its
% queue and a waiter retries the destination's ordinary receipt check.
%
%Whether an already-loaded file loads AGAIN is a condition, and the condition
%is named at the call site rather than fixed here, which is how SWI writes the
%same choice: load_files/2 takes if(Condition), and `not_loaded loads the file
%if it was not loaded before` while `changed loads the file if it was not
%loaded before or has been modified since it was loaded the last time`
%[source: SWI-Prolog 10.1 Reference Manual, load_files/2]. consult/1 is
%if(true), ensure_loaded/1 is if(not_loaded), and make/0 is what if(changed)
%is for.
%
%import! takes `changed`, so an edited file is picked up where before the
%import was skipped and the edit silently ignored. An UNCHANGED repeat is
%still skipped, which keeps the adopted behaviour: two
%imports of the same module with different destination tokens execute its
%source once [assumed: measured against an earlier reference corpus, not
%re-measured against upstream PeTTa; neither the stdlib documentation nor the
%module tutorial states a reload policy, so the edited case is ours to decide].
%
%A Python source takes `not_loaded`. Re-executing a module body over a live
%sys.modules entry is a different operation with different hazards, and
%importlib.reload/1 is what would implement it; nothing here pretends to.
%
%The Python library's load() takes `true`, and takes it through here rather
%than around it: that is what puts the two doors on one record, so an import!
%of a file load() already read is skipped as loaded rather than run a second
%time [tested: test_a_file_the_library_loaded_is_already_imported].
%A GOAL argument crossing a module boundary has to carry its module, and this
%one crosses two: engine/filereader.pl hands import_when/4 a goal of its own,
%and the loading and life markers pass it on. Without the declarations the goal
%travelled unqualified and was called in THIS module, where the loader's
%internals are invisible, so a grouped load raised
%existence_error(procedure, load_imported_metta_source_groups/3)
%[measured 2026-08-22, once engine/filereader.pl became a module].
:- meta_predicate import_when(+, +, +, 0),
                  run_import_attempt(+, +, 0),
                  metta_source_singleflight(+, 0).

import_when(Condition, Space, CanonPath, Goal) :-
    metta_source_singleflight(CanonPath,
        import_when_owned(Condition, Space, CanonPath, Goal)).

:- meta_predicate import_when_owned(+, +, +, 0).
import_when_owned(Condition, Space, CanonPath, Goal) :-
    (   import_load_needed(Condition, Space, CanonPath)
    ->  run_import_attempt(Space, CanonPath, Goal)
    ;   true
    ).

% SWI's loader uses a queue's lifetime as a broadcast completion event.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/init.pl#L2631-L2705
% Recheck after waking, since this caller may name a different destination or
% the previous load may have failed. No result is cached beside import_receipt.
:- if(current_prolog_flag(threads, true)).
metta_source_singleflight(Path, Goal) :-
    setup_call_cleanup(
        with_mutex(metta_loader, metta_source_flight_enter(Path, Claim)),
        metta_source_flight_run(Claim, Path, Goal),
        metta_source_flight_leave(Claim)).

metta_source_flight_enter(Path, Claim) :-
    thread_self(Self),
    (   metta_source_flight(Path, Owner, Queue)
    ->  ( Owner == Self -> Claim = reentrant ; Claim = waiting(Queue) )
    ;   message_queue_create(Queue),
        assertz(metta_source_flight(Path, Self, Queue), Ref),
        Claim = owner(Ref, Queue)
    ).

:- meta_predicate metta_source_flight_run(+, +, 0).
metta_source_flight_run(waiting(Queue), Path, Goal) :- !,
    catch(thread_get_message(Queue, _),
          error(existence_error(message_queue, Queue), _), true),
    metta_source_singleflight(Path, Goal).
metta_source_flight_run(_, _, Goal) :- call(Goal).

metta_source_flight_leave(owner(Ref, Queue)) :- !,
    with_mutex(metta_loader,
        % erase-license: owner; only the owner's claim carries Ref, and
        % metta_source_flight/3 is '$notransact' with nothing retracting,
        % retractalling or abolishing it, so no rollback reaches it either. A
        % failure here would skip message_queue_destroy/1 and strand every
        % waiter [source 2026-09-25T16:56:06+10:00: git grep -w
        % metta_source_flight over engine/, lib/ and the seats].
        ( erase(Ref), message_queue_destroy(Queue) )).
metta_source_flight_leave(_).
:- else.
metta_source_singleflight(_, Goal) :- call(Goal).
:- endif.

%SWI's three if(Condition) values, asked as a question about THIS load rather
%than about the previous one.
import_load_needed(true, _, _).
import_load_needed(not_loaded, Space, CanonPath) :-
    \+ import_cache_current(Space, CanonPath).
import_load_needed(changed, Space, CanonPath) :-
    import_load_needed(not_loaded, Space, CanonPath).


%`true`, the effect answer add-atom and the rest of the family give; see the
%note above 'println!'/2 in engine/metta/runtime.pl
%[source: PeTTa@ae66fa8 src/metta.pl, where 'import!' answers true].
'import!'(Space0, File, true) :-
    resolve_space_form(Space0, Space),
    metta_require_space_update_capability('import!', Space),
    importer_helper(Space, File).

%A COMPUTED SPACE designator is this engine's extension in exactly the way a
%computed path is, and the mask hands it over unreduced for the same reason:
%`(: import! (-> Atom Atom (->)))` is the adopted declaration
%[assumed 2026-08-24: `!(get-type import!)` was measured against an earlier
%reference corpus at that date]. `&self` is a
%name and stays one; `(context-space)` is a call and is run here.
resolve_space_form(Form, Space) :-
    nonvar(Form), Form = [Head|_], atom(Head), fun_here(Head), !,
    eval(Form, Space).
resolve_space_form(Form, Form).
%`(: import! (-> Atom Atom Bool))` says both arguments arrive UNREDUCED, which
%is right: a module name is a name and evaluating it would look for a function
%called `lib_constraints`. So the forms a module name can take are resolved
%here rather than by the call site.
%
%`(library Name)` is the one form that needs it, and it used to work by
%accident: the call site evaluated the argument because the Atom mask was not
%honoured for builtins, so library/2 ran before import! ever saw it. With the
%mask honoured the form arrives whole, and resolving it is import!'s job.
importer_helper(Space, File0) :-
    resolve_module_form(File0, File),
    importer_helper_impl(Space, File).

resolve_module_form(Form, Path) :-
    nonvar(Form), Form = [library, Name], !,
    library(Name, Path).
%The two-argument spelling names a registered alias and a file inside it,
%`(library metta_fixture_lib fixture)`, and it reaches here for exactly the
%reason the one-argument form does: the mask hands the whole form over, so
%every shape a module name can take is resolved on this side.
resolve_module_form(Form, Path) :-
    nonvar(Form), Form = [library, Alias, Name], !,
    library(Alias, Name, Path).
%A BUILT-IN MODULE is one the engine ships, named directly rather than by
%path: `!(import! &self skel)` is the adopted spelling and upstream
%loads six of them at startup [assumed: the spelling came from an earlier
%reference semantics, not re-measured against upstream PeTTa]. Resolved BEFORE
%the filesystem, because the name is the module's identity rather than a path
%a program may happen to have a file for, which is also what makes the same
%import work from inside another module with its own working directory
%[tested: builtin_modules].
resolve_module_form(Form, Path) :-
    atom(Form), metta_builtin_module(Form, Relative),
    metta_top_context, !,
    library(Relative, Path).
%A COMPUTED PATH is the remaining shape, and it is this engine's own extension:
%a program may write `(import! &self (dynamic-import-path))` where the path is
%whatever a function answers. The mask hands that call over unreduced, so it is
%run here, and only here: a bare symbol is a module NAME and stays one, which
%is what the mask exists for.
%
%The head must already be a function, so a `(some data form)` a program means
%as a name is left exactly as written and reaches the ordinary path resolution
%with its own error.
resolve_module_form(Form, Path) :-
    nonvar(Form), Form = [Head|_], atom(Head), fun_here(Head), !,
    eval(Form, Path).
resolve_module_form(Form, Form).

%The modules this engine ships, one row each. `skel` is upstream's own
%skeleton and the only one of its six that uses every tier at once: three
%declarations, one MeTTa equation and one grounded operation. Upstream's
%`load_builtin_mods` also registers `json`, `fileio`, `catalog` and `das`, and
%those are libraries this engine does not implement; registering a name so
%that an import succeeds while every operation behind it silently fails is the
%graceful degradation this repository refuses, so they stay unresolvable
%and say so.
metta_builtin_module(skel, 'builtin_mods/skel.metta').

%A built-in module is a child of the TOP, so its bare name means one only when
%the import is written at the top. Inside a module the same name is relative to
%that module, `skel` written in `usesskel` means `top:usesskel:skel`, which no
%built-in is, and the import fails. Comparing the written name before anything
%else gets this wrong in a way that is worse than a plain refusal: the import
%reports success and a call to the module's operation is still unreduced,
%because admission is tested against the running context and the import
%went somewhere else
%[tested: a_module_cannot_reach_a_builtin_by_its_bare_name].
%
%working_dir/1 is the load stack, one entry per file being loaded, so the
%outermost file is depth one and anything it imports is deeper.
metta_top_context :-
    findall(Held, working_dir(Held), Directories),
    length(Directories, Depth),
    Depth =< 1.
%A HOST claims and performs an import whose source is its own kind of
%file, through the ownership seam; with no host loaded, or none claiming,
%every import is a MeTTa import. The claiming clause does the whole job,
%lifecycle included, through the same published import_when/4 the engine
%uses itself.
importer_helper_impl(Space, File) :-
    ( seam:host_import(File)
      -> true
       ; resolve_metta_import_path(File, CanonPath),
         import_when(changed, Space, CanonPath,
                     load_imported_metta_file(CanonPath, _, Space)) ).

% The engine sequences requirements before handing the package argument record
% to its prelude interpreter. Catalogs and every lifecycle policy belong to it.
% [source: docs/journal/2026-09-09-packages-are-equations.md,
% "the package is an argument record and the engine knows four things";
% commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
:- use_module('../packages').

% The prelude uses the engine's bounded evaluator, seam dispatch, source
% locators and load policy. Publish these through the ordinary service seam;
% the source reader also calls the package activation and replacement doors.
% [tested: metta_published_surface, engine_layering; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
:- multifile seam:kind/2.
seam:kind(metta_package_normalise/3, service).
seam:kind(metta_package_perform/3, service).
seam:kind(metta_loader_source/1, service).
seam:kind(metta_reference_option/3, service).
seam:kind(resolve_space_form/2, service).
seam:kind(resolve_module_form/2, service).
seam:kind(resolve_unimport_path/3, service).
seam:kind(metta_package_loading/3, service).
seam:kind(metta_package_reload/3, service).
seam:kind(metta_perform_package_rows/2, service).
seam:kind(importer_helper/2, service).
seam:kind(metta_reference_check_prolog_source/1, service).
seam:kind(metta_reference_face/3, service).
seam:kind(metta_reference_read_exports/3, service).
seam:kind(metta_reference_register_prolog/4, service).
seam:kind(record_extension_membership/2, service).

% Time: one indexed source/package join plus O(p) rows, p = package rows in
% this load, and O(p) removals after they are performed. A file with no package
% rows never decodes its other atoms and retires nothing.
metta_perform_package_rows(CanonPath, Space) :-
    findall(Kind-Written,
            filereader:source_package_row(CanonPath, Space, Kind, Written), Rows),
    ( Rows == [] -> true
    ; packages:package_context(CanonPath, Space,
          metta_engine:(metta_perform_package_requires(CanonPath, Space, Rows),
                        packages:package_load(CanonPath, Space, Rows))),
      metta_retire_package_rows(CanonPath, Space) ).

%A package row's scope is its LOAD, not the space it loaded into. The join
%above already computes that scope to READ the rows; the same scope decides
%whether they remain. Law 1 says the loader grades them internal "so they never
%merge into an importer", and a manifest describes ITSELF, so a row left behind
%is one library's requirement sitting where the next importer reads it as its
%own [source: docs/journal/2026-09-09-packages-are-equations.md, law 1].
%
%The reservation was implemented by halves. metta_reference_internal/2 hides
%the NAME, which is what a face, an export and a door consult, and nothing
%consults it when an atom is stored: `get-atoms` enumerates raw stored atoms by
%contract, so grading cannot reach this and the row has to leave the importer's
%storage. Until the manifests became equations the gap was unreachable, because
%a pkg.metta carrying `!(import! ...)` directives stored nothing
%[measured 2026-09-23: importing lib_spaces and lib_uuid into `&self` left 27
%atoms where the ruling derives 26, nine of them identical `requires` rows, and
%`!(package requires)` answered the union across every manifest].
%
%KEPT at the library's own home, the one reader that should still see a row:
%`(get-property lib version)` reads them there, and for a `from` reference the
%home IS the space the manifest loaded into.
%
%Time: one home lookup, then the O(p) retirement in
%filereader:retire_source_package_rows/2. No read outside this load pays
%anything.
metta_retire_package_rows(CanonPath, Space) :-
    (   metta_reference_library_home(Space, CanonPath)
    ->  true
    ;   filereader:retire_source_package_rows(CanonPath, Space)
    ).

metta_perform_package_requires(CanonPath, Space, Rows) :-
    forall((member(requires-Written, Rows),
            metta_package_normalise(Space, Written, Required)),
           packages:package_require(CanonPath, Space, Required)).

% Compilation chooses the seam's equation; execution carries the caller's
% home. evalc alone would replace both contexts and lose native ownership.
% [tested: package_laws:backing_lives_and_retires_in_its_home; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
metta_package_perform(Home, Expression, Result) :-
    space_module('&metta', Seam), space_module(Home, Module),
    with_metta_module(Seam,
        translate_cached_expr(Expression, Goals, Produced)),
    with_metta_module(Module, call_goals_in_(Seam, Goals)),
    metta_boundary_result(Expression, Produced, Result),
    Result \== 'Empty'.

:- meta_predicate metta_package_loading(+, +, 0),
                  metta_package_reload(1, +, +).
metta_package_loading(Path, Space, Goal) :-
    packages:package_loading(Path, Space, Goal).

metta_package_reload(LoadInto, Path, Space) :-
    metta_package_loading(Path, Space,
        (call(LoadInto, Space), metta_perform_package_rows(Path, Space))).

%%%% Law 3: normalising a row before it is performed %%%%
%
%A row whose head a CLAIM answers is already the answer, so it is READ and
%performed as written: there is nothing to normalise and therefore nothing to
%charge. Every shipped row is of that kind, which is why the loader worked
%before this existed.
%
%Two earlier attempts refused every shipped row, and the reason is the same
%both times: they charged something the law does not govern. Planning the
%effect of the `package` HEAD walks every equation for it, so asking about the
%`requires` question charges the backing row's body; planning the row's own
%body reads `(prolog F (heads))` as a call to a known operation and charges it
%`oracleIO`. The law says NORMALISATION, and a literal row has nothing to
%normalise [source: docs/journal/2026-09-09-packages-are-equations.md, law 3;
%the failure is recorded against a31.6].
%
%Anything else is a term, so the law applies to it and to nothing else: it is
%evaluated in the home space under the `reads` ceiling and an inference budget,
%and the row is what it reduces to.
metta_package_normalise(_, Written, Written) :-
    metta_package_claimed(Written),
    !.
metta_package_normalise(Space, Written, Written) :-
    ( atomic(Written)
    ; nonvar(Written), Written = [Head|_], atom(Head),
      space_module(Space, Module),
      \+ metta_host_function_callable_from(Module, Head) ), !.
metta_package_normalise(Space, Written, Row) :-
    metta_package_refuse_above_ceiling(Space, Written),
    metta_package_budget(Budget),
    metta_package_reduce(Space, Written, Budget, Row).

%A token some claim answers. The registry is law 4's own: a claim is the
%equation `(= (perform (<token> ...)) ...)` a seat, library or program adds to
%the seam space, so asking whether a token is claimed is one match against it
%and the engine keeps no second list to fall out of step.
%
%The claims are ENUMERATED and the token tested here, rather than matched with
%`[Token|_]` in the pattern: a partial list does not answer through the space's
%index, where the full shape does [measured 2026-09-20: the partial pattern
%answered nothing while `(= (perform $pattern) $_)` answered `[prolog,_,_]`].
%There are as many claims as there are attached seats, so enumerating them is
%the small side of the join.
metta_package_claimed(Row) :-
    nonvar(Row),
    Row = [Token|_],
    atom(Token),
    eval([match, '&metta', ['=', [perform, Pattern], _], Pattern], Claimed),
    nonvar(Claimed),
    Claimed = [Token|_],
    !.

%Law 3's ceiling is NOT a single rank in this engine's lattice, and the
%measurement says why: `(match &self a a)` and `(add-atom &self a)` both plan
%`writesState`, while `(get-property lib version)` plans `oracleIO` through
%metta_builtin_effect_override/2, and `oracleIO` is the class the law excludes.
%Law 2 makes `get-property` the way a package reads the runtime facts law 3
%explicitly allows, so a ceiling at any single rank either refuses the one read
%the design provides or admits the filesystem [measured 2026-09-20].
%
% Admit nondeterministic reads and the conservatively classified read forms.
% Inspect every operation in a computed body, so a write nested in match is
% still refused. Host calls retain the effect declared by their own seat.
% [tested: package_laws:space_read_bodies_cannot_hide_state_writes; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
metta_package_ceiling(nondeterministicReadOnly).

metta_package_reads_runtime('get-property').
metta_package_reads_runtime(match).
metta_package_reads_runtime('match%').
metta_package_reads_runtime('get-type').
metta_package_reads_runtime('get-type-space').

%Law 3's default budget, and the pragma that moves it. A package needing more
%says so in its own source, rather than an operator raising it for every one.
metta_package_budget(Budget) :-
    (   metta_pragma('package-budget', Value),
        integer(Value),
        Value > 0
    ->  Budget = Value
    ;   Budget = 1000000
    ).

%The source planner rather than the goal planner. The goal one answers about a
%compiled Prolog body and calls ANY list `oracleIO`, which is what refused
%every shipped row in both earlier attempts; the source one answers about MeTTa
%source and prices a literal row `pureStructural` with no operations at all
%[measured 2026-09-20].
%
%The refusal NAMES the operations that exceeded the ceiling, because `it reads
%too much` says nothing a writer can act on while `py-call` names the line to
%move. Law 3 spells that remedy out and it is the same for every operation
%above the ceiling: the work belongs in a claimant, which runs when the row is
%performed rather than while it is being read.
%The plan, or a refusal, with both answers in this HEAD rather than in an
%if-then-else condition. FAIL-CLOSED, and loudly: either goal below can fail --
%an unknown space has no module, and a planner that cannot read a term says so
%by failing -- and a bare conjunction would fail the caller, fail the forall
%that calls IT, and fail the whole load with no message at all. A row nothing
%could plan is a row nothing can certify, so it is refused rather than allowed.
%
%Split out because the caller reads `Operations` and `Effect` after the choice:
%bound only in a condition, SWI reads them as introduced in one branch and not
%the other and warns, and prolog-static halts on a warning rather than reading
%past it. Binding them in the head says the same thing with nothing conditional
%about the bindings, where a dummy binding in the throwing branch would only
%silence the analyser.
metta_package_plan(Space, Written, Operations, Effect) :-
    (   metta_module_space(Module, Space),
        metta_host_source_effect_plan(Module, Written, Operations, Effect)
    ->  true
    ;   throw(error(permission_error(normalise, package_row, unplannable),
                    context('package normalisation',
                            'the row could not be planned, so nothing can say \c
                             whether it stays under the reads ceiling')))
    ).

metta_package_refuse_above_ceiling(Space, Written) :-
    metta_package_plan(Space, Written, Operations, Effect),
    metta_package_ceiling(Ceiling),
    (   metta_effect_covered(Effect, Ceiling)
    ->  true
        %The plan's operations are [Name, Class] LISTS rather than Key-Value
        %pairs, so the names are taken by matching rather than by pairs_keys/2.
        % A plan above the lattice rank is allowed only when every operation
        % responsible is one of the read forms admitted below.
    ;   findall(Operation,
                ( member(Entry, Operations),
                  metta_package_above_ceiling(Ceiling, Entry),
                  Entry = [Operation|_] ),
                Names0),
        sort(Names0, Names),
        ( Names == [] -> true
        ; throw(error(permission_error(normalise, package_row, Names),
                    context('package normalisation',
                            'a package row is normalised under the reads \c
                             ceiling, space reads and runtime facts only; \c
                             move this into a claimant, which runs when the \c
                             row is performed'))))
    ).

%One operation, with its class, against the ceiling. A runtime read is admitted
%by name because the lattice cannot say it: see metta_package_ceiling/1.
metta_package_above_ceiling(Ceiling, [Operation, Class]) :-
    \+ metta_effect_covered(Class, Ceiling),
    \+ metta_package_reads_runtime(Operation).

%Past the budget the refusal names both ways out, since a row that will not
%reduce in a million inferences is either doing work that belongs in a claimant
%or is not converging at all.
metta_package_reduce(Space, Written, Budget, Row) :-
    %A term with no answer is not a failure of this predicate: it is a row
    %that did not reduce, which law 3 calls a row nobody claims. The written
    %term passes through and the perform that follows leaves it unreduced,
    %which is what happened before this normalisation existed. Refusing it by
    %name waits on law 6's coverage rule, which decides when an unclaimed
    %backing is skipped rather than refused [source:
    %docs/journal/2026-09-09-packages-are-equations.md, laws 3 and 6].
    (   catch(metta_call_with_inference_bound(
                  findall(Reduced, evalc(Written, Space, Reduced), Answers), Budget),
              error(Formal, _),
              metta_package_budget_refusal(Formal, Budget))
    ->  ( Answers == [] -> Row = Written ; member(Row, Answers) )
    ;   Row = Written
    ).

%The engine's own signal names the limit but not WHICH budget, and a package
%row can run out under either this one or the program's `max-inferences`, so
%the refusal says which and how to move it [measured 2026-09-20: the bound
%raises metta_control_signal(inference_limit, N)].
metta_package_budget_refusal(Formal, Budget) :-
    (   Formal = metta_control_signal(inference_limit, _)
    ->  throw(error(resource_error(package_budget),
                    context('package normalisation',
                            'the row did not reduce within the inference \c
                             budget; raise it with !(pragma! package-budget \c
                             N) or move the work into a claimant')))
    ;   throw(error(Formal, context('package normalisation', Budget)))
    ).

% Claimants supply their equations; the engine fixes only the data mask.
metta_loader_source("(: perform (-> Atom %Undefined%))").

metta_register_loader_claims :-
    packages:package_register_claims.
