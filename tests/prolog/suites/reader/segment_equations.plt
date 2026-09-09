% Purpose: pin sequence variables in equation heads through compiled and
%   variable-headed dynamic calls.
% Guarantees: a declared (:seg Atom) run stays held at every tested arity
%   [tested: segment_equations; commit=WORKTREE].
% Assumes: run from tests/prolog, which is what check.sh does; the relative
%   engine path resolves against that directory.
% Guarantees:
%   - nested and empty captures project as expressions
%     [tested: segment_equations:nested_and_zero_length_segments_project_as_expressions;
%     commit=37e23dcdaafd0bcf218b31a8a6455bcd59d645cc]
%   - `(:seg $x)` in a body splices while ordinary `$x` projects one expression
%     [tested: segment_equations:a_written_rhs_segment_splices_its_bound_run;
%     commit=37e23dcdaafd0bcf218b31a8a6455bcd59d645cc]
%   - a top-level segment changes call arity, and every split is shortest-first
%     [tested: segment_equations:top_level_segment_accepts_zero_arguments_and_wider_arities,
%     segment_equations:two_segments_enumerate_splits_shortest_first; commit=37e23dcdaafd0bcf218b31a8a6455bcd59d645cc]
%   - ordinary overlapping rules remain additive
%     [tested: segment_equations:segment_and_ordinary_rules_remain_additive_in_source_order;
%     commit=37e23dcdaafd0bcf218b31a8a6455bcd59d645cc]
%   - one name can occur in segment and ordinary roles in an equation head
%     [tested: segment_equations:a_segment_name_projects_in_an_ordinary_head_position;
%     commit=37e23dcdaafd0bcf218b31a8a6455bcd59d645cc]
%   - the compiled and variable-headed dynamic doors answer alike
%     [tested: segment_equations:the_compiled_and_variable_headed_doors_answer_alike;
%     commit=37e23dcdaafd0bcf218b31a8a6455bcd59d645cc]
%   The one-sided binding rule and the parse-then-instantiate staging were
%   adopted from an earlier reference semantics. Upstream PeTTa at the parity
%   pin has no reading to compare them against: a gap in an equation head is a
%   literal child there, so `(= (allof (:seg $xs)) ...)` compiles to a
%   one-argument function and `!(allof a b)` raises
%   `Domain error: function_input_arities(allof,[1])`
%   [measured 2026-09-07 against upstream PeTTa at
%   ae66fa8e41dcd5539d614706bd4e5cfb34f9608d;
%   docs/journal/2026-09-07-sequence-variables-in-the-corpus.md carries the run]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

segment_source(Source, Answers) :-
    with_output_to(string(_), process_metta_string(Source, Answers)).

segment_equation_term(Name, Term) :-
    metta_host_stored('&self', Term),
    Term = [=, [Head|_], _],
    nonvar(Head),
    Head == Name.

forget_segment_function(Name) :-
    findall(Term, segment_equation_term(Name, Term), Terms),
    forall(member(Term, Terms), metta_remove_atom('&self', Term, _)),
    findall(Declaration,
            ( metta_host_stored('&self', Declaration),
              Declaration = [':', Head, _],
              nonvar(Head),
              Head == Name ),
            Declarations),
    forall(member(Declaration, Declarations),
           metta_remove_atom('&self', Declaration, _)).

:- begin_tests(segment_equations).

test(nested_and_zero_length_segments_project_as_expressions,
     [ cleanup(( forget_segment_function('pl-seg-nested'),
                 forget_segment_function('pl-seg-zero') )) ]) :-
    segment_source(
        "(: pl-seg-nested (-> Atom Atom))\n\c
         (= (pl-seg-nested (outer (inner left (:seg $xs) right) tail)) $xs)\n\c
         (: pl-seg-zero (-> Atom Atom))\n\c
         (= (pl-seg-zero (head (:seg $xs) tail)) $xs)", _),
    segment_source("!(pl-seg-nested (outer (inner left a b right) tail))",
                   [[a, b]]),
    segment_source("!(pl-seg-zero (head tail))", [[]]).

test(a_written_rhs_segment_splices_its_bound_run,
     [ cleanup(forget_segment_function('pl-seg-splice')) ]) :-
    segment_source(
        "(: pl-seg-splice (-> Atom Atom))\n\c
         (= (pl-seg-splice (head (:seg $xs) tail))\n\c
            (rebuilt before (:seg $xs) after))", _),
    segment_source("!(pl-seg-splice (head a b tail))",
                   [[rebuilt, before, a, b, after]]).

test(top_level_segment_accepts_zero_arguments_and_wider_arities,
     [ cleanup(forget_segment_function('pl-seg-all')) ]) :-
    segment_source(
        "(: pl-seg-all (-> (:seg Atom) Atom))\n\c
         (= (pl-seg-all (:seg $xs)) (quote $xs))", _),
    segment_source("!(pl-seg-all)", [[quote, []]]),
    segment_source("!(pl-seg-all a)", [[quote, [a]]]),
    segment_source("!(pl-seg-all a b)", [[quote, [a, b]]]).

test(two_segments_enumerate_splits_shortest_first,
     [ cleanup(forget_segment_function('pl-seg-split')) ]) :-
    segment_source(
        "(: pl-seg-split (-> Atom Atom))\n\c
         (= (pl-seg-split (row (:seg $before) SEP (:seg $after)))\n\c
            (quote (pair $before $after)))", _),
    segment_source("!(pl-seg-split (row a SEP b SEP c))", Answers),
    assertion(Answers == [[quote, [pair, [a], [b, 'SEP', c]]],
                          [quote, [pair, [a, 'SEP', b], [c]]]]).

test(segment_and_ordinary_rules_remain_additive_in_source_order,
     [ cleanup(forget_segment_function('pl-seg-overlap')) ]) :-
    segment_source(
        "(: pl-seg-overlap (-> Atom Atom))\n\c
         (= (pl-seg-overlap (row (:seg $xs))) segment-branch)\n\c
         (= (pl-seg-overlap $leaf) ordinary-branch)", _),
    segment_source("!(collapse (pl-seg-overlap (row a b)))",
                   [['segment-branch', 'ordinary-branch']]).

test(a_segment_name_projects_in_an_ordinary_head_position,
     [ cleanup(forget_segment_function('pl-seg-mixed')) ]) :-
    segment_source(
        "(: pl-seg-mixed (-> Atom Atom))\n\c
         (= (pl-seg-mixed ((:seg $xs) tag $xs)) yes)", _),
    segment_source("!(pl-seg-mixed (a b tag (a b)))", [yes]),
    segment_source("!(pl-seg-mixed (tag ()))", [yes]),
    %A call that matches no equation FAILS rather than answering itself, so
    %the non-matching row has no answer at all [source: PeTTa@ae66fa8, whose
    %equations compile to Prolog clauses; measured 2026-08-30].
    segment_source("!(pl-seg-mixed (a b tag (a c)))", []).

test(the_compiled_and_variable_headed_doors_answer_alike,
     [ cleanup(forget_segment_function('pl-seg-doors')) ]) :-
    segment_source(
        "(: pl-seg-doors (-> Atom Atom))\n\c
         (= (pl-seg-doors (row (:seg $before) SEP (:seg $after)))\n\c
            (quote (pair $before $after)))", _),
    segment_source("!(pl-seg-doors (row a SEP b SEP c))", Compiled),
    segment_source("!(let $f pl-seg-doors ($f (row a SEP b SEP c)))",
                   Dynamic),
    assertion(Dynamic == Compiled).

test(the_reference_stratego_one_rule_rebuilds_the_successful_child,
     [ cleanup(( forget_segment_function('pl-seg-child'),
                 forget_segment_function('pl-seg-one') )) ]) :-
    segment_source(
        "(: pl-seg-child (-> Atom Atom))\n\c
         (= (pl-seg-child b) B)\n\c
         (= (pl-seg-child $x) Empty)\n\c
         (: pl-seg-one (-> Atom Atom Atom))\n\c
         (= (pl-seg-one $strategy ((:seg $before) $child (:seg $after)))\n\c
            (function\n\c
              (chain (metta ($strategy $child) %Undefined% &self) $child-result\n\c
                (return ((:seg $before) $child-result (:seg $after))))))\n\c
         (= (pl-seg-one $strategy $leaf) Empty)", _),
    segment_source("!(collapse (pl-seg-one pl-seg-child (a b c)))",
                   [[[a, 'B', c]]]).

:- end_tests(segment_equations).
