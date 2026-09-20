% Purpose: verify sequence-variable (gap) parsing, fragment classification,
%   the three certified-finite solvers, the refusal fence, and the space door,
%   against the three fragments Kutsia proved finite.
% Guarantees:
%   - `...` and `(:seg $x)` parse to gaps and every other marker-shaped term
%     stays data, root included [tested: segments_parsing].
%   - the classifier answers the right case for each fragment and
%     refuses outside them, naming the rule [tested: segments_fragments].
%   - each solver answers what the calculus for its fragment answers,
%     including the shortest-first split order and the open remainder a
%     two-sided answer
%     keeps [tested: segments_one_sided, segments_last_position,
%     segments_linear_shallow].
%   - distinct `...` occurrences never constrain each other, a repeated named
%     gap has to take a runtime-equal run, and a repeated named gap is admitted
%     where the fragment permits one and refused where it does not
%     [tested: segments_identity, segments_last_position].
%   - a gap query reads a native store through its own arity window and its
%     head index, and a stored marker is data rather than a gap
%     [tested: segments_space_door].
%   - a gap-free pattern reaches no predicate of the gap unit at all, which is
%     what makes the feature free [tested: segments_costs_nothing].
%   - a WRITTEN `unify` reaches every fragment and every refusal, because that
%     door parses both operands: the four two-sided shapes answer what their
%     calculus answers, the trivial identity answers what the arbiter answers,
%     and no_certificate is reachable [tested: segments_written_pairs].
% Fails when: the two layers are read as one. segments_last_position and
%   segments_linear_shallow call metta_seq_unify/3 with two PARSED sides, which
%   pins each SOLVER: its multiplicity, its shortest-first order, its occurs
%   check and the sharing an open remainder keeps, none of which a surface
%   answer shows. segments_written_pairs runs written MeTTa source through
%   filereader:process_metta_string/2, which pins the DOOR: which fragment a
%   written pair reaches and what it answers. A change to metta_seq_pair_plan/4
%   moves the second and not the first.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

%Read one MeTTa term and parse it as a pattern side. Both halves matter: sread
%gives the surface the program wrote, and metta_seq_parse/2 is what decides
%which markers in it are live gaps.
parsed(Text, Parsed) :-
    sread(Text, Term),
    spaces:metta_seq_parse(Term, Parsed).

%Two sides of ONE read, so a name written on both shares its variable. Reading
%them separately is the trap: `$x` in two sreads is two variables, and the
%linearity and mixed-role rules both decide by identity.
pair(Text, Left, Right) :-
    sread(Text, [_, LeftTerm, RightTerm]),
    spaces:metta_seq_parse(LeftTerm, Left),
    spaces:metta_seq_parse(RightTerm, Right).

%Every answer of one solver, as the runs its gaps took.
runs(Case, Left, Right, Runs) :-
    findall(Left, spaces:metta_seq_unify(Case, Left, Right), Runs).

refusal(Left, Right, Message) :-
    catch(( spaces:metta_seq_classify(Left, Right, Case),
            Message = admitted(Case) ),
          error(Error, _),
          message_text(Error, Message)).

message_text(Error, Message) :-
    (   phrase(prolog:error_message(Error), Parts),
        with_output_to(string(Text),
                       print_message_lines(current_output, '', Parts))
    ->  Message = Text
    ;   Message = Error
    ).

%sub_string/5 with every position open can match at several offsets, so a bare
%call leaves a choicepoint the plunit gate fails a test for.
mentions(Message, Text) :-
    string(Message),
    once(sub_string(Message, _, _, _, Text)).

%Written MeTTa source, run the way the corpus runs it: the file reader's own
%string door translates each directive and evaluates it, so a test written this
%way asks exactly what `sh tools/run.sh` asks and reaches the doors a program reaches
%[source: engine/filereader.pl, process_metta_string/2]. The engine prints its
%compilation unless started with the quiet flag, which a test run is not.
written_all(Source, Results) :-
    with_output_to(string(_), filereader:process_metta_string(Source, Results)).

%One directive's answers.
written(Source, Answers) :-
    written_all(Source, [Answers]).

%The refusal a written ask carries, or admitted(Answers) when it carries none.
%A refusal is thrown at the ASK rather than while the source loads, so it
%arrives here as the error the door would have given a program.
written_reason(Source, Reason) :-
    catch(( written(Source, Answers), Reason = admitted(Answers) ),
          error(metta_seq_outside_fragment(_, _, _, Why), _),
          Reason = Why).

:- begin_tests(segments_parsing).

%The two spellings the law recognises, and nothing else.
test(both_spellings_parse_to_gaps) :-
    parsed('(A ... D)', Anonymous),
    parsed('(A (:seg $x) D)', Named),
    Anonymous = ['A', AnonymousGap, 'D'],
    Named = ['A', NamedGap, 'D'],
    AnonymousGap = '$metta_seg'(_, anon),
    NamedGap = '$metta_seg'(_, named).

%A colon-seg expression whose second position is not a variable is ordinary
%data, which is the recogniser's own condition.
test(a_bound_second_position_is_data) :-
    parsed('(A (:seg foo) D)', Parsed),
    Parsed == ['A', [':seg', foo], 'D'].

%The root of a side is never a gap.
test(the_root_is_never_a_gap) :-
    sread('(:seg $r)', Term),
    spaces:metta_seq_parse(Term, Parsed),
    Parsed = [':seg', Variable],
    var(Variable).

%A gap arriving through a BINDING is data, and the mechanism that makes it so
%is WHEN the question is asked: a pattern whose marker sits behind a variable
%is gap-free at the moment its call site compiles, so it keeps the ordinary
%door and the marker the variable later carries is matched as the atom it is
%as the ordinary parse rule requires.
test(a_marker_behind_a_variable_is_not_a_gap) :-
    sread('(A $p D)', Term),
    \+ spaces:metta_seq_present(Term),
    %And the door that answer selects still matches the marker as the atom it
    %is, which is what a program relying on the data reading needs.
    metta_add_atom('&j5late', ['A', '...', 'D'], _),
    Term = ['A', Slot, 'D'],
    Slot = '...',
    findall(x, match('&j5late', Term, x, x), Answers),
    Answers == [x],
    metta_remove_atom('&j5late', ['A', '...', 'D'], _).

test(a_gap_free_pattern_reports_no_gap) :-
    sread('(A $x (inner b))', Term),
    \+ spaces:metta_seq_present(Term).

test(a_nested_gap_is_reported) :-
    sread('(A (inner ...))', Term),
    spaces:metta_seq_present(Term).

:- end_tests(segments_parsing).

:- begin_tests(segments_fragments).

%The classifier's own dispatch order: a gap-free side first, then last
%position, then linear-shallow.
test(a_gap_free_side_is_one_sided) :-
    parsed('(A ... D)', Left),
    sread('(A b c D)', Right),
    spaces:metta_seq_classify(Left, Right, Case),
    Case == one_sided(left).

test(the_gap_free_side_may_be_either) :-
    pair('(pair (a b c) (a ... c))', Left, Right),
    spaces:metta_seq_classify(Left, Right, Case),
    Case == one_sided(right).

%Kutsia Section 6.3: every gap the last child of its own expression.
test(trailing_gaps_are_last_position) :-
    pair('(pair (f a (:seg $u)) (f a b (:seg $v)))', Left, Right),
    spaces:metta_seq_classify(Left, Right, Case),
    Case == last_position.

%Kutsia Section 6.2: every gap a direct child of the root, every named gap
%linear across the pair.
test(root_level_linear_gaps_are_linear_shallow) :-
    pair('(pair (f (:seg $u) b) (f a (:seg $v)))', Left, Right),
    spaces:metta_seq_classify(Left, Right, Case),
    Case == linear_shallow.

%The commuting equation Kutsia's Theorem 62 refutes: `X u = u X` has the family
%X = u^n for every n, so no complete finite answer set exists and the engine
%refuses rather than searching.
test(the_commuting_equation_refuses) :-
    pair('(pair (f (:seg $x) a) (f a (:seg $x)))', Left, Right),
    refusal(Left, Right, Message),
    mentions(Message, "outside the proved finitary fragment"),
    mentions(Message, "Theorem 62"),
    mentions(Message, "metta_seq_classify/3").

%A two-sided pair whose gaps are neither all final nor all shallow.
test(a_nested_two_sided_gap_refuses) :-
    pair('(pair (f (g (:seg $u) b)) (f (g a (:seg $v))))', Left, Right),
    refusal(Left, Right, Message),
    mentions(Message, "outside the proved finitary fragment").

%One name may not play both roles.
test(a_mixed_role_name_refuses) :-
    parsed('(f (:seg $m) $m)', Left),
    sread('(f a b)', Right),
    refusal(Left, Right, Message),
    mentions(Message, "mixed_roles").

%A name in both roles on OPPOSITE sides is the same mix.
test(a_mixed_role_across_sides_refuses) :-
    pair('(pair (f (:seg $m)) (f $m))', Left, Right),
    refusal(Left, Right, Message),
    mentions(Message, "mixed_roles").

:- end_tests(segments_fragments).

:- begin_tests(segments_one_sided).

%A gap consumes every possible run, SHORTEST FIRST. Two gaps around a
%separator therefore enumerate the splits in increasing prefix length.
test(splits_enumerate_shortest_first) :-
    parsed('($pre ... SEP ... $post)', Left),
    sread('(a b SEP c SEP d)', Right),
    findall(Run,
            (   spaces:metta_seq_unify(one_sided(left), Left, Right),
                Left = [_, '$metta_seg'(Run, _)|_]
            ),
            Runs),
    Runs == [[b], [b, 'SEP', c]].

test(a_gap_takes_the_empty_run) :-
    parsed('(A ... D)', Left),
    sread('(A D)', Right),
    runs(one_sided(left), Left, Right, Answers),
    Answers == [['A', '$metta_seg'([], anon), 'D']].

test(a_named_gap_answers_its_run_as_an_expression) :-
    parsed('(A (:seg $mid) D)', Left),
    sread('(A b c D)', Right),
    Left = [_, '$metta_seg'(Run, _), _],
    once(spaces:metta_seq_unify(one_sided(left), Left, Right)),
    Run == [b, c].

test(a_nested_gap_matches_below_the_root) :-
    parsed('(f (g ...) b)', Left),
    sread('(f (g 1 2) b)', Right),
    runs(one_sided(left), Left, Right, Answers),
    Answers == [[f, [g, '$metta_seg'([1, 2], anon)], b]].

%A ground clash refutes wherever the split puts it.
test(a_clash_refutes_every_split) :-
    parsed('(A ... D)', Left),
    sread('(A b c E)', Right),
    runs(one_sided(left), Left, Right, Answers),
    Answers == [].

:- end_tests(segments_one_sided).

:- begin_tests(segments_identity).

%Distinct `...` occurrences are distinct variables, so one taking a run says
%nothing about the other.
test(distinct_anonymous_gaps_do_not_constrain_each_other) :-
    parsed('(f ... g ...)', Left),
    sread('(f a g b c)', Right),
    findall(First-Second,
            (   spaces:metta_seq_unify(one_sided(left), Left, Right),
                Left = [_, '$metta_seg'(First, _), _, '$metta_seg'(Second, _)]
            ),
            Answers),
    Answers == [[a]-[b, c]].

%A repeated NAMED gap accepts exactly a runtime-equal run.
test(a_repeated_named_gap_takes_the_same_run) :-
    parsed('(f (:seg $x) g (:seg $x))', Left),
    sread('(f a b g a b)', Right),
    Left = [_, '$metta_seg'(Run, _)|_],
    once(spaces:metta_seq_unify(one_sided(left), Left, Right)),
    Run == [a, b].

test(a_repeated_named_gap_refutes_a_different_run) :-
    parsed('(f (:seg $x) g (:seg $x))', Left),
    sread('(f a b g c)', Right),
    runs(one_sided(left), Left, Right, Answers),
    Answers == [].

%The runtime comparison, not syntactic equality: 1 and 1.0 agree here as they
%do at every other atom position.
test(a_repeated_run_compares_the_engines_way) :-
    parsed('(f (:seg $x) g (:seg $x))', Left),
    sread('(f 1 g 1.0)', Right),
    runs(one_sided(left), Left, Right, Answers),
    Answers \== [].

:- end_tests(segments_identity).

:- begin_tests(segments_last_position).

%Kutsia Section 6.3 is deterministic and unitary: one answer or none. A gap
%facing a longer side takes the whole remainder, and a remainder that still
%holds a gap keeps it as the marker that would match it.
test(a_trailing_gap_absorbs_the_remainder) :-
    pair('(pair (f a (:seg $u)) (f a b (:seg $v)))', Left, Right),
    Left = [_, _, '$metta_seg'(Run, _)],
    Right = [_, _, _, '$metta_seg'(Open, _)],
    %once/1 rather than findall/3, because the open remainder in the answer IS
    %the other gap's own variable and findall would copy that sharing away.
    once(spaces:metta_seq_unify(last_position, Left, Right)),
    Run = [b, [':seg', Same]],
    Same == Open.

%Deterministic and unitary: Kutsia Section 6.3 answers once or not at all.
test(the_last_position_procedure_answers_once) :-
    pair('(pair (f a (:seg $u)) (f a b (:seg $v)))', Left, Right),
    findall(x, spaces:metta_seq_unify(last_position, Left, Right), Answers),
    Answers == [x].

test(a_trailing_gap_takes_the_empty_run) :-
    pair('(pair (f a b) (f a b (:seg $v)))', Left, Right),
    Right = [_, _, _, '$metta_seg'(Run, _)],
    findall(Run, spaces:metta_seq_unify(last_position, Left, Right), Answers),
    Answers == [[]].

test(a_shorter_fixed_side_refutes) :-
    pair('(pair (f a b) (f a c (:seg $v)))', Left, Right),
    findall(x, spaces:metta_seq_unify(last_position, Left, Right), Answers),
    Answers == [].

%LINEARITY IS NOT REQUIRED HERE. Kutsia Section 6.3 asks only that every gap be
%the last child of its own expression, so a NAMED gap may occur twice, and the
%second occurrence then solves its stored run against what it faces rather than
%demanding the two were written the same way. That is what applying the
%substitution to the worklist does in the calculus
%[source: Kutsia Section 6.3].
test(a_repeated_gap_solves_its_stored_run_against_the_second_face) :-
    pair('(pair (f (g (:seg $x)) (h (:seg $x))) (f (g (:seg $y)) (h b)))',
         Left, Right),
    Left = [_, [_, '$metta_seg'(Repeated, _)], _],
    Right = [_, [_, '$metta_seg'(Once, _)], _],
    once(spaces:metta_seq_unify(last_position, Left, Right)),
    Repeated == [b],
    Once == [b].

%The linear-shallow fragment DOES require it, and a pair that is neither final
%nor linear has no certificate at all.
test(a_repeated_root_gap_has_no_linear_shallow_certificate) :-
    pair('(pair (f (:seg $x) a) (f a (:seg $x)))', Left, Right),
    spaces:metta_seq_gaps(Left, 0, LeftGaps, []),
    spaces:metta_seq_gaps(Right, 0, RightGaps, []),
    \+ spaces:metta_seq_linear_shallow(LeftGaps, RightGaps).

%The occurs check the calculus carries: a gap whose run mentions the gap
%itself is a term containing itself, except for the trivial identity.
test(a_self_referential_run_refutes) :-
    pair('(pair (f (:seg $u)) (f a (:seg $u)))', Left, Right),
    findall(x, spaces:metta_seq_unify(last_position, Left, Right), Answers),
    Answers == [].

test(the_trivial_identity_holds) :-
    pair('(pair (f (:seg $u)) (f (:seg $u)))', Left, Right),
    findall(x, spaces:metta_seq_unify(last_position, Left, Right), Answers),
    Answers == [x].

:- end_tests(segments_last_position).

:- begin_tests(segments_linear_shallow).

%The widening calculus, projection first [source: Kutsia Section 6.2].
test(two_root_gaps_solve_to_their_runs) :-
    pair('(pair (f (:seg $u) b) (f a (:seg $v)))', Left, Right),
    Left = [_, '$metta_seg'(U, _), _],
    Right = [_, _, '$metta_seg'(V, _)],
    findall(U-V, spaces:metta_seq_unify(linear_shallow, Left, Right), Answers),
    Answers == [[a]-[b]].

test(a_gap_facing_a_longer_side_widens) :-
    pair('(pair (f (:seg $u) c) (f a b c))', Left, Right),
    Left = [_, '$metta_seg'(U, _), _],
    findall(U, spaces:metta_seq_unify(linear_shallow, Left, Right), Answers),
    Answers == [[a, b]].

test(a_flex_flex_pair_relates_the_two_gaps) :-
    pair('(pair (f (:seg $u)) (f (:seg $v)))', Left, Right),
    Left = [_, '$metta_seg'(U, _)],
    findall(U, spaces:metta_seq_unify(linear_shallow, Left, Right), Answers),
    Answers = [_|_].

%Two gaps can absorb each other's fixed items, so a refutation needs a clash no
%split can repair: both sides end in a settled child and they disagree.
test(a_trailing_clash_refutes_every_widening) :-
    pair('(pair (f (:seg $u) a) (f (:seg $v) b))', Left, Right),
    findall(x, spaces:metta_seq_unify(linear_shallow, Left, Right), Answers),
    Answers == [].

%And the widening does relate two gaps across settled children when it can.
test(gaps_absorb_each_others_settled_children) :-
    pair('(pair (f (:seg $u) (g a)) (f (g b) (:seg $v)))', Left, Right),
    Left = [_, '$metta_seg'(U, _), _],
    Right = [_, _, '$metta_seg'(V, _)],
    findall(U-V, spaces:metta_seq_unify(linear_shallow, Left, Right), Answers),
    Answers == [[[g, b]]-[[g, a]]].

:- end_tests(segments_linear_shallow).

:- begin_tests(segments_written_pairs).

%THE DOOR RATHER THAN THE SOLVER. `unify` is the one form whose two operands
%are both syntax, so it is the only written ask that can carry a gap on both
%sides. Until 2026-09-07 metta_unify_decision/3 parsed the left operand alone,
%the classifier read the right side's markers as ordinary structure and
%answered one_sided(left) for every pair, and each shape below answered as a
%one-sided match that failed. metta_seq_pair_plan/4 parses both, so each test
%here names the fragment its shape belongs to and asserts what that fragment's
%calculus answers, through the same door a MeTTa program uses.

%last_position, and the pre-parsed twin is a_trailing_gap_takes_the_empty_run:
%the right side is longer by exactly its gap, so the gap takes the empty run.
test(a_trailing_gap_on_the_right_takes_the_empty_run) :-
    written("!(collapse (unify (f a b) (f a b (:seg $v)) $v none))", Answers),
    Answers == [[]].

%last_position again, and the fragment's own point: a repeated NAME is admitted
%here, and its second occurrence solves the run its first took against what it
%faces rather than demanding the two were written alike. The pre-parsed twin is
%a_repeated_gap_solves_its_stored_run_against_the_second_face.
test(a_repeated_trailing_name_solves_across_the_pair) :-
    written("!(collapse (unify (f (g (:seg $x)) (h (:seg $x))) \c
                                (f (g (:seg $y)) (h b)) $x none))",
            Answers),
    Answers == [[b]].

%linear_shallow: two root gaps, each taking the other side's fixed child. The
%pre-parsed twin is two_root_gaps_solve_to_their_runs.
test(two_root_gaps_solve_to_their_runs_through_the_door) :-
    written("!(collapse (unify (f (:seg $u) b) (f a (:seg $v)) ($u $v) no))",
            Answers),
    Answers == [[[a], [b]]].

%linear_shallow with a settled EXPRESSION on each side, which the widening
%calculus absorbs whole. The pre-parsed twin is
%gaps_absorb_each_others_settled_children.
test(root_gaps_absorb_each_others_settled_children_through_the_door) :-
    written("!(collapse (unify (f (:seg $u) (g a)) \c
                                (f (g b) (:seg $v)) ($u $v) no))",
            Answers),
    Answers == [[[[g, b]], [[g, a]]]].

%The trivial identity, which Kutsia Section 6.3 keeps as trivial rather than as
%a clash. It refused for mixed_roles until this door parsed both sides, because
%the unparsed right side put `$u` in the classifier's ORDINARY list; `$u` plays
%one role on both sides and the pair is admitted. This is the one row where the
%repair moves this engine INTO agreement with the arbiter, which has no reading
%of a gap at all and so unifies two identical expressions
%[measured 2026-09-07: `sh tools/run.sh` on `!(collapse (unify (f (:seg $u))
%(f (:seg $u)) yes no))` after `!(import! &self ../lib/lib_he)` in the upstream
%PeTTa checkout at ae66fa8e41dcd5539d614706bd4e5cfb34f9608d answers `(yes)`;
%this engine answered a mixed_roles refusal before the repair and `(yes)` after
%it].
test(the_trivial_identity_answers_yes_as_the_arbiter_does) :-
    written("!(collapse (unify (f (:seg $u)) (f (:seg $u)) yes no))", Answers),
    Answers == [yes].

%A gap written on the RIGHT ALONE is a gap too: the classifier is symmetric, so
%it answers one_sided(right) and the solver matches the gap side against the
%closed one.
test(a_gap_on_the_right_alone_matches_the_other_way) :-
    written("!(collapse (unify (f a b) (f a (:seg $v)) $v none))", Answers),
    Answers == [[b]].

%no_certificate, the classifier's third outcome, which no written ask could
%reach while every pair classified one_sided(left). Kutsia's own infinitary
%witness reaches it: `X u = u X` has the family X = u^n for every n, its gaps
%are on both sides, and they are neither all final nor linear.
test(the_commuting_equation_reaches_no_certificate) :-
    written_reason("!(collapse (unify (f (:seg $x) a) (f a (:seg $x)) yes no))",
                   Reason),
    Reason == no_certificate.

%And a gap below the root on both sides, outside the shallow fragment for the
%other reason: depth rather than linearity.
test(a_nested_two_sided_gap_reaches_no_certificate) :-
    written_reason("!(collapse (unify (f (g (:seg $u) b)) \c
                                       (f (g a (:seg $v))) yes no))",
                   Reason),
    Reason == no_certificate.

%The mixed-role rule still fires where the roles really are mixed, so the
%identity row's repair narrowed the rule rather than removing it.
test(a_name_in_both_roles_still_refuses) :-
    written_reason("!(collapse (unify (f (:seg $m) $m) \c
                                       (f a (:seg $n)) yes no))",
                   Reason),
    Reason == mixed_roles.

%An OPEN operand takes the pattern's SURFACE, with each unsolved gap rendered
%back to the marker that would match it. Binding the parsed side instead would
%publish this engine's own '$metta_seg'/2 term into a program's answer.
test(an_open_operand_takes_the_patterns_surface) :-
    written("!(collapse (unify $q (f a (:seg $v)) $q no))", Answers),
    Answers = [Answer],
    Answer = [f, a, [':seg', _]].

%A SPACE operand makes the ask a gap QUERY, so the two doors answer the same
%rows for the same written pattern.
test(a_space_operand_answers_the_gap_query) :-
    metta_add_atom('&j5pair', [friend, 'Bob', 'Alice'], _),
    metta_add_atom('&j5pair', [friend, 'Carol', 'Alice'], _),
    written_all("!(collapse (match &j5pair (friend (:seg $who)) $who))\n\c
                 !(collapse (unify &j5pair (friend (:seg $who)) $who none))",
                [Matched, Unified]),
    Matched == [['Bob', 'Alice'], ['Carol', 'Alice']],
    Unified == Matched,
    metta_remove_atom('&j5pair', [friend, 'Bob', 'Alice'], _),
    metta_remove_atom('&j5pair', [friend, 'Carol', 'Alice'], _).

%THE FREE HALF. An operand with no written gap opens no walk at all, so a
%gap-free `unify` emits the plain matcher it always emitted and pays what it
%always paid.
test(a_gap_free_pair_emits_the_plain_matcher) :-
    sread('(unify (f a b) (f a b) yes no)', [_, Left, Right, _, _]),
    translator:metta_unify_decision(Left, Right, Goal),
    Goal == metta_match_atoms([f, a, b], [f, a, b]).

%And the repair itself, read off the emitted goal: the left operand rides
%wrapped in the fragment the two sides decided, and the right operand is handed
%over PARSED rather than as written.
test(a_written_pair_hands_the_solver_both_parsed_sides) :-
    sread('(unify (f a b) (f a b (:seg $v)) $v none)', [_, Left, Right, _, _]),
    translator:metta_unify_decision(Left, Right, Goal),
    Goal = metta_match_atoms('$metta_seq'(Case, ParsedLeft), ParsedRight),
    Case == one_sided(right),
    ParsedLeft == [f, a, b],
    ParsedRight = [f, a, b, '$metta_seg'(_, named)].

:- end_tests(segments_written_pairs).

:- begin_tests(segments_space_door).

%The arity a gap pattern matches is what the gap decides, so the store is read
%across every arity its fixed part admits and the pattern's own head still
%selects the relation through the store's first-argument index.
test(a_gap_query_reads_every_admissible_arity) :-
    metta_add_atom('&j5door', ['A', b, c, 'D'], _),
    metta_add_atom('&j5door', ['A', 'D'], _),
    metta_add_atom('&j5door', ['B', b, 'D'], _),
    spaces:metta_seq_query_plan(['A', '...', 'D'], Asked),
    findall(x, match('&j5door', Asked, x, x), Answers),
    length(Answers, Matched),
    Matched == 2,
    metta_remove_atom('&j5door', ['A', b, c, 'D'], _),
    metta_remove_atom('&j5door', ['A', 'D'], _),
    metta_remove_atom('&j5door', ['B', b, 'D'], _).

%A marker STORED as an atom is data, never a gap, which is the frozen-subject
%reading.
test(a_stored_marker_is_data) :-
    metta_add_atom('&j5stored', ['A', '...', 'D'], _),
    spaces:metta_seq_query_plan(['A', '...', 'D'], Asked),
    findall(x, match('&j5stored', Asked, x, x), Answers),
    Answers == [x],
    sread('(A ... D)', Literal),
    findall(y, match('&j5stored', Literal, y, y), Literals),
    Literals == [y],
    metta_remove_atom('&j5stored', ['A', '...', 'D'], _).

%A refusal is CARRIED in the plan and thrown at the ask, so a query nothing
%evaluates cannot stop a file from loading.
test(a_refused_plan_throws_at_the_ask) :-
    sread('(f (:seg $m) $m)', Pattern),
    spaces:metta_seq_query_plan(Pattern, Asked),
    Asked = '$metta_seq'(refused(_), _),
    catch(( match('&j5refuse', Asked, x, x), Outcome = answered ),
          error(Error, _),
          Outcome = Error),
    Outcome = metta_seq_outside_fragment(_, _, _, mixed_roles).

:- end_tests(segments_space_door).

:- begin_tests(segments_costs_nothing).

%The claim the feature rests on: a pattern with no gap never reaches the gap
%unit, because the walk that lifts modifiers answers the question on the way
%past and the two doors dispatch on a wrapper a gap-free pattern never carries.
test(a_gap_free_pattern_is_handed_over_untouched) :-
    translator:lift_pattern_modifiers([fact, X, [inner, Y]], Lifted, Guards,
                                      Segments),
    Segments == false,
    Guards == [],
    Lifted == [fact, X, [inner, Y]].

%And the door itself: an unwrapped pattern takes the clause it always took.
test(an_unwrapped_pattern_never_reaches_the_gap_door) :-
    metta_add_atom('&j5free', [edge, 1, 2], _),
    findall(x, match('&j5free', [edge, 1, 2], x, x), Answers),
    Answers == [x],
    metta_remove_atom('&j5free', [edge, 1, 2], _).

:- end_tests(segments_costs_nothing).
