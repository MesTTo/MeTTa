% Purpose: the engine prelude's REGISTRY: what the vocabulary in
%   engine/prelude.pl declares about itself, and the doors that install it,
%   evict a name a program takes over, and restore an evicted one.
% Guarantees: the arrow constructor's type uses the final (:seg Type) form
%   [tested: prelude_spec; commit=6031c83ab3002b5703cb6fcb10e70a60a89f4ad7].
%
%   Until 2026-09-07 this was engine/prelude.metta, 783 lines of MeTTa parsed
%   and translated at every boot by load_engine_prelude/0. The equations are
%   now tests/data/prelude-spec.metta, the executable spec and the differential
%   oracle; the bodies are Prolog in engine/prelude.pl; and the four tables
%   below are compiled into engine/metta.qlf like every other engine clause, so
%   a boot READS them instead of deriving them
%   [measured 2026-09-07: boot 272,323 -> 248,271 inferences, -8.83%;
%   command=swipl -q -g "metta_bench:bench_run(boot)" -t halt engine/bench.pl;
%   fixture=warm .qlf, three identical samples per arm; commit=3e778d4d13f6bee7304f7500e8e914c22bd07cec].
% Assumes: engine/metta.pl consults this plain file while its owning module is
%   the load context, after engine/metta/registration.pl, whose
%   builtin_implementation/2 the facets below extend and whose
%   register_builtin_fun/1 the install door calls.
% Guarantees:
%   - prelude_shipped_equation/2 is the same 36 equations tests/data/prelude-spec.metta
%     holds, so the register a tool enumerates the shipped tier through and the
%     text a reader reads cannot drift
%     [tested: prelude_spec:the_shipped_register_is_the_spec_fixture; commit=3e778d4d13f6bee7304f7500e8e914c22bd07cec].
%   - a user definition of a prelude name still wins ENTIRELY and ONE-WAY: the
%     declaration, the document, the cost row and the translator registration
%     go, and the Prolog body stops answering because the definition compiles
%     into the space's own module and shadows the tier
%     [tested: prelude:a_user_equation_evicts_the_prelude_definition,
%     prelude_docs:eviction_takes_the_prelude_docs_with_the_name; commit=3e778d4d13f6bee7304f7500e8e914c22bd07cec].
%   - install_engine_prelude/0 is idempotent and restores exactly what eviction
%     removed, which is what lets a suite evict a name and put it back
%     [tested: prelude_derived_forms:a_user_definition_withdraws_the_registration_with_the_clauses;
%     commit=3e778d4d13f6bee7304f7500e8e914c22bd07cec].
%   - reference maps consume held names even when those names already denote
%     grounded functions [tested:
%     references:a_reference_map_accepts_a_name_that_is_already_a_grounded_function;
%     commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Fails when: a prelude_rule_registration/2 row names a head no
%   prelude_head/2 row defines. That is an inconsistency between two tables in
%   this file and it raises rather than registering a rule that would expand
%   through somebody else's predicate
%   [tested: prelude_derived_forms:a_registration_for_a_name_the_prelude_does_not_define_is_refused;
%   commit=3e778d4d13f6bee7304f7500e8e914c22bd07cec].
% Decides: the declarations land in TWO stores, prelude_type_declaration/2 for
%   the compiler's masking tier and seam:builtin_type_declaration/2 for the
%   engine's reported type surface, and the ledger prelude_wrote_builtin_type/2
%   records which rows of the second this file put there, because
%   lib_builtin_types.metta already carries three of them and retractall/1
%   cannot tell two identical rows apart.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

%%%% The registers %%%%
%
%prelude_type_declaration/2 is a third register beside type_declaration/2
%(what the program declared) and seam:builtin_type_declaration/2 (the engine's
%Prolog surface). It is consulted on the FUNCTION path, which
%seam:builtin_type_declaration deliberately is not: that register describes
%arguments a caller writes for predicates underneath (the maplist lesson,
%documented at call_site_type_chains/2), while a prelude declaration is an
%ordinary MeTTa declaration for an ordinary vocabulary head, so honouring it at
%call sites is exactly right, and it is what makes an Atom parameter like
%assertEqualToResult's arrive unevaluated. A program's own declaration is read
%first, so a user redeclaration wins.
:- dynamic prelude_type_declaration/2.
%Which names the prelude still owns. Eviction retracts one and that is what
%makes eviction one-way; installing puts it back, which is how a suite that
%evicted a name restores the engine for its neighbours.
:- dynamic prelude_owned/1.
%Which (cost ...) rows the prelude put into '&metta', as the rows themselves:
%eviction withdraws them through metta_remove_atom/3, the door whose hook the
%catalog's derived caches watch, and that door takes the term rather than a
%clause reference.
:- dynamic prelude_cost_row/2.
%Which names the prelude registered as TRANSLATOR RULES. A derived form ships
%as an expansion body plus that registration, and the registration is the
%prelude's to withdraw: a program that defines the name itself takes the whole
%form over, and a rule pointing at that program's equations would call them as
%a compile-time expander, which is not what an ordinary definition means.
:- dynamic prelude_translator_rule/1.
%The prelude's equations as TERMS, one row per (= ...) form, so a tool can
%enumerate the shipped tier without reading MeTTa source: the vocabulary is
%Prolog now and the spec fixture lives under tests/, so this register is the
%engine's own account of what its vocabulary MEANS. The effect planner reads it
%for a name whose body is inherited rather than local, which is every space's
%view of the prelude, and the confluence reporter reads it for the shipped rule
%tier.
:- dynamic prelude_equation/2.
%Which seam:builtin_type_declaration/2 rows the prelude PUT THERE, as opposed
%to found there.
:- dynamic prelude_wrote_builtin_type/2.

%%%% What the vocabulary declares about itself %%%%
%
%Five static tables, compiled into the artifact, read by install_engine_prelude/0
%below. They are the parsed form of tests/data/prelude-spec.metta and the lane
%named in this file's Guarantees holds them to it.

%The heads and their MeTTa arities. The Prolog predicate behind each has
%one more argument, the result.
prelude_head('if-equal', 4).
prelude_head(only, 2).
prelude_head(except, 2).
prelude_head(prefix, 2).
prelude_head(rename, 2).
prelude_head(qualified, 1).
prelude_head('if-equal2', 4).
prelude_head('noreduce-eq', 2).
prelude_head(assertEqual, 2).
prelude_head(assertAlphaEqual, 2).
prelude_head(assertEqualToResult, 2).
prelude_head(assertAlphaEqualToResult, 2).
prelude_head(assertIncludes, 2).
prelude_head(assertEqualMsg, 3).
prelude_head(assertAlphaEqualMsg, 3).
prelude_head(assertEqualToResultMsg, 3).
prelude_head(assertAlphaEqualToResultMsg, 3).
prelude_head('if-error', 3).
prelude_head(throw, 1).
prelude_head('return-on-error', 2).
prelude_head('for-each-in-atom', 2).
prelude_head(atomically, 1).
prelude_head(unquote, 1).
prelude_head(interpret, 3).
prelude_head('is-function', 1).
prelude_head('match-types', 4).
prelude_head('match-type-or', 3).
prelude_head('type-cast-holds', 3).
prelude_head('type-cast', 3).
prelude_head('and-then', 2).
prelude_head('or-else', 2).
prelude_head('trace!', 2).
prelude_head(unique, 1).
prelude_head('alpha-unique', 1).
prelude_head(union, 2).
prelude_head(intersection, 2).
prelude_head(subtraction, 2).

%The 40 declarations. Three of them describe engine/kernel.pl's heads:
%has-declared-type, space-contains and space-admission-verdict each carry
%an Atom mask so the atom they are asked about arrives unreduced, and this
%file is where that mask lives.
prelude_declaration('if-equal', [->, 'Atom', 'Atom', 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(only, [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(except, [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(prefix, [->, '%Undefined%', 'Atom', '%Undefined%']).
prelude_declaration(rename, [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(qualified, [->, '%Undefined%', '%Undefined%']).
prelude_declaration('if-equal2', [->, 'Atom', 'Atom', 'Atom', 'Atom', '%Undefined%']).
prelude_declaration('noreduce-eq', [->, 'Atom', 'Atom', 'Bool']).
prelude_declaration(assertEqual, [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(assertAlphaEqual, [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(assertEqualToResult, [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(assertAlphaEqualToResult, [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(assertIncludes, [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(assertEqualMsg, [->, 'Atom', 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(assertAlphaEqualMsg, [->, 'Atom', 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(assertEqualToResultMsg, [->, 'Atom', 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(assertAlphaEqualToResultMsg, [->, 'Atom', 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(function, [->, 'Atom', 'Atom']).
prelude_declaration('collapse-bind', [->, 'Atom', 'Expression']).
prelude_declaration('superpose-bind', [->, 'Expression', 'Atom']).
prelude_declaration(throw, [->, '%Undefined%', '%Undefined%']).
prelude_declaration(atomically, [->, 'Atom', '%Undefined%']).
prelude_declaration(unquote, [->, 'Atom', '%Undefined%']).
prelude_declaration(interpret, [->, 'Atom', 'Type', 'SpaceType', 'Atom']).
prelude_declaration(->, [->, [':seg', 'Type'], 'Type']).
prelude_declaration('is-function', [->, 'Type', 'Bool']).
prelude_declaration('get-type', [->, 'Atom', '%Undefined%']).
prelude_declaration('get-type-space', [->, 'SpaceType', 'Atom', '%Undefined%']).
prelude_declaration('get-doc', [->, 'Atom', '%Undefined%']).
prelude_declaration('get-property', [->, 'Atom', 'Expression']).
prelude_declaration('get-doc', [->, 'SpaceType', 'Atom', '%Undefined%']).
prelude_declaration('get-doc-atom', [->, 'SpaceType', 'Atom', '%Undefined%']).
prelude_declaration('get-doc-single-atom', [->, 'SpaceType', 'Atom', '%Undefined%']).
prelude_declaration('get-doc-function', [->, 'SpaceType', 'Atom', 'Type', '%Undefined%']).
prelude_declaration('get-doc-params', [->, 'Expression', 'Atom', 'Expression', ['Expression', 'Atom']]).
prelude_declaration('and-then', [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration('or-else', [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration('trace!', [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(unique, [->, 'Atom', '%Undefined%']).
prelude_declaration('alpha-unique', [->, 'Atom', '%Undefined%']).
prelude_declaration(union, [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(intersection, [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration(subtraction, [->, 'Atom', 'Atom', '%Undefined%']).
prelude_declaration('has-declared-type', [->, 'Atom', '%Undefined%', 'Bool']).
prelude_declaration('space-contains', [->, '%Undefined%', 'Atom', 'Bool']).
%The rows are data: an Atom result never re-enters the evaluator, which is
%what keeps a stored (+ 1 2) unevaluated and leaves no re-entry choicepoint
%(the Expression-returning collapse-bind still shows one) [tested:
%owned_record_reads:a_ground_owner_expression_is_held_as_data; commit=dbb95d0bff10a93f2fef0453195b2331918f92dc].
prelude_declaration('owned-record-read', [->, 'Atom', 'Atom']).
prelude_declaration('space-admission-verdict', [->, '%Undefined%', 'Atom', '%Undefined%']).

%The documents get-doc's first tier answers from, so (help! type-cast)
%answers with no import and a program's own (@doc ...) atoms stay the
%program's.
prelude_document('if-equal', ['@doc', 'if-equal', ['@desc', "Selects the third argument when the first two are identical by ==, and the fourth otherwise"], ['@params', [['@param', "First atom"], ['@param', "Second atom"], ['@param', "Result on equivalence"], ['@param', "Result otherwise"]]], ['@return', "Third or fourth argument"]]).
prelude_document('if-equal2', ['@doc', 'if-equal2', ['@desc', "if-equal under its second historical name"], ['@params', [['@param', "First atom"], ['@param', "Second atom"], ['@param', "Result on equivalence"], ['@param', "Result otherwise"]]], ['@return', "Third or fourth argument"]]).
prelude_document(only, ['@doc', only, ['@desc', "Keeps a head present in the supplied names; partial application is a from map"]]).
prelude_document(except, ['@doc', except, ['@desc', "Keeps a head absent from the supplied names; partial application is a from map"]]).
prelude_document(prefix, ['@doc', prefix, ['@desc', "Concatenates a prefix and a head; partial application is a from map"]]).
prelude_document(rename, ['@doc', rename, ['@desc', "Uses the first matching (old new) pair, or keeps the head; partial application is a from map"]]).
prelude_document(qualified, ['@doc', qualified, ['@desc', "Builds a prefix map using the library name and a dot"]]).
prelude_document('get-property', ['@doc', 'get-property', ['@desc', "Answers visibility, defining origins and declared effect, cost, deprecation and documentation properties, one per answer"]]).
prelude_document('owned-record-read', ['@doc', 'owned-record-read', ['@desc', "Validates a ground @owned-record key and returns zero or one complete native value rows in an expression; retired owners and malformed occurrences are refused"], ['@params', [['@param', "Ground @owned-record declaration, held as data"]]], ['@return', "Expression containing zero or one complete value rows"]]).
prelude_document('assert-answers', ['@doc', 'assert-answers', ['@desc', "Asserts a verdict about two answer bags; a false verdict reports the call as written and the two directed bag differences, what was missing and what was in excess"], ['@params', [['@param', "Verdict, evaluated"], ['@param', "Call to report, as written"], ['@param', "Answers produced"], ['@param', "Answers expected"]]], ['@return', "unit"]]).
prelude_document('assert-includes-answers', ['@doc', 'assert-includes-answers', ['@desc', "assert-answers for a containment: a false verdict reports the call as written and only the answers missing from the expectation, because an answer in excess of it is legal under this relation"], ['@params', [['@param', "Verdict, evaluated"], ['@param', "Call to report, as written"], ['@param', "Answers produced"], ['@param', "Answers expected to be included"]]], ['@return', "unit"]]).
prelude_document(assertEqual, ['@doc', assertEqual, ['@desc', "Compares the result sets of two expressions; passes silently or raises a failed assertion naming the expression and the answers missing from and in excess of the expectation"], ['@params', [['@param', "First expression, not evaluated on the way in"], ['@param', "Second expression, not evaluated on the way in"]]], ['@return', "unit"]]).
prelude_document(assertAlphaEqual, ['@doc', assertAlphaEqual, ['@desc', "assertEqual up to alpha-equivalence of the result sets"], ['@params', [['@param', "First expression"], ['@param', "Second expression"]]], ['@return', "unit"]]).
prelude_document(assertEqualToResult, ['@doc', assertEqualToResult, ['@desc', "Checks all the results of the first expression against the second expression, which is not evaluated and is read as the set of expected results"], ['@params', [['@param', "Expression to evaluate"], ['@param', "Expected results, as written"]]], ['@return', "unit"]]).
prelude_document(assertAlphaEqualToResult, ['@doc', assertAlphaEqualToResult, ['@desc', "assertEqualToResult up to alpha-equivalence"], ['@params', [['@param', "Expression to evaluate"], ['@param', "Expected results, as written"]]], ['@return', "unit"]]).
prelude_document(assertIncludes, ['@doc', assertIncludes, ['@desc', "Passes when every expected result appears among the results the first expression produces"], ['@params', [['@param', "Expression to evaluate"], ['@param', "Expected subset, as written"]]], ['@return', "unit"]]).
prelude_document(assertEqualMsg, ['@doc', assertEqualMsg, ['@desc', "assertEqual with a message argument, which the failure report carries because it reports the call as written"], ['@params', [['@param', "First expression"], ['@param', "Second expression"], ['@param', "Message"]]], ['@return', "unit"]]).
prelude_document(assertAlphaEqualMsg, ['@doc', assertAlphaEqualMsg, ['@desc', "assertAlphaEqual with a message argument, accepted and unused"], ['@params', [['@param', "First expression"], ['@param', "Second expression"], ['@param', "Message"]]], ['@return', "unit"]]).
prelude_document(assertEqualToResultMsg, ['@doc', assertEqualToResultMsg, ['@desc', "assertEqualToResult with a message argument, which the failure report carries because it reports the call as written"], ['@params', [['@param', "Expression to evaluate"], ['@param', "Expected results"], ['@param', "Message"]]], ['@return', "unit"]]).
prelude_document(assertAlphaEqualToResultMsg, ['@doc', assertAlphaEqualToResultMsg, ['@desc', "assertAlphaEqualToResult with a message argument, accepted and unused"], ['@params', [['@param', "Expression to evaluate"], ['@param', "Expected results"], ['@param', "Message"]]], ['@return', "unit"]]).
prelude_document('if-error', ['@doc', 'if-error', ['@desc', "Selects the second argument when the first is an (Error ...) expression and the third otherwise"], ['@params', [['@param', "Value to inspect"], ['@param', "Result on error"], ['@param', "Result otherwise"]]], ['@return', "Second or third argument"]]).
prelude_document('return-on-error', ['@doc', 'return-on-error', ['@desc', "Answers the first argument when it is an (Error ...) expression, stopping the computation there, and the second otherwise"], ['@params', [['@param', "Value to inspect"], ['@param', "Result when the first is not an error"]]], ['@return', "The error, or the second argument"]]).
prelude_document('for-each-in-atom', ['@doc', 'for-each-in-atom', ['@desc', "Applies a function to every element of an expression; map-atom under its historical name"], ['@params', [['@param', "Expression to walk"], ['@param', "Function to apply"]]], ['@return', "The mapped expression"]]).
prelude_document(unquote, ['@doc', unquote, ['@desc', "Unquotes a quoted atom and evaluates it, e.g. (unquote (quote $x)) evaluates $x; a non-quote argument stays as written"], ['@params', [['@param', "Quoted atom"]]], ['@return', "Unquoted atom"]]).
prelude_document('noreduce-eq', ['@doc', 'noreduce-eq', ['@desc', "Compares two atoms as written, neither evaluated"], ['@params', [['@param', "First atom, as written"], ['@param', "Second atom, as written"]]], ['@return', "True or False"]]).
prelude_document('is-function', ['@doc', 'is-function', ['@desc', "True when the argument is an arrow type"], ['@params', [['@param', "Type atom"]]], ['@return', "True or False"]]).
prelude_document('match-types', ['@doc', 'match-types', ['@desc', "Compares two types by == and returns the third argument if identical, the fourth otherwise; neither type is bound"], ['@params', [['@param', "First type"], ['@param', "Second type"], ['@param', "Result on identity"], ['@param', "Result otherwise"]]], ['@return', "Third or fourth argument"]]).
prelude_document('match-type-or', ['@doc', 'match-type-or', ['@desc', "Returns True when the second and third arguments are identical by ==, and the first argument otherwise"], ['@params', [['@param', "Accumulator value"], ['@param', "First type"], ['@param', "Second type"]]], ['@return', "True or the accumulator"]]).
prelude_document('type-cast', ['@doc', 'type-cast', ['@desc', "Casts atom passed as a first argument to the type passed as a second argument using space as a context"], ['@params', [['@param', "Atom to be casted"], ['@param', "Type to cast atom to"], ['@param', "Context atomspace"]]], ['@return', "Atom if casting is successful, (Error ... BadType) otherwise"]]).
prelude_document('type-cast-holds', ['@doc', 'type-cast-holds', ['@desc', "Whether any declared type of the atom in the space unifies with the requested type; type-cast's fold, named because MeTTa is applicative where the corelib chains"], ['@params', [['@param', "Atom"], ['@param', "Requested type"], ['@param', "Context atomspace"]]], ['@return', "True or False"]]).
prelude_document('get-type-space', ['@doc', 'get-type-space', ['@desc', "get-type run with the selected space as the context"], ['@params', [['@param', "Space to select"], ['@param', "Atom to type"]]], ['@return', "The type, as get-type answers it in that space"]]).
prelude_document('get-doc', ['@doc', 'get-doc', ['@desc', "Returns formal documentation for an atom or function in a selected space; the one-argument MeTTa overload returns the raw (@doc ...) atom"], ['@params', [['@param', "The space to search"], ['@param', "The atom or function to document"]]], ['@return', "An (@doc-formal ...) atom"]]).
prelude_document('get-doc-atom', ['@doc', 'get-doc-atom', ['@desc', "Builds formal atom documentation from prose and the selected space's type"], ['@params', [['@param', "The space to search"], ['@param', "The atom to document"]]], ['@return', "An atom-shaped (@doc-formal ...) atom"]]).
prelude_document('get-doc-single-atom', ['@doc', 'get-doc-single-atom', ['@desc', "Dispatches one atom to function or atom documentation according to its selected-space type"], ['@params', [['@param', "The space to search"], ['@param', "The atom to document"]]], ['@return', "An (@doc-formal ...) atom"]]).
prelude_document('get-doc-function', ['@doc', 'get-doc-function', ['@desc', "Builds formal function documentation by pairing parameter and return prose with an arrow type"], ['@params', [['@param', "The space to search"], ['@param', "The function name"], ['@param', "Its arrow type"]]], ['@return', "A function-shaped (@doc-formal ...) atom"]]).
prelude_document('get-doc-params', ['@doc', 'get-doc-params', ['@desc', "Pairs informal parameter and return descriptions with their types"], ['@params', [['@param', "The (@param ...) list"], ['@param', "The (@return ...) description"], ['@param', "The parameter and return types"]]], ['@return', "The formal parameter list and return description"]]).
prelude_document('get-doc-space', ['@doc', 'get-doc-space', ['@desc', "get-doc run against the selected space"], ['@params', [['@param', "Space to select"], ['@param', "The name to look up"]]], ['@return', "The (@doc ...) atom"]]).
prelude_document('help!', ['@doc', 'help!', ['@desc', "Prints the documentation for a name, the engine's own vocabulary included"], ['@params', [['@param', "The name to look up"]]], ['@return', "unit"]]).
prelude_document(documented, ['@doc', documented, ['@desc', "Every name the CURRENT SPACE documents and presents, one per solution; program-scoped on purpose, so the engine's own vocabulary does not bury yours"], ['@params', []], ['@return', "A name"]]).
prelude_document('documented-space', ['@doc', 'documented-space', ['@desc', "documented, against the selected space"], ['@params', [['@param', "Space to select"]]], ['@return', "A name"]]).
prelude_document('defined-name', ['@doc', 'defined-name', ['@desc', "Every function name the current space defines and presents, once each; builtins and names the space keeps internal are not part of its face"], ['@params', []], ['@return', "A name"]]).
prelude_document(undocumented, ['@doc', undocumented, ['@desc', "Every name the current space presents with no documentation anywhere; the gap worth closing. A name the space keeps internal, the reserved package head included, is not reported"], ['@params', []], ['@return', "A name"]]).
prelude_document('undocumented-space', ['@doc', 'undocumented-space', ['@desc', "undocumented, against the selected space"], ['@params', [['@param', "Space to select"]]], ['@return', "A name"]]).

%The cost claims, measured by the cost-rows lane. union is linear, being an
%append, while intersection, subtraction and alpha-unique each build an
%association tree of one operand and look the other up in it. unique carries
%NO row on purpose: it reduces to unique-atom, which is SWI's list_to_set/2
%and sorts in C, so the engine's inference counter reads it linear while
%retired instructions read it linearithmic, and a row would state the
%cheaper of the two.
prelude_cost_claim([cost, ['alpha-unique', [superpose, _]], linearithmic]).
prelude_cost_claim([cost, [union, [superpose, A], [superpose, A]], linear]).
prelude_cost_claim([cost, [intersection, [superpose, A], [superpose, A]], linearithmic]).
prelude_cost_claim([cost, [subtraction, [superpose, A], [superpose, A]], linearithmic]).

%The eight derived forms, and what each registration declares. Five say
%their expansion introduces let binders, which is a statement to
%engine/narrowing.pl rather than to the rewriting: none of those binders
%takes a value from the term being rewritten.
prelude_rule_registration('and-then', []).
prelude_rule_registration('or-else', []).
prelude_rule_registration('trace!', []).
prelude_rule_registration(unique, [['extra-variables-exempt', "the let binders the expansion introduces name the collapsed answer sets before the masked family operation reads them, so none takes a value from the term being rewritten"]]).
prelude_rule_registration('alpha-unique', [['extra-variables-exempt', "the let binders the expansion introduces name the collapsed answer sets before the masked family operation reads them, so none takes a value from the term being rewritten"]]).
prelude_rule_registration(union, [['extra-variables-exempt', "the let binders the expansion introduces name the collapsed answer sets before the masked family operation reads them, so none takes a value from the term being rewritten"]]).
prelude_rule_registration(intersection, [['extra-variables-exempt', "the let binders the expansion introduces name the collapsed answer sets before the masked family operation reads them, so none takes a value from the term being rewritten"]]).
prelude_rule_registration(subtraction, [['extra-variables-exempt', "the let binders the expansion introduces name the collapsed answer sets before the masked family operation reads them, so none takes a value from the term being rewritten"]]).

%The shipped equations, the parsed form of tests/data/prelude-spec.metta.
%They are what the vocabulary MEANS: the effect planner reads them for a
%name whose body is inherited rather than local, which is every space's
%view of the prelude; the confluence reporter reads the eight derived ones
%as the shipped rewrite tier; and the differential suite runs them against
%the Prolog bodies in engine/prelude.pl.
prelude_shipped_equation('if-equal', [=, ['if-equal', A, B, C, D], [if, ['==', A, B], C, D]]).
prelude_shipped_equation(only, [=, [only, Names, Head], [if, ['is-member', Head, Names], Head, [empty]]]).
prelude_shipped_equation(except, [=, [except, Names, Head], [if, ['is-member', Head, Names], [empty], Head]]).
prelude_shipped_equation(prefix, [=, [prefix, Prefix, Head], [atom_concat, Prefix, Head]]).
prelude_shipped_equation(rename, [=, [rename, Pairs, Head], [let, Cases, ['union-atom', Pairs, [[Other, Other]]], [case, Head, Cases]]]).
prelude_shipped_equation(qualified, [=, [qualified, Library], [prefix, [atom_concat, Library, '.']]]).
prelude_shipped_equation('if-equal2', [=, ['if-equal2', A, B, C, D], [if, ['==', A, B], C, D]]).
prelude_shipped_equation('noreduce-eq', [=, ['noreduce-eq', A, B], ['=alpha', A, B]]).
prelude_shipped_equation(assertEqual, [=, [assertEqual, A, B], [let, C, [collapse, A], [let, D, [collapse, B], [let, E, [==, C, D], ['assert-answers', E, [assertEqual, A, B], C, D]]]]]).
prelude_shipped_equation(assertAlphaEqual, [=, [assertAlphaEqual, A, B], [let, C, [collapse, A], [let, D, [collapse, B], [let, E, ['=alpha', C, D], [assert, E]]]]]).
prelude_shipped_equation(assertEqualToResult, [=, [assertEqualToResult, A, B], [let, C, [collapse, A], [let, D, ['subtraction-atom', B, C], [let, E, ['subtraction-atom', C, B], [let, F, ['noreduce-eq', [D, E], [[], []]], ['assert-answers', F, [assertEqualToResult, A, B], C, B]]]]]]).
prelude_shipped_equation(assertAlphaEqualToResult, [=, [assertAlphaEqualToResult, A, B], [let, C, [collapse, A], [let, D, ['=alpha', C, B], [assert, D]]]]).
prelude_shipped_equation(assertIncludes, [=, [assertIncludes, A, B], [let, C, [collapse, A], [let, D, ['subtraction-atom', B, C], [let, E, [==, D, []], ['assert-includes-answers', E, [assertIncludes, A, B], C, B]]]]]).
prelude_shipped_equation(assertEqualMsg, [=, [assertEqualMsg, A, B, C], [let, D, [collapse, A], [let, E, [collapse, B], [let, F, [==, D, E], ['assert-answers', F, [assertEqualMsg, A, B, C], D, E]]]]]).
prelude_shipped_equation(assertAlphaEqualMsg, [=, [assertAlphaEqualMsg, A, B, _], [let, C, [collapse, A], [let, D, [collapse, B], [let, E, ['=alpha', C, D], [assert, E]]]]]).
prelude_shipped_equation(assertEqualToResultMsg, [=, [assertEqualToResultMsg, A, B, C], [let, D, [collapse, A], [let, E, ['subtraction-atom', B, D], [let, F, ['subtraction-atom', D, B], [let, G, ['noreduce-eq', [E, F], [[], []]], ['assert-answers', G, [assertEqualToResultMsg, A, B, C], D, B]]]]]]).
prelude_shipped_equation(assertAlphaEqualToResultMsg, [=, [assertAlphaEqualToResultMsg, A, B, _], [assertAlphaEqualToResult, A, B]]).
prelude_shipped_equation('if-error', [=, ['if-error', A, B, C], [function, [chain, [eval, ['get-metatype', A]], D, [eval, ['if-equal', D, 'Expression', [eval, ['if-equal', A, [], [return, C], [chain, ['decons-atom', A], E, [unify, E, [F, _], [eval, ['if-equal', F, 'Error', [return, B], [return, C]]], [return, C]]]]], [return, C]]]]]]).
prelude_shipped_equation(throw, [=, [throw, A], ['if-error', A, A, ['Error', [throw, A], A]]]).
prelude_shipped_equation('return-on-error', [=, ['return-on-error', A, B], ['if-error', A, A, B]]).
prelude_shipped_equation('for-each-in-atom', [=, ['for-each-in-atom', A, B], ['map-atom', A, B]]).
prelude_shipped_equation(atomically, [=, [atomically, A], [transaction, [eval, A]]]).
prelude_shipped_equation(unquote, [=, [unquote, [quote, A]], [let, _, [cut], [eval, A]]]).
prelude_shipped_equation(unquote, [=, [unquote, A], [quote, [unquote, A]]]).
prelude_shipped_equation(interpret, [=, [interpret, A, B, C], [function, [chain, [eval, [metta, A, B, C]], D, [return, D]]]]).
prelude_shipped_equation('is-function', [=, ['is-function', A], [let, B, ['get-metatype', A], [unify, B, 'Expression', [let, C, ['size-atom', A], [unify, C, 0, false, [let, [D, _], ['decons-atom', A], [unify, D, ->, true, false]]]], false]]]).
prelude_shipped_equation('match-types', [=, ['match-types', A, B, C, D], [if, ['==', A, B], C, D]]).
prelude_shipped_equation('match-type-or', [=, ['match-type-or', A, B, C], ['match-types', B, C, true, A]]).
prelude_shipped_equation('type-cast-holds', [=, ['type-cast-holds', A, B, C], [let, D, ['__metta_type_syntax__', B, C], [let, E, [collapse, ['get-type-space', C, A]], ['foldl-atom', E, false, F, G, ['match-type-or', F, G, D]]]]]).
prelude_shipped_equation('type-cast', [=, ['type-cast', A, B, C], [let, D, ['__metta_type_syntax__', B, C], [let, E, ['get-metatype', A], [if, ['=alpha', D, E], A, [if, ['type-cast-holds', A, B, C], A, ['Error', A, 'BadType']]]]]]).
prelude_shipped_equation('and-then', [=, ['and-then', A, B], [noeval, [if, A, B, false]]]).
prelude_shipped_equation('or-else', [=, ['or-else', A, B], [noeval, [if, A, true, B]]]).
prelude_shipped_equation('trace!', [=, ['trace!', A, B], [noeval, [progn, ['println!', A], B]]]).
prelude_shipped_equation(unique, [=, [unique, A], [noeval, [let, B, [collapse, A], [let, C, ['unique-atom', B], [superpose, C]]]]]).
prelude_shipped_equation('alpha-unique', [=, ['alpha-unique', A], [noeval, [let, B, [collapse, A], [let, C, ['alpha-unique-atom', B], [superpose, C]]]]]).
prelude_shipped_equation(union, [=, [union, [superpose, A], [superpose, B]], [noeval, [let, C, [collapse, [superpose, A]], [let, D, [collapse, [superpose, B]], [let, E, ['union-atom', C, D], [superpose, E]]]]]]).
prelude_shipped_equation(union, [=, [union, A, B], [noeval, [noeval, [union, A, B]]]]).
prelude_shipped_equation(intersection, [=, [intersection, [superpose, A], [superpose, B]], [noeval, [let, C, [collapse, [superpose, A]], [let, D, [collapse, [superpose, B]], [let, E, ['intersection-atom', C, D], [superpose, E]]]]]]).
prelude_shipped_equation(intersection, [=, [intersection, A, B], [noeval, [noeval, [intersection, A, B]]]]).
prelude_shipped_equation(subtraction, [=, [subtraction, [superpose, A], [superpose, B]], [noeval, [let, C, [collapse, [superpose, A]], [let, D, [collapse, [superpose, B]], [let, E, ['subtraction-atom', C, D], [superpose, E]]]]]]).
prelude_shipped_equation(subtraction, [=, [subtraction, A, B], [noeval, [noeval, [subtraction, A, B]]]]).

prelude_builtin_facet('if-equal'/4, prolog(prelude)).
prelude_builtin_facet(only/2, prolog(prelude)).
prelude_builtin_facet(except/2, prolog(prelude)).
prelude_builtin_facet(prefix/2, prolog(prelude)).
prelude_builtin_facet(rename/2, prolog(prelude)).
prelude_builtin_facet(qualified/1, prolog(prelude)).
prelude_builtin_facet('if-equal2'/4, prolog(prelude)).
prelude_builtin_facet('noreduce-eq'/2, prolog(prelude)).
prelude_builtin_facet(assertEqual/2, prolog(prelude)).
prelude_builtin_facet(assertAlphaEqual/2, prolog(prelude)).
prelude_builtin_facet(assertEqualToResult/2, prolog(prelude)).
prelude_builtin_facet(assertAlphaEqualToResult/2, prolog(prelude)).
prelude_builtin_facet(assertIncludes/2, prolog(prelude)).
prelude_builtin_facet(assertEqualMsg/3, prolog(prelude)).
prelude_builtin_facet(assertAlphaEqualMsg/3, prolog(prelude)).
prelude_builtin_facet(assertEqualToResultMsg/3, prolog(prelude)).
prelude_builtin_facet(assertAlphaEqualToResultMsg/3, prolog(prelude)).
prelude_builtin_facet('if-error'/3, prolog(prelude)).
prelude_builtin_facet(throw/1, prolog(prelude)).
prelude_builtin_facet('return-on-error'/2, prolog(prelude)).
prelude_builtin_facet('for-each-in-atom'/2, prolog(prelude)).
prelude_builtin_facet(atomically/1, prolog(prelude)).
prelude_builtin_facet(unquote/1, prolog(prelude)).
prelude_builtin_facet(interpret/3, prolog(prelude)).
prelude_builtin_facet('is-function'/1, prolog(prelude)).
prelude_builtin_facet('match-types'/4, prolog(prelude)).
prelude_builtin_facet('match-type-or'/3, prolog(prelude)).
prelude_builtin_facet('type-cast-holds'/3, prolog(prelude)).
prelude_builtin_facet('type-cast'/3, prolog(prelude)).
prelude_builtin_facet('and-then'/2, prolog(prelude)).
prelude_builtin_facet('or-else'/2, prolog(prelude)).
prelude_builtin_facet('trace!'/2, prolog(prelude)).
prelude_builtin_facet(unique/1, prolog(prelude)).
prelude_builtin_facet('alpha-unique'/1, prolog(prelude)).
prelude_builtin_facet(union/2, prolog(prelude)).
prelude_builtin_facet(intersection/2, prolog(prelude)).
prelude_builtin_facet(subtraction/2, prolog(prelude)).

%%%% The registration facets %%%%
%
%A prelude head is an ordinary Prolog-implemented engine builtin now, and its
%facet says so: prolog(prelude), the same shape engine/kernel.pl's four heads
%carry. The key is the MeTTa arity and the predicate behind it has one more
%argument, which is the rule the coverage validation reads.
%
%The rows go through register_builtin_implementation/2 rather than being
%written as builtin_implementation/2 clauses here, because a dynamic predicate
%whose clauses come from a second FILE stops being modifiable: SWI reports
%`Redefined static procedure builtin_implementation/2` and
%finalize_builtin_implementations/0's retractall then raises
%[measured 2026-09-07: that exact boot failure with the clauses written here].
%
%The directive runs at this file's load time, when engine/prelude.pl's
%predicates already exist, so register_prolog_arities/1 inside
%register_builtin_fun/1 sees every arity they are callable at.

:- forall(prelude_builtin_facet(Key, Implementation),
          ( register_builtin_implementation(Key, Implementation),
            Key = Name/MettaArity,
            register_declared_builtin_name(Name),
            PrologArity is MettaArity + 1,
            register_arity(Name, PrologArity) )).

%%%% Installing the registers %%%%
%
%Idempotent, and it restores exactly what eviction removed: a name still owned
%keeps everything it has, and an evicted one gets its declaration, its
%document, its cost row and its translator registration back. The order is the
%loader's own: ownership is asserted before the rule registrations, because
%install_prelude_rule/2 refuses a rule for a name the prelude does not own.
install_engine_prelude :-
    forall(prelude_head(Name, MettaArity),
           install_prelude_head(Name, MettaArity)),
    forall(prelude_shipped_equation(Name, Equation),
           install_prelude_equation(Name, Equation)),
    forall(prelude_declaration(Name, Type),
           install_prelude_declaration(Name, Type)),
    forall(prelude_document(Name, Document),
           install_prelude_document(Name, Document)),
    forall(prelude_cost_claim(Row), install_prelude_cost_row(Row)),
    forall(prelude_rule_registration(Name, Declarations),
           install_prelude_rule(Name, Declarations)).

install_prelude_head(Name, MettaArity) :-
    register_builtin_fun(Name),
    PrologArity is MettaArity + 1,
    register_arity(Name, PrologArity),
    (   prelude_owned(Name)
    ->  true
    ;   assertz(prelude_owned(Name))
    ).

%The register is a copy of the static row rather than a rule over it, because
%tests/prolog/translator_confluence.pl's selftest plants rows here and takes
%them out again with retractall/1, which would take a rule's clause with them.
install_prelude_equation(Name, Equation) :-
    (   prelude_equation(Name, Stored),
        Stored =@= Equation
    ->  true
    ;   assertz(prelude_equation(Name, Equation))
    ).

%A declaration lands in TWO stores. lib_builtin_types.metta loads FIRST and may
%already carry the same declaration, which is the case for a builtin the
%prelude declares only so the CALL SITE honours its Atom mask: get-type is in
%both files for two different readers. A second identical fact would give the
%engine's type surface a duplicate row, so the prelude writes one only when it
%is the one putting it there, and records that it did.
install_prelude_declaration(Name, Type) :-
    (   prelude_type_declaration(Name, Type)
    ->  true
    ;   assertz(prelude_type_declaration(Name, Type)),
        (   seam:builtin_type_declaration(Name, Type)
        ->  true
        ;   assertz(seam:builtin_type_declaration(Name, Type)),
            assertz(prelude_wrote_builtin_type(Name, Type))
        )
    ).

%The prelude documents its own vocabulary the way lib_doc documented its own,
%because a vocabulary that reports undocumented names and has none of its own
%would be telling other people to do what it does not.
install_prelude_document(Name, Document) :-
    (   prelude_doc_atom(Name, Document)
    ->  true
    ;   assertz(prelude_doc_atom(Name, Document))
    ).

%A (cost ...) row is the prelude's THIRD declaration about its own vocabulary,
%beside the type and the document: what class the call's cost grows in, as a
%catalog row the cost-rows lane then has to hold it to. The row is remembered
%so eviction can withdraw it, and a row already standing belongs to whoever
%wrote it.
install_prelude_cost_row([cost, Witness|Fields]) :-
    Witness = [Name|_],
    Row = [cost, Witness|Fields],
    (   prelude_cost_row(Name, _)
    ->  true
    ;   ensure_shipped_cost_row(Row, Wrote),
        (   Wrote == true
        ->  assertz(prelude_cost_row(Name, Row))
        ;   true
        )
    ).

%The registration that makes the translator consult a derived form's expansion
%while a call site compiles. The name has to be one the prelude itself owns, so
%a registration can never point at somebody else's predicate.
install_prelude_rule(Name, Declarations) :-
    (   prelude_owned(Name)
    ->  (   Declarations == []
        ->  'add-translator-rule!'(Name, _)
        ;   'add-translator-rule!'(Name, Declarations, _)
        ),
        (   prelude_translator_rule(Name)
        ->  true
        ;   assertz(prelude_translator_rule(Name))
        )
    ;   throw(error(existence_error(prelude_definition, Name),
                    context(install_engine_prelude/0,
                            'a translator rule registers for a prelude head')))
    ).

%%%% Eviction: a user definition wins, entirely and one-way %%%%
%
%When a space compiles an equation for a name the prelude owns, the prelude's
%declarations, documents, cost rows and translator registration are withdrawn,
%so the program's own definition answers ALONE, exactly as it did before the
%name was promoted (examples/ch09-types/14-matchtypes.metta defines its own
%match-types and must keep meaning ITS match-types).
%
%There are no CLAUSES to evict any more, and that is the change the Prolog
%vocabulary makes here: the bodies live in the prelude tier module, a space's
%definition compiles into the space's own module, and SWI's module resolution
%is what makes the definition win. Eviction is about the REGISTERS, which is
%all it was ever really about; erasing clauses was the price of compiling the
%vocabulary into '&self' [source: engine/spaces/lifecycle.pl,
%metta_prepare_function_predicate/3, which abolishes the materialised import so
%the local definition is the one that answers; commit=3e778d4d13f6bee7304f7500e8e914c22bd07cec].
%
%Additive answers would be the non-exclusive-equations reading, but the prelude
%is engine vocabulary, not part of the program, and the house rule everywhere
%else on this boundary is that the user's word replaces the engine's. Eviction
%is one-way; removing the user's equation later does not resurrect the
%prelude's registers, the same as redefining any function. An ordinary
%named-space function shadows through its module, but a translator registration
%is global, so register_fun_in/2 invokes this door for a prelude rule name from
%every module.
evict_prelude_definition(FAtom) :-
    (   retract(prelude_owned(FAtom))
    ->  %Read before the declarations go, for the reason the write door reads
        %it before it stores: it is the state the compiled clauses were built
        %under.
        result_finality(FAtom, Before),
        retract_prelude_declarations(FAtom),
        retractall(prelude_doc_atom(FAtom, _)),
        forall(retract(prelude_cost_row(FAtom, Row)),
               metta_remove_atom('&metta', Row, _)),
        retractall(prelude_equation(FAtom, _)),
        (   retract(prelude_translator_rule(FAtom))
        ->  translator_rules:forget_translator_rule(FAtom)
        ;   true
        ),
        %The prelude is the base tier's, so its eviction is &self's change.
        %An eviction takes the prelude's DECLARATION away with its equations,
        %so it reaches the same two directions a declaration write does.
        metta_self_module(Self),
        announce_declaration_changed(Self, FAtom, Before)
    ;   true
    ).

%The ledger rows say exactly which seam:builtin_type_declaration entries are
%the prelude's, so eviction purges both stores and nothing else. A row the
%prelude found already written by lib_builtin_types.metta stays, because it was
%never the prelude's to remove.
retract_prelude_declarations(Name) :-
    forall(retract(prelude_type_declaration(Name, Type)),
           (   retract(prelude_wrote_builtin_type(Name, Type))
           ->  retractall(seam:builtin_type_declaration(Name, Type))
           ;   true
           )).

%The declaration half of the same rule, for the loader's door: a ':' atom a
%file writes into the base tier replaces the prelude's declaration for that
%name, so the compile-time findall over type chains sees ONE authority, the
%user's.
evict_prelude_declaration(Space, [':', Name, _]) :-
    atom(Name),
    Space == '&self',
    !,
    retract_prelude_declarations(Name).
evict_prelude_declaration(_, _).
