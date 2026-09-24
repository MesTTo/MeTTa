% Purpose: reproduce conflicting declarations from overlapping raw transactions.
% Assumes: argv contains an engine checkout and either rule or alias; the alias
%   mode requires structural alias support in that checkout.
% Guarantees: a message barrier opens the worker's snapshot before the main
%   thread publishes its declaration [measured 2026-09-05: both declarations
%   survive; command=swipl -q --on-error=status -s
%   tests/prolog/probes/type_declaration_snapshot.pl -g main -t halt -- . alias;
%   fixture=SWI-Prolog 10.1.13; commit=acad923476d21110870f235192757281a737ee71].
% Owns resources: the probe joins its worker, destroys its message queue,
%   removes its typing rules and releases its private space on every outcome.
% Fails when: the engine no longer allows both conflicting declarations; this
%   is a diagnostic reproduction of an unfixed limitation, not a passing gate.

main :-
    current_prolog_flag(argv, [Root, Kind]),
    memberchk(Kind, [rule, alias]),
    directory_file_path(Root, 'engine/qlf_boot.pl', Boot),
    directory_file_path(Root, 'engine/metta.pl', Engine),
    ensure_loaded(Boot),
    ensure_loaded(Engine),
    setup_call_cleanup(
        'new-space'(Space),
        ( space_module(Space, Module),
          setup_call_cleanup(message_queue_create(Ready),
                             snapshot_probe(Space, Module, Kind, Ready),
                             message_queue_destroy(Ready)) ),
        ( space_module(Space, Module),
          with_metta_module(Module,
              'remove-typing-rule!'('snapshot-probe-rule', _)),
          metta_release_space(Space) )).

snapshot_probe(Space, Module, Kind, Ready) :-
    snapshot_declarations(Kind, Space, Module, First, Second, Read, Expected),
    setup_call_cleanup(
        thread_create(
            transaction((thread_send_message(Ready, started),
                         thread_get_message(proceed),
                         call(Second))), Worker, []),
        ( thread_get_message(Ready, started),
          call(First),
          thread_send_message(Worker, proceed),
          thread_join(Worker, Status),
          call(Read, Declarations),
          format('status=~q declarations=~q~n', [Status, Declarations]),
          Status == true,
          Declarations == Expected ),
        ( catch(thread_signal(Worker, throw(snapshot_probe_cleanup)), _, true),
          catch(thread_join(Worker, _), _, true) )).

snapshot_declarations(alias, Space, _,
    metta_add_atom(Space, [':','Count',['Alias','Number']], true),
    metta_add_atom(Space, [':','Count',['Alias','String']], true),
    snapshot_aliases(Space), [['Alias','Number'],['Alias','String']]).
snapshot_declarations(rule, _, Module,
    with_metta_module(Module,
        'add-typing-rule!'('snapshot-probe-rule', ordinary,
                           'Number', 'Number', 'Accept', true)),
    with_metta_module(Module,
        'add-typing-rule!'('snapshot-probe-rule', ordinary,
                           'Number', 'Number', ['Refuse',second], true)),
    snapshot_rules(Module), ['Accept',['Refuse',second]]).

snapshot_aliases(Space, Declarations) :-
    findall(Type, match_stored(Space, [':','Count',Type], Type, _), Declarations).

snapshot_rules(Module, Declarations) :-
    findall(Outcome,
            registered_typing_rule(user, Module, 'snapshot-probe-rule',
                                   ordinary, 'Number', 'Number', Outcome),
            Declarations).
