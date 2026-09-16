% Purpose: expose provider metadata lost during concurrent inherited import removal.
% Assumes: plain SWI-Prolog, with no repository engine or workaround loaded.
% Guarantees: the last line is present when the provider loses its clause count
%   or meta declaration while its original clause remains [tested:
%   sh check.sh host-workarounds; commit=518e67bc11d72ed28dfda7dd0646d1f48d14ac24]
%   [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14 as shipped,
%   absent on 10.1.14 built with tests/checks/host_workarounds/swi-concurrent-import-removal-resets-provider.patch;
%   command=sh check.sh host-workarounds;
%   fixture=SWI-Prolog 10.1.14 with the patch; commit=ca22f73782c1cc9ef159e18eeb2036e8bb6045b7].
% Owns resources: two finite worker threads, joined before inspecting metadata.
:- module(import_removal_probe, [main/0, sample/1]).
:- meta_predicate sample(0).

sample(Goal) :- call(Goal).

% Retain the child Procedure before its default module can resolve this call.
read_child :- import_removal_child:sample(true).

main :-
    set_module(import_removal_child:base(import_removal_probe)),
    import_removal_child:sample(true),
    setup_call_cleanup(
        thread_create(forall(between(1, 1000000, _),
                             abolish(import_removal_child:sample/1)), Writer, []),
        ( thread_create(forall(between(1, 1000000, _), read_child), Reader, []),
          thread_join(Reader, ReaderStatus) ),
        thread_join(Writer, WriterStatus)),
    ( WriterStatus == true -> true ; throw(error(writer_failed(WriterStatus), main/0)) ),
    ( ReaderStatus == true -> true
    ; ReaderStatus = exception(error(existence_error(procedure, _), _)) -> true
    ; throw(error(reader_failed(ReaderStatus), main/0))
    ),
    findall(Body, clause(sample(_), Body), Clauses),
    ( Clauses = [call(_)] -> true ; throw(error(changed_provider(Clauses), main/0)) ),
    findall(Property, predicate_property(sample(_), Property), Properties),
    write_canonical(status(WriterStatus, ReaderStatus)), nl,
    write_canonical(Properties), nl,
    (   memberchk(number_of_clauses(1), Properties),
        memberchk(meta_predicate(_), Properties)
    ->  writeln(absent)
    ;   writeln(present)
    ).
