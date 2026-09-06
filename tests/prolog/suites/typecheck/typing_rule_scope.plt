% Purpose: fix the REACH of a user typing rule, in both directions a rule can
%   overreach: across the pairs of one module, and across the lives of one
%   execution module.
% Assumes: each case owns its space and releases it; the named space is used
%   where a second life of one module has to be observed, because releasing a
%   gensym name does not hand the same name back at this layer.
% Guarantees:
%   - a module holding a user rule still answers the ordinary BadArgType for
%     every pair that rule says nothing about, and the named refusal still
%     replaces it for the pair the rule does name
%     [tested: typing_rule_scope:a_user_rule_that_names_no_refusal_leaves_the_ordinary_one,
%     typing_rule_scope:a_named_refusal_replaces_the_ordinary_one_for_its_own_pair;
%     commit=WORKTREE].
%   - releasing a space retires the user typing rules declared in it, so the
%     next life of that execution module checks under the shipped policy
%     [tested: typing_rule_scope:a_released_space_retires_the_typing_rules_declared_in_it,
%     typing_rule_scope:the_next_life_of_a_released_module_answers_the_ordinary_refusal;
%     commit=WORKTREE].
% Owns resources: setup/cleanup releases each space; no file is written.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(typing_rule_scope).

context(Space, Module) :-
    'new-space'(Space),
    space_module(Space, Module).

named_context(Space, Module) :-
    space_module(Space, Module).

release_quietly(Space) :-
    catch(metta_release_space(Space), _, true).

run_in(Space, Source, Answers) :-
    setup_call_cleanup(asserta(filereader:silent(true), Ref),
                       process_metta_string(Source, Answers, Space),
                       erase(Ref)).

answers_in(Module, Term, Answers) :-
    with_metta_module(Module, findall(Answer, eval(Term, Answer), Answers)).

%A declared arrow, a value of the declared type and a value of a KNOWN and
%different type, which is the pair every case below asks about.
typed_source(
"(: concrete (-> Number Atom))
(= (concrete $x) (got $x))
(: held (-> Bespoke Atom))
(= (held $x) (kept $x))
(: b Bespoke)").

ordinary_refusal(['Error', [concrete, "s"],
                  ['BadArgType', 1, 'Number', 'String']]).

%%%%%%%%%% One module: which pairs a rule reaches %%%%%%%%%%

%The rule below refuses `(Bespoke, Bespoke)` and says nothing about
%`(String, Number)`. Before this, the module's FIRST user rule silenced every
%ordinary refusal in it: the named-refusal clause committed on the mere
%EXISTENCE of a user rule and then failed, so `(concrete "s")` answered
%nothing at all, neither `(got "s")` nor an error.
test(a_user_rule_that_names_no_refusal_leaves_the_ordinary_one,
     [setup(context(S, M)), cleanup(release_quietly(S))]) :-
    typed_source(Source),
    run_in(S, Source, _),
    ordinary_refusal(Refusal),
    answers_in(M, [concrete, "s"], Before),
    assertion(Before == [Refusal]),
    run_in(S, "!(add-typing-rule! plunit-scope-elsewhere ordinary \c
               Bespoke Bespoke (refuse denied))", [true]),
    answers_in(M, [concrete, "s"], After),
    assertion(After == [Refusal]).

test(a_named_refusal_replaces_the_ordinary_one_for_its_own_pair,
     [setup(context(S, M)), cleanup(release_quietly(S))]) :-
    typed_source(Source),
    run_in(S, Source, _),
    answers_in(M, [held, b], Accepted),
    assertion(Accepted == [[kept, b]]),
    run_in(S, "!(add-typing-rule! plunit-scope-own ordinary \c
               Bespoke Bespoke (refuse denied))", [true]),
    answers_in(M, [held, b], Refused),
    assertion(Refused == [['Error', [held, b],
                           ['BadArgType', 1, 'Bespoke', 'Bespoke',
                            ['TypingRuleRefusal', 'plunit-scope-own',
                             denied]]]]),
    %And the ordinary refusal of the OTHER pair is still answered beside it,
    %which is what makes the two decisions independent rather than ordered.
    ordinary_refusal(Ordinary),
    answers_in(M, [concrete, "s"], Beside),
    assertion(Beside == [Ordinary]).

%%%%%%%%%% One module: which lives a rule reaches %%%%%%%%%%

test(a_released_space_retires_the_typing_rules_declared_in_it,
     [setup(named_context('&plunit-typing-scope-release', M)),
      cleanup(release_quietly('&plunit-typing-scope-release'))]) :-
    Space = '&plunit-typing-scope-release',
    run_in(Space, "!(add-typing-rule! plunit-scope-released ordinary \c
                   Bespoke Bespoke (refuse denied))", [true]),
    assertion(raw_registered_typing_rule(user, M, 'plunit-scope-released',
                                         _, _, _, _)),
    metta_release_space(Space),
    assertion(\+ raw_registered_typing_rule(user, M, _, _, _, _, _)).

%The next life of a released name runs in the SAME execution module, which is
%what makes a surviving rule a wrong answer rather than dead data: the Python
%surface POOLS anonymous space names, so an inherited rule re-decides the
%argument checks of a program that never declared it.
test(the_next_life_of_a_released_module_answers_the_ordinary_refusal,
     [setup(named_context('&plunit-typing-scope-reuse', First)),
      cleanup(release_quietly('&plunit-typing-scope-reuse'))]) :-
    Space = '&plunit-typing-scope-reuse',
    run_in(Space, "!(add-typing-rule! plunit-scope-reused ordinary \c
                   Bespoke Bespoke (refuse denied))", [true]),
    metta_release_space(Space),
    space_module(Space, Second),
    assertion(Second == First),
    typed_source(Source),
    run_in(Space, Source, _),
    ordinary_refusal(Refusal),
    answers_in(Second, [concrete, "s"], Answers),
    assertion(Answers == [Refusal]),
    %The inherited rule is gone rather than merely outvoted: the pair it named
    %is accepted again.
    answers_in(Second, [held, b], Accepted),
    assertion(Accepted == [[kept, b]]).

:- end_tests(typing_rule_scope).
