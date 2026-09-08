/* Purpose: compile the shipped vocabulary's type atoms into an inert payload
   the catalog publishes into &metta through the native write funnel, one
   minted occurrence token per row.
   Assumes: spaces:metta_vocabulary_seed_context/0 admitted the initial catalog
   before this file was loaded. Load through
   spaces:metta_publish_every_vocabulary_type/0.
   Guarantees: seed_rows/1 depends on metta_catalog_preset/1 and the shipped
   name mapping, never on live catalog rows; seed_payload/1 is those rows
   compiled, and publish_seed/0 stores them in the recipe's order through
   spaces:add_sexp_in/5, so every row carries a token this process minted and
   remains a removable dynamic clause; the published rows equal ordinary
   publication in order [tested: catalog_vocabulary_bootstrap; commit=WORKTREE].
   Owns resources: dynamic &metta clauses, removed by the ordinary catalog
   mutation doors or released with the Prolog process.
   Fails when: loaded directly; it bypasses admission and row-change observers.
   Decides: the rows are published through the storage funnel rather than
   compiled as storage clauses, because a compiled clause cannot carry the
   token the running actor mints, the ruling
   docs/journal/2026-09-07-every-fact-has-a-token.md records for static
   caches; what the compiled form still buys is the recipe's evaluation and
   the per-row admission the guard proves unnecessary.
*/
:- module(catalog_vocabulary_seed, [publish_seed/0]).

seed_rows(Rows) :-
    findall(Vocab, spaces:metta_catalog_preset([vocabulary, Vocab|_]), Names0),
    sort(Names0, Names),
    findall(Row, (member(Vocab, Names), seed_row(Vocab, Row)), Rows0),
    list_to_set(Rows0, Rows).

seed_row(Vocab, Row) :-
    ( spaces:metta_catalog_preset(['vocabulary-type', Vocab, Written])
    -> Type = Written
    ;  spaces:metta_camel_name(Vocab, Type) ),
    (   Row = [':', Type, 'Type']
    ;   ( spaces:metta_catalog_preset([vocabulary, Vocab|Members]),
          member(Member, Members)
        ; spaces:metta_catalog_preset(['vocabulary-member', Vocab, Member]) ),
        Row = [':', Member, Type]
    ;   spaces:metta_catalog_preset(['vocabulary-order', Vocab|Chain]),
        seed_order_edge(Chain, Row)
    ).

seed_order_edge([Narrow, Wide|Rest], Row) :-
    ( Row = [':<', Narrow, Wide]
    ; seed_order_edge([Wide|Rest], Row) ).

%The recipe's rows become one fact in the QLF, like library(record)'s
%generated accessors [source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/record.pl#L541;
%commit=32650f9ff4d1c4aa0749d8eb8b153e5bb448ee5c]. The source predicates above remain the independent recipe the
%differential compares with ordinary publication.
term_expansion(metta_vocabulary_seed, [seed_payload(Rows)]) :-
    seed_rows(Rows).

metta_vocabulary_seed.

%Each row goes through the storage funnel, which mints its token; the
%catalog's admission and observers are skipped, since the seed context
%proved the catalog untouched and unwatched.
publish_seed :-
    seed_payload(Rows),
    spaces:ensure_native_storage_module('&metta', Module),
    forall(member(Row, Rows), spaces:add_sexp_in(Module, '&metta', Row, _, _)).
