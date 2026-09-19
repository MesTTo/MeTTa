% This source holds non-ASCII text, and the encoding is declared HERE, ahead
% of it, rather than inherited from the ambient locale: SWI decodes the file as
% a stream, so a directive placed after the first non-ASCII byte is already too
% late. A boot under LC_ALL=C warned `Illegal multibyte Sequence` without it,
% which is every perf-measured child, because measure_instructions builds its
% environment from a small allowlist carrying no locale.
:- encoding(utf8).

% Guarantees: withdraw_source_load/3 preserves equal atoms owned by other loads
%   or the caller [tested: lib_import_lifecycle; commit=4f2d6c0f8eb293b73f8dde30a1c84e24834f7393].
% Guarantees: with_source_load/3 restores its context through metta_with_trailed/3;
%   rollback_source_load_stable/1 retains its undo plan until retirement ends
%   [tested: trailed_scopes; commit=40b71fc99571872ca5fc85cdaf7902b467166539].
% Guarantees: source_package_row/4 answers only the package rows the named load
%   stored, so a later load into the same space re-performs none of them
%   [tested: packages:a_backing_row_performs_only_for_the_file_that_carries_it;
%   commit=WORKTREE].
%
% Purpose: implement fast caches, source digests, transactional reload, and source assertion ownership.
% Guarantees: every source retirement restores surviving function registrations
%   before repairing callers, including deferred equations in other spaces
%   [tested: lib_import_lifecycle:first_owner_retirement_keeps_other_spaces_callable,
%   lib_import_lifecycle:failed_first_load_keeps_a_nested_import_callable,
%   lib_import_lifecycle:retirement_inside_a_failed_load_keeps_older_registrations;
%   commit=b039123616aa9ec9ede3ceec146660a49f4e6709].
% Guarantees: retain_source_assertion/1 relinquishes source ownership only of
%   the artifact reference adopted by a longer-lived owner
%   [tested: lib_import_lifecycle:host_registration_outlives_the_importing_source;
%   commit=b039123616aa9ec9ede3ceec146660a49f4e6709].
% Guarantees: source atoms omit reference projections; portable program text
%   rebuilds owned equation spaces and resolved bindings with fresh identities
%   [tested: program_source,
%   extensions/python/tests/ch18_performance/test_program_source.py;
%   commit=10d17763d8bd55cf70c14efe965846893eb03c81].
%   A translator rule with a missing derived equation is refused before text
%   publication [tested: test_program_source_refuses_an_incomplete_translator_rule;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Owns resources: source claims, registrations and explicit space allocations
%   retire with their load; retained spaces retain their source owner through
%   seam:space_dependency/2 [tested:
%   extensions/python/tests/ch18_performance/test_program_source.py;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Owns resources: with_source_publication_context/2 restores its trailed
%   context on exit, failure and exception
%   [tested: source_publication; commit=e246959279271d22f166a1c8fb1840896295a020].
% Guarantees: source and recompile scopes resolve their owner selection once;
%   each artifact, stored atom and support group still writes its original
%   indexed journal row immediately [tested: source_publication; commit=e246959279271d22f166a1c8fb1840896295a020].
% Assumes: engine/filereader.pl consults this plain file while its owning module is the load context.
% Guarantees: every definition retains engine/filereader.pl's implementation module and original load order;
%   failed loads withdraw their assertions and repair dependent recompiles;
%   source_load_receipt_current/4 accepts a receipt only while its source row, digest, and every tagged stored output remain current;
%   version-5 images preserve occurrence tokens, original atoms and each compiled equation's
%   resolved source across relocation and later recompilation [tested:
%   test_fast_images_preserve_each_equations_binding, test_image_collision_rule;
%   commit=8ca8a387fc61d0918484b19a1a3baf85b6523043];
%   checksum validation accepts exactly 64 lowercase hexadecimal characters and
%   its inference cost is independent of their values [tested:
%   spaces_token_images:hash_header_keeps_the_lowercase_hexadecimal_language,
%   spaces_token_images:hash_header_cost_is_content_independent; commit=7f00ac7932fefa6f380fc8d14ec583ea0c58eff4];
%   fast-image nodes materialize only after their source and registry restore
%   completes [tested: test_reloading_a_materialized_program_preserves_its_bag;
%   commit=3c64e2e24787362a5a5081513bc24b880711a1d7];
%   fast-cache restore batches unchanged atoms and compiles resolved equations
%   against their stored references; program analysis reconciles once at the
%   image boundary [tested:
%   test_fast_restore_batches_content_dependent_program_analysis;
%   commit=3c64e2e24787362a5a5081513bc24b880711a1d7];
%   a fast cache captures one consistent equation-world graph and restores its
%   child spaces, space-valued token bindings, and translator registry through
%   fresh runtime identities [tested:
%   test_fast_cache_restores_translator_rules_and_bound_spaces;
%   commit=d2279ea320e54790dab4484421a168e93755b185];
%   a failed load erases its typing rules and recompiles affected retained
%   clauses under the restored policy [tested:
%   filereader_source_rollback:a_failed_source_rule_restores_discharged_contracts;
%   commit=c00341f0ff9d83d1b9338ca86ad51708eaf07ebd];
%   withdraw_source_load/3 removes the atoms a load STORED and leaves every
%   clause it derived to the reference sweep, so a reload never removes an
%   equal atom another space still owns [tested:
%   metta_arrow_products:a_reloaded_library_declaration_withdraws_only_its_own_effect_row;
%   commit=bbb512316280110a747e31c26adfc31e8c5104be].
% Fails when: loaded directly or from another module; internal state and unqualified meta-goals would acquire the wrong owner.
% [tested: tests/prolog/suites/reader/filereader.plt, tests/prolog/static_checks.pl; commit=9a116762fb4372d55675e2ef64b7657092bc136d]
% Guarantees: rollback_source_load/1 repairs surviving callers after
%   withdrawing alias declarations from a failed load [tested:
%   test_a_failed_first_file_load_restores_existing_callers,
%   test_file_replacement_updates_aliases_and_failed_replacement_restores_them;
%   commit=acad923476d21110870f235192757281a737ee71].
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- use_module(library(ugraphs), []).

% Static QLF files contain inert data, never executable native storage clauses.
% Their temporary space mints at the same funnel as every ordinary write.
metta_static_import_image(Atoms, Image) :-
    setup_call_cleanup(
        'new-space'(Space),
        ( maplist(add_sexp(Space), Atoms),
          metta_host_fast_capture_image(Space, Image, _, Problem),
          ( Problem == none -> true
          ; throw(error(metta_static_image_unwritable(Problem), none)) ) ),
        metta_release_space(Space)).

metta_restore_static_import(File, Space, Image) :-
    metta_static_import_payload(File, Image, Portable),
    absolute_file_name(File, CanonPath, [access(read)]),
    metta_source_digest(CanonPath, Digest),
    import_when(true, Space, CanonPath,
        replacing_previous_load(CanonPath, Space,
            metta_restore_static_into(CanonPath, Digest, Portable),
            metta_restore_static_into(CanonPath, Digest, Portable, Space))).

%The payload a static cache may carry: exactly one inert tokenized data space.
%Two clauses rather than an if-then-else whose else branch throws, because
%SWI's branch check cannot see that the throw never returns and reads the
%payload as a variable one branch forgot to bind.
metta_static_import_payload(_, Image, Portable) :-
    metta_fast_image_valid(Image, Portable, none),
    Portable = metta_fast_image(_, [space(0, root, _, [], _)], [], [], []),
    !.
metta_static_import_payload(File, _, _) :-
    throw(error(metta_fast_payload_invalid(File),
                context(metta_restore_static_import/3,
                        'a static cache must contain one inert tokenized data space'))).

metta_restore_static_into(Path, Digest,
                          metta_fast_image(identity(_, Next),
                                           [space(0, root, Atoms, [], Incoming)],
                                           [], [], []), Space) :-
    with_source_load(Path, Space,
        ( active_source_load(Load),
          assertz(source_load_digest(Load, Path, Digest)),
          metta_identity:metta_generation_receive(Next),
          spaces:metta_with_occurrence_load(
              filereader:( spaces:metta_receive_occurrences(Space, Incoming, Tokens),
                           maplist(metta_static_store_atom(Space), Atoms, Tokens) )) )).

metta_static_store_atom(Space, Atom, Token) :-
    add_sexp(Space, Atom, Token, Ref),
    record_source_atom_assertion(Ref).

%%%% The fast cache and the content digest %%%%
%
%The binary save format, its integrity-checked loader, and the space
%digest are engine machinery: SWI streams, fastrw, zlib and the crypto
%hash, with exactly one host question in them, whether a term holds a
%live host object, which is the published seam:host_object/1 ownership
%seam each bridge answers for its own kind of object. They lived in the
%Python shim and the walk that found a live object asked py_is_object
%directly, which is how a second binding would have re-paid the whole
%section.
%
%Results cross as terms, the codec staying each host's own: a save or
%digest that refuses answers object(Atom) or symbol(Atom) naming the
%offender, a save that lands answers saved(Count), a digest answers
%digest(Hash).

%The version prefix of the header; the file appends a tab, the sha256 of
%the payload bytes, and a newline, so integrity refuses before fast_read
%sees a single payload byte.
% Version 5 adds identity(Actor, NextGeneration) and each space's parallel
% occurrence-token list. Integers name the image actor; t(Actor, Generation)
% names another actor. The payload hash covers this metadata as well as atoms.
% Each space(Id, Parent, Atoms, Bindings, Occurrences) preserves its atom bag.
% binding(Index, ResolvedEquation) names one one-based atom occurrence; indexes
% are strictly increasing. Resolved terms use the same world-node relocation
% as atoms, tokens and rules. A row is written only where arrival-time
% rewriting did more than resolve &self (a bound token, a form rewriter);
% &self is resolved against the restoring space when the occurrence compiles,
% which is what relocates it. Earlier schemas lack this source provenance and
% are refused by the exact header comparison before payload decoding.
metta_host_fast_header(Header) :-
    current_prolog_flag(version_data, swi(Major, Minor, Patch, _)),
    format(string(Header), 'METTA-CACHE\tMETTA-FAST\t5\t~d.~d.~d',
           [Major, Minor, Patch]).

%A file whose path ends .gz reads and writes through zlib's stream; Python's
%gzip module accepts the same files and vice versa. Every .gz the engine opens
%comes through here -- the cache's own reads and writes, and read_source_text/2
%below for a .gz PROGRAM -- so this is the one place the compressed-sources
%capability is required, and the refusal names the FILE, which is the part of
%it a user can act on. A path that does not end .gz pays nothing: the guard is
%inside the branch that needs it.
metta_host_fast_open(File, Mode, Stream) :-
    (   file_name_extension(_, gz, File)
    ->  metta_require_platform(File, 'compressed-sources'),
        gzopen(File, Mode, Stream, [type(binary)])
    ;   open(File, Mode, Stream, [type(binary)])
    ).

%Whether any subterm is a live host object, the one question only a host
%can answer, asked through its published seam. The seam is consulted only
%behind blob/2, because every host's live object crosses as a non-text
%blob (janus wraps Python objects so, and swipl-wasm renders its objects
%as opaque blobs), and asking the multifile seam at every subterm instead
%cost the fast save +320,062 inferences over its corpus
%[measured 2026-08-20: 2,322,901 against 2,002,839 on save-load-fast].
metta_host_atom_carries_object(Term) :-
    compound(Term),
    !,
    compound_name_arity(Term, _, Arity),
    between(1, Arity, Index),
    arg(Index, Term, Argument),
    metta_host_atom_carries_object(Argument),
    !.
metta_host_atom_carries_object(Term) :-
    blob(Term, Type),
    Type \== text,
    seam:host_object(Term).

%A fast save is a binary file, so it refuses before it writes rather than
%after: an object has no spelling at all, and a symbol whose name splits a
%token or carries a quote has one that reads back as something else.
%metta_unwritable_symbol/2 is the grammar's own answer to the second, so
%asking it is what keeps this from holding a second copy of the delimiter
%rules; the copy it replaced missed three classes.
%
%One of the two doors the fast cache has, and the capability is required at
%each, before anything is read or written. The refusal names the FILE rather
%than a MeTTa form because there is no MeTTa form: a binding calls these, and
%the path is the part of the request its caller can act on. Refusing rather
%than quietly writing something else is the point -- a save that answered
%saved(N) after writing a text file would be a receipt for a payload that is
%not there, and a fast cache is bytes only fastrw can read, so there is
%nothing to fall back to. What DEGRADES on a build without this is the engine,
%which never reads a cache of its own accord and so loads and runs unchanged.
metta_host_save_fast(File, Space, Result) :-
    ( atom(File) -> FA = File ; atom_string(FA, File) ),
    metta_require_platform(FA, 'fast-cache'),
    snapshot(metta_host_fast_capture_image(Space, Image, Count, Problem)),
    (   Problem = object(ObjectAtom)
    ->  Result = object(ObjectAtom)
    ;   Problem = symbol(BadSymbol)
    ->  Result = symbol(BadSymbol)
    ;   setup_call_cleanup(
            new_memory_file(MF),
            ( setup_call_cleanup(
                  open_memory_file(MF, write, PW, [encoding(octet)]),
                  fast_write(PW, Image),
                  close(PW)),
              metta_host_hash_memory_file(MF, Hash),
              metta_host_fast_header(Prefix),
              format(string(Header), '~w\t~w\n', [Prefix, Hash]),
              string_codes(Header, HeaderCodes),
              setup_call_cleanup(
                  metta_host_fast_open(FA, write, Out),
                  ( maplist(put_byte(Out), HeaderCodes),
                    setup_call_cleanup(
                        open_memory_file(MF, read, PR, [encoding(octet)]),
                        copy_stream_data(PR, Out),
                        close(PR)) ),
                  close(Out)) ),
            free_memory_file(MF)),
        Result = saved(Count)
    ).

%The cache is a graph image rather than a bag of addresses. Runtime space and
%module names are process-local; compact node IDs preserve aliasing and every
%semantic term is relocated through the same table. snapshot/1 gives all
%tables and atom stores one generation, the read-side counterpart of the
%transaction that restores them.
metta_host_fast_capture_image(Root, Image, Count, Problem) :-
    metta_fast_capture_space_graph(Root, RawSpaces, NodeSpaces),
    metta_token_snapshot(NodeSpaces, RawTokens),
    translator_rules:translator_rule_snapshot(NodeSpaces, RawRules,
                                                RawDerived),
    metta_actor(Actor), flag('$metta_generation', Next, Next),
    Raw = fast_raw(identity(Actor, Next), RawSpaces, RawTokens, RawRules, RawDerived),
    RawSpaces = [raw_space(0, root, Root, RootAtoms, _, _)|_],
    length(RootAtoms, Count),
    (   metta_fast_persisted_term(RawSpaces, RawTokens, Term),
        metta_host_atom_carries_object(Term)
    ->  Problem = object(Term)
    ;   metta_fast_persisted_term(RawSpaces, RawTokens, Term),
        metta_unwritable_symbol(Term, Bad)
    ->  Problem = symbol(Bad)
    ;   metta_fast_encode_image(Raw, NodeSpaces, Image),
        Problem = none
    ).

metta_fast_persisted_term(RawSpaces, _, Term) :-
    member(raw_space(_, _, _, Atoms, _, _), RawSpaces),
    member(Term, Atoms).
metta_fast_persisted_term(RawSpaces, _, Term) :-
    member(raw_space(_, _, _, _, Bindings, _), RawSpaces),
    member(binding(_, Term), Bindings).
metta_fast_persisted_term(_, RawTokens, Value) :-
    member(token(_, _, Value), RawTokens).

metta_fast_capture_space_graph(Root, RawSpaces, NodeSpaces) :-
    empty_assoc(Seen0),
    metta_fast_capture_space_node(0, root, Root, 1, Seen0, _, _,
                                  RawSpaces, [], NodeSpaces, []).

metta_fast_capture_space_node(
        Id, Parent, Space, Next0, Seen0, Seen, Next,
        [raw_space(Id, Parent, Space, Atoms, Bindings, Occurrences)|Rows0], Rows,
        [Id-Space|NodeSpaces0], NodeSpaces) :-
    %The throw is a GUARD rather than one arm of a choice: binding Seen1 inside
    %the else arm leaves it unbound in a branch the analyser cannot see is
    %unreachable, and list_undefined's walk halts on that warning.
    (   get_assoc(Space, Seen0, _)
    ->  throw(error(metta_fast_space_graph_cycle(Space),
                    context(metta_host_save_fast/3,
                            'an equation-world cache must be a tree')))
    ;   true
    ),
    put_assoc(Space, Seen0, true, Seen1),
    (   Id =\= 0,
        seam:foreign_space(Space)
    ->  throw(error(permission_error(snapshot, foreign_space, Space),
                    context(metta_host_save_fast/3,
                            'a foreign child needs a provider restore \c
                             contract before it can enter a fast cache')))
    ;   true
    ),
    metta_fast_capture_space_atoms(Space, Atoms, Bindings, Occurrences),
    metta_space_equation_children(Space, Children),
    metta_fast_capture_space_children(Children, Id, Next0, Seen1, Seen, Next,
                                      Rows0, Rows, NodeSpaces0, NodeSpaces).

% A syntax image needs its resolved references beside its original datum.
% Racket's serializer keeps module-path indices separately and shifts them on
% restore; this image uses its existing world-node relocation for bound terms.
% https://github.com/racket/racket/blob/v8.17/racket/src/expander/syntax/serialize.rkt
% [source: syntax-serialize and syntax-deserialize; commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
metta_fast_capture_space_atoms(Space, Atoms, Bindings, Occurrences) :-
    findall(row(Atom, Bound, Token),
            metta_fast_atom_binding(Space, Atom, Bound, Token), Rows),
    metta_fast_binding_rows(Rows, 1, Atoms, Bindings, Occurrences),
    sort(Occurrences, Unique),
    ( same_length(Occurrences, Unique) -> true
    ; throw(error(domain_error(distinct_occurrence_tokens, Space), none)) ).

metta_fast_signatures(Atoms, Signatures) :-
    findall(F-Arity,
            ( member(Term, Atoms), metta_fast_equation(Term, F, Args),
              length(Args, Inputs), Arity is Inputs+1 ), Rows),
    sort(Rows, Signatures).

metta_fast_equation(Term, F, Args) :-
    is_list(Term), Term = [Equal, Head, _], Equal == (=),
    nonvar(Head), Head = [F|Args], atom(F), is_list(Args).

metta_fast_read_space(Space, Each) :-
    (   spaces:space_parent(Space, _)
    ->  spaces:space_read_chain(Space, Each)
    ;   Each = Space
    ).

% This is get-atoms' native enumeration with its clause reference retained.
% The reference identifies the occurrence directly; compiled-clause order and
% equality between duplicate source equations cannot recover that identity.
% [source: engine/spaces/native_matching.pl, get_native_atom/3; commit=3c64e2e24787362a5a5081513bc24b880711a1d7]
metta_fast_atom_binding(Space, Atom, Bound, Token) :-
    metta_fast_read_space(Space, Each),
    metta_direct_atom_binding(Each, Atom, Bound, Token).

metta_direct_atom_binding(Each, Atom, Bound, Token) :-
    spaces:metta_require_token_read(Each, save),
    metta_source_occurrence(Each, Atom, Token, StoredRef),
    (   StoredRef \== none,
        translated_equation_binding(Each, StoredRef, Ref),
        translated_from(Ref, Resolved)
    ->  Bound = resolved(Resolved)
    ;   Bound = none
    ).

% FROM regenerates its projected declarations and documentation. Persisting
% those occurrences as source would give them a second, independent owner.
metta_source_occurrence(Space, Atom, Token, Ref) :-
    spaces:metta_space_pair(Space, Atom, Token, Ref),
    \+ metta_engine:metta_reference_projection(Space, _, Token, _).

metta_host_source_atoms(Space, Atoms) :-
    findall(Atom,
            ( metta_fast_read_space(Space, Each),
              ( seam:foreign_space(Each)
              -> 'get-atoms'(Each, Atom)
              ;  metta_source_occurrence(Each, Atom, _, _) ) ), Atoms).

% Text conversion closes over referenced spaces as well as owned children.
% Reference edges may cycle; creation-time model edges remain a DAG. The fast
% image's occurrence capture and relocation preserve shared bindings in both.
metta_host_program_source(Space, Result) :-
    snapshot(( metta_program_capture_image(Space, Image, Problem),
               ( Problem == none
               -> metta_program_image(Image, Program), Result = program(Program)
               ;  Result = Problem ) )).

metta_program_capture_image(Root, Image, Problem) :-
    empty_assoc(Empty),
    metta_program_capture_nodes([Root], Root, Empty, 0, RawSpaces, NodeSpaces),
    metta_token_snapshot(NodeSpaces, Tokens),
    translator_rules:translator_rule_snapshot(NodeSpaces, Rules, Derived),
    (   metta_fast_persisted_term(RawSpaces, Tokens, Term),
        metta_host_atom_carries_object(Term)
    ->  Problem = object(Term)
    ;   metta_fast_persisted_term(RawSpaces, Tokens, Term),
        metta_unwritable_symbol(Term, Bad)
    ->  Problem = symbol(Bad)
    ;   metta_fast_encode_image(fast_raw(none, RawSpaces, Tokens, Rules, Derived),
                                NodeSpaces, Image),
        Problem = none
    ).

metta_program_capture_nodes([], _, _, _, [], []).
metta_program_capture_nodes([Space|Pending], Root, Seen, Next, Rows, Nodes) :-
    (   get_assoc(Space, Seen, _)
    ->  metta_program_capture_nodes(Pending, Root, Seen, Next, Rows, Nodes)
    ;   metta_program_space_model(Space, Model0),
        ( Space == Root -> Model = root ; Model = Model0 ),
        findall(row(Atom, Bound, Token),
                metta_program_atom_binding(Space, Atom, Bound, Token), Captured),
        metta_fast_binding_rows(Captured, 1, Atoms, Bindings, Occurrences),
        Rows = [raw_space(Next, Model, Space, Atoms, Bindings, Occurrences)|Rest],
        Nodes = [Next-Space|RestNodes],
        put_assoc(Space, Seen, Next, Seen1),
        After is Next+1,
        findall(Dependency,
                ( member(Term, [Atoms, Bindings, Model]),
                  metta_program_term_space(Term, Dependency),
                  \+ spaces:metta_engine_owned_base_space(Dependency) ), Referenced),
        metta_space_equation_children(Space, Children),
        append([Referenced, Children, Pending], Queue),
        metta_program_capture_nodes(Queue, Root, Seen1, After, Rest, RestNodes)
    ).

% A missing binding row means the ordinary storing-space law, not raw &self.
% Resolve it before embedding the equation in a directive read by another space.
metta_program_atom_binding(Space, Atom, Bound, Token) :-
    spaces:metta_require_token_read(Space, save),
    metta_source_occurrence(Space, Atom, Token, Ref),
    (   Ref \== none, metta_fast_equation(Atom, _, _)
    ->  stored_equation_source(Space, Atom, Resolved, Ref),
        Bound = resolved(Resolved)
    ;   Bound = none
    ).

metta_program_space_model(Space, Model) :-
    (   seam:foreign_space(Space)
    ->  throw(error(permission_error(snapshot, foreign_space, Space),
                    context(metta_host_program_source/2,
                            'a foreign space needs a provider restore contract')))
    ;   \+ atom(Space)
    ->  throw(error(permission_error(snapshot, parametric_space, Space),
                    context(metta_host_program_source/2,
                            'a parametric identity needs an explicit data serialization')))
    ;   spaces:space_parent(Space, Parent)
    ->  Model = [inherits, Parent]
    ;   spaces:space_restricted(Space, Grants)
    ->  Model = [restricted, [grants|Grants]]
    ;   spaces:space_equation_home(Space, Home)
    ->  Model = [scoped, Home]
    ;   Model = [scoped, '&self']
    ).

metta_program_term_space(Term, Space) :-
    nonvar(Term),
    (   ground(Term), spaces:metta_space_identity_live(Term)
    ->  Space = Term
    ;   compound(Term), compound_name_arguments(Term, _, Arguments),
        member(Argument, Arguments), metta_program_term_space(Argument, Space)
    ).

metta_program_image(metta_fast_image(_, Spaces, Tokens, Rules, Derived), Program) :-
    maplist(metta_program_space(Derived), Spaces, SpaceGoals),
    append(SpaceGoals, AtomGoals),
    maplist(metta_program_token, Tokens, TokenGoals),
    exclude(metta_program_derived_rule, Rules, SourceRules),
    maplist(metta_program_rule, SourceRules, RuleGoals),
    append([TokenGoals, AtomGoals, RuleGoals, [true]], Goals),
    metta_program_creation_order(Spaces, Children),
    metta_program_allocations(Children, [progn|Goals], Body0),
    % The receiver's &self is lexical; an engine-root reference is literal.
    % A computed symbol crosses the reader without becoming the receiver.
    metta_host_substitute(['&self'-Global], Body0, Body),
    Encoded = [let, '$metta_fast_space_ref'(0), '&self',
               [let, Global, [atom_concat, "&self", ""], Body]],
    findall(Id-_, member(space(Id, _, _, _, _), Spaces), Pairs),
    ord_list_to_assoc(Pairs, IdVariables),
    metta_fast_decode_term(IdVariables, Encoded, Program).

metta_program_allocations([], Body, Body).
metta_program_allocations([space(Id, Model, _, _, _)|Rows], Body,
                          [let, '$metta_fast_space_ref'(Id),
                           ['new-space', _, Model],
                           Rest]) :-
    metta_program_allocations(Rows, Body, Rest).

metta_program_creation_order(Spaces, Children) :-
    maplist(metta_program_node_pair, Spaces, Pairs),
    ord_list_to_assoc(Pairs, Index),
    findall(Parent-Id,
            ( member(space(Id, Model, _, _, _), Spaces),
              metta_program_term_node(Model, Parent) ), Edges),
    pairs_keys(Pairs, Ids),
    ugraphs:vertices_edges_to_ugraph(Ids, Edges, Graph),
    ( ugraphs:top_sort(Graph, Order)
    -> delete(Order, 0, ChildIds),
       maplist(metta_program_index_node(Index), ChildIds, Children)
    ; throw(error(metta_program_model_cycle, context(metta_host_program_source/2,
                                                   'space models must be acyclic'))) ).

metta_program_node_pair(Node, Id-Node) :- Node = space(Id, _, _, _, _).
metta_program_index_node(Index, Id, Node) :- get_assoc(Id, Index, Node).

metta_program_term_node(Term, Id) :-
    nonvar(Term),
    ( Term = '$metta_fast_space_ref'(Id) -> true
    ; compound(Term), compound_name_arguments(Term, _, Arguments),
      member(Argument, Arguments), metta_program_term_node(Argument, Id) ).

metta_program_space(Derived, space(Id, _, Atoms, Bindings, _), Goals) :-
    findall(Source-Equation, member(derived(Source, Id, Equation), Derived), Generated),
    metta_program_atoms(Atoms, Bindings, Generated, 1, Id, Goals).

metta_program_atoms([], _, Generated, _, _, []) :-
    (   Generated = []
    ->  true
    ;   Generated = [Source-_|_],
        throw(error(permission_error(snapshot, incomplete_translator_rule, Source),
                    context(metta_host_program_source/2,
                            'a derived equation is missing; remove or re-register \c
                             its translator rule before exporting')))
    ).
metta_program_atoms([Atom|Atoms], Bindings, Generated0, Index, Id, Goals) :-
    (   select(_-Equation, Generated0, Generated), Equation =@= Atom
    ->  Goals = Rest
    ;   Generated = Generated0,
        ( memberchk(binding(Index, Resolved), Bindings) -> Value = Resolved
        ; Value = Atom ),
        Goals = [['add-atom', '$metta_fast_space_ref'(Id), Value]|Rest]
    ),
    Next is Index+1,
    metta_program_atoms(Atoms, Bindings, Generated, Next, Id, Rest).

metta_program_token(token(Name, Id, Value),
                    [let, Token, [atom_concat, Text, ""],
                     [evalc, ['bind!', Token, Value], '$metta_fast_space_ref'(Id)]]) :-
    atom_string(Name, Text).

metta_program_rule(rule(Name, Declarations, Id, _),
                   [evalc, ['add-translator-rule!', Name, Forms],
                    '$metta_fast_space_ref'(Id)]) :-
    maplist(translator_rules:translator_rule_declaration, Forms, Declarations).

% install_inverse_equation/3 derives this registry row with its equation.
% Emitting it independently would turn an internal direction into source syntax.
metta_program_derived_rule(rule(_, Declarations, _, _)) :-
    memberchk(direction(inverse(_)), Declarations).

metta_fast_binding_rows([], _, [], [], []).
metta_fast_binding_rows([row(Atom, Bound, Token)|Rows], Index, [Atom|Atoms],
                        Bindings, [Token|Tokens]) :-
    (   Bound = resolved(Resolved)
    ->  Bindings = [binding(Index, Resolved)|Rest]
    ;   Bindings = Rest
    ),
    Next is Index+1,
    metta_fast_binding_rows(Rows, Next, Atoms, Rest, Tokens).

metta_fast_capture_space_children([], _, Next, Seen, Seen, Next,
                                  Rows, Rows, NodeSpaces, NodeSpaces).
metta_fast_capture_space_children(
        [Child|Children], Parent, Next0, Seen0, Seen, Next,
        Rows0, Rows, NodeSpaces0, NodeSpaces) :-
    ChildId = Next0,
    ChildNext is Next0 + 1,
    metta_fast_capture_space_node(ChildId, Parent, Child, ChildNext,
                                  Seen0, Seen1, Next1,
                                  Rows0, Rows1, NodeSpaces0, NodeSpaces1),
    metta_fast_capture_space_children(Children, Parent, Next1, Seen1,
                                      Seen, Next, Rows1, Rows,
                                      NodeSpaces1, NodeSpaces).

metta_fast_encode_image(fast_raw(Identity, RawSpaces, RawTokens, RawRules, RawDerived),
                        NodeSpaces,
                        metta_fast_image(Identity, Spaces, Tokens, Rules, Derived)) :-
    metta_fast_space_id_index(NodeSpaces, SpaceIds),
    maplist(metta_fast_encode_space(SpaceIds), RawSpaces, Spaces),
    maplist(metta_fast_encode_token(SpaceIds), RawTokens, Tokens),
    maplist(metta_fast_encode_rule(SpaceIds), RawRules, Rules),
    maplist(metta_fast_encode_derived(SpaceIds), RawDerived, Derived).

metta_fast_space_id_index(NodeSpaces, SpaceIds) :-
    empty_assoc(Empty),
    metta_fast_index_spaces(NodeSpaces, Empty, SpaceIds).

metta_fast_index_spaces([], SpaceIds, SpaceIds).
metta_fast_index_spaces([Id-Space|Rows], SpaceIds0, SpaceIds) :-
    put_assoc(Space, SpaceIds0, Id, SpaceIds1),
    metta_fast_index_spaces(Rows, SpaceIds1, SpaceIds).

metta_fast_encode_space(SpaceIds, raw_space(Id, Parent, _, Atoms, Bindings, Occurrences),
                        space(Id, EncodedParent, Encoded, EncodedBindings, Occurrences)) :-
    metta_fast_encode_term(SpaceIds, Parent, EncodedParent),
    maplist(metta_fast_encode_term(SpaceIds), Atoms, Encoded),
    maplist(metta_fast_encode_term(SpaceIds), Bindings, EncodedBindings).

metta_fast_encode_token(SpaceIds, token(Name, OwnerId, Value),
                        token(Name, OwnerId, Encoded)) :-
    metta_fast_encode_term(SpaceIds, Value, Encoded).

metta_fast_encode_rule(SpaceIds,
                       rule(Name, Declarations, HomeId, Override),
                       rule(Name, Encoded, HomeId, Override)) :-
    metta_fast_encode_term(SpaceIds, Declarations, Encoded).

metta_fast_encode_derived(SpaceIds, derived(Name, SpaceId, Equation),
                          derived(Name, SpaceId, Encoded)) :-
    metta_fast_encode_term(SpaceIds, Equation, Encoded).

metta_fast_encode_term(_, Term, _) :-
    nonvar(Term),
    compound(Term),
    compound_name_arity(Term, '$metta_fast_space_ref', 1),
    !,
    throw(error(metta_fast_reserved_payload_term(Term),
                context(metta_host_save_fast/3,
                        'the cache relocation marker is engine-owned'))).
metta_fast_encode_term(SpaceIds, Term, '$metta_fast_space_ref'(Id)) :-
    ground(Term),
    get_assoc(Term, SpaceIds, Id),
    !.
metta_fast_encode_term(_, Term, Term) :-
    ( var(Term) ; atomic(Term) ),
    !.
%Rebuilt only when a child actually changed. A program with no child space
%encodes to the term it was given, and reconstructing every node to answer
%that cost 198,015 of a 468,074-inference save over 2,000 equations
%[measured 2026-09-04]. == on the argument lists is one comparison against
%one compound_name_arguments per node, and both walks below have the same
%shape for the same reason.
metta_fast_encode_term(SpaceIds, Term, Encoded) :-
    compound_name_arguments(Term, Name, Arguments),
    maplist(metta_fast_encode_term(SpaceIds), Arguments, EncodedArguments),
    (   Arguments == EncodedArguments
    ->  Encoded = Term
    ;   compound_name_arguments(Encoded, Name, EncodedArguments)
    ).

%One compact octet string, one C hash. Measured against the crypto
%filter-stream route (copy through the filter into a null sink), which
%charged ~9ms per 700KB pass; this stays ~1ms.
metta_host_hash_memory_file(MF, Hash) :-
    memory_file_to_string(MF, Payload, octet),
    metta_octets_digest(Payload, Hash).

metta_host_hash_stream(In, Hash) :-
    read_string(In, _, Payload),
    metta_octets_digest(Payload, Hash).

metta_host_fast_expect_header([], _).
metta_host_fast_expect_header([Expected|Rest], In) :-
    get_byte(In, Actual),
    (   Actual =:= Expected
    ->  metta_host_fast_expect_header(Rest, In)
    ;   throw(error(metta_fast_header_mismatch(Expected, Actual), none))
    ).

metta_host_fast_read(In, File, Image, Seen) :-
    catch(fast_read(In, Read), Caught,
          throw(error(metta_fast_read_failed(File, Caught), none))),
    (   metta_fast_image_valid(Read, Image, Seen)
    ->  true
    ;   throw(error(metta_fast_payload_invalid(File),
                    context(metta_host_fast_read/4,
                            'the cache payload is not a complete version-5 \c
                             equation-world image')))
    ).

%ONE walk where there were three. This pass used to walk every term for
%space references (metta_fast_term_refs_valid) and then walk the WHOLE image
%again for host objects (metta_host_atom_carries_object), and the decode in
%metta_host_fast_restore_image/3 walked it a third time, rebuilding every node
%to swap references that a program with no child spaces does not have.
%Measured 2026-09-04 on a 2,000-equation cache: 264,121 inferences validating
%and 116,011 decoding, against 270,105 for the storing that is the work.
%
%Seen comes back `refs` when a '$metta_fast_space_ref' was found anywhere and
%`none` otherwise, and `none` is what lets the restore skip the decode instead
%of rebuilding a term that cannot change. The object check moves into the same
%walk's atomic leaf, which is the only place a blob can sit.
metta_fast_image_valid(Image, Portable, Seen) :-
    acyclic_term(Image),
    Image = metta_fast_image(identity(Actor, Next), Spaces, Tokens, Rules, Derived),
    atom(Actor), Actor \== '',
    integer(Next), Next >= 0, Next =< 9223372036854775807,
    is_list(Spaces),
    is_list(Tokens),
    is_list(Rules),
    is_list(Derived),
    Spaces = [space(0, root, _, _, _)|_],
    findall(Id, member(space(Id, _, _, _, _), Spaces), Ids),
    length(Ids, Count),
    Last is Count - 1,
    numlist(0, Last, Ids),
    maplist(metta_fast_space_row_valid(Last, Actor, Next),
            Spaces, PortableSpaces, SeenRows),
    ( memberchk(refs, SeenRows) -> SeenSpaces = refs ; SeenSpaces = none ),
    foldl(metta_fast_token_row_valid(Last), Tokens, SeenSpaces, SeenTokens),
    foldl(metta_fast_rule_row_valid(Last), Rules, SeenTokens, SeenRules),
    findall(Name, member(token(Name, _, _), Tokens), TokenNames),
    sort(TokenNames, UniqueTokenNames),
    same_length(TokenNames, UniqueTokenNames),
    findall(Name, member(rule(Name, _, _, _), Rules), RuleNames),
    sort(RuleNames, UniqueRuleNames),
    same_length(RuleNames, UniqueRuleNames),
    foldl(metta_fast_derived_row_valid(Last, UniqueRuleNames), Derived,
          SeenRules, Seen),
    Portable = metta_fast_image(identity(Actor, Next), PortableSpaces,
                                Tokens, Rules, Derived).

metta_fast_space_row_valid(Last, Actor, Next,
                            space(Id, Parent, Atoms, Bindings, Occurrences),
                            space(Id, Parent, Atoms, Bindings, Portable), Seen) :-
    integer(Id),
    is_list(Atoms), is_list(Bindings), is_list(Occurrences),
    same_length(Atoms, Occurrences),
    maplist(metta_fast_occurrence_valid(Actor, Next), Occurrences, Portable),
    sort(Portable, Unique), same_length(Portable, Unique),
    (   Id =:= 0
    ->  Parent == root
    ;   integer(Parent), Parent >= 0, Parent < Id, Parent =< Last
    ),
    foldl(metta_fast_term_scan(Last), Atoms, none, SeenAtoms),
    length(Atoms, Count),
    metta_fast_bindings_valid(Bindings, Atoms, 1, Count),
    foldl(metta_fast_term_scan(Last), Bindings, SeenAtoms, Seen).

% A token's actor is metadata, never a relocatable space reference. Validation
% is semidet so all malformed images reach the one named payload refusal.
metta_fast_occurrence_valid(ImageActor, Next, Token, t(Actor, Generation)) :-
    ( integer(Token) -> Actor = ImageActor, Generation = Token
    ; nonvar(Token), Token = t(Actor, Generation) ),
    atom(Actor), Actor \== '',
    integer(Generation), Generation >= 0, Generation < Next.

metta_fast_bindings_valid([], _, _, _).
metta_fast_bindings_valid([Binding|Bindings], Atoms, Position, Count) :-
    nonvar(Binding), Binding = binding(Index, Resolved),
    integer(Index), Index >= Position, Index =< Count,
    Skip is Index-Position,
    length(Prefix, Skip), append(Prefix, [Original|Rest], Atoms),
    metta_fast_equation(Original, _, _),
    metta_fast_equation(Resolved, _, _),
    Next is Index+1,
    metta_fast_bindings_valid(Bindings, Rest, Next, Count).

metta_fast_token_row_valid(Last, token(Name, OwnerId, Value), Seen0, Seen) :-
    atom(Name),
    metta_fast_node_id_valid(Last, OwnerId),
    metta_fast_term_scan(Last, Value, Seen0, Seen).

metta_fast_rule_row_valid(Last,
                          rule(Name, Declarations, HomeId, Override),
                          Seen0, Seen) :-
    atom(Name),
    is_list(Declarations),
    metta_fast_node_id_valid(Last, HomeId),
    ( Override == none ; Override = override(Kind), atom(Kind) ),
    metta_fast_term_scan(Last, Declarations, Seen0, Seen).

metta_fast_derived_row_valid(Last, RuleNames,
                             derived(Name, SpaceId, Equation),
                             Seen0, Seen) :-
    atom(Name),
    memberchk(Name, RuleNames),
    metta_fast_node_id_valid(Last, SpaceId),
    metta_fast_term_scan(Last, Equation, Seen0, Seen).

metta_fast_node_id_valid(Last, Id) :-
    integer(Id),
    Id >= 0,
    Id =< Last.

%The one walk. It answers three questions at once because it visits each
%node once and the alternative visited each node three times: is every space
%reference in range, does any host object sit in the payload, and is there a
%space reference ANYWHERE. The third is what the restore reads to decide
%whether decoding is work or a copy.
%
%A blob is atomic in SWI, so the object check belongs on the atomic leaf and
%nowhere else, which is also why the old carries_object walk could be a
%separate pass at all.
metta_fast_term_scan(_, Term, Seen, Seen) :-
    var(Term),
    !.
metta_fast_term_scan(Last, Term, _, refs) :-
    compound(Term),
    compound_name_arity(Term, '$metta_fast_space_ref', 1),
    !,
    arg(1, Term, Id),
    metta_fast_node_id_valid(Last, Id).
%An atom, a number or a string is the overwhelmingly common leaf and can
%never be a host object: only a blob can, and none of these is one. Deciding
%them with one type test saves the three-goal negation below on every leaf of
%every term in the payload.
metta_fast_term_scan(_, Term, Seen, Seen) :-
    ( atom(Term) ; number(Term) ; string(Term) ),
    !.
metta_fast_term_scan(_, Term, Seen, Seen) :-
    atomic(Term),
    !,
    \+ ( blob(Term, Type), Type \== text, seam:host_object(Term) ).
metta_fast_term_scan(Last, Term, Seen0, Seen) :-
    compound_name_arguments(Term, _, Arguments),
    foldl(metta_fast_term_scan(Last), Arguments, Seen0, Seen).

%After the version prefix: one tab, sixty-four hex digits, one newline.
metta_host_fast_expect_hash(In, File, Hash) :-
    read_string(In, "\n", "", _, Line),
    (   string_concat("\t", Hash, Line),
        metta_fast_hash_valid(Hash)
    ->  true
    ;   throw(error(metta_fast_integrity_header(File), none))
    ).

%Each accepted character takes the same calls: image tokens change the digest,
%so a digit/letter branch makes otherwise identical loads cost differently.
metta_fast_hash_valid(Hash) :-
    string_length(Hash, 64),
    forall(string_code(_, Hash, Code),
           ( code_type(Code, xdigit(_)),
             \+ code_type(Code, upper) )).

%A cache is a file this door loaded, so it is replaced on a second load
%the same way a text program is. It needs neither a reader nor a digest of
%its own for that: the format already carries the sha256 of its payload,
%the same question metta_source_digest/2 asks of a source's text
%[tested test_loading_a_fast_cache_twice_leaves_one_copy].
%
%The other door. The guard is above absolute_file_name/3 on purpose: on a
%build without the capability there is no cache to have been written either,
%so the honest complaint is the missing capability and not the missing file.
metta_host_load_fast(File, Space) :-
    ( atom(File) -> FA = File ; atom_string(FA, File) ),
    metta_require_platform(FA, 'fast-cache'),
    absolute_file_name(FA, CanonPath, [access(read)]),
    import_when(true, Space, CanonPath,
                replacing_previous_load(CanonPath, Space,
                                        metta_host_fast_load_into(CanonPath),
                                        metta_host_fast_load_into(CanonPath,
                                                                  Space))).

metta_host_fast_load_into(CanonPath, Space) :-
    with_source_load(CanonPath, Space,
                     metta_host_fast_add_atoms(CanonPath, Space)).

%Two passes: the first proves the payload hash, the second lets fast_read
%consume the now-proven bytes straight off the file. fastrw is unsafe on
%untrusted bytes, so no payload byte reaches it before the digest agrees.
metta_host_fast_add_atoms(FA, Space) :-
    metta_host_fast_header(Prefix),
    string_codes(Prefix, PrefixCodes),
    setup_call_cleanup(
        metta_host_fast_open(FA, read, HIn),
        ( metta_host_fast_expect_header(PrefixCodes, HIn),
          metta_host_fast_expect_hash(HIn, FA, ExpectedHash),
          metta_host_hash_stream(HIn, ActualHash) ),
        close(HIn)),
    atom_string(ActualHash, ActualHashText),
    (   ActualHashText == ExpectedHash
    ->  true
    ;   throw(error(metta_fast_integrity_mismatch(FA), none))
    ),
    %Unconditional, because the only caller wraps this in a load context. A
    %fast load that reached here without one would be recorded under
    %nothing and so could never be replaced, and failing outright is the
    %right way to find that out. Ownership pins are skipped so the digest
    %keys the load that is actually running, never a pinned owner.
    active_source_load(LoadId),
    LoadId \= '$metta_owner_pin'(_),
    assertz(source_load_digest(LoadId, FA, ActualHash)),
    setup_call_cleanup(
        metta_host_fast_open(FA, read, In),
        ( metta_host_fast_expect_header(PrefixCodes, In),
          metta_host_fast_expect_hash(In, FA, _),
          metta_host_fast_read(In, FA, Image, Seen),
          spaces:metta_with_occurrence_load(
              filereader:metta_host_fast_restore_image(Space, Image, Seen)) ),
        close(In)).

%Restore allocates fresh child identities first, then registries, program
%atoms, and derived ownership. Translator rows precede compilation because a
%rule changes what a call site means; derived equations are already in the
%atom lists and only their removal associations land afterward. Every created
%resource joins the active source journal before the next phase can fail.
%Seen is what the validity walk already learned, so decoding is skipped
%outright when the payload holds no space reference at all -- which is every
%program without a child space. Decoding it would rebuild each term node for
%node and answer the term it was given [measured 2026-09-04: 116,011
%inferences over a 2,000-equation cache, none of which could change anything].
metta_host_fast_restore_image(Target,
                              metta_fast_image(identity(_, Next), Spaces0,
                                               Tokens0, Rules0, Derived0), Seen) :-
    % Validation retained portable identities. Advancing once before restore
    % puts every reminted collision above every incoming generation.
    metta_identity:metta_generation_receive(Next),
    metta_fast_allocate_space_nodes(Spaces0, Target, NodeSpaces),
    (   Seen == none
    ->  Spaces = Spaces0, Tokens = Tokens0,
        Rules = Rules0, Derived = Derived0
    ;   ord_list_to_assoc(NodeSpaces, IdSpaces),
        maplist(metta_fast_decode_space(IdSpaces), Spaces0, Spaces),
        maplist(metta_fast_decode_token(IdSpaces), Tokens0, Tokens),
        maplist(metta_fast_decode_rule(IdSpaces), Rules0, Rules),
        maplist(metta_fast_decode_derived(IdSpaces), Derived0, Derived)
    ),
    metta_restore_token_snapshot(Tokens, NodeSpaces, TokenRefs),
    forall(member(Ref, TokenRefs), record_source_assertion(Ref)),
    translator_rules:restore_translator_rule_snapshot(Rules, NodeSpaces,
                                                       Installed),
    forall(member(Rule, Installed), record_source_resource(Rule)),
    metta_host_fast_restore_spaces(NodeSpaces, Spaces),
    translator_rules:restore_translator_rule_derived_snapshot(
        Derived, NodeSpaces, DerivedRefs),
    forall(member(Ref, DerivedRefs), record_source_assertion(Ref)),
    forall(member(space(Id, _, Atoms, _, _), Spaces),
           ( memberchk(Id-Space, NodeSpaces),
             findall(F, metta_fast_equation_name(Atoms, F), Names0),
             sort(Names0, Names),
             materialize:with_source_materialization(Space, Names, true) )).

metta_fast_allocate_space_nodes([space(0, root, _, _, _)|Rows], Target,
                                [0-Target|NodeSpaces]) :-
    empty_assoc(Empty),
    put_assoc(0, Empty, Target, Known),
    metta_fast_allocate_space_rows(Rows, Known, NodeSpaces).

metta_fast_allocate_space_rows([], _, []).
metta_fast_allocate_space_rows([space(Id, ParentId, _, _, _)|Rows], Known,
                               [Id-Space|NodeSpaces]) :-
    get_assoc(ParentId, Known, Parent),
    metta_mint_space_equation_child(Parent, Space),
    record_source_resource(owned_space(Space)),
    put_assoc(Id, Known, Space, NextKnown),
    metta_fast_allocate_space_rows(Rows, NextKnown, NodeSpaces).

record_source_resource(Resource) :-
    forall(source_assertion_owner(LoadId),
           assertz(source_load_resource(LoadId, Resource))).

% Only a program's explicit allocation belongs to its source load. Provider
% libraries may allocate while that load runs but have their own shared owners.
record_source_space(Space) :-
    (   active_source_load(LoadId), LoadId \= '$metta_owner_pin'(_)
    ->  ( source_load_resource(LoadId, owned_space(Space)) -> true
        ; record_source_resource(owned_space(Space)) )
    ;   true
    ).

% A referenced allocation may use a global equation home while its source
% owns its lifetime. Scope retention follows that ownership through the same
% dependency relation as equation homes and FROM references. Keeping either
% side retains the source program, including allocations reachable only as data.
:- multifile seam:space_dependency/2.
seam:space_dependency(Space, Home) :-
    source_load_resource(Load, owned_space(Space)),
    metta_source_load(_, Home, Load, _),
    Space \== Home.
seam:space_dependency(Home, Space) :-
    metta_source_load(_, Home, Load, _),
    source_load_resource(Load, owned_space(Space)),
    Space \== Home.

% The journal records native allocations, including ones whose equation home
% is elsewhere. A Scope may already have retired one before its source closes.
source_owned_space(Home, Space) :-
    source_owns_space(Home, Space),
    spaces:native_storage_module_cache(Space, _).

% The ownership relation alone. A retirement's commit validation asks it in
% the refreshed view, where the allocation it would otherwise require is gone.
source_owns_space(Home, Space) :-
    metta_source_load(_, Home, Load, _),
    source_load_resource(Load, owned_space(Space)).

source_owned_release_plan(Home, Plan) :-
    findall(Space, source_owned_space(Home, Space), Spaces),
    spaces:metta_space_release_plan(Spaces, Plan).

metta_fast_decode_space(IdSpaces, space(Id, Parent, Atoms, Bindings, Occurrences),
                        space(Id, Parent, Decoded, DecodedBindings, Occurrences)) :-
    maplist(metta_fast_decode_term(IdSpaces), Atoms, Decoded),
    maplist(metta_fast_decode_term(IdSpaces), Bindings, DecodedBindings).

metta_fast_decode_token(IdSpaces, token(Name, OwnerId, Value),
                        token(Name, OwnerId, Decoded)) :-
    metta_fast_decode_term(IdSpaces, Value, Decoded).

metta_fast_decode_rule(IdSpaces,
                       rule(Name, Declarations, HomeId, Override),
                       rule(Name, Decoded, HomeId, Override)) :-
    metta_fast_decode_term(IdSpaces, Declarations, Decoded).

metta_fast_decode_derived(IdSpaces, derived(Name, SpaceId, Equation),
                          derived(Name, SpaceId, Decoded)) :-
    metta_fast_decode_term(IdSpaces, Equation, Decoded).

metta_fast_decode_term(IdSpaces, Term, Space) :-
    nonvar(Term),
    Term = '$metta_fast_space_ref'(Id),
    !,
    get_assoc(Id, IdSpaces, Space).
metta_fast_decode_term(_, Term, Term) :-
    ( var(Term) ; atomic(Term) ),
    !.
metta_fast_decode_term(IdSpaces, Term, Decoded) :-
    compound_name_arguments(Term, Name, Arguments),
    maplist(metta_fast_decode_term(IdSpaces), Arguments, DecodedArguments),
    (   Arguments == DecodedArguments
    ->  Decoded = Term
    ;   compound_name_arguments(Decoded, Name, DecodedArguments)
    ).

%One program-order boundary covers every node. The old scalar loop fired
%function_call_graph_changed after each equation and rebuilt the growing SCC
%and effect plan once per atom. metta_add_program_atoms/3 stores each node as
%one batch while the shared boundary rebuilds derived analyses once.
metta_host_fast_restore_spaces(NodeSpaces, Spaces) :-
    findall(F,
            ( member(space(_, _, Atoms, _, _), Spaces),
              metta_fast_equation_name(Atoms, F) ),
            Names0),
    sort(Names0, Names),
    with_named_definition_order(
        Names,
        ( metta_fast_restore_space_rows(Spaces, NodeSpaces, Arrived0),
          sort(Arrived0, Arrived),
          forall(member(F, Arrived), source_definition_arrived(F)) )).

metta_fast_restore_space_rows([], _, []).
metta_fast_restore_space_rows([space(Id, _, Atoms, Bindings, Incoming)|Rows],
                              NodeSpaces, Arrived) :-
    memberchk(Id-Space, NodeSpaces),
    spaces:metta_receive_occurrences(Space, Incoming, Tokens),
    (   Bindings == []
    ->  metta_add_program_atoms(Space, Atoms, Tokens, Here)
    ;   metta_fast_signatures(Atoms, Signatures),
        register_function_signatures(Signatures),
        metta_fast_restore_bound_atoms(Bindings, Atoms, Tokens, 1, Space),
        pairs_keys(Signatures, Here)
    ),
    metta_fast_restore_space_rows(Rows, NodeSpaces, Rest),
    append(Here, Rest, Arrived).

metta_fast_restore_bound_atoms([], Atoms, Tokens, _, Space) :-
    metta_add_program_atoms(Space, Atoms, Tokens, _).
metta_fast_restore_bound_atoms([binding(Index, Resolved)|Bindings], Atoms, Tokens,
                               Position, Space) :-
    Skip is Index-Position,
    length(Prefix, Skip), append(Prefix, [Original|Rest], Atoms),
    length(PrefixTokens, Skip), append(PrefixTokens, [Token|RestTokens], Tokens),
    metta_add_program_atoms(Space, Prefix, PrefixTokens, _),
    Original = [=, [F|_], _],
    metta_ensure_compiled(F),
    add_sexp(Space, Original, Token, Ref), record_source_atom_assertion(Ref),
    space_module(Space, Module),
    compile_metta_equation(Module, Resolved, Ref, _, _),
    Next is Index+1,
    metta_fast_restore_bound_atoms(Bindings, Rest, RestTokens, Next, Space).

metta_fast_equation_name(Atoms, F) :-
    member([=, [F|_], _], Atoms),
    atom(F).

%A space's content as one sha256: each atom canonicalized (fresh copy,
%numbered variables, quoted write) so alpha-equivalent equations print
%identically in every process, the lines multiset-sorted so insertion
%order cannot matter, then hashed as one utf8 document. Live objects
%print by address and are refused, the save contract.
metta_host_digest(Space, Result) :-
    findall(Atom, 'get-atoms'(Space, Atom), Atoms),
    (   member(ObjectAtom, Atoms),
        metta_host_atom_carries_object(ObjectAtom)
    ->  Result = object(ObjectAtom)
    ;   member(SymbolAtom, Atoms),
        metta_unwritable_symbol(SymbolAtom, BadSymbol)
    ->  Result = symbol(BadSymbol)
    ;   findall(Line,
                ( member(Atom, Atoms),
                  metta_host_digest_line(Atom, Line) ),
                Lines),
        msort(Lines, Sorted),
        atomic_list_concat(Sorted, '\n', Joined),
        metta_text_digest(Joined, Hash),
        Result = digest(Hash)
    ).

metta_host_digest_line(Atom, Line) :-
    copy_term(Atom, Copy),
    numbervars(Copy, 0, _),
    with_output_to(string(Line),
                   write_term(Copy, [quoted(true), numbervars(true)])).


% A .gz program reads through the engine's own zlib stream. Any other path
% reads plain text, so imports and the CLI share the same source reader.
%
%A load's own read is where its digest is taken, because that is where the text
%already is. Computing it again when the load finished read the file a second
%time, and only the digest belongs to the load: metta_source_digest/2 below asks
%the same question of a file that is NOT loading, and going through here would
%have filed its answer under whatever load happened to be running, which for a
%nested import is the importing file's [measured 2026-08-19: the second read
%cost 113 inferences of every load].
read_metta_source(Filename, S) :-
    read_source_text(Filename, S),
    (   active_source_load(LoadId),
        LoadId \= '$metta_owner_pin'(_)
    ->  metta_text_digest(S, Digest),
        assertz(source_load_digest(LoadId, Filename, Digest))
    ;   true
    ).

%The .gz branch opens through metta_host_fast_open/3 rather than calling
%gzopen/3 itself, so the engine has ONE gzip door and the capability is
%required in one place. The stream it hands back is binary and this sets the
%encoding on it, which is what the text-mode open did anyway: both routes read
%the same UTF-8 [measured 2026-08-28: a source holding é, ö and an emoji reads
%identically through gzopen/3 plus set_stream and through gzopen/4 with
%type(binary) plus the same set_stream].
read_source_text(Filename, S) :-
    ( file_name_extension(_, gz, Filename)
      -> catch(setup_call_cleanup(metta_host_fast_open(Filename, read, In),
                                  ( set_stream(In, encoding(utf8)),
                                    read_string(In, _, S) ),
                                  close(In)),
               error(Type, _),
               throw(error(Type, context(Filename,
                                         'while reading gzip-compressed MeTTa source'))))
    ; read_file_to_string(Filename, S, [encoding(utf8)]) ).

% Every space that receives a file compiles its own copy of the file's
% equations, into its own execution module, exactly as the runtime door
% does: the arbiter's import law admits a module's contents into the
% importing space and nowhere else, so a clause cannot be shared across
% spaces without making the name callable where it was never imported.
%The re-population closure is load_imported_metta_file_impl/3 with its first
%two arguments filled: the file, and a fresh Results slot per space, since a
%space that is only being brought back up to date has no answers to report.
load_imported_metta_file(Filename, Results, Space) :-
    catch(replacing_previous_load(Filename, Space,
                                  load_imported_metta_file_impl(Filename, _),
                                  load_imported_metta_file_impl(Filename, Results,
                                                                Space)),
          Error,
          rethrow_metta_file_error(Filename, Error)).

%The grouped door differs only in its result shape. Re-population of other
%spaces deliberately uses the ordinary loader because no caller observes
%those spaces' directive groups.
load_imported_metta_source_groups(Filename, Groups, Space) :-
    catch(replacing_previous_load(
              Filename, Space,
              load_imported_metta_file_impl(Filename, _),
              load_imported_metta_source_groups_impl(Filename, Groups, Space)),
          Error,
          rethrow_metta_file_error(Filename, Error)).

%Each pass gets a load context of its own: a file's equations compile into
%EVERY receiving space's module and its atoms are stored once per space, so
%the second space's copy is a contribution the file made and has to be
%recorded as one; without this a reload replaced the first space's copy and
%left the second's standing. The loading marker still guards the FIRST load
%of a path, so a recursive import of the file being loaded is caught.
load_imported_metta_file_impl(Filename, Results, Space) :-
    ( compiled_metta_source(Filename)
      -> with_source_load(Filename, Space,
                          load_metta_file_impl(Filename, Results, Space))
       ; run_with_loading_marker(
             compiled_metta_source(Filename),
             run_new_source_load(Filename, Results, Space)) ).

run_new_source_load(Filename, Results, Space) :-
    with_source_load(Filename, Space,
                     load_metta_file_impl(Filename, Results, Space)).

load_imported_metta_source_groups_impl(Filename, Groups, Space) :-
    ( compiled_metta_source(Filename)
      -> with_source_load(
             Filename, Space,
             load_metta_source_groups_impl(Filename, Space, Groups))
       ; run_with_loading_marker(
             compiled_metta_source(Filename),
             with_source_load(
                 Filename, Space,
                 load_metta_source_groups_impl(Filename, Space, Groups))) ).

%One source load: the context every assertion is filed under while it runs, the
%repair pass at the end, and the two ways it can finish. A failure rolls the
%whole partial load back, which is what this always did. A SUCCESS now keeps
%the list instead of dropping it, because that list is precisely what a later
%load of the same file has to take back out, and metta_source_load/4 is the key
%onto it.
%
%It is a wrapper rather than a fixed body because the Python library's load()
%runs the same file through a reader of its own, to keep one answer group per
%directive (metta_py_load/3 in extensions/python/metta/_binding/shim.pl), and a load that is not
%recorded here cannot be replaced later. Both doors, one lifecycle
%[tested: test_both_doors_replace_a_files_definitions].
%
%Publishing is part of the GOAL and not of the cleanup, because it only happens
%on success and because it can raise: a cleanup handler is the wrong place for
%either.
:- meta_predicate with_source_load(+, +, 0).
with_source_load(CanonPath, Space, Goal) :-
    gensym(source_load_, LoadId),
    source_publication_load_context(LoadId, LoadId, Context),
    setup_call_catcher_cleanup(
        true,
        with_source_publication_context(Context,
          once(materialize:with_source_materialization_batch(
                 Space,
                 filereader:( call(Goal), run_source_repairs(LoadId) ),
                 filereader:publish_source_load(CanonPath, Space, LoadId)))),
        Catcher,
        catch(finish_source_load(Catcher, Space, LoadId), Ball,
              (finish_source_load(Catcher, Space, LoadId), throw(Ball)))).

finish_source_load(Catcher, Space, LoadId) :-
    retractall(source_load_repair(LoadId, _)),
    retractall(support_recompile_pending(LoadId, _, _)),
    retractall(source_load_digest(LoadId, _, _)),
    ( Catcher == exit -> true
    ; materialize:discard_space(Space), rollback_source_load(LoadId) ),
    ( current_transaction(_) -> true ; metta_repair_emptied_shadows ).

publish_source_load(CanonPath, Space, LoadId) :-
    (   source_load_digest(LoadId, CanonPath, Digest)
    ->  assertz(metta_source_load(CanonPath, Space, LoadId, Digest))
    ;   throw(error(existence_error(metta_source_digest, CanonPath),
                    context(publish_source_load/3,
                            'a source load finished without reading its own \c
                             source, so nothing records what a reload replaces')))
    ).

%Whether the file on disk still holds the text a load was built from, which is
%SWI's if(changed) condition, "the file ... has been modified since it was
%loaded the last time" [source: SWI-Prolog 10.1 Reference Manual, load_files/2].
%
%SWI answers it from the modification time. This hashes the CONTENT instead,
%because a timestamp cannot answer it soundly here: Linux stamps a file from
%the coarse clock, so two writes inside one tick carry the same time, and an
%edit that keeps the length then reads as unmodified. That is exactly the edit
%this item exists for, `(= (answer) 1)` to `(= (answer) 2)`, and a reload that
%misses it is the silent staleness the second door already had.
%
%The text is read either way when the file does load, so what being sure costs
%is one read of a file that turns out not to need loading: 333 inferences over
%a 128-form 3,236-byte source, where loading it costs 95,165
%[measured 2026-08-19, five runs each, no spread].
metta_source_digest(CanonPath, Digest) :-
    file_name_extension(_, qlf, CanonPath), !,
    setup_call_cleanup(open(CanonPath, read, In, [type(binary)]),
                       metta_host_hash_stream(In, Digest), close(In)).
metta_source_digest(CanonPath, Digest) :-
    metta_fast_file_declared_digest(CanonPath, Digest),
    !.
metta_source_digest(CanonPath, Digest) :-
    read_source_text(CanonPath, Text),
    metta_text_digest(Text, Digest).

%A fast image already declares the payload digest in its ASCII header. Reading
%the complete binary as UTF-8 during a repeat load emitted `Illegal UTF-8
%start` and then continued. The loader verifies the declared value against the
%payload before applying it; change detection needs only the same identity key
%and therefore reads one line, never binary payload through the text codec.
metta_fast_file_declared_digest(CanonPath, Digest) :-
    setup_call_cleanup(
        metta_host_fast_open(CanonPath, read, In),
        read_string(In, "\n", "", _, Header),
        close(In)),
    split_string(Header, "\t", "", ["METTA-CACHE", "METTA-FAST", _, _, Hash]),
    metta_fast_hash_valid(Hash),
    atom_string(Digest, Hash).

metta_source_changed(CanonPath) :-
    metta_source_load(CanonPath, _, _, Loaded), !,
    metta_source_digest(CanonPath, Digest),
    Digest \== Loaded.

%Reloading is what makes the trace-edit-verify cycle possible, and the manual
%describes that cycle as the reason it exists: trace a goal, find unexpected
%behaviour, "Fix the sources and reload them using make/0", retry
%[source: SWI-Prolog 10.1 Reference Manual, section 4.3.2]. Two things were
%missing here and they failed in opposite directions. The Python door had no
%file identity at all, so a second load ADDED the file's definitions on top of
%the first and `(answer)` answered 1 and 2; import! had identity but no change
%detection, so a second import was skipped and the edit was ignored. Neither
%said anything [measured 2026-08-19, both doors].
%
%So this is the other half of the lifecycle P11.6 gave a space: clearing a
%space empties its execution module, and loading a file again replaces what
%that file put there. It is not retract-and-assert. The atoms leave through
%metta_remove_atom/3, the funnel that owns every consequence of an atom
%leaving: an equation un-compiles and forgets its name, a declaration
%recompiles the call sites it was shaping, invalidate_specializations/2 drops
%the specializer's clones, seam:function_removed/1 drops lib_memo's
%generations and lib_tabling's tables and duals.pl's duals, and
%seam:atom_removed/2 tells every LiveView and Python subscription. What no
%atom owns leaves through rollback_source_load/1, the same erase a failed load
%uses, and there is one such thing: a file imported into a NAMED space compiles
%into &self's module while its atoms are stored in that space, so its clauses
%are global where its atoms are not
%[tested: test_a_reloaded_source_replaces_its_definitions_and_says_what_it_replaced,
%test_reloading_invalidates_a_memoized_answer].
%
%Replacement reaches the asking space, and any OTHER space the change has made
%stale. The compiled half is shared for the reason just given, so a file whose
%text has changed cannot be replaced in one space alone: another space still
%holding the old atoms would list definitions the rebuilt module no longer
%answers. A space holding the SAME text is not stale and is left alone, which
%is what keeps loading one file into many spaces linear. The asking space loads
%first, so its pass is the one that compiles; the stale ones are populated
%again after, through LoadInto, called as call(LoadInto, Space).
%
%LoadInto is a parameter because how a file goes into a space is a property of
%the FILE, and the engine is not the only thing that reads one: the Python
%library's trusted fast cache is a serialised space with a format of its own,
%and re-populating one through the MeTTa reader would try to parse its binary
%header. Each door hands in the loader its own format needs.
%
%The withdrawal and the load that follows it are ONE transaction, so a reload
%that raises leaves the previous definitions standing rather than taking them
%with it. This is the difference between a reload being safe to attempt and a
%typo in the source costing the session its program, and the manual makes the
%same point about make/0: "Reloading a previously loaded file is safe, both in
%the debug scenario above and when the code is being executed by another
%thread", where the debug scenario is the fix-and-reload cycle this item is for
%[source: SWI-Prolog 10.1 Reference Manual, section 4.3.2]. transaction/1
%restores an erased clause the same way it discards an asserted one
%[measured 2026-08-19: an erase inside a transaction that then throws left the
%clause answering]. The reload path owns the outer transaction so withdrawal
%and replacement commit together; with_source_load/3 supplies the same atomic
%boundary for a first load, whose dependent repairs can replace older clauses
%[tested: test_a_reload_that_fails_leaves_the_previous_definitions_standing].
%A file's package rows perform after its source journal is published, inside
%the replacement transaction. This is the predicate every door into a space
%passes through: `import!`, the `load` door, the grouped door that answers
%directive groups, and the re-population of a space being brought up to date.
%Hooking a single door left the others silently unperformed, which is how a
%face loaded with `load` answered its own head unreduced while the same file
%imported answered normally. A failed activation restores the preceding source;
%lib_package compensates external acquisitions outside Prolog's transaction.
%[tested: lib_package:failed_replacement_preserves_the_previous_source_and_handles;
%commit=WORKTREE].
%
%The PATH travels with the space, because the rows performed are this file's
%and law 14 performs them at once, when the file carrying them loads.
:- meta_predicate replacing_previous_load(+, +, 1, 0).
replacing_previous_load(CanonPath, Space, LoadInto, Goal) :-
    metta_engine:metta_package_loading(CanonPath, Space,
        filereader:replacing_previous_load_(CanonPath, Space,
            metta_engine:metta_package_reload(LoadInto, CanonPath),
            ( call(Goal),
              metta_engine:metta_perform_package_rows(CanonPath, Space) ))).

%One file's own package rows in one space, read from the journal its load
%wrote rather than by matching the space.
%
%Matching answered every row the SPACE held, so each later load into a space
%re-performed every earlier file's rows: N libraries in one space cost
%N*(N+1)/2 performs instead of N, and a row that refuses raised on every load
%after the one that carried it, including loads of files that declare nothing
%[measured 2026-09-19: a backing naming a library nothing holds made the next
%three unrelated imports raise its `source_sink ... does not exist`; tested:
%packages:a_backing_row_performs_only_for_the_file_that_carries_it].
%
%Cost: one indexed lookup for the load, one for the rows, and a decode per
%CANDIDATE rather than per stored atom. Decoding the load's every atom to test
%its shape read 26 inferences each and nearly doubled a load: 310,765 against
%571,917 on the memory-scale load-metta corpus, and the same +261,152 on
%load-fast, both of which declare no package row at all [measured 2026-09-20].
%The walk itself was never the cost -- enumerating the same journal without
%decoding read +1,151 over the whole corpus -- so what had to go was the
%decode, not the enumeration.
:- export(source_package_row/4).
source_package_row(CanonPath, Space, Kind, Payload) :-
    metta_source_load(CanonPath, Space, LoadId, _),
    package_row_reference(Space, LoadId, Ref),
    spaces:stored_atom_of_ref(Ref, Space, Row, _),
    package_row(Row, Kind, Payload).

%Candidates by HEAD SYMBOL, then the load's journal for ownership. This is the
%answer engine/spaces/native_matching.pl already reached for the same question
%one level down: ask the storage predicate for the shape, because a fixed
%expression uses clause indexing and a space holding none of that shape pays
%nothing, where filtering an enumeration costs an inference per stored atom
%[source: engine/spaces/native_matching.pl:compiled_half_atom/3, which records
%+20,002 inferences on py-method-call for the filtering form, measured
%2026-08-19].
%
%Matching ALONE is what the journal was brought in to fix, and it still is:
%the space answers every package row any file put there, so the join on
%source_load_assertion/3 is what keeps this file to its own rows and stops a
%later load re-performing an earlier one's
%[tested: packages:a_backing_row_performs_only_for_the_file_that_carries_it].
%The two together are the indexed lookup AND the per-file scope; either alone
%is a defect this repository has already paid for.
%
%A FOREIGN space answers tokens rather than clause references, so there is no
%reference to join on and its own journal is the only scope available. It
%keeps the walk, which is what it always did.
package_row_reference(Space, LoadId, Ref) :-
    \+ seam:foreign_space(Space),
    !,
    spaces:metta_native_pair(Space, ['=', [package, _], _], _, Ref),
    source_load_assertion(LoadId, stored, Ref).
package_row_reference(_, LoadId, Ref) :-
    source_load_assertion(LoadId, stored, Ref).

%A row is an EQUATION whose head is `(package <kind>)`, and every level of that
%is tested rather than unified into, because a space can hold a bare VARIABLE
%as an atom and a variable unifies with whatever pattern is offered to it. A
%`$scalar` written on its own line answered as a backing row whose payload was
%an unbound variable, and the loader carried it all the way to
%check_prolog_function_names/3, which refused `a var` where the names belong
%[tested: lib_import_tokens:static_equations_and_variable_data_remain_inert].
%
%`==` on the two CONSTANTS for the same reason one level down: `Row = ['=', ...]`
%accepts a row whose head position is an unbound variable and binds it, so
%`(= ($x backing) ...)` would read as a package row. Recognising before matching
%is the rule, and a constant is recognised with `==`.
package_row(Row, Kind, Payload) :-
    nonvar(Row),
    Row = [Equation, Head, Payload],
    Equation == '=',
    nonvar(Head),
    Head = [Reserved, Kind],
    Reserved == package,
    nonvar(Kind),
    nonvar(Payload).

:- meta_predicate replacing_previous_load_(+, +, 1, 0).
replacing_previous_load_(CanonPath, Space, LoadInto, Goal) :-
    (   metta_source_load(CanonPath, _, _, _)
    ->  replaced_source_spaces(CanonPath, Space, Replaced),
        (   Replaced == []
        ->  call(Goal)
        ;   call_cleanup(
                materialize:materialization_transaction(
                    filereader:replace_source_load(CanonPath, Space, Replaced,
                                                   LoadInto, Goal)),
                metta_repair_emptied_shadows),
            %After the commit, because the repair drops predicate entries
            %and abolish/1 is not clause-level: remove_equation/6 records
            %what the withdrawal emptied, and only a function the load
            %did not refill is still a shadow to drop.
            metta_repair_emptied_shadows
        )
    ;   call(Goal)
    ).

%Which spaces this load replaces. Its own, whenever it holds a copy, because
%that is what a consult means. And any OTHER space whose copy this load is
%about to invalidate, which is one holding text this file no longer has: the
%compile that follows rebuilds the shared half from the NEW source, so a space
%still holding the old atoms would list definitions the module no longer
%answers.
%
%A space holding a copy of the SAME text is left alone, and that is what keeps
%the common shape cheap: loading one unchanged file into ten spaces is ten
%loads and not fifty-five, and it says nothing, because nothing was replaced
%[tested test_loading_one_file_into_many_spaces_replaces_none_of_them].
%
%import! asked the same question a moment ago, to decide whether to load at
%all, and this reads the file again rather than being handed that answer.
%Threading it down would save 336 inferences on a path that is about to spend
%tens of thousands loading, and it would be answering from a digest of what
%the file held BEFORE the decision rather than of what is about to be read.
replaced_source_spaces(CanonPath, Space, Replaced) :-
    metta_source_digest(CanonPath, Now),
    findall(S,
            ( metta_source_load(CanonPath, S, _, Loaded),
              ( S == Space -> true ; Loaded \== Now ) ),
            Replaced).

:- meta_predicate replace_source_load(+, +, +, 1, 0).
replace_source_load(CanonPath, Space, Replaced, LoadInto, Goal) :-
    findall(N, ( member(S, Replaced), withdraw_source_load(CanonPath, S, N) ),
            Counts),
    sum_list(Counts, Withdrawn),
    retractall(compiled_metta_source(CanonPath)),
    print_message(informational,
                  metta_source_replaced(CanonPath, Replaced, Withdrawn)),
    call(Goal),
    forall(( member(S, Replaced), S \== Space ), call(LoadInto, S)).

%One space's copy of one file, taken back out. The atoms go first so that the
%funnel sees the state the program was actually running with; the references
%then go the way a rolled-back load's do, and erase/1 on a reference the funnel
%already erased is why rollback_source_load/1 guards it.
%
%The atom pass reads the load's STORED references, the ones every storage door
%journals through record_source_atom_assertion/1, and not its artifacts. An
%artifact is a clause a load DERIVED and owns by reference: it is released by
%the reference sweep below, and its owner releases it earlier when the atom it
%was derived from goes. An annotated arrow declaration is the case where the
%difference shows, because its derived artifact is itself a stored '&metta'
%catalog row. Decoding it here removed it a second time BY VALUE, and by value
%a catalog row is indistinguishable from the equal row another space's copy of
%the same file owns: importing a library that declares `-[det,writesState]->`
%into two spaces and reloading it raised
%permission_error(remove, annotated_arrow_effect, ...) part way through the
%withdrawal, leaving metta_source_load/4 retracted and the load's references
%never rolled back
%[tested:
%metta_arrow_products:a_reloaded_library_declaration_withdraws_only_its_own_effect_row;
%commit=bbb512316280110a747e31c26adfc31e8c5104be].
%
%Asking whether the clause is still there instead does not work, because a
%withdrawal runs inside the reload's transaction and SWI answers that question
%two different ways there [measured 2026-09-05: inside transaction/1, after a
%nested transaction/1 erased a clause, clause_property(Ref, erased) is false
%and clause(_, true, Ref) still answers it, while clause/3 enumeration of the
%same predicate already does not; both agree once the outer transaction
%commits; commit=bbb512316280110a747e31c26adfc31e8c5104be]. stored_atom_of_ref/4 reads a bound reference, so
%it decodes an atom the same transaction has already taken out.
withdraw_source_load(CanonPath, Space, Count) :-
    metta_source_load(CanonPath, Space, LoadId, _),
    source_load_function_names(LoadId, Names),
    retract(metta_source_load(CanonPath, Space, LoadId, _)),
    findall(Ref, source_load_assertion(LoadId, stored, Ref), Asserted),
    reverse(Asserted, Refs),
    findall(AtomSpace-Atom,
            ( member(Ref, Refs), stored_atom_of_ref(Ref, AtomSpace, Atom, _) ),
            Atoms),
    forall(member(Ref, Refs), spaces:metta_remove_atom_reference(Ref)),
    with_typing_policy_stable(
        rollback_source_load_stable(LoadId, rollback_source_owned_space, Names)),
    length(Atoms, Count).

% Capture names before removing stored rows or their registration artifacts.
% The same snapshot serves explicit withdrawal, space release and failed loads.
source_load_function_names(LoadId, Names) :-
    metta_engine_module(Engine),
    findall(F,
            ( source_load_assertion(LoadId, Kind, Ref),
              ( Kind == stored, stored_atom_of_ref(Ref, _, [=, [F|_], _], _)
              ; Kind == artifact,
                clause_property(Ref, module(Engine)),
                clause(Recorded, true, Ref), strip_module(Recorded, _, Row),
                % policy-inventory-exempt: mechanism-internal; reason=the four artifact row shapes are this loader's own record of which clauses name a function, matched so retirement restores only affected registrations; evidence=engine/filereader/source_lifecycle.pl:source_load_function_names/2
                member(Shape, [fun(F), arity(F,_), fun_in(_,F), fun_scoped(F)]),
                Row = Shape ) ), Names0),
    sort(Names0, Names).

% The first source that introduced a name owns its registry references, but
% later sources and caller equations can reuse them. Once that first source
% leaves, derive their replacements from the executable equations that remain.
% Pin to no source: an enclosing import does not own these older definitions.
% [tested: lib_import_lifecycle; commit=4f2d6c0f8eb293b73f8dde30a1c84e24834f7393]
restore_surviving_source_functions(Names) :-
    forall(( member(F, Names),
             ( translated_equation_of(F, Ref, [=, [F|Args], _]),
               clause_property(Ref, module(Module)), length(Args, Inputs)
             ; spaces:deferred_metta_function(F, Module, _, Inputs, _, _) ) ),
           ( register_fun_in(Module, F),
             Arity is Inputs+1, register_arity(F, Arity) )).

% Clearing a source owner withdraws its artifacts in other spaces too. Unlike
% file replacement, explicit clearing also releases owned children containing
% caller additions. Release keeps its normal inherited-child refusal.
% [tested: test_a_cleared_space_forgets_what_a_file_put_in_it,
% test_a_program_releases_referenced_class_spaces_with_its_context;
% commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
forget_space_source_loads(Space) :-
    source_owned_release_plan(Space, Plan),
    forall(member(Child, Plan), metta_release_space(Child)),
    forall(translated_equation_binding(Space, _, Ref),
           forget_translated_equation_binding(Ref)),
    forall(retract(metta_source_load(_, Space, LoadId, _)),
           ( with_typing_policy_stable(
                 ( source_load_function_names(LoadId, Names),
                   rollback_source_load_stable(LoadId, release_source_owned_space, Names) )),
             retractall(source_load_digest(LoadId, _, _)) )).

%The marker is the CALLER's fact, so the caller's module has to travel with
%it. `:` on the first argument is what makes SWI qualify the term at the call
%site; without it the assert landed in whichever module this predicate happens
%to live in, and the marker the caller reads back is a different predicate of
%the same name. That is exactly what happened when this file became a module:
%engine/metta.pl's import_when/4 marks imported_metta_source/2 for the
%duration of a load, and this asserted filereader:imported_metta_source/2, so
%the re-entry guard saw nothing, a mutually importing pair recursed 78,000
%frames deep and SWI segfaulted on
%examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/03-import_duplicate_cycle.metta [measured 2026-08-22].
:- meta_predicate run_with_loading_marker(:, 0).

run_with_loading_marker(Marker, Goal) :-
    Owner = owned(none),
    % Workaround: swi-cleanup-window - register rollback first, then protect the marker and its ownership write from signals and inference trips.
    setup_call_catcher_cleanup(true,
        ( sig_atomic(( assertz(Marker, Ref),
                       catch(nb_setarg(1,Owner,Ref), AcquireBall,
                             (ignore(erase(Ref)), throw(AcquireBall))) )),
          once(Goal) ),
        Catcher,
        catch(retire_loading_marker(Catcher, Owner), Ball,
              (retire_loading_marker(Catcher, Owner), throw(Ball)))).

retire_loading_marker(exit, _) :- !.
retire_loading_marker(_, Owner) :-
    arg(1, Owner, Ref), ( Ref == none -> true ; ignore(erase(Ref)) ).

% Resolve the journal's owner once at scope entry. A recompile replaces an
% artifact for its original owners; a nested pin supersedes that context
% unless it names the same marked load. Stored atoms always belong to the
% active source or pin, independently of recompile ownership.
source_publication_load_context(Load, Marker,
        source_context([Marker|Loads], Recompiles, Owners, Load)) :-
    b_getval('$metta_source_publication', source_context(Loads, Recompiles, _, _)),
    ( Recompiles = [recompile(load(Marker), Recompiled)|_] -> Owners = Recompiled
    ; Load == none -> Owners = []
    ; Owners = [Load] ).

active_source_load(Load) :-
    b_getval('$metta_source_publication', source_context(Loads, _, _, _)),
    member(Load, Loads).
source_recompile_context(Context, Owners) :-
    b_getval('$metta_source_publication', source_context(_, Recompiles, _, _)),
    member(recompile(Context, Owners), Recompiles).

record_recompiled_source_assertion(Owners, Ref) :-
    forall(member(LoadId, Owners),
           assertz(source_load_assertion(LoadId, artifact, Ref))).
%Both recorders unwrap the deferral door's ownership pin: a clause a force
%materialises belongs to the source that DEFINED it, so the pin names that
%closed load and the journal row lands there; a none owner journals
%nowhere, exactly as its arrival did. The row keeps this tree's KIND
%column either way.
% Recompiled metadata belongs to the executable clause's original owners.
% The same precedence already governs grouped support-graph assertions below.
% [tested: filereader_source_reload:recompiled_metadata_keeps_the_equations_source_owner; commit=7f00ac7932fefa6f380fc8d14ec583ea0c58eff4]
% The same precedence as the recorder, for a mutator that must retain a
% previous version only when this source will own its new assertion.
recording_source_assertion :-
    once(source_assertion_owner(_)).

source_assertion_owner(Load) :-
    (   source_recompile_owners(Owners)
    ->  member(Load, Owners)
    ;   active_source_load(Load0)
    ->  ( Load0 = '$metta_owner_pin'(Load) -> Load \== none ; Load = Load0 )
    ;   fail
    ).

record_source_assertion(Ref) :-
    b_getval('$metta_source_publication', source_context(_, _, Owners, _)),
    ( Owners == [] -> true
    ; Owners = [Load] -> assertz(source_load_assertion(Load, artifact, Ref))
    ; forall(member(Load, Owners), assertz(source_load_assertion(Load, artifact, Ref))) ).

% A longer-lived owner has adopted this artifact. Its clause stays in place;
% retiring a former source owner must no longer erase it by reference.
retain_source_assertion(Ref) :-
    retractall(source_load_assertion(_, artifact, Ref)).

record_source_atom_assertion(Ref) :-
    b_getval('$metta_source_publication', source_context(_, _, _, Load)),
    ( Load == none -> true ; assertz(source_load_assertion(Load, stored, Ref)) ).

record_source_support_assertions(Refs) :-
    b_getval('$metta_source_publication', source_context(_, _, Owners, _)),
    ( Owners == [] -> true
    ; Owners = [Load] -> assertz(source_load_support_assertions(Load, Refs))
    ; forall(member(Load, Owners), assertz(source_load_support_assertions(Load, Refs))) ).

:- meta_predicate with_source_publication_context(+, 0).

% Workaround: swi-cleanup-window - trail the publication context so abandonment restores it even if cleanup is interrupted.
% Source IDs and owner bags contain no mutable program terms. The engine's
% own primitive is the write: it trails the entry and restores on the
% ordinary exit, so failure, an exception, a cut and a redo all unwind
% through the trail and an inner restore cannot overwrite an outer scope's
% undo record. The pair this was, a `b_setval/2` in a setup_call_cleanup/3
% Setup, put the write one call port before the cleanup was registered,
% which is the window the ledger entry names and the prolog-static rule
% refuses. Transaction rollback cannot resurrect an already closed scope.
with_source_publication_context(Context, Goal) :-
    metta_with_trailed('$metta_source_publication', Context, Goal).

%The same journal decision hoisted out of a run: the context lookup and the
%owner-pin unwrap happen once, and the run's store loop journals each
%reference against the answer with one indexed assert, or skips outright.
%The two must stay one policy: journal_data_ref(L, R) for the L this
%answers writes exactly the row record_source_atom_assertion(R) writes.
journal_load_now(Load) :-
    b_getval('$metta_source_publication', source_context(_, _, _, Load)).

journal_data_ref(none, _) :- !.
journal_data_ref(Load, Ref) :-
    assertz(source_load_assertion(Load, stored, Ref)).

%The load an assertion made RIGHT NOW would be charged to, or none. The
%deferral door records this beside each waiting definition, because the
%definition's clauses are only asserted when something first calls it, and
%that can be inside a DIFFERENT load, on another thread, or nowhere at all.
current_owning_source_load(Load) :-
    (   b_getval('$metta_source_publication', source_context(Loads, _, _, _)),
        member(Load0, Loads),
        Load0 \= '$metta_owner_pin'(_)
    ->  Load = Load0
    ;   Load = none
    ).

%The source a derived artifact made HERE AND NOW belongs to, and the revision
%of that source's text. Written for anything that keeps a record ALONGSIDE a
%compile, a diagnostic or a warning or a coverage row, and needs a reload of
%the source to REPLACE its old set instead of accumulating a second one.
%
%The charge is record_source_assertion/1's, pin UNWRAPPED, and it has to be
%that one: a clause journalled through that door is withdrawn when the OWNING
%file reloads, so an identity naming whichever file happened to force the work
%would print one path and die with another. A deferred equation first called
%inside an unrelated import is exactly that case, which is why the pin exists.
%
%Two digest tables, because the owning load may be OPEN or CLOSED.
%source_load_digest/3 is written at the load's own read and retracted in its
%cleanup, so it answers while the file is still compiling; metta_source_load/4
%is written at publish and answers afterwards, which is every pinned owner. The
%pair is exhaustive: publish_source_load/3 throws rather than let a load finish
%without having read its own source, so a load that ran has a row in one.
%
%`immediate` is support_recompile_pending/3's word for this absence and `none`
%is journal_load_now/1's. A definition asserted outside every load has no
%source revision and answering so is the point: a caller wanting
%replace-on-change for one has to key it on the definition, because nothing
%about a source can.
%
%DETERMINISTIC and total. A caller asking what it is compiling for gets an
%answer or the named absence, never a failure it could read as "nothing here".
current_source_identity(Key, Revision) :-
    (   journal_load_now(Load),
        Load \== none,
        source_load_identity(Load, Path, Digest)
    ->  Key = file(Path),
        Revision = Digest
    ;   Key = immediate,
        Revision = none
    ).

source_load_identity(Load, Path, Digest) :-
    (   source_load_digest(Load, P, D)
    ->  Path = P, Digest = D
    ;   metta_source_load(P, _, Load, D)
    ->  Path = P, Digest = D
    ).

%Run Goal with the source-load JOURNAL charging LOAD, whatever load is
%active here and now. A deferred equation's compiled clause belongs to the
%source that DEFINED it: journalled under the load that happened to force
%it, a reload of that unrelated file withdrew the clause. Pinning the
%CLOSED owning load is the point: its journal rows are exactly what
%withdrawal walks when the OWNING file is reloaded, so the materialised
%clauses leave with their definitions. A rollback for a closed load never
%runs, so the pin cannot widen any failure. The context keeps the marked pin
%on its load stack and caches the unwrapped journal owner. Queries that skip
%pins still reach the nearest real load beneath it.
:- meta_predicate with_owning_source_load(+, 0).
with_owning_source_load(Load, Goal) :-
    source_publication_load_context(Load, '$metta_owner_pin'(Load), Context),
    with_source_publication_context(Context, Goal).

%A receipt consults the source journal rather than the support graph because
%its dependencies are physical source-load and clause-reference identities,
%not derived logical nodes. An erased storage reference remains in the journal
%and therefore makes the receipt stale after commit; a transaction rollback
%preserves the reference and therefore preserves the receipt.
source_load_receipt_current(CanonPath, Space, LoadId, Digest) :-
    metta_source_load(CanonPath, Space, LoadId, Digest),
    metta_source_digest(CanonPath, CurrentDigest),
    CurrentDigest == Digest,
    forall(source_load_assertion(LoadId, stored, Ref),
           stored_atom_of_ref(Ref, _, _, _)).

% Support edges created while a source is loading belong to that load just as
% its executable and provenance clauses do. A failed load therefore erases
% the graph rows it added instead of leaving stale dependencies behind.
:- multifile support_graph:support_assertions_tracked/0.
support_graph:support_assertions_tracked :-
    source_recompile_owners(_).
support_graph:support_assertions_tracked :-
    active_source_load(_).

:- multifile support_graph:support_assertion_record/1.
support_graph:support_assertion_record(Ref) :-
    record_source_assertion(Ref).

% The compiled-form publisher creates several adjacent graph clauses. One
% ownership row retains their references as a group, cutting per-edge loader
% bookkeeping while rollback still erases every clause precisely.
:- multifile support_graph:support_assertion_records/1.
support_graph:support_assertion_records(Refs) :-
    record_source_support_assertions(Refs).

%One pass over the stored equations answers the whole batch. Repairing each
%function separately walked every equation in the system once per function, so
%a load that repaired several paid that scan several times. The recompiled set
%is the union either way, and recompiling rebuilds clauses from stored source
%without changing translated_from, so a single snapshot answers the same set.
run_source_repairs(LoadId) :-
    findall(F, source_load_repair(LoadId, F), Functions0),
    sort(Functions0, Functions),
    transaction(
        ( repair_stale_definitions_batch(Functions),
          repair_support_invalidations(LoadId) )).

repair_stale_definitions_batch([]) :- !.
repair_stale_definitions_batch(Functions) :-
    findall(Node,
            ( member(F, Functions), support_function_node(F, Node) ),
            Nodes0),
    sort(Nodes0, Nodes),
    support_invalidate_many(Nodes).

%Newest first, so an assertion is undone before whatever it was built on.
%
%A reference that is already gone is not an error here, and it arrives two
%ways: erase/1 THROWS on one kind and FAILS on another. The catch alone was
%enough while the only caller was a failed load, whose references are all still
%live. A withdrawal reaches this after metta_remove_atom/3 has already taken
%the equations out, so several references are erased before the sweep starts,
%and a failing erase/1 made forall/2 fail and took the whole withdrawal down
%with it [measured 2026-08-19: it reported one atom and then failed].
rollback_source_load(LoadId) :-
    with_typing_policy_stable(
        ( source_load_function_names(LoadId, Names),
          rollback_source_load_stable(LoadId, rollback_source_owned_space, Names) )).

:- meta_predicate rollback_source_load_stable(+, 1, +).
rollback_source_load_stable(LoadId, ReleaseSpace, Names) :-
    source_typing_policy_modules(LoadId, PolicyModules),
    findall(Module-Name,
            ( source_load_assertion(LoadId, stored, Ref),
              stored_atom_of_ref(Ref, Space, [':', Name, _], _),
              atom(Name), space_module(Space, Module) ),
            TypeLookups0),
    sort(TypeLookups0, TypeLookups),
    findall(F,
            ( source_load_assertion(LoadId, stored, Ref),
              stored_atom_of_ref(Ref, _, [=, [F|_], _], _),
              atom(F) ),
            Functions0),
    sort(Functions0, Functions),
    findall(Refs,
            source_load_support_assertions(LoadId, Refs),
            SupportGroups),
    forall(retract(source_load_resource(LoadId, translator_rule(Name, Ref))),
           translator_rules:rollback_source_translator_rule(Name, Ref)),
    forall(( member(Refs, SupportGroups), member(Ref, Refs) ),
           ( catch(erase(Ref), _, true) -> true ; true )),
    findall(Ref, retract(source_load_assertion(LoadId, _, Ref)), Asserted),
    reverse(Asserted, Refs),
    forall(member(Ref, Refs),
           ( catch(erase(Ref), _, true) -> true ; true )),
    findall(Space,
            retract(source_load_resource(LoadId, owned_space(Space))),
            Owned0),
    reverse(Owned0, Owned),
    forall(member(Space, Owned), call(ReleaseSpace, Space)),
    retractall(source_load_resource(LoadId, _)),
    with_owning_source_load(none, restore_surviving_source_functions(Names)),
    forall(member(Module, PolicyModules), typing_policy_changed(Module)),
    support_prune_orphans,
    repair_after_source_rollback(Functions),
    repair_type_aliases_after_rollback(TypeLookups),
    retractall(source_load_support_assertions(LoadId, _)),
    retractall(source_load_assertion(LoadId, _, _)),
    retractall(source_load_resource(LoadId, _)).

% Cleanup already owns these exact reference groups. Attempt every reference,
% including stale ones and duplicates, and preserve the established policy
% that one failed cleanup does not abandon the rest of a failed source load.
retire_source_artifacts([]).
retire_source_artifacts([Ref|Refs]) :-
    ( catch(erase(Ref), _, true) -> true ; true ),
    retire_source_artifacts(Refs).

repair_type_aliases_after_rollback(_) :- current_transaction(_), !.
repair_type_aliases_after_rollback(Lookups) :-
    transaction(
        forall(member(Module-Name, Lookups),
               type_alias_lookup_changed(Module, Name))).

release_source_owned_space(Space) :-
    % A Scope tombstone reserves an identity through foreign_space/1 but owns
    % no live native storage. Another owner may already have released this
    % allocation, so only its surviving storage requires teardown.
    (   spaces:native_storage_module_cache(Space, _)
    ->  metta_release_space(Space)
    ;   true
    ).

rollback_source_owned_space(Space) :-
    (   once('get-atoms'(Space, _))
    ->  throw(error(permission_error(replace, fast_cache_owned_space, Space),
                    context(rollback_source_load/1,
                            'the cache child has caller-added atoms; remove \c
                             them before replacing its source image')))
    ;   metta_release_space(Space)
    ).

source_typing_policy_modules(LoadId, Modules) :-
    findall(Module,
            ( source_load_assertion(LoadId, _, Ref),
              type_rules:typing_rule_reference_module(Ref, Module) ),
            Modules0),
    sort(Modules0, Modules).

%A failed first load has no enclosing database transaction, yet one of its
%definitions may already have made an older caller recompile.  Once the failed
%definition is erased, invalidate its live function views again so those
%callers rebuild against the restored registry.  A replacement load already
%runs inside replacing_previous_load/4's transaction; its rollback restores
%the old callers itself, and an inner repair would only be discarded with it.
%Keeping this transaction around the dependency repair, instead of around the
%whole source load, also keeps definitions visible to hyperpose worker threads
%while a file's runnable forms execute [tested:
%filereader_source_rollback:failed_late_definition_does_not_recompile_existing_callers;
%examples/ch17-concurrency-and-the-loop/04-thin_forms.metta; commit=b77e3ce5233e5f6032cfc8546ff83ecf4dc3de87].
repair_after_source_rollback([]) :- !.
repair_after_source_rollback(_) :-
    current_transaction(_),
    !.
repair_after_source_rollback(Functions) :-
    transaction(
        ( repair_stale_definitions_batch(Functions),
          repair_support_invalidations )).

rethrow_metta_file_error(_, Error) :- control_exception(Error), !,
                                      throw(Error).
rethrow_metta_file_error(_, Error) :- Error = error(_, context(_, _)), !,
                                      throw(Error).
rethrow_metta_file_error(Filename, error(Type, _)) :- !,
                                                      throw(error(Type, context(Filename, 'while loading MeTTa file'))).
rethrow_metta_file_error(_, Error) :- throw(Error).

:- thread_initialization(
       nb_setval('$metta_source_publication', source_context([], [], [], none))).
