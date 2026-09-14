% Purpose: recognize parametric space values without binding open source terms.
% Guarantees: classification preserves variables and cached execution keeps
% every sibling's identity [tested: run_tests(space_value_recognition); commit=WORKTREE].
% Owns resources: plunit cleanup releases each explicit name and its query home.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(space_value_recognition).

recognition_names(Names) :-
    findall(['plunit-space-value', Parameter],
            member(Parameter, ["tenant", tenant, true, 1, 1.0, 0.0, -0.0,
                               [nested, "tenant"]]), Names).

recognition_setup(Home, Names) :-
    'new-space'(Home),
    recognition_names(Names),
    forall(nth0(Index, Names, Name),
           ( metta_declare_parametric_space(Name),
             metta_add_atom(Name, [entry, Index], true) )).

recognition_cleanup(Home, Names) :-
    maplist(metta_release_space, Names),
    metta_release_space(Home).

test(an_open_name_is_not_a_recognized_value,
     [ setup(recognition_setup(Home, Names)),
       cleanup(recognition_cleanup(Home, Names)),
       forall(member(Candidate,
                     [ _, ['plunit-space-value', _], [_, "tenant"],
                       ['plunit-space-value'|_],
                       ['plunit-space-value', [nested, _]] ])) ]) :-
    copy_term(Candidate, Original),
    ( metta_space_operand(Candidate) -> Recognized = true ; Recognized = false ),
    assertion(Recognized == false),
    assertion(Candidate =@= Original).

test(classification_does_not_choose_a_registered_instance,
     [ setup(recognition_setup(Home, Names)),
       cleanup(recognition_cleanup(Home, Names)) ]) :-
    space_module(Home, Module),
    metta_engine_module(Engine),
    Candidate = ['plunit-space-value', _],
    forall(member(Goal,
                  [ get_type_candidate(Candidate, _),
                    get_type_candidate_in(Module, Candidate, _),
                    scoped_type_candidate(Home, Module, Candidate, _),
                    metatype_of(Candidate, _) ]),
           ( copy_term(Candidate, Original),
             ( once(Engine:Goal) -> true ; true ),
             assertion(Candidate =@= Original) )).

test(is_space_leaves_an_open_name_as_an_expression,
     [ setup(recognition_setup(Home, Names)),
       cleanup(recognition_cleanup(Home, Names)) ]) :-
    Candidate = ['plunit-space-value', Parameter],
    'is-space'(Candidate, Result),
    assertion(Result == false),
    assertion(var(Parameter)),
    'get-metatype'(Candidate, Metatype),
    assertion(Metatype == 'Expression'),
    assertion(var(Parameter)).

test(translation_keeps_the_parameter_it_abstracted,
     [ setup(recognition_setup(Home, Names)),
       cleanup(recognition_cleanup(Home, Names)) ]) :-
    space_module(Home, Module),
    Source = ['get-atoms', ['plunit-space-value', 1]],
    translator:translation_template(Source, Template, _),
    copy_term(Template, Original),
    with_metta_module(Module,
        translator:translate_runnable_expr(Template, Goals, Value)),
    assertion(Template =@= Original),
    Template = Source,
    findall(Value, call_goals_in(Module, Goals), Answers),
    assertion(Answers == [[entry, 3]]).

test(cached_reads_preserve_every_sibling_name,
     [ setup(recognition_setup(Home, Names)),
       cleanup(recognition_cleanup(Home, Names)) ]) :-
    space_module(Home, Module),
    forall(nth0(Index, Names, Name),
           ( with_metta_module(Module,
                 translator:translate_cached_expr(['get-atoms', Name],
                                                  Goals, Value)),
             findall(Value, call_goals_in(Module, Goals), Answers),
             assertion(Answers == [[entry, Index]]) )).

test(registered_values_retain_types_and_relational_enumeration,
     [ setup(recognition_setup(Home, Names)),
       cleanup(recognition_cleanup(Home, Names)) ]) :-
    forall(member(Name, Names),
           ( assertion(metta_space_operand(Name)),
             'get-type'(Name, Type), assertion(Type == 'SpaceType'),
             'get-metatype'(Name, Metatype), assertion(Metatype == 'Grounded') )),
    findall(['plunit-space-value', Parameter],
            spaces:space_parametric(['plunit-space-value', Parameter]), Found),
    assertion(Found == Names).

:- end_tests(space_value_recognition).
