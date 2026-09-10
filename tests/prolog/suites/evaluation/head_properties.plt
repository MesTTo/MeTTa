% Purpose: check common claims, defining origins and reflection without demand.
% Owns resources: each fixture releases its receiver and home and deletes its source.
% Guarantees: source changes cannot leave a fabricated origin line
%   [tested: head_properties; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(head_properties).

properties_setup :-
    properties_setup("; source position fixture\n(internal properties-private)\n(@doc properties-visible (@desc \"visible documentation\"))\n(= (properties-visible $x) (+ $x 1))\n(= (properties-visible 0) 9)\n(= (properties-private) hidden)\n").

properties_setup(Text) :-
    metta_host_set_silent(true), tmp_file(properties, Stem),
    atom_concat(Stem, '.metta', Path),
    setup_call_cleanup(open(Path, write, Out),
        format(Out, '~s', [Text]),
        close(Out)),
    atom_concat('&library:', Path, Home), gensym('&properties-', Receiver),
    space_module(Receiver, Module),
    with_metta_module(Module, 'pragma!'(load, lazy, _)),
    metta_add_atom(Receiver, [from,Path,[prefix,'alias.']], _),
    nb_setval(properties_fixture, fixture(Path, Home, Receiver)).

properties_cleanup :-
    nb_getval(properties_fixture, fixture(Path, Home, Receiver)),
    metta_release_space(Receiver), metta_release_space(Home), delete_file(Path),
    nb_delete(properties_fixture), metta_host_set_silent(false).

test(origins_follow_aliases_and_keep_occurrences_without_compiling,
     [setup(properties_setup), cleanup(properties_cleanup)]) :-
    nb_getval(properties_fixture, fixture(Path, Home, Receiver)), atom_string(Path, File),
    assertion(spaces:deferred_metta_function('properties-visible',_,Home,_,_,_)),
    findall(P, evalc(['get-property','alias.properties-visible'], Receiver, P), Properties),
    findall(L, member([origin,Home,File,L],Properties), Lines), assertion(Lines == [4,5]),
    assertion(memberchk([visibility,'public'],Properties)),
    assertion(memberchk([doc,['@desc',"visible documentation"]],Properties)),
    assertion(spaces:deferred_metta_function('properties-visible',_,Home,_,_,_)).

test(internal_occurrences_and_engine_catalog_visibility_share_the_door,
     [setup(properties_setup), cleanup(properties_cleanup)]) :-
    nb_getval(properties_fixture, fixture(_, Home, Receiver)),
    assertion(metta_head_property(Home,'properties-private',[visibility,internal])),
    assertion(\+ metta_head_property(Receiver,'alias.properties-private',[origin|_])),
    once(metta_engine:metta_contract_fact([visibility,Internal,'INTERNAL'])),
    assertion(metta_head_property('&self',Internal,[visibility,internal])).

test(origins_group_arities_and_skip_declarations_runnables_and_other_heads,
     [setup(properties_setup("(: properties-many (-> Number Number))\n(= (properties-many $x) $x)\n(= (properties-other) other)\n!(+ 1 2)\n(= (properties-many) zero)\n(= (properties-many 0) 9)\n")),
      cleanup(properties_cleanup)]) :-
    nb_getval(properties_fixture, fixture(Path, Home, Receiver)), atom_string(Path, File),
    metta_head_origins(Receiver,'alias.properties-many',Origins),
    assertion(Origins == [[Home,File,5],[Home,File,2],[Home,File,6]]),
    assertion(spaces:deferred_metta_function('properties-many',_,Home,_,_,_)),
    metta_head_origins(Receiver,'absent-property-head',Missing),
    assertion(Missing == []).

test(origin_of_delegates_without_forcing_a_definition,
     [setup(properties_setup), cleanup(properties_cleanup)]) :-
    nb_getval(properties_fixture, fixture(Path, Home, Receiver)), atom_string(Path, File),
    library(lib_reflect, Library), once('import!'(Receiver,Library,true)),
    findall(Origin,evalc(['origin-of','alias.properties-visible'],Receiver,Origin),Origins),
    assertion(Origins == [[origin,Home,File,4],[origin,Home,File,5]]),
    assertion(spaces:deferred_metta_function('properties-visible',_,Home,_,_,_)).

test(explain_and_batch_claims_read_the_same_property_bag,
     [setup(properties_setup), cleanup(properties_cleanup)]) :-
    nb_getval(properties_fixture, fixture(_, _, Receiver)),
    findall(P, metta_head_property(Receiver,'alias.properties-visible',P), Properties),
    metta_head_claims(space(Receiver),['alias.properties-visible'],Rows),
    assertion(Rows == [['alias.properties-visible',Properties]]),
    evalc([explain,['alias.properties-visible',1]],Receiver,Explanation),
    forall(member(P,Properties), assertion(memberchk(P,Explanation))).

test(a_deleted_or_edited_source_retains_its_path_and_loses_its_line,
     [setup(properties_setup), cleanup(properties_cleanup)]) :-
    nb_getval(properties_fixture, fixture(Path, Home, Receiver)), atom_string(Path, File),
    setup_call_cleanup(open(Path,write,Out),
                       format(Out,'~s',["(= (another-head) different)\n"]),close(Out)),
    metta_head_origins(Receiver,'alias.properties-visible',Origins),
    assertion(Origins == [[Home,File,-1],[Home,File,-1]]).

test(a_source_withdrawal_preserves_the_surviving_equations_actual_line,
     [setup(properties_setup), cleanup(properties_cleanup)]) :-
    nb_getval(properties_fixture, fixture(Path, Home, Receiver)), atom_string(Path, File),
    once(metta_remove_atom(Home,[=,['properties-visible',0],9],_)),
    metta_head_origins(Receiver,'alias.properties-visible',Origins),
    assertion(Origins == [[Home,File,4]]).

test(mapped_declared_effect_cost_and_deprecation_keep_the_original_name,
     [setup(properties_setup), cleanup(properties_cleanup)]) :-
    nb_getval(properties_fixture, fixture(_, _, Receiver)),
    Rows = [[effect,'properties-visible',readOnlyLookup],
            [cost,['properties-visible',_],linear,int],
            [deprecated,'properties-visible',"1.0",'replacement-visible']],
    setup_call_cleanup(maplist(properties_add_claim,Rows),
        ( assertion(metta_head_property(Receiver,'alias.properties-visible',[effect,readOnlyLookup])),
          assertion(metta_head_property(Receiver,'alias.properties-visible',[cost,linear,int])),
          assertion(metta_head_property(Receiver,'alias.properties-visible',
                        [deprecated,"1.0",'replacement-visible'])) ),
        maplist(properties_remove_claim,Rows)).

properties_add_claim(Row) :- metta_add_atom('&metta',Row,_).
properties_remove_claim(Row) :- metta_remove_atom('&metta',Row,_).

test(unrelated_rows_do_not_change_a_named_definition_claim_cost,
     [setup(metta_host_set_silent(true)), cleanup(metta_host_set_silent(false))]) :-
    forall(member(Shape,[application,symbol]),
        ( properties_claim_cost(Shape,256,Small),
          properties_claim_cost(Shape,4096,Large),
          assertion(Large < 2*Small) )).

properties_claim_cost(Shape,Count,Cost) :-
    gensym('&properties-cost-',Space), space_module(Space,Module),
    setup_call_cleanup(true,
        ( findall(['properties-unrelated',N],between(1,Count,N),Rows),
          spaces:metta_add_atoms(Space,Rows),
          ( Shape == application -> Head = ['properties-cost',_] ; Head = 'properties-cost' ),
          metta_add_atom(Space,[=,Head,yes],_),
          once(metta_function_cacheable(Module,'properties-cost')),
          statistics(inferences,Before),
          forall(between(1,10,_),once(metta_function_cacheable(Module,'properties-cost'))),
          statistics(inferences,After), Cost is After-Before ),
        metta_release_space(Space)).

:- end_tests(head_properties).
