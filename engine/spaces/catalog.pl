% Purpose: own native storage modules and enforce the self-describing policy
% and capability catalog Assumes: engine/spaces.pl consults this plain file
% while its owning module is the load context. Guarantees: every definition
% retains engine/spaces.pl's implementation module and original load order.
% Guarantees: a value's (claim ...) rows are cached per value and the cache
% answers what the storage does: a row landing after a read beats the entry,
% a row removed after a read stops answering through the erased-reference
% check, and a value carrying several rows answers a property from any of them
% [tested: catalog_self_description:a_claim_landing_after_a_read_beats_the_cached_answer,
% catalog_self_description:a_claim_removed_after_a_read_stops_answering,
% catalog_self_description:a_value_may_carry_several_claim_rows; commit=6b4dceb61ccc78e308e6678af58f8daf43c31523].
% Guarantees: a (cost ...) row's witness names exactly one size hole and one
% head, both checked at the write with the remedy named, and one head carries
% at most one row [tested: catalog_self_description:a_cost_witness_needs_exactly_one_hole,
% catalog_self_description:a_second_cost_row_for_one_head_is_refused_with_its_remedy,
% catalog_self_description:one_hole_used_twice_is_one_hole; commit=6b4dceb61ccc78e308e6678af58f8daf43c31523].
% Fails when: loaded directly or from another module; internal state and
% unqualified meta-goals would acquire the wrong owner. Guarantees: counting
% and tropical are ordinary catalog algebras, the semiring vocabulary derives
% from every shipped algebra preset, and each ordered preset declares its best
% direction [tested: shipped_algebra_rows_are_the_semiring_vocabulary;
% commit=5e0ae6c22d604c4b980766e3cc4811ee545e5c9e]. Guarantees: the algebra-law vocabulary and its alias claims
% derive from the engine's accepted law facts [tested:
% algebra_law_vocabulary_and_alias_claims_are_exact; commit=5e0ae6c22d604c4b980766e3cc4811ee545e5c9e].
% Guarantees: the five boolean operations ship a `dispatch-policy` row selecting
%   MismatchFail, so a declared-type mismatch on one of them has no answer
%   rather than a BadArgType atom, which is what a relation out of its domain
%   means and what upstream PeTTa answers
%   [tested: examples/ch07-control-flow/07-01-if-and-booleans/11-boolean_domain.metta;
%   commit=5540a0d03942741ed9565fbb671f18e37cb6eca5].
% Guarantees: the algebra-law vocabulary carries the ghostwriter names,
% identity and distributes-over as aliases and roundtrip and equivalent as
% seam laws the engine never checks, and the refinement vocabulary row names
% the eleven heads engine/metta/refinements.pl decides [tested:
% algebra_law_vocabulary_and_alias_claims_are_exact,
% refinements:the_rule_table_and_the_catalog_vocabulary_agree; commit=19093dd75eda0102eb0329a71460e8a0c7a0c727].
% Guarantees: deprecated is a
% schema-checked catalog kind whose name, since, and remedy fields remain
% ordinary queryable data [tested: the_shipped_catalog_is_queryable_data;
% commit=d74e2e828cd9272882dcf907cfaf095d2d147ce0]. Guarantees: every shipped
% callable receives one PUBLIC or INTERNAL visibility row after prelude
% registration, and internal classification does not remove the callable
% [tested: every_shipped_callable_has_one_visibility;
% commit=8779452fed89853c3f77c3469f7a6ec7b12e9efa]. Guarantees: async is a
% declared operation kind whose compiled result is a FutureSpace [tested:
% test_an_async_operation_answers_a_future_space;
% commit=39092863ae34184a9f955f185ff57c1ff177ec40]. Guarantees: world effect
% coverage and saga compensation are schema-checked catalog rows; compensation
% is admitted only for writesState-or-stronger operations and names one
% callable recovery operation [tested:
% effects_lattice:compensation_declarations_require_an_effectful_operation,
% test_a_structural_operation_cannot_declare_a_compensation;
% commit=173eeed021beb360b5e5f9f8461889e27190affc]. [tested:
% tests/prolog/suites/spaces/spaces.plt, tests/prolog/static_checks.pl;
% commit=9a116762fb4372d55675e2ef64b7657092bc136d]
% Guarantees: fixed-width metta_catalog_clause/2 queries select their storage
% predicate directly, preserving clause references and duplicate order;
% open-tail queries enumerate stored arities [tested:
% catalog_self_description:catalog_queries_preserve_width_multiplicity_and_references,
% catalog_self_description:fixed_width_catalog_lookup_ignores_unrelated_arities;
% commit=8bd37f3042555ee016a7b917234ce44c75a97c3e].
% Guarantees: a user algebra row is owned by the same context key as its
% annotations row, while shipped preset rows remain global fallbacks [tested:
% extensions/python/tests/ch06_many_answers/test_under_algebra.py::test_custom_algebras_are_context_owned;
% commit=2e627a593413191cda3170f2eb716835f7f62543].
% Guarantees: metta_retire_space_catalog/1 removes declarations owned by a
% released space through metta_remove_atom/3, including context-routed kinds,
% while global vocabularies and sibling algebra declarations remain intact
% [tested: run_tests(catalog_lifecycle); commit=074dc0a88b1605c54824de677d586b6f60998bcf].
% Guarantees: a third-party kind joins that retirement with one
% (owned-by-space Head) row and leaves it when the row is withdrawn; the row
% is refused unless Head has a kind row starting at the owning space
% [tested: catalog_lifecycle:release_retires_a_third_party_owned_by_space_kind,
% catalog_lifecycle:withdrawing_the_ownership_row_stops_the_retirement,
% catalog_self_description:an_ownership_row_without_its_kind_is_refused,
% catalog_self_description:an_ownership_row_over_a_kind_without_a_space_position_is_refused;
% commit=76dbea9f4bc10804a5ca19493972dfb7975bc4b0].

% Guarantees: finite tensor closure and law witnesses compare shape and exact
% values [tested: test_finite_tensor_semiring_checks_every_law; commit=074dc0a88b1605c54824de677d586b6f60998bcf].
% Guarantees: one (refusal ...) row per kind the engine's own table declares,
% each naming one class, standing on an admitted authority with a citation
% that names its place, and carrying a remedy whose title holes are fields
% that kind declares; the `refusal-kind` vocabulary is derived from the rows
% and `ground-kind`, `remedy-kind` and `applicability` are the three closed
% sets metta.errors validates against
% [tested: run_tests(catalog_refusal_rows),
% extensions/python/tests/repository/test_refusal_rows.py; commit=f33b7ab0200e6dc74c88fb4c7f827bf545a447ed].

% Guarantees: every (vocabulary ...) row carries its MeTTa TYPE NAME by one
% rule, the mechanical CamelCase of the kebab name with declared exceptions as
% (vocabulary-type ...) rows, and the ENGINE writes the type atoms: one
% (: <TypeName> Type) per row, one (: <member> <TypeName>) per member and the
% (:< ...) edges of a declared (vocabulary-order ...) chain, published once the
% engine is loaded and thereafter as each row lands
% [tested: catalog_vocabulary_words:every_vocabulary_row_is_typed,
% catalog_vocabulary_words:the_declared_type_name_beats_the_map,
% catalog_vocabulary_words:a_declared_order_is_a_chain; commit=7f9c810e5f4a2023ad98de34e848667dd72bc4a7].
% Guarantees: a (vocabulary-open ...) row is what admits a
% (vocabulary-member ...) write, a closed vocabulary refuses one naming the row
% and the property, and an admitted member answers from every consulting site
% and leaves with its row; an (algebra ...) row registers its own carrier
% through that door, which is what lets a declared algebra claim its ordering
% [tested: catalog_vocabulary_words:a_closed_vocabulary_refuses_a_member,
% catalog_vocabulary_words:an_open_vocabulary_admits_a_member,
% catalog_vocabulary_words:a_withdrawn_member_leaves_with_its_type_atom,
% catalog_vocabulary_words:a_declared_algebra_joins_the_semiring_vocabulary,
% catalog_vocabulary_words:an_algebra_row_leaving_takes_its_membership;
% commit=7f9c810e5f4a2023ad98de34e848667dd72bc4a7].
% Guarantees: the wire grammar is thirteen (wire-tag Tag Class Payload Means)
% rows, and the shim's own encoder and decoder speak exactly the term tags they
% declare [tested: catalog_vocabulary_words:the_shim_speaks_the_declared_wire_tags;
% commit=7f9c810e5f4a2023ad98de34e848667dd72bc4a7].
% Guarantees: type carriers validate membership without certifying laws;
% only finite enumerations permit exhaustive law checks [tested:
% test_type_carrier_cannot_certify_laws,
% test_type_carrier_refuses_values_outside_its_type; commit=074dc0a88b1605c54824de677d586b6f60998bcf].

:- dynamic native_storage_module_cache/2.
:- dynamic space_parametric/1.
%The two host idle-hook seams these read are declared with every other seam,
%in engine/ext_points.pl, rather than here. Declaring a seam in the module of
%the file that happens to CALL it was the flat namespace's habit; a seam
%belongs to the seam module whichever subsystem asks it.

%Only a module that actually holds something belongs to somebody else.
%current_module/1 is not that test: SWI creates a module as a side effect of
%merely naming it, including from read-only introspection, so
%predicate_property('$metta_atoms:&kb':anything, dynamic) was enough to make
%&kb throw on every write for the life of the process, with clear/1 reporting
%success and changing nothing. An empty module of that name is ours to claim
%[tested: spaces_registration:naming_the_storage_module_does_not_claim_it].
native_storage_module_occupied(Module) :-
    current_module(Module),
    predicate_property(Module:Head, defined),
    \+ predicate_property(Module:Head, imported_from(_)),
    \+ predicate_property(Module:Head, foreign), !.

native_storage_ready(Module) :-
    current_predicate(Module:'$metta_native_storage'/0),
    predicate_property(Module:'$metta_native_storage', dynamic),
    \+ predicate_property(Module:'$metta_native_storage',
                           imported_from(_)).

native_storage_module_ready(Space, Module) :-
    native_storage_module_cache(Space, Module).

%Whether a NAME is a space, which is the wider question: one this engine
%already holds, or one it would create by being written to. A space is created
%on demand here, so the second half cannot be the registry.
%
%ANY SYMBOL IS ONE, which is upstream's answer and not a relaxation of taste.
%There a space IS a Prolog predicate name: `match/4` builds
%`Term =.. [Space, Rel|PatArgs]` and `add_sexp/2` asserts the same shape, so
%writing to `my_space_name` creates it exactly as writing to `&self` does
%[source: PeTTa@ae66fa8 src/spaces.pl:1-6,52-62].
%
%This engine required a leading `&` between 2026-08-20 and 2026-08-30, on a
%rule taken from an earlier reference semantics: bare symbols resolve only
%through the running context's token table, so an unbound symbol is not a space
%[assumed: adopted from an earlier reference semantics and since withdrawn, not
%re-measured against upstream PeTTa]. Under
%that rule `examples/add_atom_fun_space.metta` could not run, and this engine's
%own copy of it was respelled to `&my_space_name` to fit.
%
%is-space/2 KEEPS the prefix test, and that is upstream's split rather than an
%oversight here: `'is-space'(A,R) :- atom(A), atom_concat('&', _, A) -> ...`
%sits in the same file as the match/4 that accepts any atom
%[source: PeTTa@ae66fa8 src/metta.pl:208]. So
%`(add-atom not_a_space (bad add))` answers true and
%`(is-space not_a_space)` answers false in the same program, on BOTH engines
%[measured 2026-08-30].
metta_space_name(S) :- metta_space_prefixed_name(S), !.
metta_space_name(S) :- metta_space_operand(S).

%What a WRITE may create, which is wider than what the rest of the engine
%calls a space. Upstream has no registry at all: `add_sexp/2` is
%`Term =.. [Space, Rel|Args], assertz(Term)`, so writing to any symbol creates
%that symbol's space [source: PeTTa@ae66fa8 src/spaces.pl:1-6]. This is asked
%ONLY where a space is created, never on the nine hot paths that ask
%metta_space_operand/1: making the shared test true for every atom was
%measured on 2026-08-30 and cost two corpus files (translatepredicate,
%spaces_succeedspredicate), five examples and five plunit units, because those
%paths use it to tell a space operation from an ordinary symbol.
metta_space_writable_name(S) :- atom(S), !.
metta_space_writable_name(S) :- metta_space_operand(S).

%The narrower question, and the only one is-space/2 asks.
metta_space_prefixed_name(S) :- atom(S), sub_atom(S, 0, 1, _, '&').
%HERE rather than beside metta_space_operand/1 below, because the two
%directives that create &self's and &metta's storage modules run while this
%file loads and a directive can only call what is already defined.

ensure_native_storage_module(Space, Module) :-
    native_storage_module_cache(Space, Module), !.
%CREATION is where a name that is not a space is refused, and refusing here is
%what makes the check free: a space this engine already holds answered from the
%cache above without asking, and only a name it would have to CREATE reaches
%the question. The doors above turn this failure into the arbiter's own error
%answer [tested: space_argument_refusals]. Asking at each door instead cost one
%to three inferences on every space operation and four benchmarks saw it
%[measured 2026-08-20: direct-join +10, prepared-join +10, register-op +200,
%py-method-call +30,002].
ensure_native_storage_module(Space, Module) :-
    metta_space_writable_name(Space),
    native_storage_module(Space, Module),
    with_mutex('$metta_native_storage',
               ensure_native_storage_module_locked(Space, Module)).

ensure_native_storage_module_locked(Space, Module) :-
    native_storage_module_cache(Space, Module), !.
ensure_native_storage_module_locked(Space, Module) :-
    native_storage_ready(Module), !,
    assertz(native_storage_module_cache(Space, Module)).
ensure_native_storage_module_locked(Space, Module) :-
    ( native_storage_module_occupied(Module)
      -> throw(error(permission_error(create, native_space_storage, Module),
                     context(ensure_native_storage_module/2,
                             'the reserved storage module name is already in use')))
    ; set_prolog_flag(Module:unknown, fail),
      dynamic(Module:'$metta_native_storage'/0),
      assertz(native_storage_module_cache(Space, Module)) ).

%A foreign claim over an EXISTING name falsifies the premise the match
%door's cache-first clause states (a foreign-claimed name never has a native
%storage cache row): a space can be created native, cached by its first
%operation, and only then claimed by a provider, at which point the stale row
%routes every match to the empty native module and the provider is never
%asked. Measured as view({'port': 80}) answering [] while has_provider said
%True [tested: extensions/python/tests/ch04_spaces_and_matching/test_spaces_combinators.py::test_view_is_a_live_queryable_space;
%commit=57f21ba9edf94bcf28cde11f938bce2c241a3709]. The claim door calls this on every atom-name claim, under
%the same mutex the seeding path holds, so the premise is enforced rather
%than assumed; prefix claims seed no rows (their spaces are created through
%the provider path) and need no sweep.
native_storage_cache_forget(Space) :-
    with_mutex('$metta_native_storage',
               retractall(native_storage_module_cache(Space, _))).

%The dynamic marker and module properties survive transaction rollback even
%when its cache fact does not. A later write can therefore recover the cache
%instead of finding a stranded reserved module name [tested:
%spaces_registration:rolled_back_first_write_keeps_storage_reusable].
:- ensure_native_storage_module('&self', _).
:- dynamic '$metta_atoms:&self':'&self'/3.
%&metta too, at load: the contract read path probes it on every foreign
%match, and against a module that does not exist yet each probe is a thrown
%and caught existence error, 65 inferences where the created module's
%unknown=fail flag answers the same miss in a handful [measured 2026-08-17:
%metta_handles_route 136 to 30 inferences per miss].
:- ensure_native_storage_module('&metta', _).

% Return the asserted clause reference so a source load can roll back every
% atom it added if a later form fails.
add_sexp(Space, Term) :- add_sexp(Space, Term, _).
%&self's storage module is fixed and created when this file loads, so the
%default space skips the cache lookup that every other space needs. Writes are
%the one path that pays per atom: resolving the module per write cost four
%inferences of every seven on this path [measured 2026-08-15: 7.00 to 5.00
%inferences per write over 200,000 writes].
add_sexp('&self', Term, Ref) :- !, add_sexp_in('$metta_atoms:&self', '&self', Term, Ref).
%The contract flag rides an indexed clause of its own, so an ordinary
%add never even tests for '&metta': first-argument indexing dispatches
%past this clause for every other space at zero cost, where a guard
%inside the shared funnel taxed every write (+26k on source-load's
%counter, caught by the gate).
add_sexp('&metta', Term, Ref) :- !,
    metta_declaration_check(Term),
    metta_note_ctx_declared(Term),
    ensure_native_storage_module('&metta', Module),
    add_sexp_in(Module, '&metta', Term, Ref),
    metta_catalog_note_added(Term).
add_sexp(Space, Term, Ref) :- ensure_native_storage_module(Space, Module),
                              add_sexp_in(Module, Space, Term, Ref).

%The two clause bodies below are native_atom_clause/3 written out rather than
%called, and that is measured rather than assumed: calling it cost one goal
%per write, +2001 inferences over add-batch's thousand atoms, +2 per write on
%a seven-inference path. native_atom_clause/3 stays the definition, this is
%its copy on the hot path, and native_storage_shapes_agree binds them.
:- dynamic metta_ctx_declared/1.

%Monotone-conservative contract flag, set at the one funnel every native
%'&metta' write passes: flag ABSENT proves no declaration has ever named
%the context, so the per-call guards below skip their probes outright;
%flag PRESENT only means "run the real probes", so a declaration removed
%or rolled back later costs nothing but the shortcut. The subject is
%conservatively the declaration's first argument whatever the head,
%because over-flagging a non-context symbol is harmless while missing a
%real context would silently skip a guard. This closes CA-7's open
%squeeze: the undeclared pure-Prolog foreign match paid the handles,
%source and on-error probes on every call.
metta_note_ctx_declared([Head|_]) :-
    metta_catalog_head(Head),
    !.
metta_note_ctx_declared([_, Ctx|_]) :-
    atom(Ctx),
    \+ metta_ctx_declared(Ctx),
    !,
    assertz(metta_ctx_declared(Ctx)).
metta_note_ctx_declared(_).

%The same monotone-conservative shortcut narrowed to the events head, and it
%is the one head that needs its own: a (subscription ...) atom names a SPACE
%in the same position, so every standing query flags its own space as
%ctx-declared and the general flag can no longer say "this context declared
%nothing about events". Without a flag the admission check walked the growing
%'&metta' store on every subscription: one subscribe cost 983,768
%instructions before the check existed, 1,093,524 with the check and 988,037
%with the flag, so the capability costs 0.43% rather than 11.2% [measured
%2026-08-21, instructions:u per subscribe, 1,000 standing queries against a
%0-query baseline, min of 3].
%
%It is set from metta_check_catalog_semantics/3 rather than from the walk
%above, and the difference is measured: that walk runs on EVERY '&metta'
%write and its first argument is a list, so every clause added to it is one
%inference on every write, which register-op's benchmark caught at +94 over
%its declarations. The semantics check dispatches on the head ATOM, so a
%clause for one head costs the other heads nothing.
:- dynamic metta_events_declared/1.

%The catalog's own rows never name a context in their first argument, a
%kind head or a vocabulary name being what sits there, and flagging those
%grew metta_ctx_declared from a handful of real contexts to forty rows,
%which the guards' first miss then paid as a linear walk before the JIT
%index built [measured 2026-08-20: the single-pattern snapshot probe read
%687 against 685 by warm-up order]. Skipping them keeps the flag exactly
%what it says: a context some declaration names.
metta_catalog_head(kind).
metta_catalog_head(vocabulary).
metta_catalog_head('vocabulary-type').
metta_catalog_head('vocabulary-order').
metta_catalog_head('vocabulary-open').
metta_catalog_head('vocabulary-member').
metta_catalog_head('wire-tag').
metta_catalog_head(claim).
metta_catalog_head(policy).
metta_catalog_head('routed-by-shape').
metta_catalog_head('dispatch-default').
metta_catalog_head('dispatch-policy').
metta_catalog_head(deprecated).
metta_catalog_head(visibility).

add_sexp_in(Module, [Family|Parameters], [Rel|Args], Ref) :-
    Space = [Family|Parameters],
    space_parametric(Space),
    !,
    Term =.. ['$metta_parametric_atom', Rel|Args],
    assertz(Module:Term, Ref).
%One more indexed clause, not a guard: a ':' head fails this clause's head
%unification for every other write at zero inferences, the same trick the
%'&metta' funnel clause above documents. A declaration LANDING in a space
%is what upgrades that space's compile-time self tier from the &self
%literal to the two-probe storage clause, so a space that never declares
%never pays the second probe (alpha-unique's ten thousand data heads
%measured the difference at +30 inferences per head when every module
%carried the specialized clause unconditionally).
add_sexp_in(Module, Space, [':'|Args], Ref) :- !,
    self_tier_arrived(Space),
    Term =.. [Space, ':' | Args],
    assertz(Module:Term, Ref).
add_sexp_in(Module, Space, [Rel|Args], Ref) :- !,
                                               Term =.. [Space, Rel | Args],
                                               assertz(Module:Term, Ref).

%A scalar or empty expression cannot be a plain Space(Term) fact, because that
%is already the encoding of the singleton expression (Term). It gets its own
%predicate rather than a marked rule inside the space: a marked rule makes
%every clause of the space predicate a rule, so reading one back has to go
%through clause/2, which walks the clause list instead of using SWI's clause
%indexing. Measured on examples/ch22-a-reasoner-you-can-serve/22-03-search/03-matespace.metta, that cost 15.3x,
%99.5 billion instructions against 1,520 billion. Keeping scalars in
%the private scalar predicate leaves expressions as facts a direct indexed
%call reaches.
add_sexp_in(Module, _, Atom, Ref) :-
    assertz(Module:'$metta_native_scalar'(Atom), Ref).

%Below every add_sexp_in/4 clause so the write funnel stays contiguous for
%the source reader; the tier note itself is order-free.
self_tier_arrived('&self') :- !.
self_tier_arrived(Space) :-
    (   metta_exec_module_known(Space, Module)
    ->  translator:self_tier_note(Module, Space)
    ;   true
    ).

%%%% The catalog describes its own kinds %%%%
%
%Three declaration heads make the catalog self-describing, themselves
%ordinary '&metta' atoms a program can match and remove:
%
%    (vocabulary Name Value...)       a named value set, every value a symbol
%    (claim Vocab Value Property...)  properties of one value, read where a
%                                     consultation site needs a per-value fact
%                                     rather than a list compiled into the
%                                     engine
%    (kind Head ArgSpec...)           the positional shape of every (Head ...)
%                                     declaration
%
%An argspec is symbol, integer, pattern, term, (one-of Vocab),
%(some-of Vocab), (optional Spec) in the tail only, or (rest Spec) in final
%position matching zero or more. pattern and term both admit any term; the two
%names keep a kind's row readable, a pattern is matched against queries and a
%term is carried. (some-of Vocab) admits one member of the vocabulary, a
%member APPLIED to the arguments its (claim Vocab Member takes Spec...) row
%declares, or a list of those, so a composable option set such as
%(cache f (monotonic lazy (max-answers 100))) is one argument; a member
%claimed (claim Vocab Member alone) stands by itself. metta_policy_members/3
%below is the one parser, and the consumer that compiles the members reads
%the same list the checker admitted.
%
%The checker runs at the two doors every native '&metta' write passes, the
%per-atom funnel above and the bulk door below. A head with a declared kind
%is validated positionally, and a violation is a hard error naming the atom,
%the argument position and the argspec it missed, where the old behaviour
%was an atom that silently never matched its consultation site. A head with
%NO declared kind passes untouched, which is what keeps the data axis open:
%a third-party declaration kind is atoms here first, schema-checked only
%once its author declares a kind row for it. The shape is PostgreSQL's: enum
%values are catalog rows and a write validates against the catalog, not
%against a list compiled into the server [source: PostgreSQL documentation,
%8.7 Enumerated Types]. Removal is monotone-conservative, the
%metta_ctx_declared rule: a removed kind row means later adds of that head
%pass unchecked, and remove-then-redeclare, even WIDER than the shipped
%preset, is how a program deliberately loosens a shipped kind.
%
%Self-description bootstraps by declaration order: the presets below add the
%vocabularies first, then (kind kind ...) while no kind row exists yet, so
%it enters unchecked, and from that atom on every (kind ...) add is
%validated against it, its argspecs walked by the same checker that walks
%any other declaration.
metta_declaration_check(Term) :-
    Term = [Head|Args],
    atom(Head),
    metta_kind_spec(Head, Spec),
    !,
    metta_check_positions(Args, Spec, 1, Term),
    metta_check_catalog_semantics(Head, Args, Term).
metta_declaration_check(_).

%A landed catalog row must beat any negative cache row for its subject:
%the positive rows self-heal through their stored reference, the negative
%ones have nothing to watch, so the write funnel retracts them here. A
%kind or routing row landing also rebuilds its head's materialized route
%dispatch, which is how the shipped routes come up during the preset walk
%and how a third-party routed kind starts routing the moment its rows are
%in.
metta_catalog_note_added(['dispatch-policy', Function, Axis, _]) :-
    !,
    metta_dispatch_cache_forget(Function, Axis),
    metta_dispatch_policy_changed(Function, Axis).
metta_catalog_note_added(['dispatch-default', Axis, _]) :-
    !,
    metta_dispatch_default_cache_forget(Axis),
    metta_dispatch_default_changed(Axis).
metta_catalog_note_added([kind, Head|_]) :-
    !,
    retractall(metta_kind_cache(Head, _, _)),
    metta_materialize_route(Head).
metta_catalog_note_added([vocabulary, Vocab|_]) :-
    !,
    retractall(metta_vocab_cache(Vocab, _, _)),
    metta_publish_vocabulary_types(Vocab).
%A vocabulary's words are typed the moment its row lands, so the three rows
%that change what the type IS or which words carry it republish. The declared
%type name arrives AFTER the vocabulary row at boot (a kind row has to be in
%place to check it), so this is also how the shipped exception takes effect.
metta_catalog_note_added(['vocabulary-type', Vocab, _]) :-
    !,
    metta_camel_name(Vocab, Mechanical),
    metta_vocabulary_values(Vocab, Values),
    metta_retract_types_under(Mechanical, Values),
    metta_publish_vocabulary_types(Vocab).
metta_catalog_note_added(['vocabulary-order', Vocab|_]) :-
    !,
    metta_publish_vocabulary_order(Vocab).
metta_catalog_note_added(['vocabulary-member', Vocab, Member]) :-
    !,
    retractall(metta_vocab_cache(Vocab, _, _)),
    metta_publish_member_type(Vocab, Member).
%A landed claim beats the entry for its value, whether that entry is a list of
%earlier rows or the empty one a value with no claims cached. The erased-ref
%revalidation above covers removal and cannot cover this: an entry built before
%the row landed watches references that are all still live.
metta_catalog_note_added([claim, Vocab, Value|_]) :-
    !,
    retractall(metta_claim_cache(Vocab, Value, _, _)).
metta_catalog_note_added(['routed-by-shape', Head|_]) :-
    !,
    metta_materialize_route(Head).
metta_catalog_note_added([algebra, Name, _, _, _, _, _, _, _, Owner]) :-
    !,
    (   Owner == global
    ->  retractall(metta_algebra_descriptor_cache(_, Name, _, _, _, _, _, _, _))
    ;   retractall(metta_algebra_descriptor_cache(Owner, Name, _, _, _, _, _, _, _))
    ),
    metta_register_semiring(Name).
metta_catalog_note_added([annotations, Ctx|_]) :-
    !,
    retractall(metta_annotations_cache(Ctx, _)).
metta_catalog_note_added([cache, Function, _]) :-
    !,
    metta_cache_policy_changed(Function).
metta_catalog_note_added([tabled, _, Function, _]) :-
    !,
    metta_cache_policy_changed(Function).
metta_catalog_note_added([capacity, Pool, _]) :-
    !,
    metta_capacity_contract_added(Pool).
metta_catalog_note_added(_).

% A policy write is rare, while every equation compilation is hot. Materialize
% the typed root at mutation time over the function-view index the translated
% forms already maintain, then invalidate it. This gives stored callers the
% common forward walk without adding six edges to every compiled form.
metta_dispatch_policy_changed(Function, Axis) :-
    findall(F-Module,
            dispatch_changed_context(Function, F, Module),
            Contexts0),
    sort(Contexts0, Contexts),
    findall(Root,
            ( member(F-Module, Contexts),
              dispatch_changed_axis(Axis, ChangedAxis),
              Root = dispatch_policy(Module, F, ChangedAxis),
              support_record(function_view(Module, F), Root) ),
            Roots0),
    sort(Roots0, Roots),
    support_invalidate_many(Roots),
    forall(support_repair_invalidations, true),
    (   atom(Function)
    ->  invalidate_translated_forms(Function)
    ;   clear_translation_cache
    ).

dispatch_changed_context(Pattern, Function, Module) :-
    support_view_module(Function, Module),
    ( var(Pattern) -> true ; Function == Pattern ).

dispatch_changed_axis(Pattern, Axis) :-
    dispatch_axis_vocabulary(Axis, _),
    ( var(Pattern) -> true ; Axis == Pattern ).

% A default row applies to every function without an override, so invalidating
% all published roots for that axis is the exact conservative update. Clearing
% runnable templates avoids a second global dependency index for a rare edit.
metta_dispatch_default_changed(Axis) :-
    metta_dispatch_policy_changed(_, Axis).

metta_dispatch_all_changed :-
    forall(dispatch_axis_vocabulary(Axis, _),
           metta_dispatch_default_changed(Axis)).

%The removal twin, called by the '&metta' clause of remove_sexp below for
%a row that actually left. A variable head means the caller removed by
%pattern and anything may have gone, so everything derived is dropped and
%rebuilt, which over-invalidates and never under-invalidates.
metta_catalog_note_removed([Rel|_]) :-
    var(Rel),
    !,
    retractall(metta_kind_cache(_, _, _)),
    retractall(metta_vocab_cache(_, _, _)),
    retractall(metta_claim_cache(_, _, _, _)),
    retractall(metta_algebra_descriptor_cache(_, _, _, _, _, _, _, _, _)),
    retractall(metta_annotations_cache(_, _)),
    retractall(metta_dispatch_value_cache(_, _, _, _)),
    metta_materialize_routes,
    metta_capacity_counts_prune,
    metta_dispatch_all_changed,
    metta_cache_policy_changed(_).
metta_catalog_note_removed(['dispatch-policy', Function, Axis, _]) :-
    !,
    metta_dispatch_cache_forget(Function, Axis),
    metta_dispatch_policy_changed(Function, Axis).
metta_catalog_note_removed(['dispatch-default', Axis, _]) :-
    !,
    metta_dispatch_default_cache_forget(Axis),
    metta_dispatch_default_changed(Axis).
metta_catalog_note_removed([kind, Head|_]) :-
    !,
    retractall(metta_kind_cache(Head, _, _)),
    metta_materialize_route(Head).
%The row is already gone when this runs, so the members it published are read
%from the entry the removal invalidates rather than from the store.
metta_catalog_note_removed([vocabulary, Vocab|Declared]) :-
    !,
    (   metta_registered_members(Vocab, Registered, _)
    ->  true
    ;   Registered = []
    ),
    append(Declared, Registered, Values),
    retractall(metta_vocab_cache(Vocab, _, _)),
    metta_retract_vocabulary_types(Vocab, Values).
metta_catalog_note_removed(['vocabulary-type', Vocab, Type]) :-
    !,
    (   metta_vocabulary_values(Vocab, Values)
    ->  metta_retract_types_under(Type, Values),
        metta_publish_vocabulary_types(Vocab)
    ;   true
    ).
metta_catalog_note_removed(['vocabulary-order', _|Chain]) :-
    !,
    metta_retract_order_edges(Chain).
metta_catalog_note_removed(['vocabulary-member', Vocab, Member]) :-
    !,
    retractall(metta_vocab_cache(Vocab, _, _)),
    metta_retract_member_type(Vocab, Member).
%Removal is covered by the erased-ref revalidation, and this is here anyway for
%the case that revalidation cannot see: a removal by PATTERN, whose Vocab or
%Value is a variable, retracts every entry it could have matched.
metta_catalog_note_removed([claim, Vocab, Value|_]) :-
    !,
    retractall(metta_claim_cache(Vocab, Value, _, _)).
metta_catalog_note_removed(['routed-by-shape', Head|_]) :-
    !,
    metta_materialize_route(Head).
metta_catalog_note_removed([algebra, Name, _, _, _, _, _, _, _, Owner]) :-
    !,
    (   Owner == global
    ->  retractall(metta_algebra_descriptor_cache(_, Name, _, _, _, _, _, _, _))
    ;   retractall(metta_algebra_descriptor_cache(Owner, Name, _, _, _, _, _, _, _))
    ),
    metta_unregister_semiring(Name).
metta_catalog_note_removed([annotations, Ctx|_]) :-
    !,
    retractall(metta_annotations_cache(Ctx, _)).
metta_catalog_note_removed([cache, Function, _]) :-
    !,
    metta_cache_policy_changed(Function).
metta_catalog_note_removed([tabled, _, Function, _]) :-
    !,
    metta_cache_policy_changed(Function).
metta_catalog_note_removed([capacity|_]) :-
    !,
    metta_capacity_counts_prune.
metta_catalog_note_removed(_).

metta_cache_policy_changed(Function) :-
    forall(seam:cache_policy_changed(Function), true).

%Ask every library to drop what it derived earlier. Beside the policy event
%because it is the same neighbourhood -- a cache row says whether answers may
%be kept, this says forget the ones that were -- and because both are the
%engine telling rather than an extension reaching.
metta_forget_derived :-
    forall(seam:forget_derived, true).

% A space owner is a catalog position, not a symbol mentioned anywhere in a
% row. Algebra laws and their carrier certificate live inside the owned
% algebra row; vocabulary and claim rows are global definitions. Context
% routes describe their owner position already, including third-party kinds.
% [tested: run_tests(catalog_lifecycle); commit=074dc0a88b1605c54824de677d586b6f60998bcf].
metta_space_catalog_head(Head) :- metta_routed_head(Head, context).
%A kind that is space-owned but has nothing to dispatch says so with one row.
%Shape routing was the only self-service path into this list, and it forces
%the shape (Head Ctx Pattern Payload...) on a kind whose rows are a per-space
%FACT with nothing to match, so the alternative was a clause here per
%third-party head and an engine edit for every library that stores one.
%Recording the ownership edge as data is how PostgreSQL's pg_depend lets DROP
%CASCADE reach an extension's own objects, walking stored edges instead of a
%list compiled into the server
%[source: https://www.postgresql.org/docs/18/catalog-pg-depend.html, the
%DEPENDENCY_EXTENSION row; commit=76dbea9f4bc10804a5ca19493972dfb7975bc4b0], and it is the ownership rule the
%2026-09-06 retirement thread already mapped this walk onto
%[source: docs/journal/2026-09-06-algebra-rows-die-with-their-space.md,
%"Research mapping"; commit=76dbea9f4bc10804a5ca19493972dfb7975bc4b0].
%The retirement walk below reads position 1 as the owning space, which is
%where every shipped context-owned head already carries it, so the marker
%names the head alone
%[tested: catalog_lifecycle:release_retires_a_third_party_owned_by_space_kind;
%commit=76dbea9f4bc10804a5ca19493972dfb7975bc4b0].
metta_space_catalog_head(Head) :- metta_catalog_row(['owned-by-space', Head]).
metta_space_catalog_head(annotations).
metta_space_catalog_head(source).
metta_space_catalog_head(context).
metta_space_catalog_head(admits).
metta_space_catalog_head(capacity).
metta_space_catalog_head(writes).
metta_space_catalog_head(events).
metta_space_catalog_head(emits).
metta_space_catalog_head(image).
metta_space_catalog_head(on).
metta_space_catalog_head(agenda).
metta_space_catalog_head(tabled).
metta_space_catalog_head(defined).
metta_space_catalog_head(subscription).
metta_space_catalog_head(inherits).
metta_space_catalog_head(restricted).
metta_space_catalog_head(grants).
metta_space_catalog_head(parametric).
metta_space_catalog_head(covers).
metta_space_catalog_head('pre-add').
metta_space_catalog_head('post-add').

metta_retire_space_catalog(Space) :-
    metta_undeclare_hook(pre_add, Space),
    metta_undeclare_hook(post_add, Space),
    findall(Head, metta_space_catalog_head(Head), Heads0),
    sort(Heads0, Heads),
    findall(Row,
            ( member(Head, Heads),
              Row = [Head, Space|_],
              metta_catalog_row(Row) ),
            ContextRows),
    findall([algebra, Name, Combine, Extend, Zero, One,
             Laws, Carrier, Requires, Space],
            ( Space \== global,
              metta_catalog_row([algebra, Name, Combine, Extend, Zero, One,
                                 Laws, Carrier, Requires, Space]) ),
            AlgebraRows),
    append(ContextRows, AlgebraRows, Rows),
    forall(member(Row, Rows), metta_remove_atom('&metta', Row, _)),
    retractall(metta_annotations_cache(Space, _)),
    retractall(metta_algebra_descriptor_cache(Space, _, _, _, _, _, _, _, _)),
    retractall(metta_ctx_declared(Space)),
    retractall(metta_events_declared(Space)).

%One catalog row as a list, whatever its arity: '&metta'(kind, handles,
%symbol, ...) reads back as [kind, handles, symbol, ...]. The walk over the
%arities is needed only when the query leaves its width open. A fixed-width
%query already names one storage predicate, as get_native_atom/3 does
%[source: engine/spaces/native_matching.pl:get_native_atom/3;
%commit=2458294ae03b8dc1c982a5bc7d31601cc6332dd3].
metta_catalog_row(Row) :-
    metta_catalog_clause(Row, _).

metta_catalog_clause([Rel|Args], Ref) :-
    native_storage_module('&metta', Module),
    (   is_list(Args)
    ->  Goal =.. ['&metta', Rel|Args]
    ;   current_predicate(Module:'&metta'/N),
        N >= 1,
        functor(Goal, '&metta', N),
        Goal =.. ['&metta', Rel|Args]
    ),
    clause(Module:Goal, true, Ref).

%The write-path cache. The checker runs on every '&metta' write, and the
%uncached lookup walks current_predicate over the storage arities, which
%cost register-op +2,302 inferences and made its samples drift as the
%bench's own writes created new arities [measured 2026-08-20: 42,632 to
%44,934..46,707]. One first-arg-indexed row per head fixes both. A hit
%carries the catalog clause's reference and revalidates with erased/1, so
%removing a kind or vocabulary row self-heals on the next lookup with no
%hook in the removal path; a miss is cached as a negative row, which the
%write funnel retracts when a row for that head lands. Cache writes inside
%a transaction roll back with the catalog writes they mirror, so the two
%cannot part ways.
:- dynamic metta_kind_cache/3.    %Head, Spec | none, ref(Ref) | none
:- dynamic metta_vocab_cache/3.   %Vocab, Values | none, ref(Ref) | none
:- dynamic metta_annotations_cache/2. %Ctx, Algebra
:- dynamic metta_algebra_descriptor_cache/9.
%Ctx, Name, Combine, Extend, Zero, One, Laws, Carrier, Requires
:- dynamic metta_dispatch_value_cache/4. %Function, Axis, Value | none, ref(Ref) | none
:- dynamic metta_claim_cache/4.   %Vocab, Value, Properties lists, Refs

%A compiled call can ask four dispatch axes on every recursive step. Walking
%the variadic catalog storage for each question makes the loop proportional
%to the size of the whole catalog. This cache keeps &metta authoritative: the
%value carries the exact override or default clause reference that supplied
%it, mutation callbacks forget affected keys, and a transaction rollback or
%source withdrawal self-heals through the erased-reference check.
metta_dispatch_value(Function, Axis, Value) :-
    (   metta_dispatch_value_cache(Function, Axis, Cached, Validity)
    ->  (   Validity = ref(Ref)
        ->  (   metta_catalog_ref_erased(Ref)
            ->  retractall(metta_dispatch_value_cache(Function, Axis, _, _)),
                metta_dispatch_value_fresh(Function, Axis, Value)
            ;   Value = Cached
            )
        ;   fail
        )
    ;   metta_dispatch_value_fresh(Function, Axis, Value)
    ).

metta_dispatch_value_fresh(Function, Axis, Value) :-
    (   metta_catalog_clause(['dispatch-policy', Function, Axis, Fresh], Ref)
    ->  assertz(metta_dispatch_value_cache(Function, Axis, Fresh, ref(Ref))),
        Value = Fresh
    ;   metta_catalog_clause(['dispatch-default', Axis, Fresh], Ref)
    ->  assertz(metta_dispatch_value_cache(Function, Axis, Fresh, ref(Ref))),
        Value = Fresh
    ;   assertz(metta_dispatch_value_cache(Function, Axis, none, none)),
        fail
    ).

metta_dispatch_cache_forget(Function, Axis) :-
    retractall(metta_dispatch_value_cache(Function, Axis, _, _)).

metta_dispatch_default_cache_forget(Axis) :-
    retractall(metta_dispatch_value_cache(_, Axis, _, _)).

metta_kind_spec(Head, Spec) :-
    (   metta_kind_cache(Head, Spec0, Validity)
    ->  (   Validity = ref(Ref)
        ->  (   metta_catalog_ref_erased(Ref)
            ->  retractall(metta_kind_cache(Head, _, _)),
                metta_kind_spec_fresh(Head, Spec)
            ;   Spec = Spec0
            )
        ;   fail
        )
    ;   metta_kind_spec_fresh(Head, Spec)
    ).

%A reference whose clause is gone, by property or by the reference itself
%having been collected, either way the cached row is stale.
metta_catalog_ref_erased(Ref) :-
    catch(clause_property(Ref, erased), _, true).

metta_kind_spec_fresh(Head, Spec) :-
    (   metta_catalog_clause([kind, Head|Fresh], Ref)
    ->  assertz(metta_kind_cache(Head, Fresh, ref(Ref))),
        Spec = Fresh
    ;   assertz(metta_kind_cache(Head, none, none)),
        fail
    ).

%A vocabulary's members: the row's own, then every (vocabulary-member ...) row
%a program or library registered against an open vocabulary, in the order they
%landed. The stored (vocabulary ...) ATOM never grows, which is what keeps a
%program matching it by arity working ((vocabulary delivery $a $b $c) in
%examples/ch16-events-and-standing-queries/01-event_catalog.metta is one of
%five such matches); what grows is the answer every consulting site reads,
%which is (one-of ...), (some-of ...), the claim check and metta_vocabulary_value/2.
%
%Cached like a claim rather than like a single row: the entry carries the base
%row's reference AND every member row's, and any one of them being erased
%refreshes the whole entry, so a withdrawn member self-heals on the next read.
metta_vocabulary_values(Vocab, Values) :-
    (   metta_vocab_cache(Vocab, Values0, Validity)
    ->  (   Validity = refs(Refs)
        ->  (   ( member(Ref, Refs), metta_catalog_ref_erased(Ref) )
            ->  retractall(metta_vocab_cache(Vocab, _, _)),
                metta_vocabulary_values_fresh(Vocab, Values)
            ;   Values = Values0
            )
        ;   fail
        )
    ;   metta_vocabulary_values_fresh(Vocab, Values)
    ).

metta_vocabulary_values_fresh(Vocab, Values) :-
    (   metta_catalog_clause([vocabulary, Vocab|Declared], BaseRef)
    ->  metta_registered_members(Vocab, Registered, MemberRefs),
        append(Declared, Registered, Values),
        assertz(metta_vocab_cache(Vocab, Values, refs([BaseRef|MemberRefs])))
    ;   assertz(metta_vocab_cache(Vocab, none, none)),
        fail
    ).

%The registered half, asked as a FIXED-WIDTH query so it selects the '&metta'/3
%storage predicate directly and indexes on the head rather than enumerating
%every stored arity, which is what the open-tail branch above the vocabulary
%row has to do.
metta_registered_members(Vocab, Members, Refs) :-
    findall(Member-Ref,
            metta_catalog_clause(['vocabulary-member', Vocab, Member], Ref),
            Pairs),
    pairs_keys_values(Pairs, Members, Refs).

%One value's membership, the question every consulting site asks.
metta_vocabulary_value(Vocab, Value) :-
    metta_vocabulary_values(Vocab, Values),
    memberchk(Value, Values).

%A vocabulary's MeTTa type name: the declared exception where there is one,
%and otherwise the mechanical CamelCase of the kebab name, which is the map
%extensions/python/tools/vocabgen.py applies to reach the Python and Node
%spellings. One rule and one declared exception list, so the type atom the
%engine writes below, the Python enum and the Node table cannot disagree.
%Protocol Buffers spells the same arrangement as json_name: derived by rule,
%overridden by declaration [source: https://protobuf.dev/programming-guides/proto3,
%"JSON Mapping", the json_name field option].
metta_vocabulary_type(Vocab, Type) :-
    (   metta_catalog_row(['vocabulary-type', Vocab, Declared])
    ->  Type = Declared
    ;   metta_camel_name(Vocab, Type)
    ).

%`effect-class` is `EffectClass`; a name already in CamelCase keeps its
%spelling, which is what makes `MismatchEnum` come back as itself.
metta_camel_name(Name, Camel) :-
    atomic_list_concat(Parts, -, Name),
    maplist(metta_capitalise, Parts, Capitalised),
    atomic_list_concat(Capitalised, Camel).

metta_capitalise(Part, Capitalised) :-
    atom_chars(Part, Chars),
    (   Chars = [First|Rest]
    ->  upcase_atom(First, Upper),
        atom_chars(UpperAtom, [Upper]),
        atomic_list_concat([UpperAtom|Rest], Capitalised)
    ;   Capitalised = Part
    ).

%Whether a library may add a member, and why. Absent means closed, which is
%the safe answer and the one the catalog header already gives every value set:
%a member no consumer acts on would pass the checker only to sit inert.
%Protocol Buffers' features.enum_type carries the same per-type property, and
%Rust's #[non_exhaustive] and Swift's non-frozen enums are the same decision
%stated on the type [source: https://protobuf.dev/programming-guides/enum,
%"Definitions"].
metta_vocabulary_open(Vocab, Reason) :-
    metta_catalog_row(['vocabulary-open', Vocab, Reason]).

%%%%%%%%%% The type atoms a vocabulary row implies %%%%%%%%%%
%
%`&metta` is the ENGINE's space, so the engine types the engine's own words:
%one (: <TypeName> Type) beside each (vocabulary ...) row and one
%(: <member> <TypeName>) beside each of its members. A host seat writing them
%put a seat's chosen CamelCase on the engine's vocabulary and gave the same
%set three spellings, one of which went stale (extensions/python/metta/_contract.py
%listed six semirings while the engine derived ten).
%
%A member type atom is inert against evaluation, which is tested rather than
%assumed: six of these members are engine callables or special forms, and
%(: min MemoAggregate) beside `min`'s own (-> Number Number Number) leaves
%(min 1 2), (max 1 2), (+ 1 2), (timeout 1 (+ 1 2)) and (get-type min)
%answering exactly what they answered before
%[tested: catalog_vocabulary_words:a_member_type_atom_does_not_shadow_a_callable;
%commit=7f9c810e5f4a2023ad98de34e848667dd72bc4a7].
metta_publish_vocabulary_types(Vocab) :-
    metta_vocabulary_type(Vocab, Type),
    metta_ensure_atom([':', Type, 'Type']),
    metta_vocabulary_values(Vocab, Values),
    forall(member(Value, Values), metta_ensure_atom([':', Value, Type])),
    metta_publish_vocabulary_order(Vocab).

%A row-declared chain, written as the subtype edges the engine's own widening
%reads: (vocabulary-order fidelity Exact Partial Sound) is (:< Exact Partial)
%and (:< Partial Sound), so a stronger claim stands wherever a weaker one is
%required. A member left OUT of the row is deliberately outside the chain,
%which is how `Refuse` stays a Fidelity that is not a weaker Sound.
metta_publish_vocabulary_order(Vocab) :-
    (   metta_catalog_row(['vocabulary-order', Vocab|Chain])
    ->  metta_publish_order_edges(Chain)
    ;   true
    ).

metta_publish_order_edges([Narrow, Wide|Rest]) :-
    !,
    metta_ensure_atom([':<', Narrow, Wide]),
    metta_publish_order_edges([Wide|Rest]).
metta_publish_order_edges(_).

%One registered member's type atom, written when its row lands rather than at
%boot, so a member added at runtime answers get-type like a shipped one.
metta_publish_member_type(Vocab, Member) :-
    metta_vocabulary_type(Vocab, Type),
    metta_ensure_atom([':', Member, Type]).

metta_retract_member_type(Vocab, Member) :-
    metta_vocabulary_type(Vocab, Type),
    metta_forget_atom([':', Member, Type]).

%Everything a vocabulary row published, withdrawn with it. Removing by the
%EXACT atom is what keeps a member shared between two vocabularies typed by
%the other: dropping the op-kind row leaves (: det Determinism) standing.
metta_retract_vocabulary_types(Vocab, Values) :-
    metta_vocabulary_type(Vocab, Type),
    (   metta_catalog_row(['vocabulary-order', Vocab|Chain])
    ->  metta_retract_order_edges(Chain)
    ;   true
    ),
    metta_retract_types_under(Type, Values).

metta_retract_types_under(Type, Values) :-
    forall(member(Value, Values), metta_forget_atom([':', Value, Type])),
    metta_forget_atom([':', Type, 'Type']).

metta_retract_order_edges([Narrow, Wide|Rest]) :-
    !,
    metta_forget_atom([':<', Narrow, Wide]),
    metta_retract_order_edges([Wide|Rest]).
metta_retract_order_edges(_).

%Idempotent because a vocabulary shares members with a sibling and because a
%re-consulted engine meets its own atoms: (: det OpKind) and (: det Determinism)
%are two atoms, while publishing `det` twice under one name would be a
%duplicate declaration the engine warns about and keeps anyway.
%
%Silent until the engine is loaded, for the same reason
%metta_publish_builtin_visibility runs late: a (: ...) write reaches
%self_tier_arrived/1, whose metta_exec_module_known/2 lives in
%engine/spaces/lifecycle.pl and does not exist yet while THIS file's own
%preset directive is running. Everything written before the flag is typed in
%one pass by metta_publish_every_vocabulary_type/0; everything after it, as
%it lands.
metta_ensure_atom(Atom) :-
    (   \+ metta_vocabulary_types_published
    ->  true
    ;   metta_catalog_row(Atom)
    ->  true
    ;   add_sexp('&metta', Atom, _)
    ).

metta_forget_atom(Atom) :-
    (   metta_vocabulary_types_published
    ->  metta_remove_atom('&metta', Atom, _)
    ;   true
    ).

:- dynamic metta_vocabulary_types_published/0.

%An (algebra ...) row IS the door a program has into the semiring vocabulary,
%so the engine walks through it on the author's behalf rather than asking for
%a second row. Before this, the vocabulary was derived from the shipped
%presets once and frozen: a declared algebra was refused
%(claim semiring <name> ordered ascending) with "argument 2 expects a value of
%the vocabulary", so its ordering could never be stated and
%metta_annotations_order/2 could never see it
%[tested: catalog_vocabulary_words:a_declared_algebra_joins_the_semiring_vocabulary;
%commit=7f9c810e5f4a2023ad98de34e848667dd72bc4a7].
metta_register_semiring(Name) :-
    (   metta_vocabulary_value(semiring, Name)
    ->  true
    ;   add_sexp('&metta', ['vocabulary-member', semiring, Name], _)
    ).

%The membership leaves with the LAST row that named the algebra: two contexts
%may declare the same name, and the vocabulary is global.
metta_unregister_semiring(Name) :-
    (   metta_catalog_row([algebra, Name|_])
    ->  true
    ;   metta_remove_atom('&metta', ['vocabulary-member', semiring, Name], _)
    ).

%Every vocabulary row typed in one pass, run from engine/metta.pl's
%initialization beside metta_publish_builtin_visibility so the whole engine
%is loaded first. The flag goes up BEFORE the walk, which is what makes the
%walk itself write anything, and it stays up so a vocabulary a program
%declares later is typed as its row lands.
metta_publish_every_vocabulary_type :-
    (   metta_vocabulary_types_published
    ->  true
    ;   assertz(metta_vocabulary_types_published)
    ),
    findall(Vocab, metta_catalog_row([vocabulary, Vocab|_]), Vocabs0),
    sort(Vocabs0, Vocabs),
    forall(member(Vocab, Vocabs), metta_publish_vocabulary_types(Vocab)).


%Every (claim Vocab Value Property...) row's properties for one value, cached.
%
%A claim row carries ANY number of properties, so the query that reads one has
%an open tail, and an open-tail catalog read is the branch that enumerates every
%'&metta' storage arity rather than selecting a predicate by width. That is the
%design 2026-09-05 settled after rejecting both a membership walk and an index
%build on measurements, and it is fine for a question nobody asks in a loop.
%This one IS asked in a loop: metta_annotations_order/2 consults it once per
%answer, so a `(top k ...)` evaluation made fifteen open-tail reads at 73
%inferences each, 1,095 of that workload's 1,756 inferences per evaluation
%[measured 2026-09-07: instrumenting the open-tail branch over ten evaluations
%counted 150 reads, all of them claim rows; commit=6b4dceb61ccc78e308e6678af58f8daf43c31523].
%
%Cached exactly as a vocabulary's values are: the answer carries the clause
%references it was built from and revalidates with erased/1, so a REMOVED row
%self-heals on the next read with no hook. Unlike a vocabulary there may be
%several rows per value, so the entry carries several references and any one of
%them being erased refreshes the whole entry. The empty answer is cached too,
%which makes a value that claims nothing one indexed probe instead of the walk,
%and that negative row is what metta_catalog_note_added/1 has to retract when a
%claim lands.
metta_value_claims(Vocab, Value, Claims) :-
    (   metta_claim_cache(Vocab, Value, Cached, Refs),
        \+ ( member(Ref, Refs), metta_catalog_ref_erased(Ref) )
    ->  Claims = Cached
    ;   retractall(metta_claim_cache(Vocab, Value, _, _)),
        metta_value_claims_fresh(Vocab, Value, Claims)
    ).

metta_value_claims_fresh(Vocab, Value, Claims) :-
    findall(Properties-Ref,
            metta_catalog_clause([claim, Vocab, Value|Properties], Ref),
            Pairs),
    pairs_keys_values(Pairs, Claims, Refs),
    assertz(metta_claim_cache(Vocab, Value, Claims, Refs)).

%The compatibility projection lives beside the vocabulary it projects into.
%pure=true and the old immutable spelling mean pureStructural; stable means
%readOnlyLookup; volatile means oracleIO. The first clause keeps every
%canonical value data-driven from the catalog, so adding an alias cannot make
%it a sixth public EffectClass member.
%[tested:
%effects_lattice:legacy_effect_spellings_map_but_cannot_enter_the_canonical_catalog;
%commit=d74e2e828cd9272882dcf907cfaf095d2d147ce0]
metta_effect_class_canonical(Value, Canonical) :-
    nonvar(Value),
    !,
    (   metta_vocabulary_value('effect-class', Value)
    ->  Canonical = Value
    ;   metta_legacy_effect_class(Value, Canonical)
    ).
metta_effect_class_canonical(Canonical, Canonical) :-
    metta_vocabulary_values('effect-class', Values),
    member(Canonical, Values).

metta_legacy_effect_class(immutable, pureStructural).
metta_legacy_effect_class(stable, readOnlyLookup).
metta_legacy_effect_class(volatile, oracleIO).

%The determinism vocabulary resolved the same way its effect-class sibling is,
%and for the same reason: the canonical members come from the catalog row, so
%adding one there reaches the arrow reader without a second edit, and a long
%spelling maps IN without becoming a fourth public member.
%
%metta_arrow_type_shape/5 read its effect class through the canonicaliser above
%while deciding its CARDINALITY from a literal list repeated in both of its
%branches. One predicate, two ownership rules; the policy-inventory lane names
%a closed list with no owner, and it named these two
%[tested: metta_arrow_projection:the_long_determinism_spellings_map_to_the_catalog_members;
%commit=8fdcfd754d0916544667751e0c959a2f113f96f0].
metta_determinism_canonical(Value, Canonical) :-
    nonvar(Value),
    !,
    (   metta_vocabulary_value(determinism, Value)
    ->  Canonical = Value
    ;   metta_long_determinism(Value, Canonical)
    ).
metta_determinism_canonical(Canonical, Canonical) :-
    metta_vocabulary_values(determinism, Values),
    member(Canonical, Values).

metta_long_determinism(deterministic, det).
metta_long_determinism(semideterministic, semidet).
metta_long_determinism(nondeterministic, nondet).

%The positional walk. Position counts declaration arguments from 1, the way
%the refusal prints them; the Expected a refusal carries is the argspec as
%declared, so the message shows the row's own words.
metta_check_positions([], [], _, _) :- !.
metta_check_positions([], [Spec|Rest], Position, Term) :-
    !,
    (   forall(member(S, [Spec|Rest]), metta_spec_omittable(S))
    ->  true
    ;   metta_declaration_refused(Term, Position, Spec)
    ).
metta_check_positions([_|_], [], Position, Term) :-
    !,
    metta_declaration_refused(Term, Position, 'no further argument').
metta_check_positions(Args, [[rest, Spec]], Position, Term) :-
    !,
    metta_check_rest(Args, Spec, Position, Term).
metta_check_positions([Arg|Args], [[optional, Spec]|Rest], Position, Term) :-
    !,
    metta_check_value(Arg, Spec, Position, Term),
    Next is Position + 1,
    metta_check_positions(Args, Rest, Next, Term).
metta_check_positions([Arg|Args], [Spec|Rest], Position, Term) :-
    metta_check_value(Arg, Spec, Position, Term),
    Next is Position + 1,
    metta_check_positions(Args, Rest, Next, Term).

metta_check_rest([], _, _, _).
metta_check_rest([Arg|Args], Spec, Position, Term) :-
    metta_check_value(Arg, Spec, Position, Term),
    Next is Position + 1,
    metta_check_rest(Args, Spec, Next, Term).

metta_spec_omittable([optional, _]).
metta_spec_omittable([rest, _]).

metta_check_value(Arg, symbol, Position, Term) :-
    !,
    (   atom(Arg) -> true ; metta_declaration_refused(Term, Position, symbol) ).
metta_check_value(Arg, integer, Position, Term) :-
    !,
    (   integer(Arg) -> true ; metta_declaration_refused(Term, Position, integer) ).
metta_check_value(_, pattern, _, _) :- !.
metta_check_value(_, term, _, _) :- !.
metta_check_value(Arg, ['one-of', Vocab], Position, Term) :-
    !,
    (   atom(Arg),
        metta_vocabulary_values(Vocab, Values),
        memberchk(Arg, Values)
    ->  true
    ;   metta_declaration_refused(Term, Position, ['one-of', Vocab])
    ).
metta_check_value(Arg, ['some-of', Vocab], Position, Term) :-
    !,
    (   metta_policy_members(Vocab, Arg, _)
    ->  true
    ;   metta_declaration_refused(Term, Position, ['some-of', Vocab])
    ).
metta_check_value(_, Spec, Position, Term) :-
    metta_declaration_refused(Term, Position, Spec).

%The members a (some-of Vocab) argument names, each a bare word or [Word|Args]
%with the arguments the word's `takes` claim declares. One argument reads
%three ways and the claims decide between them: a word is one member; an
%expression whose head is a word claimed to take exactly the arguments that
%follow it is one APPLIED member, so (lattice join) is not the pair of words
%lattice and join; anything else is a list, every element read the same way.
%A word with a `takes` claim never stands bare and a word claimed `alone`
%never shares a list, so (cache f lattice) and (cache f (force monotonic))
%are refused at the door rather than read as half a policy.
metta_policy_members(Vocab, Arg, [Member]) :-
    metta_policy_member(Vocab, Arg, Member),
    !.
metta_policy_members(Vocab, Args, Members) :-
    is_list(Args),
    Args \== [],
    maplist(metta_policy_member(Vocab), Args, Members),
    \+ ( Members = [_, _|_],
         member(Member, Members),
         metta_policy_member_word(Member, Word),
         metta_catalog_row([claim, Vocab, Word, alone]) ).

metta_policy_member(Vocab, Word, Word) :-
    atom(Word),
    metta_vocabulary_value(Vocab, Word),
    \+ metta_catalog_row([claim, Vocab, Word, takes|_]).
metta_policy_member(Vocab, [Word|Args], [Word|Args]) :-
    atom(Word),
    metta_vocabulary_value(Vocab, Word),
    metta_catalog_row([claim, Vocab, Word, takes|Specs]),
    is_list(Args),
    same_length(Specs, Args),
    maplist(metta_policy_argument, Specs, Args).

metta_policy_argument(symbol, Arg) :- atom(Arg).
metta_policy_argument(integer, Arg) :- integer(Arg).

metta_policy_member_word([Word|_], Word) :- !.
metta_policy_member_word(Word, Word).

%kind and claim rows carry meaning past their shape, and the checker owns
%their language, so their adds get the deeper walk: a kind's argspecs must
%be well-formed with optional confined to the tail and rest final, and a
%claim must name a declared vocabulary and one of its values. Everything
%else was already covered by the positional walk.
metta_check_catalog_semantics(kind, [KindHead|Spec], Term) :-
    !,
    (   metta_kind_spec(KindHead, _)
    ->  metta_declaration_refused(Term, 1,
                                  'one kind row per head; remove the old row first')
    ;   true
    ),
    metta_check_argspecs(Spec, 2, Term),
    %A head already routed by shape keeps routable: redeclaring its kind
    %(remove, then add) with a spec the route cannot dispatch would leave a
    %standing routed-by-shape row over an unroutable shape, so the unfit
    %spec is refused here rather than discovered as dead routing.
    (   metta_routed_head(KindHead, Key)
    ->  metta_check_route_fit(Key, Spec, Term)
    ;   true
    ).
metta_check_catalog_semantics('routed-by-shape', [Head|KeyArgs], Term) :-
    !,
    (   KeyArgs == []
    ->  Key = context
    ;   KeyArgs = [Key]
    ),
    (   metta_kind_spec(Head, Spec)
    ->  metta_check_route_fit(Key, Spec, Term)
    ;   metta_declaration_refused(Term, 1,
                                  'a kind row for the routed head, declared first')
    ).
%The marked head must already have a kind row starting at symbol, because the
%retirement walk treats position 1 as the owning space and a kind whose first
%argument is something else (a vocabulary name, a pattern) would have rows
%deleted by whichever space happened to be spelled the same. Refused at the
%write, where the remedy is one line, rather than discovered as rows that
%vanish on an unrelated drop.
metta_check_catalog_semantics('owned-by-space', [Head|_], Term) :-
    !,
    (   metta_kind_spec(Head, [symbol|_])
    ->  true
    ;   metta_declaration_refused(Term, 1,
            'a head whose kind row starts at the owning space: \c
             (kind <head> symbol ...), declared first')
    ).
metta_check_catalog_semantics(vocabulary, [Name|_], Term) :-
    !,
    (   metta_vocabulary_values(Name, _)
    ->  metta_declaration_refused(Term, 1,
                                  'one vocabulary row per name; remove the old row first')
    ;   metta_vocabulary_type(Name, Type),
        metta_type_name_free(Name, Type, 1, Term)
    ).
%The type name is what a program writes in an arrow and what each seat's enum
%is called, so two vocabularies resolving to one name would give two closed
%sets one type. Refused at the write, where the remedy is one row, rather than
%discovered as a (: value X) atom whose X means two things.
metta_check_catalog_semantics('vocabulary-type', [Name, Type], Term) :-
    !,
    (   \+ metta_vocabulary_values(Name, _)
    ->  metta_declaration_refused(Term, 1, 'a declared vocabulary')
    ;   metta_catalog_row(['vocabulary-type', Name, _])
    ->  metta_declaration_refused(Term, 1,
            'one vocabulary-type row per vocabulary; remove the old row first')
    ;   metta_type_name_free(Name, Type, 2, Term)
    ).
%The chain the engine writes as (:< ...) edges. Every word in it is a member
%of the vocabulary it orders, and a chain of one names no edge at all, so both
%are refused here rather than published as nothing.
metta_check_catalog_semantics('vocabulary-order', [Name|Chain], Term) :-
    !,
    (   \+ metta_vocabulary_values(Name, _)
    ->  metta_declaration_refused(Term, 1, 'a declared vocabulary')
    ;   metta_catalog_row(['vocabulary-order', Name|_])
    ->  metta_declaration_refused(Term, 1,
            'one vocabulary-order row per vocabulary; remove the old row first')
    ;   Chain = [_, _|_]
    ->  metta_check_order_members(Name, Chain, 2, Term)
    ;   metta_declaration_refused(Term, 2,
            'at least two members, narrowest first: a chain of one has no edge')
    ).
%The reason is load-bearing: this row is what admits a member into an engine
%vocabulary, and an author reading a refused (vocabulary-member ...) is told
%to write one, so it has to say why the set opens rather than merely that it
%does.
metta_check_catalog_semantics('vocabulary-open', [Name, Reason], Term) :-
    !,
    (   \+ metta_vocabulary_values(Name, _)
    ->  metta_declaration_refused(Term, 1, 'a declared vocabulary')
    ;   metta_catalog_row(['vocabulary-open', Name, _])
    ->  metta_declaration_refused(Term, 1,
            'one vocabulary-open row per vocabulary; remove the old row first')
    ;   ( string(Reason), Reason \== "" )
    ->  true
    ;   metta_declaration_refused(Term, 2,
            'a nonempty string saying why the set is open')
    ).
%The one door a program or library has into an engine vocabulary. Open rows
%admit; closed rows refuse with the row and the property named, because the
%author's next move is either to open the vocabulary deliberately or to
%declare one of their own, and neither is guessable from "not a member".
metta_check_catalog_semantics('vocabulary-member', [Name, Member], Term) :-
    !,
    (   \+ metta_vocabulary_values(Name, _)
    ->  metta_declaration_refused(Term, 1, 'a declared vocabulary')
    ;   metta_vocabulary_value(Name, Member)
    ->  metta_declaration_refused(Term, 2,
                                  'a word the vocabulary does not already carry')
    ;   metta_vocabulary_open(Name, _)
    ->  true
    ;   format(atom(Remedy),
               'an open vocabulary: ~w is closed, so add \c
                (vocabulary-open ~w "<why it opens>") to &metta first, or \c
                declare a vocabulary of your own',
               [Name, Name]),
        metta_declaration_refused(Term, 1, Remedy)
    ).
%One row per tag, because a tag is one claim about one payload and a second
%row would let the shim's encoder and its decoder read different grammars.
metta_check_catalog_semantics('wire-tag', [Tag, _, _, Means], Term) :-
    !,
    (   metta_catalog_row(['wire-tag', Tag, _, _, _])
    ->  metta_declaration_refused(Term, 1,
                                  'one wire-tag row per tag; remove the old row first')
    ;   ( string(Means), Means \== "" )
    ->  true
    ;   metta_declaration_refused(Term, 4,
            'a nonempty string saying what the tag carries')
    ).
metta_check_catalog_semantics(policy, [Axis|_], Term) :-
    !,
    (   metta_catalog_row([policy, Axis, _, _])
    ->  metta_declaration_refused(Term, 1,
                                  'one policy row per axis; remove the old row first')
    ;   true
    ).
metta_check_catalog_semantics(claim, [Vocab, Value|_], Term) :-
    !,
    (   metta_vocabulary_values(Vocab, Values)
    ->  (   memberchk(Value, Values)
        ->  true
        ;   metta_declaration_refused(Term, 2, 'a value of the vocabulary')
        )
    ;   metta_declaration_refused(Term, 1, 'a declared vocabulary')
    ).
metta_check_catalog_semantics(algebra,
                              [Name, Combine, Extend, Zero, One,
                               Laws, Carrier, Requires, Owner],
                              Term) :-
    !,
    (   metta_catalog_row([algebra, Name, _, _, _, _, _, _, _, Owner])
    ->  metta_declaration_refused(
            Term, 1,
            'one algebra row per context and name; remove the old row first')
    ;   true
    ),
    metta_check_algebra_fields(Name, Combine, Extend, Zero, One,
                               Laws, Carrier, Requires, Term).

metta_check_catalog_semantics(annotations, [Ctx, Algebra|CapabilityArgs], Term) :-
    !,
    metta_declared_algebra_requirements(Ctx, Algebra, Required, Term),
    metta_annotation_capabilities(CapabilityArgs, Capabilities, Term),
    (   member(Requirement, Required),
        \+ memberchk(Requirement, Capabilities)
    ->  metta_algebra_requirement_refusal(Ctx, Algebra, Requirement)
    ;   true
    ).
metta_check_catalog_semantics(cache, [Function, _], Term) :-
    !,
    (   metta_catalog_row([cache, Function, _])
    ->  metta_declaration_refused(
            Term, 1, 'one cache row per function; remove the old row first')
    ;   true
    ).
%A cost row's witness is a CALL with exactly one size hole, because the lane
%that checks it substitutes a ladder of sizes for that hole and fits the
%inference counts against the declared class. Zero holes leaves nothing to
%vary and two leaves the lane no way to say which one the class is in, so
%both are refused here rather than discovered as a row nothing can measure.
%Repeated occurrences of ONE hole are a hole: (intersection-atom $n $n) sizes
%both arguments together, which is one ladder and one class.
%
%One row per head, the rule the cache row above keeps for the same reason: a
%head with two classes has no class, and the remedy is the removal rather
%than a silent last-writer-wins. A head whose two call shapes really do cost
%differently declares the witness that matters.
metta_check_catalog_semantics(cost, [Witness|_], Term) :-
    !,
    %The condition names its own variable: Head below is introduced after the
    %if-then-else, and a variable bound inside the condition and read after it
    %is what SWI's "not introduced in all branches" warning names.
    (   nonvar(Witness), Witness = [Head0|_], atom(Head0)
    ->  true
    ;   metta_declaration_refused(
            Term, 1, 'a call whose head is a function name, as in (nrev $n)')
    ),
    (   term_variables(Witness, [_])
    ->  true
    ;   metta_declaration_refused(
            Term, 1, 'a call naming exactly one size hole $n')
    ),
    Witness = [Head|_],
    (   metta_cost_row(Head, _, _, _)
    ->  metta_declaration_refused(
            Term, 1,
            'one cost row per head; remove-atom the standing row to declare another')
    ;   true
    ).

metta_check_catalog_semantics('dispatch-default', [Axis, Value], Term) :-
    !,
    metta_check_dispatch_value(Axis, Value, Term),
    (   metta_catalog_row(['dispatch-default', Axis, _])
    ->  metta_declaration_refused(Term, 1,
                                  'one default per dispatch axis; remove the old row first')
    ;   true
    ).
metta_check_catalog_semantics('dispatch-policy', [Function, Axis, Value], Term) :-
    !,
    metta_check_dispatch_value(Axis, Value, Term),
    (   metta_catalog_row(['dispatch-policy', Function, Axis, _])
    ->  metta_declaration_refused(Term, 2,
                                  'one override per function and dispatch axis; remove the old row first')
    ;   true
    ).
%A compensation is useful only for an operation whose successful answer leaves
%a saga receipt. The receipt threshold and this declaration threshold are the
%same rank comparison, so a row cannot promise recovery for work the runner
%will never journal. A recovery takes exactly the one quoted receipt the runner
%passes. Host-operation rows record that MeTTa arity directly; a compiled
%function records one more Prolog argument for its answer.
metta_check_catalog_semantics(compensates,
                              [Operation, Compensation], Term) :-
    !,
    metta_require_saga_effect(Operation, Term),
    (   metta_saga_operation_callable(Operation)
    ->  true
    ;   metta_declaration_refused(
            Term, 1,
            'a registered host operation, native operation, or compiled MeTTa function')
    ),
    (   metta_saga_compensation_callable(Compensation)
    ->  true
    ;   metta_declaration_refused(
            Term, 2,
            'a registered host operation or compiled MeTTa function taking exactly one receipt')
    ),
    (   metta_catalog_row([compensates, Operation, _])
    ->  metta_declaration_refused(
            Term, 1,
            'one compensation per operation; remove the old row first')
    ;   true
    ).

%A standing query is a PROMISE about the watched context, so it is checked
%against what that context declares it can deliver, here at the catalog
%door every '&metta' write already passes rather than at one host's
%subscribe method. (subscription ...) is the reflection atom every
%subscription writes before it activates and (on ...) is a declared
%reaction, and both hear a context only through its change events, so a
%context with no (events ...) capability refuses both, naming what is
%missing. One authority, one door, every host: a MeTTa program adding the
%atom by hand is refused exactly as the Python surface is
%[tested: test_a_context_that_declares_events_serves_them_and_one_that_does_not_refuses].
metta_check_catalog_semantics(events, [Ctx|_], _) :-
    !,
    (   atom(Ctx), \+ metta_events_declared(Ctx)
    ->  assertz(metta_events_declared(Ctx))
    ;   true
    ).
metta_check_catalog_semantics(subscription, [Ctx|_], _) :-
    !,
    metta_require_events(Ctx, 'be subscribed to').
%A reaction row installs the write hook it needs, the way a capacity row
%installs its admission counter. It was the one declaration whose side effect
%stayed on the HOST: every binding had to call metta_install_bridges/0 after
%writing the row, the Python seat does it inside a goal string, and a binding
%whose Prolog is statically checked could not do it at all. Doing it here makes
%the row self-sufficient in every seat and takes an engine internal off the
%host-service floor rather than adding one to it.
%
%HERE and not in metta_catalog_note_added/1, for the reason the events flag
%above is here: that walk takes a LIST, so a clause added to it is one
%inference on every '&metta' write, measured at +10 on the identity twin's
%pinned budget. This dispatches on the head atom, so a clause for one head
%costs the other heads nothing.
%
%Before the row lands rather than after, which is what this pass is, and that
%is sound: the hook reads reaction rows when it FIRES, so installing it for a
%row whose store then failed leaves an idempotent hook that finds nothing. The
%measured property is unchanged because the TRIGGER is unchanged -- bridges
%install when a reaction is declared and not before, so an engine with no
%reaction keeps the direct write path and its cost.
metta_check_catalog_semantics(on, [Ctx|_], _) :-
    !,
    metta_require_events(Ctx, 'carry a reaction'),
    metta_install_bridges.
metta_check_catalog_semantics(_, _, _).
%One head's standing cost row, at either width: the measure field is optional
%and reads `none` when it was left out, which is the case the engine resolves
%from the head's arrow. Enumerating over the witness rather than indexing on
%the head is what the row's shape allows, and there are as many rows as there
%are declared heads.
metta_cost_row(Head, Witness, Class, Measure) :-
    (   metta_catalog_row([cost, Witness, Class, Measure])
    ;   metta_catalog_row([cost, Witness, Class]),
        Measure = none
    ),
    nonvar(Witness),
    Witness = [Head|_],
    atom(Head).

metta_check_algebra_fields(Name, Combine, Extend, Zero, One,
                           Laws, Carrier, Requires, Term) :-
    metta_algebra_list_field(Laws, laws, Term, 6),
    metta_algebra_carrier_field(Carrier, Term),
    metta_algebra_list_field(Requires, requires, Term, 8),
    metta_require_algebra_value(Name, Carrier, Zero),
    metta_require_algebra_value(Name, Carrier, One),
    metta_algebra_carrier_parts(Carrier, _, Values),
    forall(member(Value, Values), metta_require_algebra_value(Name, Carrier, Value)),
    metta_check_algebra_laws(Name, Combine, Extend, Zero, One,
                             Laws, Carrier, Term).

metta_require_saga_effect(Operation, Term) :-
    metta_operation_effect(Operation, Effect),
    !,
    metta_effect_rank(Effect, Rank),
    metta_effect_rank(writesState, ReceiptRank),
    (   Rank >= ReceiptRank
    ->  true
    ;   metta_declaration_refused(
            Term, 1,
            'an operation ranked writesState or oracleIO, because weaker operations leave no saga receipt')
    ).
metta_require_saga_effect(_, Term) :-
    metta_declaration_refused(
        Term, 1, 'an operation with a declared effect class'),
    fail.

metta_saga_operation_callable(Name) :-
    metta_catalog_row([op, Name, _, _]),
    !.
metta_saga_operation_callable(Name) :-
    builtin_fun(Name),
    !.
metta_saga_operation_callable(Name) :-
    fun(Name),
    metta_ensure_compiled(Name),
    arity(Name, Arity),
    Arity > 0.

metta_saga_compensation_callable(Name) :-
    metta_catalog_row([op, Name, 1, _]),
    !.
metta_saga_compensation_callable(Name) :-
    fun(Name),
    metta_ensure_compiled(Name),
    arity(Name, 2).

metta_declared_algebra_requirements(Ctx, Algebra, Required, _) :-
    metta_catalog_row([algebra, Algebra, _, _, _, _, _, _,
                       [requires|Required], Ctx]),
    !.
metta_declared_algebra_requirements(_, Algebra, Required, _) :-
    metta_catalog_row([algebra, Algebra, _, _, _, _, _, _,
                       [requires|Required], global]),
    !.
metta_declared_algebra_requirements(_, _, _, Term) :-
    metta_declaration_refused(Term, 2, 'a declared algebra').

metta_algebra_list_field([Head|Values], Head, _, _) :-
    atom(Head),
    maplist(atom, Values),
    !.
metta_algebra_list_field(_, Head, Term, Position) :-
    metta_declaration_refused(Term, Position, [Head, '... symbols']).

metta_algebra_carrier_field([type, Type, Carrier], Term) :-
    !,
    (   ground(Type), (atom(Type) ; is_list(Type) ; seam:host_object(Type))
    ->  metta_algebra_carrier_field(Carrier, Term),
        ( Carrier = [carrier|_] -> true
        ; metta_declaration_refused(Term, 7, [type, 'Type', [carrier, '... finite values']]) )
    ;   metta_declaration_refused(Term, 7, 'a ground type or grounded membership predicate')
    ).
metta_algebra_carrier_field([carrier|Values], Term) :-
    !,
    (   maplist(ground, Values)
    ->  true
    ;   metta_declaration_refused(Term, 7, [carrier, '... ground atoms'])
    ).
metta_algebra_carrier_field(_, Term) :-
    metta_declaration_refused(Term, 7, [carrier, '... atoms']).

% A type is a membership relation; a finite enumeration additionally bounds
% the domain over which a law can be checked by exhaustion.
metta_algebra_carrier_parts([carrier|Values], none, Values).
metta_algebra_carrier_parts([type, Type, [carrier|Values]], some(Type), Values).

metta_require_algebra_value(_, [carrier], _) :- !.
metta_require_algebra_value(Name, Carrier, Value) :-
    metta_algebra_carrier_parts(Carrier, Type, Values),
    (   ground(Value),
        metta_algebra_type_admits(Type, Value),
        ( Values == []
        ; member(Member, Values), metta_algebra_equal(Value, Member) )
    ->  true
    ;   throw(error(metta_algebra_value_outside_carrier(Name, Value, Carrier), none))
    ).

metta_algebra_type_admits(none, _).
metta_algebra_type_admits(some(Type), Value) :-
    (   seam:host_object(Type)
    ->  (   once(seam:grounded_algebra_type(Type, Value, Answer))
        ->  Answers = [Answer]
        ;   once(findnsols(2, Answer, eval([Type, Value], Answer), Answers))
        ),
        (   Answers == [true] -> true
        ;   Answers == [false] -> fail
        ;   throw(error(metta_algebra_type_predicate(Type, Answers), none))
        )
    ;   current_metta_module(Module),
        type_witness_in(Module, Value, Type)
    ).

prolog:error_message(metta_algebra_value_outside_carrier(Name, Value, Carrier)) -->
    [ 'algebra_value_outside_carrier: ~w value ~w is outside ~w; provide a value of the declared type or finite carrier, or declare the intended type'-
      [Name, Value, Carrier] ].
prolog:error_message(metta_algebra_type_predicate(Type, Answers)) -->
    [ 'algebra_type_predicate: ~w must answer one bool, not ~w; use a predicate returning exactly True or False'-
      [Type, Answers] ].

%A public law is a certificate, not a planner hint. User rows therefore name
%only this vocabulary and supply a finite carrier for every equation; shipped
%rows are trusted data presets whose laws are proved by their source modules.
metta_algebra_equational_law('combine-associative').
metta_algebra_equational_law('combine-commutative').
metta_algebra_equational_law('extend-associative').
metta_algebra_equational_law('extend-commutative').
metta_algebra_equational_law('left-distributive').
metta_algebra_equational_law('right-distributive').
metta_algebra_equational_law('combine-idempotent').
metta_algebra_equational_law('combine-zero-identity').
metta_algebra_equational_law('extend-one-identity').
metta_algebra_equational_law('extend-zero-annihilates').

metta_algebra_law_alias(associative,
                        ['combine-associative', 'extend-associative']).
metta_algebra_law_alias(commutative, ['combine-commutative']).
metta_algebra_law_alias(distributive,
                        ['left-distributive', 'right-distributive']).
metta_algebra_law_alias(idempotent, ['combine-idempotent']).
metta_algebra_law_alias(contraction, [contraction]).
%The property-test vocabulary Hypothesis's ghostwriter spells for a binary
%operation, `identity` and `distributes_over`, as aliases over the same
%equational laws the checker already decides: a semiring's two identities are
%its zero under combine and its one under extend, and extend distributing over
%combine is the two-sided law `distributive` already names. Both spellings stay
%reachable; the ghostwriter's is what a generated property test is named by.
metta_algebra_law_alias(identity,
                        ['combine-zero-identity', 'extend-one-identity']).
metta_algebra_law_alias('distributes-over',
                        ['left-distributive', 'right-distributive']).

%The two laws a carrier owes the SEAM rather than its operations, and which
%only a host can check: `roundtrip`, every carrier value survives projection
%through the engine and back, and `equivalent`, each operation agrees with its
%reference twin on the host. Known here so a declaration may name them, and
%never equational, so the engine's finite-carrier checker leaves them to the
%host's property tests exactly as it leaves `contraction` to the capability
%it names.
metta_algebra_seam_law(roundtrip).
metta_algebra_seam_law(equivalent).

metta_algebra_known_law(contraction).
metta_algebra_known_law(Law) :- metta_algebra_seam_law(Law).
metta_algebra_known_law(Law) :- metta_algebra_equational_law(Law).
metta_algebra_known_law(Law) :- metta_algebra_law_alias(Law, _).

metta_algebra_law_expansion(Law, Expansion) :-
    metta_algebra_law_alias(Law, Expansion), !.
metta_algebra_law_expansion(Law, [Law]).

metta_algebra_law_vocabulary(Laws) :-
    findall(Law, metta_algebra_equational_law(Law), Equational),
    findall(Law, metta_algebra_seam_law(Law), Seam),
    findall(Alias, metta_algebra_law_alias(Alias, _), Aliases),
    append([Equational, [contraction], Seam, Aliases], All),
    list_to_set(All, Laws).

metta_check_algebra_laws(Name, Combine, Extend, Zero, One,
                         [laws|Laws], CarrierField, Term) :-
    metta_algebra_carrier_parts(CarrierField, Type, Carrier),
    (   Type = some(_), Carrier == [], Laws \== []
    ->  throw(error(metta_algebra_law_uncheckable(Name, Laws,
                                                  finite_carrier_required), none))
    ;   true
    ),
    (   member(Unknown, Laws),
        \+ metta_algebra_known_law(Unknown)
    ->  throw(error(metta_algebra_law_unknown(Name, Unknown), none))
    ;   true
    ),
    findall(Equation,
            ( member(Law, Laws),
              metta_algebra_law_expansion(Law, Expansion),
              member(Equation, Expansion),
              metta_algebra_equational_law(Equation) ), Equational0),
    list_to_set(Equational0, Equational),
    (   Equational == []
    ->  true
    ;   Carrier == [],
        \+ metta_catalog_preset(Term)
    ->  throw(error(metta_algebra_law_uncheckable(Name, Equational,
                                                  finite_carrier_required),
                    none))
    ;   Carrier == []
    ->  true
    ;   metta_check_algebra_closure(Name, Combine, Extend, CarrierField, Carrier),
        forall(member(Law, Equational),
               metta_check_algebra_law(Name, Combine, Extend, Zero, One,
                                       CarrierField, Carrier, Law))
    ).

metta_check_algebra_closure(Name, Combine, Extend, CarrierField, Carrier) :-
    forall(( member(Operation, [Combine, Extend]),
             member(A, Carrier), member(B, Carrier) ),
           ( metta_apply_algebra_operation(Name, Operation, A, B, Result),
             (   member(Candidate, Carrier),
                 metta_algebra_equal(Result, Candidate)
             ->  true
             ;   throw(error(metta_algebra_carrier_not_closed(
                                 Name, Operation, A, B, Result), none))
             ),
             metta_require_algebra_value(Name, CarrierField, Result) )).

metta_algebra_apply(Name, CarrierField, Operation, A, B, Result) :-
    metta_require_algebra_value(Name, CarrierField, A),
    metta_require_algebra_value(Name, CarrierField, B),
    metta_apply_algebra_operation(Name, Operation, A, B, Result),
    metta_require_algebra_value(Name, CarrierField, Result).

metta_check_algebra_law(Name, Combine, _, _, _, CarrierField, Carrier,
                        'combine-associative') :- !,
    forall(( member(A, Carrier), member(B, Carrier), member(C, Carrier) ),
           ( metta_algebra_apply(Name, CarrierField, Combine, A, B, AB),
             metta_algebra_apply(Name, CarrierField, Combine, AB, C, Left),
             metta_algebra_apply(Name, CarrierField, Combine, B, C, BC),
             metta_algebra_apply(Name, CarrierField, Combine, A, BC, Right),
             metta_require_algebra_equal(Name, 'combine-associative',
                                         [A,B,C], Left, Right) )).
metta_check_algebra_law(Name, Combine, _, _, _, CarrierField, Carrier,
                        'combine-commutative') :- !,
    forall(( member(A, Carrier), member(B, Carrier) ),
           ( metta_algebra_apply(Name, CarrierField, Combine, A, B, Left),
             metta_algebra_apply(Name, CarrierField, Combine, B, A, Right),
             metta_require_algebra_equal(Name, 'combine-commutative',
                                         [A,B], Left, Right) )).
metta_check_algebra_law(Name, _, Extend, _, _, CarrierField, Carrier,
                        'extend-associative') :- !,
    forall(( member(A, Carrier), member(B, Carrier), member(C, Carrier) ),
           ( metta_algebra_apply(Name, CarrierField, Extend, A, B, AB),
             metta_algebra_apply(Name, CarrierField, Extend, AB, C, Left),
             metta_algebra_apply(Name, CarrierField, Extend, B, C, BC),
             metta_algebra_apply(Name, CarrierField, Extend, A, BC, Right),
             metta_require_algebra_equal(Name, 'extend-associative',
                                         [A,B,C], Left, Right) )).
metta_check_algebra_law(Name, _, Extend, _, _, CarrierField, Carrier,
                        'extend-commutative') :- !,
    forall(( member(A, Carrier), member(B, Carrier) ),
           ( metta_algebra_apply(Name, CarrierField, Extend, A, B, Left),
             metta_algebra_apply(Name, CarrierField, Extend, B, A, Right),
             metta_require_algebra_equal(Name, 'extend-commutative',
                                         [A,B], Left, Right) )).
metta_check_algebra_law(Name, Combine, Extend, _, _, CarrierField, Carrier,
                        'left-distributive') :- !,
    forall(( member(A, Carrier), member(B, Carrier), member(C, Carrier) ),
           ( metta_algebra_apply(Name, CarrierField, Combine, B, C, BC),
             metta_algebra_apply(Name, CarrierField, Extend, A, BC, Left),
             metta_algebra_apply(Name, CarrierField, Extend, A, B, AB),
             metta_algebra_apply(Name, CarrierField, Extend, A, C, AC),
             metta_algebra_apply(Name, CarrierField, Combine, AB, AC, Right),
             metta_require_algebra_equal(Name, 'left-distributive',
                                         [A,B,C], Left, Right) )).
metta_check_algebra_law(Name, Combine, Extend, _, _, CarrierField, Carrier,
                        'right-distributive') :- !,
    forall(( member(A, Carrier), member(B, Carrier), member(C, Carrier) ),
           ( metta_algebra_apply(Name, CarrierField, Combine, A, B, AB),
             metta_algebra_apply(Name, CarrierField, Extend, AB, C, Left),
             metta_algebra_apply(Name, CarrierField, Extend, A, C, AC),
             metta_algebra_apply(Name, CarrierField, Extend, B, C, BC),
             metta_algebra_apply(Name, CarrierField, Combine, AC, BC, Right),
             metta_require_algebra_equal(Name, 'right-distributive',
                                         [A,B,C], Left, Right) )).
metta_check_algebra_law(Name, Combine, _, _, _, CarrierField, Carrier,
                        'combine-idempotent') :- !,
    forall(member(A, Carrier),
           ( metta_algebra_apply(Name, CarrierField, Combine, A, A, Result),
             metta_require_algebra_equal(Name, 'combine-idempotent',
                                         [A], Result, A) )).
metta_check_algebra_law(Name, Combine, _, Zero, _, CarrierField, Carrier,
                        'combine-zero-identity') :- !,
    metta_check_algebra_identity(Name, Combine, Zero, CarrierField, Carrier,
                                 'combine-zero-identity').
metta_check_algebra_law(Name, _, Extend, _, One, CarrierField, Carrier,
                        'extend-one-identity') :- !,
    metta_check_algebra_identity(Name, Extend, One, CarrierField, Carrier,
                                 'extend-one-identity').
metta_check_algebra_law(Name, _, Extend, Zero, _, CarrierField, Carrier,
                        'extend-zero-annihilates') :- !,
    forall(member(A, Carrier),
           ( metta_algebra_apply(Name, CarrierField, Extend, Zero, A, Left),
             metta_require_algebra_equal(Name, 'extend-zero-annihilates',
                                         [Zero,A], Left, Zero),
             metta_algebra_apply(Name, CarrierField, Extend, A, Zero, Right),
             metta_require_algebra_equal(Name, 'extend-zero-annihilates',
                                         [A,Zero], Right, Zero) )).

metta_check_algebra_identity(Name, Operation, Identity, CarrierField, Carrier, Law) :-
    forall(member(A, Carrier),
           ( metta_algebra_apply(Name, CarrierField, Operation, Identity, A, Left),
             metta_require_algebra_equal(Name, Law, [Identity,A], Left, A),
             metta_algebra_apply(Name, CarrierField, Operation, A, Identity, Right),
             metta_require_algebra_equal(Name, Law, [A,Identity], Right, A) )).

% Carrier membership and equations compare values without binding witnesses.
% A provider's negative result is final, including a tensor compared with itself.
metta_algebra_equal(Left, Right) :-
    is_list(Left), is_list(Right), !,
    same_length(Left, Right),
    maplist(metta_algebra_equal, Left, Right).
metta_algebra_equal(Left, Right) :-
    seam:grounded_algebra_equal(Left, Right, Equal), !,
    Equal == true.
metta_algebra_equal(Left, Right) :- Left == Right.

metta_require_algebra_equal(_, _, _, Left, Right) :-
    metta_algebra_equal(Left, Right), !.
metta_require_algebra_equal(Name, Law, Inputs, Left, Right) :-
    throw(error(metta_algebra_law_violation(Name, Law, Inputs, Left, Right),
                none)).

metta_annotation_capabilities([], [], _) :- !.
metta_annotation_capabilities([[capabilities|Capabilities]], Capabilities, Term) :-
    !,
    (   maplist(atom, Capabilities)
    ->  true
    ;   metta_declaration_refused(Term, 3, [capabilities, '... symbols'])
    ).
metta_annotation_capabilities(_, _, Term) :-
    metta_declaration_refused(Term, 3, [capabilities, '... symbols']).

metta_algebra_requirement_refusal(Ctx, amplitude, Requirement) :-
    !,
    throw(error(metta_amplitude_fragment_refused(Ctx, Requirement), none)).
metta_algebra_requirement_refusal(Ctx, Algebra, Requirement) :-
    throw(error(metta_algebra_requirement_missing(Ctx, Algebra, Requirement),
                none)).

metta_check_dispatch_value(Axis, Value, Term) :-
    (   dispatch_axis_vocabulary(Axis, Vocabulary)
    ->  (   metta_vocabulary_value(Vocabulary, Value)
        ->  true
        ;   metta_declaration_refused(Term, 3,
                                      ['one-of', Vocabulary])
        )
    ;   metta_declaration_refused(Term, 2, 'a declared dispatch axis')
    ).

dispatch_axis_vocabulary('MismatchEnum', 'MismatchEnum').
dispatch_axis_vocabulary('NoMatchEnum', 'NoMatchEnum').
dispatch_axis_vocabulary('EvaluationOrderEnum', 'EvaluationOrderEnum').
dispatch_axis_vocabulary('FunctionResultEnum', 'FunctionResultEnum').
dispatch_axis_vocabulary('ClauseFailedEnum', 'ClauseFailedEnum').
dispatch_axis_vocabulary('OutOfClausesEnum', 'OutOfClausesEnum').

metta_check_argspecs([], _, _).
metta_check_argspecs([Spec|Rest], Position, Term) :-
    metta_check_argspec_form(Spec, Position, Term),
    (   Spec = [rest, _], Rest \== []
    ->  metta_declaration_refused(Term, Position, 'rest only in final position')
    ;   Spec = [optional, _], Rest = [NextSpec|_], \+ metta_spec_omittable(NextSpec)
    ->  metta_declaration_refused(Term, Position, 'optional only in the tail')
    ;   true
    ),
    Next is Position + 1,
    metta_check_argspecs(Rest, Next, Term).

metta_check_argspec_form(symbol, _, _) :- !.
metta_check_argspec_form(integer, _, _) :- !.
metta_check_argspec_form(pattern, _, _) :- !.
metta_check_argspec_form(term, _, _) :- !.
metta_check_argspec_form(['one-of', Vocab], Position, Term) :-
    !,
    (   atom(Vocab),
        metta_vocabulary_values(Vocab, _)
    ->  true
    ;   metta_declaration_refused(Term, Position,
                                  'a vocabulary declared before the kind that names it')
    ).
metta_check_argspec_form(['some-of', Vocab], Position, Term) :-
    !,
    metta_check_argspec_form(['one-of', Vocab], Position, Term).
metta_check_argspec_form([optional, Spec], Position, Term) :-
    !,
    metta_check_argspec_form(Spec, Position, Term).
metta_check_argspec_form([rest, Spec], Position, Term) :-
    !,
    metta_check_argspec_form(Spec, Position, Term).
metta_check_argspec_form(_, Position, Term) :-
    metta_declaration_refused(Term, Position, 'an argspec').

metta_declaration_refused(Term, Position, Expected) :-
    throw(error(metta_declaration_malformed(Term, Position, Expected), none)).

%A type name answers for exactly one vocabulary. Two closed sets sharing one
%name would put (: keep X) and (: depth X) under the same X, so get-type on a
%word would answer a type whose membership means two different things. The
%walk is over the vocabulary rows rather than over the published type atoms
%because a program may have declared a type of its own for its own reasons,
%and that is not this row's business.
metta_type_name_free(Name, Type, Position, Term) :-
    (   metta_catalog_row([vocabulary, Other|_]),
        Other \== Name,
        metta_vocabulary_type(Other, Type)
    ->  format(atom(Remedy),
               'a type name no other vocabulary answers to: ~w already names \c
                the ~w vocabulary, so both closed sets would type under one \c
                name',
               [Type, Other]),
        metta_declaration_refused(Term, Position, Remedy)
    ;   true
    ).

%Every word in a chain is a member of the vocabulary it orders, refused at the
%position it sits in so the message names the word rather than the row.
metta_check_order_members(_, [], _, _).
metta_check_order_members(Name, [Member|Rest], Position, Term) :-
    (   metta_vocabulary_value(Name, Member)
    ->  true
    ;   metta_declaration_refused(Term, Position, ['one-of', Name])
    ),
    Next is Position + 1,
    metta_check_order_members(Name, Rest, Next, Term).

%%%% Materialized shape-route dispatch %%%%
%
%(routed-by-shape Head [Key]) in the catalog makes (Head ...) declarations
%route by shape through metta.pl's one algorithm: specificity over adorned
%entries, coherence among the maximal ones. The materializer compiles the
%head's kind row into the exact metta_shape_fact/4 and
%metta_shape_declared/2 clauses the router dispatches on, one fact clause
%per stored arity with omitted trailing optionals padded to none, and one
%guard clause probing those arities, so consulting a route costs what the
%hand-written clauses cost, indexed clause dispatch, and the catalog pays
%at its own writes: every add or removal of a kind or routing row lands in
%the notes above and rebuilds that head's clauses from the rows then
%standing. The shipped handles, on-error and merge dispatch is built by
%this same walk from the presets below, which is what makes a third-party
%routed kind and a shipped one the same thing.
metta_materialize_routes :-
    forall(metta_routed_head(Head, _), metta_materialize_route(Head)).

metta_routed_head(Head, Key) :-
    metta_catalog_row(['routed-by-shape', Head|KeyArgs]),
    (   KeyArgs == []
    ->  Key = context
    ;   KeyArgs = [Key]
    ).

metta_materialize_route(Head) :-
    \+ atom(Head),
    !,
    metta_materialize_routes.
metta_materialize_route(Head) :-
    retractall(metta_shape_fact(Head, _, _, _)),
    retractall(metta_shape_declared(Head, _)),
    (   metta_routed_head(Head, Key),
        metta_kind_spec(Head, Spec),
        metta_route_shape(Key, Spec, PayloadSpecs)
    ->  forall(metta_payload_slice(PayloadSpecs, Stored, Payload),
               metta_assert_route_fact(Key, Head, Stored, Payload)),
        metta_assert_route_guard(Key, Head, PayloadSpecs)
    ;   true
    ).

%How a kind row reads as a route: a context-keyed route is (head ctx-symbol
%entry-pattern payload...), a global one is (head entry-pattern payload...),
%and the payload may not carry rest, whose open arity nothing could probe.
metta_route_shape(context, [symbol, pattern|PayloadSpecs], PayloadSpecs) :-
    \+ memberchk([rest, _], PayloadSpecs).
metta_route_shape(global, [pattern|PayloadSpecs], PayloadSpecs) :-
    \+ memberchk([rest, _], PayloadSpecs).

metta_check_route_fit(Key, Spec, Term) :-
    (   metta_route_shape(Key, Spec, _)
    ->  true
    ;   metta_declaration_refused(Term, 1,
            'a kind row the route can dispatch: (symbol pattern payload...) \c
             under the context key, (pattern payload...) under global, \c
             payload without rest')
    ).

%Stored and consumed payload pairs, one per legal arity: mandatory specs
%are always stored, and the first omitted trailing optional pads every
%remaining consumed position with none, which is the padding the handles
%consumers have always read for an entry that declared no determinism.
metta_payload_slice([], [], []).
metta_payload_slice([_Spec|Specs], [V|Stored], [V|Payload]) :-
    metta_payload_slice(Specs, Stored, Payload).
metta_payload_slice([[optional, _]|Specs], [], [none|Padding]) :-
    metta_payload_padding(Specs, Padding).

metta_payload_padding([], []).
metta_payload_padding([_|Specs], [none|Padding]) :-
    metta_payload_padding(Specs, Padding).

metta_assert_route_fact(context, Head, Stored, Payload) :-
    assertz((metta_shape_fact(Head, Ctx, Entry, Payload) :-
                 metta_contract_fact([Head, Ctx, Entry|Stored]))).
metta_assert_route_fact(global, Head, Stored, Payload) :-
    assertz((metta_shape_fact(Head, global, Entry, Payload) :-
                 metta_contract_fact([Head, Entry|Stored]))).

%The guard probes the smallest stored arity first, the common case (an
%entry declaring no trailing optionals), each probe deterministic the way
%the hand-written guards were.
metta_assert_route_guard(Key, Head, PayloadSpecs) :-
    findall(N,
            ( metta_payload_slice(PayloadSpecs, Stored, _),
              length(Stored, N) ),
            Ns),
    sort(0, @<, Ns, Arities),
    metta_route_probes(Key, Head, Module, Ctx, Arities, Probes),
    metta_probe_chain(Probes, Chain),
    assertz((metta_shape_declared(Head, Ctx) :-
                 metta_contract_storage(Module),
                 Chain)).

%A global route's guard leaves Ctx free on purpose: metta_shape_declared
%(merge, _) has always matched any context, the entries being keyed by
%query shape alone.
metta_route_probes(context, Head, Module, Ctx, Arities, Probes) :-
    maplist(metta_route_probe(Head, Module, Ctx), Arities, Probes).
metta_route_probes(global, Head, Module, _Ctx, Arities, Probes) :-
    maplist(metta_route_probe_global(Head, Module), Arities, Probes).

metta_route_probe(Head, Module, Ctx, N, Module:Goal) :-
    length(Vars, N),
    Goal =.. ['&metta', Head, Ctx, _Entry|Vars].
metta_route_probe_global(Head, Module, N, Module:Goal) :-
    length(Vars, N),
    Goal =.. ['&metta', Head, _Entry|Vars].

metta_probe_chain([Probe], (Probe -> true)) :- !.
metta_probe_chain([Probe|Probes], (Probe -> true ; Chain)) :-
    metta_probe_chain(Probes, Chain).

:- multifile prolog:error_message//1.
prolog:error_message(metta_declaration_malformed(Term, Position, Expected)) -->
    { Term = [Head|_],
      sdisplay(Term, TermText),
      (   is_list(Expected)
      ->  sdisplay(Expected, ExpectedText)
      ;   ExpectedText = Expected
      ) },
    [ 'the declaration ~w does not fit its declared kind: argument ~w \c
       expects ~w. Match (kind ~w $spec) in &metta to read the declared \c
       shape, or remove the kind row and redeclare it to widen the \c
       kind'-[TermText, Position, ExpectedText, Head] ].
prolog:error_message(metta_duplicate_declaration(Space, Second, First)) -->
    { sdisplay(Second, SecondText), sdisplay(First, FirstText) },
    [ 'the declaration ~w is a duplicate in ~w; the first declaration is ~w'-
      [SecondText, Space, FirstText] ].

%The same term reaches print_message/2 as a bare WARNING as well as a thrown
%error: metta_add_atom/3 keeps the first declaration and warns rather than
%refusing [source: engine/spaces/lifecycle.pl:1452]. error_message//1 covers
%only the error(Formal, Context) form, so the warning route printed `Unknown
%message: metta_duplicate_declaration(...)` and the operator was told the term
%rather than what happened. Delegating keeps one text for both routes
%[tested: discharge_audit:an_audited_compile_wraps_the_intrinsic_discharge,
%which fails on the unknown-message warning it provokes].
:- multifile prolog:message//1.
prolog:message(metta_duplicate_declaration(Space, Second, First)) -->
    prolog:error_message(metta_duplicate_declaration(Space, Second, First)).

%The shipped catalog, as data. Every row becomes an ordinary '&metta' atom
%when the directive below runs, matchable and removable like any other.
%Vocabularies come first; (kind kind ...) enters while no kind row exists
%to check it; every later row is validated by the self-description already
%in place, claims last so their kind row checks them. The value sets are
%exactly what an engine consultation site or generated binding surface acts
%on today, strict by design: a value no consumer acts on would pass the
%checker only to sit silently inert, the failure mode this catalog exists to
%make loud.
metta_catalog_preset([vocabulary, fidelity, 'Exact', 'Partial', 'Sound', 'Refuse']).
metta_catalog_preset([vocabulary, determinism, det, semidet, nondet]).
metta_catalog_preset([vocabulary, 'numeric-type', 'Number', 'BigInt']).
metta_catalog_preset([vocabulary, 'on-error-mode', keep, empty, abort]).
metta_catalog_preset([vocabulary, 'image-mode', opaque, transparent, auto]).
metta_catalog_preset([vocabulary, 'registry-image',
                      expression, symbol, handle, operations]).
metta_catalog_preset([vocabulary, 'answer-policy', depth, fair, 'best-first']).
%Every algebra this catalog DEFINES below is nameable here, because the row
%IS the list of those definitions. Written out by hand it carried eight while
%the [algebra, ...] rows defined ten, so `budget` and `amplitude` were shipped
%presets the vocabulary would not admit and the generated Semiring enum could
%not spell, while the runtime's own refusal already named all ten. Deriving
%the row makes that disagreement unrepresentable rather than merely corrected.
%The two goals below read [algebra, ...] and the alias facts, neither of which
%unifies with a [vocabulary, ...] head, so these clauses do not recurse.
metta_catalog_preset([vocabulary, semiring|Semirings]) :-
    findall(Name, metta_catalog_preset([algebra, Name|_]), Semirings).
metta_catalog_preset([vocabulary, 'algebra-law'|Laws]) :-
    metta_algebra_law_vocabulary(Laws).
%The heads a refinement may carry inside `(Annotated Base ...)` and still
%constrain a VALUE: the eleven engine/metta/refinements.pl decides, spelled as
%annotated_types spells them so a Python `Annotated[int, Gt(0)]` and a MeTTa
%`(Annotated Number (Gt 0))` are one declaration. The type reader admits an
%encoded metadata atom as a refinement only when its head is here; anything
%else, `doc` and `Timezone` included, stays in the annotation claim alone.
%Held equal to the rule table by refinements:the_rule_table_and_the_catalog_vocabulary_agree.
metta_catalog_preset([vocabulary, refinement,
                      'Gt', 'Ge', 'Lt', 'Le', 'Interval', 'MultipleOf',
                      'MinLen', 'MaxLen', 'Len', 'Predicate', 'Unit']).
metta_catalog_preset([vocabulary, 'source-kind', linear, repeated, peek]).
metta_catalog_preset([vocabulary, world, 'closed-world', 'open-world']).
metta_catalog_preset([vocabulary, atomicity,
                      transactional, 'atomic-single', 'best-effort']).
metta_catalog_preset([vocabulary, 'memo-strategy', wtinylfu, lru]).
metta_catalog_preset([vocabulary, 'memo-aggregate', none, min, max, sum, count]).
metta_catalog_preset([vocabulary, 'save-format', metta, fast]).
%The cache policy is one vocabulary because one row, (cache Name Policy),
%carries it: force and refuse are lib_memo's word about the AUTOMATIC memo,
%the rest are lib_tabling's compilation targets, SWI's own table/1 option
%list and answer-subsumption mode spelled as MeTTa words. The four members
%that take an argument and the two that stand alone are claimed below, which
%is what lets (some-of cache-policy) read (lattice join) as one member.
metta_catalog_preset([vocabulary, 'cache-policy', force, refuse,
                      plain, incremental, monotonic, lazy, shared, private,
                      subsumptive, lattice, 'max-answers', 'subgoal-abstract',
                      'answer-abstract']).
%The asymptotic classes a (cost ...) row may claim, in the order a cost
%grows. The six are the shapes the checker can tell apart on a size ladder:
%google/benchmark's own model set minus cubic and plus exponential, which its
%selection has no term for and a recursion without a memo reaches
%[source: https://github.com/google/benchmark/blob/eddb0241389718a23a42db6af5f0164b6e0139af/src/complexity.cc#L133-L146].
%Ciao states the same claim as `:- check comp nrev(A,B) + steps_o(length(A))`
%and CiaoPP proves it from inferred bounds; here the checker is the cost-rows
%lane, which measures it
%[source: https://ciao-lang.org/ciao/build/doc/ciaopp_tutorials.html/tut_advanced.html,
%"CiaoPP can also infer lower and upper bounds on the sizes of terms and the
%computational cost of predicates"].
metta_catalog_preset([vocabulary, 'cost-class',
                      constant, log, linear, linearithmic,
                      quadratic, exponential]).
metta_catalog_preset([vocabulary, 'effect-class',
                      pureStructural, readOnlyLookup,
                      nondeterministicReadOnly, writesState, oracleIO]).
metta_catalog_preset([vocabulary, visibility, 'PUBLIC', 'INTERNAL']).
metta_catalog_preset([vocabulary, 'op-kind', det, many, async,
                      raw_det, raw_many]).
metta_catalog_preset([vocabulary, 'subscription-edge', add, remove, both]).
%How a materialised view of a query is kept current. One meaning, three
%maintenance algorithms, and the word names which is in force. `pattern`
%maintains a multiset from the write events themselves, O(1) per event, and
%serves one pattern; `heads` watches the heads the query mentions and re-answers
%the query once per commit that touched one, which is exact for any read-only
%query and costs nothing on a write the query cannot see; `tabled` serves a call
%to a tabled head by watching the invalidation counter of its own table, so a
%commit that leaves the table valid costs the counter and nothing else. This is
%the choice a differential-dataflow engine makes internally and names nowhere;
%naming it is what lets a program ask for one, and read back which it got.
metta_catalog_preset([vocabulary, 'live-strategy', pattern, heads, tabled]).
%What one change to a materialised view says. `add` and `remove` carry a signed
%multiplicity for one answer; `progress` carries neither answer nor atom and its
%whole content is the generation it names, which is Materialize's SUBSCRIBE
%progress row, where "everything in the row except for mz_timestamp is not a
%valid update and its content should be ignored"
%[source: https://materialize.com/docs/sql/subscribe/].
metta_catalog_preset([vocabulary, 'delta-kind', add, remove, progress]).
%What a context promises about the change events it emits. The three
%delivery words are messaging's own, at-most-once, at-least-once and the
%exactly-once rung, spelled per-write-exactly here because the unit is one
%write into one space rather than one message; ordering is the second axis
%because a channel may deliver every write and still deliver them out of
%order. A context that promises neither declares no (events ...) row and
%is refused a subscription instead of serving one that silently drops
%writes [source: Eugster, Felber, Guerraoui and Kermarrec, The Many Faces
%of Publish/Subscribe, ACM Computing Surveys 35(2), 2003, whose space,
%time and synchronization decoupling are the dimensions a declaration
%here is about].
metta_catalog_preset([vocabulary, delivery,
                      'at-most-once', 'at-least-once', 'per-write-exactly']).
metta_catalog_preset([vocabulary, 'event-order', ordered, unordered]).
%The direction an ordered semiring counts in, which the claim rows
%below already speak (ranked and prob count down from the best,
%tropical counts up from the cheapest). Declared as a vocabulary so the
%host surfaces read the closed set from the engine instead of each
%spelling it as a literal pair: nine of them did, across four files.
metta_catalog_preset([vocabulary, 'semiring-order', ascending, descending]).
%Which reaction fires first when several match one write. This is the
%conflict-resolution question production systems settled in 1981, and the
%words are theirs. declaration is the order they were declared, a queue,
%which is what the engine did before this was a policy at all and is now the
%stated default; recency is the most recently declared first, a stack, which
%is CLIPS's depth strategy and its own recommended default; specificity is
%the most tests in the pattern first, OPS5's specificity criterion, which
%CLIPS spells complexity; priority reads each reaction's own declared number,
%highest first, which is CLIPS salience, CHR-rp's user-definable rule
%priorities (De Koninck, Schrijvers and Demoen, PPDP 2007) and ECLiPSe's
%twelve prioritized suspension levels; and user hands each reaction to a
%MeTTa function of the author's own that scores it, which is CHR-rp's DYNAMIC
%priority, an expression evaluated per instance rather than a constant
%[source: CLIPS Basic Programming Guide, conflict resolution strategies;
%Brownston et al., Programming Expert Systems in OPS5, 1985].
%
%OPS5's other criterion, recency of the matched working-memory elements, has
%nothing to discriminate here and is deliberately absent: every reaction in
%this conflict set was triggered by the SAME write, so their time tags are
%equal by construction. What varies between them is when they were declared
%and how specific they are.
metta_catalog_preset([vocabulary, 'agenda-policy',
                      declaration, recency, specificity, priority, user]).
metta_catalog_preset([vocabulary, volatility, volatile, stable, immutable]).
metta_catalog_preset([vocabulary, 'route-key', context, global]).
metta_catalog_preset([vocabulary, 'space-capability', file, process, network]).
%What a space PROVIDER can be asked to do, in the engine's own words. The
%nine are the operations engine/spaces/foreign.pl gates: match, enumerate,
%add, add-many, remove and clear are the seam hooks a provider implements,
%plan is the pushdown offer, and subscribe and rules are the two PROMISES no
%method list can derive - one about what the context delivers, one about
%whether the space's atoms include equations.
%
%Open, because seam:foreign_capability/2 and engine/ext_points.pl's kind/2
%are both multifile: a seat or a library declares a hook of its own and the
%word that gates it. extensions/node/bridge.pl does exactly that today with
%bounded, pushdown and transactional, which it registers through the
%(vocabulary-member ...) door at load.
metta_catalog_preset([vocabulary, 'provider-capability',
                      match, enumerate, add, 'add-many', remove, clear,
                      subscribe, plan, rules]).
%How a callable receives its arguments: `atoms` hands the syntax through
%untouched, `values` decodes it to the host's own data first, and the absence
%of an (arguments ...) row means values. It is a catalog vocabulary rather
%than a seat's tuple because the DECLARATION lives in '&metta' and all three
%seats read the same word out of it.
metta_catalog_preset([vocabulary, 'argument-delivery', atoms, values]).
%The wire's own grammar, as rows, because all three seats speak the same tags
%and the grammar had three partial copies between them: the shim's clauses,
%metta._schemas' eight JSON payload shapes and metta._projection's nine
%decoder tags. A tag is a CLAIM about its payload rather than a label on it,
%so a row states which class of thing the payload is and one lane holds every
%copy to it.
%
%The three classes: a `term` tag is part of an atom and nests; a `frame` tag
%wraps a whole answer and never appears inside one; a `reply` tag is one
%door's answer shape and is neither.
metta_catalog_preset([vocabulary, 'wire-class', term, frame, reply]).
%What a tag's payload IS. Each seat spells these its own way - JSON Schema in
%metta._schemas, a Prolog type test in the shim's decoder - and the word is
%what the seats agree on, exactly as the type table in
%extensions/python/metta/_projection.py carries one column per target.
metta_catalog_preset([vocabulary, 'wire-payload',
                      text, number, boolean, term, terms, host, handle,
                      truth, bindings, control]).
%Which bound stopped a piece of engine work that answers what it managed
%before the stop. The five words are the names a caller SETS them under, so
%the value is also the remedy: max_events for events, m.limits(inferences=),
%(timeout=) and (stack=) for the other three, and for memory the engine's own
%store-cell budget, which no caller sets and which asking for more events
%cannot lift. A bounded run that answered only "yes, something cut this"
%told a caller to raise the wrong bound; naming it is what makes a prefix
%actionable [source: GDB's trace-experiment stop reasons, which report tfull
%against tstop against terror rather than one truncated flag, GDB manual,
%Tracepoints; call_with_inference_limit/3 is SWI's own reading of the same
%decision, reporting inference_limit_exceeded as a RESULT rather than an
%exception].
metta_catalog_preset([vocabulary, limit,
                      events, memory, inferences, timeout, stack]).
metta_catalog_preset([vocabulary, 'MismatchEnum',
                      'MismatchOriginal', 'MismatchError', 'MismatchFail']).
metta_catalog_preset([vocabulary, 'NoMatchEnum',
                      'NoMatchOriginal', 'NoMatchFail', 'NoMatchError']).
metta_catalog_preset([vocabulary, 'EvaluationOrderEnum',
                      'OrderClause', 'OrderFittest']).
metta_catalog_preset([vocabulary, 'FunctionResultEnum',
                      'Nondeterministic', 'Deterministic']).
metta_catalog_preset([vocabulary, 'ClauseFailedEnum',
                      'ClauseFailNonDet', 'ClauseFailDet']).
metta_catalog_preset([vocabulary, 'OutOfClausesEnum',
                      'FailureOriginal', 'FailureEmpty', 'FailureError']).
%The three closed sets a (refusal ...) row's ground and remedy name. They are
%here rather than in a seat's source because the ROWS below use them and the
%rows are catalog data: a ground kind or an applicability no consumer acts on
%would otherwise sit in a seat's tuple where nothing compares it to what the
%engine writes.
%
%`ground-kind` is the authority a refusal stands on: the HOST language's own
%reference, a named law this engine states, or a measured answer of upstream
%PeTTa under tests/conformance/petta/, which is what settles a question
%neither language's documentation answers. The first is spelled without
%naming a host, because a host is what this engine does not name; each seat's
%citation names its own reference.
%
%`remedy-kind` is LSP 3.17's CodeActionKind restricted to the three this
%engine issues, and `applicability` is rustc's Applicability with its four
%levels collapsed to three: machine is MachineApplicable, maybe is
%MaybeIncorrect, prose is HasPlaceholders. rustc's Unspecified is not
%admitted, because a remedy nobody classified is a defect
%[source: rustc_lint_defs::Applicability; LSP 3.17 CodeActionKind].
%Held equal to metta.errors' own three tuples by
%extensions/python/tests/repository/test_refusal_rows.py.
metta_catalog_preset([vocabulary, 'ground-kind',
                      'host-reference', 'metta-law', arbiter]).
metta_catalog_preset([vocabulary, 'remedy-kind', quickfix, refactor, source]).
metta_catalog_preset([vocabulary, applicability, machine, maybe, prose]).
%The refusal kinds a host seat classifies, derived from the declarations at
%the foot of this file so a kind reaches the vocabulary by having a row rather
%than by being remembered here, the way the semiring vocabulary is derived
%from the algebra presets above. The members are the ENGINE's own kind words,
%the ones the raised ball and every seat's wire already carry, so a generated
%member's VALUE is the word a classifier compares; `op-kind`'s raw_det carries
%an underscore for the same reason.
metta_catalog_preset([vocabulary, 'refusal-kind'|Kinds]) :-
    findall(Kind, metta_refusal_declaration(Kind, _, _, _), Kinds).
metta_catalog_preset([kind, kind, symbol, [rest, term]]).
metta_catalog_preset([kind, 'routed-by-shape', symbol,
                      [optional, ['one-of', 'route-key']]]).
metta_catalog_preset([kind, 'owned-by-space', symbol]).
metta_catalog_preset([kind, vocabulary, symbol, [rest, symbol]]).
%The four rows a vocabulary carries BESIDE its members, sibling rows rather
%than columns because the (vocabulary ...) atom is matched by ARITY by
%programs (five example files match one, from (vocabulary delivery $a $b $c)
%up to the ten-member semiring row), so a column would break every one of
%them and every reader that takes the tail as the member list.
metta_catalog_preset([kind, 'vocabulary-type', symbol, symbol]).
metta_catalog_preset([kind, 'vocabulary-order', symbol, [rest, symbol]]).
metta_catalog_preset([kind, 'vocabulary-open', symbol, term]).
metta_catalog_preset([kind, 'vocabulary-member', symbol, symbol]).
%One wire tag: the class of thing it is, the class of its payload, and the
%sentence CODEC.md and the OpenAPI schema both show. The prose is on the row
%for the same reason a (refusal ...) row carries its ground and its remedy:
%three seats and two documents were each keeping their own copy of it.
metta_catalog_preset([kind, 'wire-tag', symbol, ['one-of', 'wire-class'],
                      ['one-of', 'wire-payload'], term]).
metta_catalog_preset([kind, claim, symbol, symbol, [rest, symbol]]).
metta_catalog_preset([kind, policy, symbol, symbol, term]).
metta_catalog_preset([kind, handles, symbol, pattern, ['one-of', fidelity],
                      [optional, ['one-of', determinism]]]).
metta_catalog_preset([kind, 'on-error', symbol, pattern,
                      ['one-of', 'on-error-mode']]).
metta_catalog_preset([kind, merge, pattern, ['one-of', 'answer-policy']]).
metta_catalog_preset([kind, annotations, symbol, symbol,
                      [optional, term]]).
metta_catalog_preset([kind, algebra, symbol, symbol, symbol, term, term,
                      term, term, term, symbol]).
metta_catalog_preset([kind, source, symbol, ['one-of', 'source-kind']]).
metta_catalog_preset([kind, context, symbol, ['one-of', world]]).
metta_catalog_preset([kind, admits, symbol, term]).
metta_catalog_preset([kind, capacity, symbol, integer]).
metta_catalog_preset([kind, writes, symbol, ['one-of', atomicity]]).
metta_catalog_preset([kind, events, symbol, ['one-of', delivery],
                      [optional, ['one-of', 'event-order']]]).
metta_catalog_preset([kind, emits, symbol, ['one-of', 'answer-policy']]).
metta_catalog_preset([kind, cache, symbol, ['some-of', 'cache-policy']]).
metta_catalog_preset([kind, cost, pattern, ['one-of', 'cost-class'],
                      [optional, symbol]]).
metta_catalog_preset([kind, image, symbol, symbol, ['one-of', 'image-mode']]).
metta_catalog_preset([kind, 'type-image', symbol,
                      ['one-of', 'registry-image']]).
metta_catalog_preset([kind, effect, symbol, ['one-of', 'effect-class']]).
metta_catalog_preset([kind, covers, term, ['one-of', 'effect-class']]).
metta_catalog_preset([kind, compensates, symbol, symbol]).
metta_catalog_preset([kind, inverse, symbol]).
metta_catalog_preset([kind, op, symbol, integer, ['one-of', 'op-kind']]).
%How a callable's arguments reach it. The declaration was written by the
%Python seat and typed there by hand, with no kind row, so a misspelt
%(arguments f atomz) landed silently and read as `values` at every call site.
metta_catalog_preset([kind, arguments, symbol,
                      ['one-of', 'argument-delivery']]).
metta_catalog_preset([kind, deprecated, symbol, term, term]).
metta_catalog_preset([kind, visibility, symbol, ['one-of', visibility]]).
metta_catalog_preset([kind, on, symbol, pattern, term, [optional, integer]]).
metta_catalog_preset([kind, agenda, symbol, ['one-of', 'agenda-policy'],
                      [optional, symbol]]).
metta_catalog_preset([kind, tabled, symbol, symbol, integer]).
metta_catalog_preset([kind, defined, symbol, symbol]).
metta_catalog_preset([kind, subscription, symbol, pattern,
                      ['one-of', 'subscription-edge']]).
metta_catalog_preset([kind, inherits, term, term]).
metta_catalog_preset([kind, restricted, term]).
metta_catalog_preset([kind, grants, term,
                      ['one-of', 'space-capability']]).
metta_catalog_preset([kind, parametric, term]).
metta_catalog_preset([kind, 'dispatch-default', symbol, term]).
metta_catalog_preset([kind, 'dispatch-policy', symbol, symbol, term]).
metta_catalog_preset([kind, refusal, ['one-of', 'refusal-kind'], symbol,
                      term, term]).
metta_catalog_preset(['routed-by-shape', handles]).
metta_catalog_preset(['routed-by-shape', 'on-error']).
metta_catalog_preset(['routed-by-shape', merge, global]).
%A vocabulary's MeTTa type name is the mechanical CamelCase of its kebab
%name, and the exceptions are rows. One ships. `on-error-mode` is the row's
%<head>-<argname> name, while the TYPE a program writes and the enum each
%seat generates is OnError, which is the spelling the design record ruled
%(ai-python-first-revamp-discussion.md, the de-stringify ruling:
%"mode=OnError.keep ... list(OnError) enumeration"). Declaring it here is
%what deleted the RENAMES dict from extensions/python/tools/vocabgen.py, so
%the type name and both seats' enums now come from one place.
metta_catalog_preset(['vocabulary-type', 'on-error-mode', 'OnError']).
%The one chain the engine ships, written as the subtype edges (:< Exact
%Partial) and (:< Partial Sound). A stronger fidelity claim stands wherever a
%weaker one is required, which is what makes an Exact handler serve a Sound
%route. `Refuse` is a Fidelity and deliberately NOT in the chain: it is not a
%weaker claim, it is the absence of a stream.
metta_catalog_preset(['vocabulary-order', fidelity, 'Exact', 'Partial', 'Sound']).
%The two open vocabularies, each with the reason it opens. Everything not
%named here is closed, which is this catalog's standing rule: a value no
%consumer acts on would pass the checker only to sit silently inert.
metta_catalog_preset(['vocabulary-open', semiring,
                      "an (algebra ...) row is the door a program already \c
                       has, and the engine registers its name here when the \c
                       row lands, so a declared carrier can claim its own \c
                       ordering"]).
metta_catalog_preset(['vocabulary-open', 'provider-capability',
                      "seam:foreign_capability/2 and engine/ext_points.pl's \c
                       kind/2 are multifile, so a seat or library declares a \c
                       hook of its own and the word gating it; \c
                       extensions/node/bridge.pl registers bounded, pushdown \c
                       and transactional this way"]).
%The wire grammar, one row per tag. Nine term tags nest inside an atom, three
%frame tags wrap a whole answer, and `r` is metta_py_cast/4's reply, which
%CODEC.md's kit does not carry because it is one door's answer shape rather
%than part of the atom grammar - the class column is what says so, and the
%lane over the kit reads it rather than carrying an exception.
metta_catalog_preset(['wire-tag', s, term, text,
                      "a symbol: a name that denotes itself"]).
metta_catalog_preset(['wire-tag', g, term, text,
                      "a grounded value carried as text; a string crosses \c
                       this way"]).
metta_catalog_preset(['wire-tag', n, term, number,
                      "a grounded Number or BigInt; signed-i64 width fixes \c
                       an integer's language type"]).
metta_catalog_preset(['wire-tag', b, term, boolean,
                      "a grounded boolean; the engine writes true and false, \c
                       and reads True and False as the same two constants"]).
metta_catalog_preset(['wire-tag', v, term, text,
                      "a variable, the payload an identity within this term"]).
metta_catalog_preset(['wire-tag', e, term, terms,
                      "an expression, its children in order; the empty one \c
                       is unit"]).
metta_catalog_preset(['wire-tag', p, term, text,
                      "an executable space reference carried by its portable \c
                       engine name, ampersand-prefixed or not; the tag is a \c
                       species and a name that is no space keeps s"]).
metta_catalog_preset(['wire-tag', o, term, host,
                      "a live host value crossing by reference, in process \c
                       only"]).
metta_catalog_preset(['wire-tag', h, term, handle,
                      "a native engine value held by reference"]).
metta_catalog_preset(['wire-tag', u, frame, truth,
                      "an answer whose truth is undefined under the \c
                       well-founded semantics"]).
metta_catalog_preset(['wire-tag', a, frame, bindings,
                      "an answer together with the bindings it is returned \c
                       under"]).
metta_catalog_preset(['wire-tag', x, frame, control,
                      "stream control: exhaustion, no answer at all, or a \c
                       failure kept as a value"]).
metta_catalog_preset(['wire-tag', r, reply, term,
                      "the refinement constraint a cast violated, answered \c
                       when the base type admits the value and the \c
                       refinement does not"]).
%One row per engine decision axis. The inventory lane joins these live rows
%to the implementation seam named for each knob; keeping the defaults here
%means a program can read the same table the gate checks.
metta_catalog_preset([policy, dispatch, 'dispatch-policy', 'MismatchOriginal']).
metta_catalog_preset([policy, order, 'dispatch-policy', 'OrderClause']).
metta_catalog_preset([policy, merge, merge, depth]).
metta_catalog_preset([policy, agenda, reduce, 'depth-first']).
metta_catalog_preset([policy, equality, '==', 'structural-identity']).
metta_catalog_preset([policy, errors, 'on-error', abort]).
metta_catalog_preset([policy, world, context, 'closed-world']).
metta_catalog_preset([policy, algebra, annotations, bool]).
metta_catalog_preset([policy, storage, 'config-memoize', wtinylfu]).
metta_catalog_preset([policy, caching, cache, automatic]).
metta_catalog_preset([policy, typing, 'typing-rule', strict]).
metta_catalog_preset([policy, fidelity, handles, 'Exact']).
metta_catalog_preset([policy, 'source-kind', source, repeated]).
metta_catalog_preset([policy, 'transaction-mode', transaction, 'all-answers']).
metta_catalog_preset([policy, atomicity, writes, transactional]).
metta_catalog_preset([policy, delivery, events, 'per-write-exactly']).
metta_catalog_preset([policy, 'reaction-order', agenda, declaration]).
metta_catalog_preset([policy, 'save-format', save, metta]).
metta_catalog_preset([policy, volatility, volatility, stable]).
metta_catalog_preset([policy, determinism, determinism, nondet]).
metta_catalog_preset([claim, semiring, ranked, ordered, descending]).
metta_catalog_preset([claim, semiring, tropical, ordered, ascending]).
metta_catalog_preset([claim, semiring, prob, ordered, descending]).
%budget is ordered the way tropical is, min over the reals with an ascending
%reading, and declares order=ascending in its own preset. Its claim row was
%the one an ordered carrier was missing.
metta_catalog_preset([claim, semiring, budget, ordered, ascending]).
%The applied and the standalone members of the cache-policy vocabulary, read
%by metta_policy_members/3 when a (cache ...) row is written.
metta_catalog_preset([claim, 'cache-policy', lattice, takes, symbol]).
metta_catalog_preset([claim, 'cache-policy', 'max-answers', takes, integer]).
metta_catalog_preset([claim, 'cache-policy', 'subgoal-abstract', takes, integer]).
metta_catalog_preset([claim, 'cache-policy', 'answer-abstract', takes, integer]).
metta_catalog_preset([claim, 'cache-policy', force, alone]).
metta_catalog_preset([claim, 'cache-policy', refuse, alone]).
%Each alias is published as data so a consumer outside this module expands it
%by asking &metta rather than by keeping a second copy of the table.
metta_catalog_preset([claim, 'algebra-law', Alias, 'expands-to'|Expansion]) :-
    metta_algebra_law_alias(Alias, Expansion).
metta_catalog_preset([algebra, bool, max, '*', 0, 1,
                      [laws, 'combine-associative', 'combine-commutative',
                       'extend-associative', 'left-distributive',
                       'right-distributive', 'combine-zero-identity',
                       'extend-one-identity', 'extend-zero-annihilates',
                       contraction],
                      [carrier], [requires], global]).
metta_catalog_preset([algebra, bag, '+', '*', 0, 1,
                      [laws, 'combine-associative', 'combine-commutative',
                       'extend-associative', 'left-distributive',
                       'right-distributive', 'combine-zero-identity',
                       'extend-one-identity', 'extend-zero-annihilates',
                       contraction],
                      [carrier], [requires], global]).
metta_catalog_preset([algebra, counting, '+', '*', 0, 1,
                      [laws, 'combine-associative', 'combine-commutative',
                       'extend-associative', 'left-distributive',
                       'right-distributive', 'combine-zero-identity',
                       'extend-one-identity', 'extend-zero-annihilates',
                       contraction],
                      [carrier], [requires], global]).
metta_catalog_preset([algebra, set, max, '*', 0, 1,
                      [laws, 'combine-associative', 'combine-commutative',
                       'combine-idempotent', 'extend-associative',
                       'left-distributive', 'right-distributive',
                       'combine-zero-identity', 'extend-one-identity',
                       'extend-zero-annihilates', contraction],
                      [carrier], [requires], global]).
metta_catalog_preset([algebra, ranked, max, '*', 0, 1,
                      [laws, 'combine-associative', 'combine-commutative',
                       'extend-associative', 'left-distributive',
                       'right-distributive', 'combine-zero-identity',
                       'extend-one-identity', 'extend-zero-annihilates',
                       contraction],
                      [carrier], [requires], global]).
metta_catalog_preset([algebra, tropical, min, '+', infinity, 0,
                      [laws, 'combine-associative', 'combine-commutative',
                       'combine-idempotent', 'extend-associative',
                       'left-distributive', 'right-distributive',
                       'combine-zero-identity', 'extend-one-identity'],
                      [carrier], [requires], global]).
metta_catalog_preset([algebra, prob, '+', '*', 0, 1,
                      [laws, 'combine-associative', 'combine-commutative',
                       'extend-associative', 'left-distributive',
                       'right-distributive', 'combine-zero-identity',
                       'extend-one-identity', 'extend-zero-annihilates',
                       contraction],
                      [carrier], [requires], global]).
metta_catalog_preset([algebra, prov, plus, times, zero, one,
                      [laws, 'combine-associative', 'combine-commutative',
                       'extend-associative', 'left-distributive',
                       'right-distributive', 'combine-zero-identity',
                       'extend-one-identity', 'extend-zero-annihilates',
                       contraction],
                      [carrier], [requires], global]).
metta_catalog_preset([algebra, budget, min, '+', infinity, 0,
                      [laws, 'combine-associative', 'combine-commutative',
                       'combine-idempotent', 'extend-associative',
                       'combine-zero-identity', 'extend-one-identity'],
                      [carrier], [requires], global]).
metta_catalog_preset([algebra, amplitude, 'amplitude-add',
                      'amplitude-multiply', [complex, 0, 0], [complex, 1, 0],
                      [laws, 'combine-associative', 'combine-commutative',
                       'extend-associative', 'extend-commutative',
                       'left-distributive', 'right-distributive',
                       'combine-zero-identity', 'extend-one-identity',
                       'extend-zero-annihilates', contraction],
                      [carrier], [requires, finite, contractive, staged], global]).
%The requirements above are the executable amplitude fence [tested:
%an_amplitude_context_without_the_whole_fragment_is_refused_by_name;
%commit=7ae3103aee78e947d23c5872e3db23c28ad7fe1c].
metta_catalog_preset(['dispatch-default', 'MismatchEnum', 'MismatchOriginal']).

%A RELATION OUT OF ITS DOMAIN HAS NO ROW, which is a different answer from a
%function refusing a badly typed argument, and these five are relations: an
%unbound operand ENUMERATES the booleans, which is why their positions are
%already relational_input_position/2 rather than guarded ones
%[source: engine/metta/input_guards.pl:75-79]. Their declared
%`(-> Bool Bool Bool)` reads as a function everywhere else, so the call site's
%default mismatch answer, a `BadArgType` naming the position, contradicted the
%operation's own guard, which simply fails. Upstream says failure in both
%places -- `and(A,B,C) :- bool(A), bool(B), ...` and no argument check at all
%[source: PeTTa@ae66fa8 src/metta.pl:97-104] -- and it is measurable:
%`!(collapse (and True 5))` is `()` there and was
%`((Error (and True 5) (BadArgType 2 Bool Number)))` here, `!(collapse (not 5))`
%and the other three the same [measured 2026-09-07 against PeTTa@ae66fa8].
%
%Written as POLICY rather than as an exemption in the type checker, because
%the axis already exists and its vocabulary already carries this value: one
%row per name says what that name answers when its declared types do not
%match, and a program can read the same table.
metta_catalog_preset(['dispatch-policy', and, 'MismatchEnum', 'MismatchFail']).
metta_catalog_preset(['dispatch-policy', or, 'MismatchEnum', 'MismatchFail']).
metta_catalog_preset(['dispatch-policy', not, 'MismatchEnum', 'MismatchFail']).
metta_catalog_preset(['dispatch-policy', xor, 'MismatchEnum', 'MismatchFail']).
metta_catalog_preset(['dispatch-policy', implies, 'MismatchEnum',
                      'MismatchFail']).
metta_catalog_preset(['dispatch-default', 'NoMatchEnum', 'NoMatchFail']).
metta_catalog_preset(['dispatch-default', 'EvaluationOrderEnum', 'OrderClause']).
metta_catalog_preset(['dispatch-default', 'FunctionResultEnum', 'Nondeterministic']).
metta_catalog_preset(['dispatch-default', 'ClauseFailedEnum', 'ClauseFailNonDet']).
metta_catalog_preset(['dispatch-default', 'OutOfClausesEnum', 'FailureOriginal']).

%One (refusal ...) row per declaration below, which is where the shape and
%the reasoning live; this clause is here so every metta_catalog_preset/1
%clause stays together in the file.
metta_catalog_preset([refusal, Kind, Class, Ground, Remedy]) :-
    metta_refusal_declaration(Kind, Class, Ground, Remedy).

%%%%%%%%%% Refusal kinds, as rows %%%%%%%%%%
%
%One row per refusal a host seat classifies, each carrying what the engine's
%own kind table cannot: the class name a seat raises, the authority the
%refusal stands on, and the repair, as the template a seat renders with the
%fields that refusal carried.
%
%    (refusal <kind> <class> (ground <authority> "<citation>")
%             (remedy "<title>" <kind> <applicability> <act>...))
%
%<kind> is the ENGINE's own kind word, the one metta_host_error_kind_row/3
%declares in engine/metta/registration.pl and every seat's wire already
%carries; the two are held equal both ways by
%catalog_refusal_rows:the_refusal_rows_are_the_engines_own_kinds, the same
%shape refinements:the_rule_table_and_the_catalog_vocabulary_agree uses and
%for the same reason: this file is consulted into the spaces module and may
%not reach an engine predicate, so a row here is checked against the engine's
%table rather than derived from it.
%
%<class> is the SEAT-INDEPENDENT class name: what a seat calls the condition
%unless its own language already owns that word for a different meaning, in
%which case tests/data/error-kinds.json records the departure and its reason
%beside the seat's own spelling. That file is where the two seats' spellings
%live; this row is where the name they depart FROM lives, so a kind added
%here tells a new seat what to call it.
%
%<ground> and <remedy> are the two rows metta.errors publishes, projected
%exactly as Ground.as_atom() and Remedy.as_atom() write them, so a seat reads
%one back with Ground.from_atom() and Remedy.from_atom() rather than parsing a
%shape of its own. A remedy TITLE carries <field> holes named for the fields
%that kind declares, which the renderer fills from the raised ball; an ACT's
%remaining hole is the reader's own choice and is what keeps the applicability
%at `prose`, which is rustc's HasPlaceholders
%[source: rustc_lint_defs::Applicability,
%https://doc.rust-lang.org/nightly/nightly-rustc/rustc_lint_defs/enum.Applicability.html].
%The nine refusals whose repair is a decision carry a title and no act, which
%is PostgreSQL's errhint and clang's note: advice with no mechanical edit
%[source: PostgreSQL documentation, 55.3.2 Error Message Style Guide,
%errhint()].
%
%The whole shape is the errno/SQLSTATE one the kind table already follows:
%one table where the raising happens, one map per binding, and a test per
%binding that its map covers the table.
metta_refusal_declaration(
    syntax, 'MettaSyntaxError',
    [ground, 'metta-law',
     "HostLaws: engine/filereader.pl metta_host_rethrow_syntax/1 -- text the \c
      reader cannot read stops the load, at the line it stopped on"],
    [remedy, "close or correct the form that starts at line <line>",
     quickfix, prose]).
metta_refusal_declaration(
    time_limit, 'TimeLimitError',
    [ground, 'metta-law',
     "HostLaws: engine/metta/control.pl metta_pragma_key/2 max-time -- a \c
      wall-clock bound stops the evaluation where it stands, and the writes \c
      it already made stand with it"],
    [remedy, "raise the bound past <limit> seconds, or narrow the query",
     quickfix, prose, [edit, ['pragma!', 'max-time', '<seconds>']]]).
metta_refusal_declaration(
    inference_limit, 'InferenceLimitError',
    [ground, 'metta-law',
     "HostLaws: engine/metta/control.pl metta_pragma_key/2 max-inferences -- \c
      an inference bound stops the evaluation where it stands, and the writes \c
      it already made stand with it"],
    [remedy, "raise the bound past <limit> inferences, or narrow the query",
     quickfix, prose,
     [edit, ['pragma!', 'max-inferences', '<inferences>']]]).
metta_refusal_declaration(
    restraint, 'RestraintError',
    [ground, 'metta-law',
     "HostLaws: engine/spaces/catalog.pl (cache F (max-answers N)) -- a bound \c
      a program declared for one of its own tables stops the call that passed \c
      it, naming the bound rather than answering fewer rows in silence"],
    [remedy, "raise the <restraint> bound past <bound> in the row that \c
     declares it, or ask <call> for fewer answers",
     quickfix, prose]).
metta_refusal_declaration(
    interrupted, 'Interrupted',
    [ground, 'metta-law',
     "HostLaws: engine/metta/registration.pl metta_host_error_kind_row/3 \c
      interrupted -- a run stopped from outside reports the stop, so a caller \c
      tells it from a fault"],
    [remedy, "start the run again if the stop was not meant",
     source, prose]).
metta_refusal_declaration(
    value, 'WireError',
    [ground, 'metta-law',
     "HostLaws: engine/json_codec.pl -- the crossing carries only values JSON \c
      can carry and refuses the rest by name, rather than coercing them"],
    [remedy, "give the crossing a value JSON can carry, or carry the whole \c
     thing as a grounded atom",
     quickfix, prose]).
metta_refusal_declaration(
    type, 'CastError',
    [ground, 'metta-law',
     "HostLaws: engine/json_codec.pl -- a term that is not JSON data at all \c
      is refused as a type rather than as a value, so a caller tells a bad \c
      number from a bad shape"],
    [remedy, "carry this term whole as a grounded atom instead of as data",
     quickfix, prose]).
metta_refusal_declaration(
    assertion, 'AssertionFailure',
    [ground, 'metta-law',
     "HostLaws: engine/metta/runtime.pl report_failed_assertion/4 -- a false \c
      claim is printed and thrown under the MeTTa head the program wrote, so \c
      a harness separates it from a broken engine"],
    [remedy, "correct the claim <operation> makes, or the equations it reads",
     quickfix, prose]).
metta_refusal_declaration(
    capability, 'SpaceCapabilityError',
    [ground, 'metta-law',
     "HostLaws: engine/spaces/lifecycle.pl metta_space_capability_required/3 \c
      -- a restricted space answers only for the capabilities its (grants \c
      ...) rows name"],
    [remedy, "grant <capability> to <space>, which <operation> needs",
     quickfix, maybe, [edit, [grants, '<space>', '<capability>']]]).
metta_refusal_declaration(
    operation, 'MettaOperationError',
    [ground, arbiter,
     "upstream PeTTa at the parity pin: \c
      tests/conformance/petta/expected/he_error.metta.out answers Error to \c
      (catch (+ 40 a)), so a builtin refusing a value is a VALUE inside \c
      MeTTa and becomes a host exception only at the crossing"],
    [remedy, "give <operation> a <expected> where it got <culprit>",
     quickfix, prose]).
metta_refusal_declaration(
    stack, 'StackLimitError',
    [ground, 'metta-law',
     "HostLaws: engine/metta/control.pl metta_pragma_key/2 stack-limit -- the \c
      ceiling in force when the stack ran out is the one the refusal names, \c
      not the one in force now"],
    [remedy, "raise the ceiling past <limit> bytes, or make the recursion \c
     shallower",
     quickfix, prose, [edit, ['pragma!', 'stack-limit', '<bytes>']]]).
metta_refusal_declaration(
    source, 'SourceNotFound',
    [ground, 'metta-law',
     "HostLaws: engine/filereader.pl -- a source a program names is read only \c
      once it exists, and the refusal carries the path rather than the \c
      sentence about it"],
    [remedy, "create <source>, or correct the path that names it",
     quickfix, prose]).
metta_refusal_declaration(
    engine, 'EngineError',
    [ground, 'metta-law',
     "HostLaws: engine/metta/registration.pl metta_host_error_kind/3 -- a ball \c
      this engine did not shape is reported as itself rather than classified \c
      by guess"],
    [remedy, "report the ball with the message it carries; this engine did \c
     not shape it",
     source, prose]).

%Visibility controls generated documentation and static members, not whether a
%name can be mentioned. These are implementation steps behind public forms, or
%the language-level interpreter whose exact S/fn mention remains available.
metta_internal_catalog_name('get-doc-atom').
metta_internal_catalog_name('get-doc-function').
metta_internal_catalog_name('get-doc-params').
metta_internal_catalog_name('get-doc-single-atom').
metta_internal_catalog_name(interpret).
metta_internal_catalog_name('__metta_type_syntax__').
metta_internal_catalog_name('match-type-or').

metta_builtin_visibility(Name, 'INTERNAL') :-
    metta_internal_catalog_name(Name),
    !.
metta_builtin_visibility(_, 'PUBLIC').

%Run after the prelude has registered its equations. Materialising the rows
%makes ordinary &metta matching, generators, and reflection share one source
%rather than teaching a second private-name list in each consumer.
metta_publish_builtin_visibility :-
    findall(Name,
            ( fun(Name)
            ; metta_special_form_head(Name)
            ),
            Names0),
    sort(Names0, Names),
    forall(member(Name, Names),
           (   metta_catalog_row([visibility, Name, _])
           ->  true
           ;   metta_builtin_visibility(Name, Visibility),
               add_sexp('&metta', [visibility, Name, Visibility], _)
           )).

%Presets land only where their subject has no row yet, which makes the
%directive reconsult-idempotent (a re-consulted engine meets its own rows
%and the duplicate refusal must not fire) and keeps a program's own
%remove-then-redeclare widening standing across an engine reload.
metta_catalog_preset_missing([kind, Head|_]) :-
    !,
    \+ metta_kind_spec(Head, _).
metta_catalog_preset_missing([vocabulary, Name|_]) :-
    !,
    \+ metta_vocabulary_values(Name, _).
metta_catalog_preset_missing(['routed-by-shape', Head|_]) :-
    !,
    \+ metta_routed_head(Head, _).
metta_catalog_preset_missing(Atom) :-
    \+ metta_catalog_row(Atom).

:- forall(( metta_catalog_preset(Atom), metta_catalog_preset_missing(Atom) ),
          add_sexp('&metta', Atom, _)).
