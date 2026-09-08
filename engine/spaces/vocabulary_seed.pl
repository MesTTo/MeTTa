/* Purpose: compile the shipped vocabulary's type atoms into their physical
   &metta storage clauses.
   Assumes: spaces:metta_vocabulary_seed_context/0 admitted the initial catalog
   before this file was loaded. Load through
   spaces:metta_publish_every_vocabulary_type/0.
   Guarantees: seed_rows/1 depends on metta_catalog_preset/1 and the shipped
   name mapping, never on live catalog rows. Its ordered atoms equal ordinary
   publication and remain removable dynamic facts [tested:
   catalog_vocabulary_bootstrap; commit=32650f9ff4d1c4aa0749d8eb8b153e5bb448ee5c].
   Owns resources: dynamic &metta clauses, removed by the ordinary catalog
   mutation doors or released with the Prolog process.
   Fails when: loaded directly; it bypasses admission and row-change observers.
*/
:- module(catalog_vocabulary_seed, []).

:- dynamic '$metta_atoms:&metta':'&metta'/3.
:- multifile '$metta_atoms:&metta':'&metta'/3.
:- discontiguous '$metta_atoms:&metta':'&metta'/3.

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

seed_clause(Row, '$metta_atoms:&metta':Fact) :- Fact =.. ['&metta'|Row].

%The declaration becomes facts in the QLF, like library(record)'s generated
%accessors [source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/record.pl#L541;
%commit=32650f9ff4d1c4aa0749d8eb8b153e5bb448ee5c]. The source predicates above remain the independent recipe the
%differential compares with ordinary publication.
term_expansion(metta_vocabulary_seed, Clauses) :-
    seed_rows(Rows), maplist(seed_clause, Rows, Clauses).

metta_vocabulary_seed.
