% Purpose: hold the engine's patched-host refusal to its contract: a home that
%   declares every required patch at its digest boots, and one missing a patch,
%   declaring an older digest, or holding a malformed declaration is refused
%   naming exactly that, whether the list checked is the engine's own or one a
%   host's bridge passes for the patches only it relies on.
% Guarantees: each refusal separates the patches the host lacks from the ones
%   it carries at another digest, and the message names every one of them
%   [tested: host_check; commit=WORKTREE].
% Owns resources: each test plants its declaration in a fresh directory from
%   tmp_file/2 and an asserta'd swi search-path entry pointing at it, and
%   removes both in cleanup whatever the test did.
%
% The plant is an ordinary search-path entry, not a test mode in the engine:
% absolute_file_name/3 returns the first readable swi('metta-host.pl'), and an
% entry asserted ahead of the home is simply the first place it looks.

:- use_module('../../../../engine/host_check').
:- use_module(library(lists)).
:- use_module(library(filesex)).

:- begin_tests(host_check).

%Every required patch, behind the host_build/1 of the build running this suite,
%which is what a declaration written for this binary holds.
required([host_build(Running)|Facts]) :-
    current_prolog_flag(compiled_at, Running),
    findall(host_patch(File, Sha), metta_host_patches:host_patch(File, Sha), Facts).

with_declaration(Facts, Goal) :-
    tmp_file(host_check, Dir),
    setup_call_cleanup(
        ( make_directory(Dir),
          directory_file_path(Dir, 'metta-host.pl', File),
          setup_call_cleanup(open(File, write, Out),
                             forall(member(Fact, Facts),
                                    format(Out, '~q.~n', [Fact])),
                             close(Out)),
          asserta(user:file_search_path(swi, Dir), Ref) ),
        Goal,
        ( erase(Ref),
          delete_directory_and_contents(Dir) )).

refusal(Error) :-
    catch(( metta_require_patched_host, Error = none ), Error, true).

rendered(Error, Text) :-
    once(phrase(prolog:message(Error), Lines)),
    with_output_to(string(Text), print_message_lines(current_output, '', Lines)).

test(a_complete_declaration_boots) :-
    required(Facts),
    with_declaration(Facts, refusal(Error)),
    assertion(Error == none).

test(a_missing_patch_is_named_as_missing) :-
    required([Build, host_patch(First, _)|Rest]),
    with_declaration([Build|Rest], refusal(Error)),
    assertion(Error = error(metta_host_unpatched('the MeTTa engine', [First], [], _, _), _)),
    rendered(Error, Text),
    assertion(sub_string(Text, _, _, _, First)).

test(an_older_digest_is_named_as_stale) :-
    required([Build, host_patch(First, _)|Rest]),
    with_declaration([Build, host_patch(First, older)|Rest], refusal(Error)),
    assertion(Error = error(metta_host_unpatched('the MeTTa engine', [], [First], _, _), _)),
    rendered(Error, Text),
    assertion(sub_string(Text, _, _, _, "older version")).

test(a_declaration_naming_only_its_build_misses_every_patch) :-
    required([Build|Facts]),
    findall(File, member(host_patch(File, _), Facts), Every),
    with_declaration([Build], refusal(Error)),
    length(Every, N),
    assertion(Error = error(metta_host_unpatched('the MeTTa engine', Every, [], _, N), _)).

test(a_term_that_is_not_a_patch_fact_is_refused_as_malformed) :-
    required(Facts),
    with_declaration([hello(world)|Facts], refusal(Error)),
    assertion(Error = error(metta_host_declaration_malformed(_, hello(world)), _)).

test(a_declaration_for_another_build_is_refused_before_any_patch) :-
    required([_|Facts]),
    with_declaration([host_build('Jan 1 1970, 00:00:00')|Facts], refusal(Error)),
    assertion(Error = error(metta_host_declaration_foreign(_, 'Jan 1 1970, 00:00:00', _), _)),
    rendered(Error, Text),
    assertion(sub_string(Text, _, _, _, "SWI_HOME_DIR")).

test(a_declaration_naming_no_build_is_refused_as_foreign) :-
    required([_|Facts]),
    with_declaration(Facts, refusal(Error)),
    assertion(Error = error(metta_host_declaration_foreign(_, none, _), _)).

test(a_second_build_line_is_malformed) :-
    required([Build|Facts]),
    with_declaration([Build, host_build(other)|Facts], refusal(Error)),
    assertion(Error = error(metta_host_declaration_malformed(_, host_build(other)), _)).

%A bridge's own list is held to the same declaration: here it asks for one
%patch the home does not declare, while the engine's own set is complete.
test(a_bridges_own_requirement_is_refused_under_its_own_name) :-
    required(Facts),
    Pair = 'bridge-only.patch'-'0123',
    with_declaration(Facts,
        catch(( metta_require_host_patches('the planted bridge', [Pair]), Error = none ),
              Error, true)),
    assertion(Error = error(metta_host_unpatched('the planted bridge', ['bridge-only.patch'], [], _, 1), _)),
    rendered(Error, Text),
    assertion(sub_string(Text, _, _, _, "every patch the planted bridge needs")),
    assertion(sub_string(Text, _, _, _, "against the 1 the planted bridge requires")).

test(a_bridges_own_requirement_passes_when_declared) :-
    required(Facts),
    with_declaration([host_patch('bridge-only.patch', '0123')|Facts],
        catch(( metta_require_host_patches('the planted bridge', ['bridge-only.patch'-'0123']),
                Error = none ),
              Error, true)),
    assertion(Error == none).

test(the_declaration_is_read_not_run) :-
    with_declaration([(:- assertz(user:host_check_ran))], refusal(Error)),
    assertion(Error = error(metta_host_declaration_malformed(_, _), _)),
    assertion(\+ catch(user:host_check_ran, _, fail)).

:- end_tests(host_check).
