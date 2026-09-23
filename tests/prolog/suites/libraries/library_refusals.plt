% Purpose: witness, by running them, the refusals the shipped libraries
%     document but no suite exercised, and keep the cases as a table so a
%     fifteenth promise costs a row rather than a test body.
% Assumes:
%     - every expectation below was MEASURED by calling the head, never
%       predicted from its prose [measured 2026-09-21; every row below
%       re-measures it on each run, because the expected term is compared
%       against what the head actually throws rather than against prose]
%     - the two socket rows reach lib_file's handle table before any socket
%       operation, so they raise its handle refusal on a build with or without
%       the socket capability; lib_socket's capability guard sits after that
%       lookup [source: lib/lib_socket/lib_socket.pl:socket_handle/4;
%       commit=76b710d028bf4c9ed2bf6c8462a9f50fec2c7f90]
% Guarantees:
%     - each documented refusal below raises the term the row names, and
%       returns no answer instead [tested: a_documented_refusal_refuses]
%     - a promise that cannot be induced on this host is still checked in the
%       direction it can be, namely that the head SUCCEEDS, so losing the
%       provider turns the row red instead of leaving it a silent excuse
%       [tested: a_capability_refusal_is_not_inducible_here]
%     - the assertion itself is not vacuous: a goal that succeeds, one that
%       fails, and one that throws the wrong term each fail must_throw/2
%       [tested: the_assertion_sees_a_planted_success,
%       the_assertion_sees_a_planted_failure,
%       the_assertion_sees_a_planted_mismatch]
% Fails when: a row's trigger stops being a trigger, which reads as a red test
%     naming the head rather than as silent coverage loss.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('library_assertions.pl', [must_throw/2, throws_matching/2]).
:- use_module('../../scratch.pl', [with_scratch_directory/2]).
:- use_module(library(filesex), [directory_file_path/3]).
:- initialization(consult('../../lib/lib_crypto/lib_crypto.pl')).
:- initialization(consult('../../lib/lib_datetime/lib_datetime.pl')).
:- initialization(consult('../../lib/lib_file/lib_file.pl')).
:- initialization(consult('../../lib/lib_json/lib_json.pl')).
:- initialization(consult('../../lib/lib_regex/lib_regex.pl')).
:- initialization(consult('../../lib/lib_socket/lib_socket.pl')).
:- initialization(consult('../../lib/lib_uuid/lib_uuid.pl')).

:- begin_tests(library_refusals).

% Head, the call that triggers it, and the term it threw when measured.
% The context argument stays a variable wherever the library leaves it
% unbound, which is itself recorded: only with-file names its own operation.
refusal_case('crypto-hash-file!',
             'crypto-hash-file!'(sha256, '/nonexistent/zz', _),
             error(existence_error(source_sink, '/nonexistent/zz'), _)).
refusal_case('crypto-random-integer',
             'crypto-random-integer'(5, 5, _),
             error(domain_error(nonempty_integer_interval, [5, 5]), _)).
refusal_case('crypto-password-verify',
             'crypto-password-verify'("pw", "not-a-record", _),
             error(domain_error(crypto_password_record, envelope), _)).
refusal_case('format-datetime',
             'format-datetime'(0, "%Y", 'no-such-zone', _),
             error(domain_error(timezone, 'no-such-zone'), _)).
refusal_case('parse-date',
             'parse-date'("not a date at all", _),
             error(domain_error(date_text, "not a date at all"), _)).
refusal_case('re-compile',
             're-compile'("(unclosed", _),
             error(syntax_error('missing closing parenthesis'), _)).
%\C is the byte-oriented match the doc line names; the same pattern over
%"ab" succeeds, so the boundary and not \C is what refuses.
refusal_case('re-ranges',
             're-ranges'("\\C", "🦊", _),
             error(representation_error(regex_character_boundary), _)).
refusal_case('json-lines-read!',
             'json-lines-read!'('/nonexistent/zz.jsonl', _),
             error(existence_error(source_sink, "/nonexistent/zz.jsonl"), _)).
%The head promises TWO refusals and the coverage lane counts per head, so the
%second needs its own row or it rides on the first. This is the line-numbered
%one, and it is the only refusal outside lib_file that names its operation and
%carries a remedy: the library's line parser is disciplined and only its open
%path reports context(system:open/4).
refusal_case('json-lines-read!',
             a_malformed_json_lines_file_is_read,
             error(json_line(2, _), context('json-lines', _))).
%The one row whose refusal names the library operation and carries a remedy,
%because lib_file routes through metta_file_refusal/2. The other ten report a
%raw host error, two of them naming system:open/4 rather than the head called.
refusal_case('with-file',
             'with-file'('/nonexistent/zz', "r", 'car-atom', _),
             error('file-not-found'('file-open!', source_sink, "/nonexistent/zz"),
                   context('file-open!', _))).
refusal_case('socket-endpoint',
             'socket-endpoint'(999999, local, _),
             error(existence_error(metta_file_handle, 999999), _)).
refusal_case('udp-receive!',
             'udp-receive!'(999999, _),
             error(existence_error(metta_file_handle, 999999), _)).

% A promise whose trigger is the ABSENCE of a host provider, which this box
% has. Checked in the one direction available: the head must still succeed.
not_inducible('crypto-password-hash', 'crypto-password-hash'("pw", _),
              'PBKDF2 is present, so absent-capability cannot be induced').
not_inducible('uuid-time!', 'uuid-time!'(_),
              'OSSP uuid provides version 1 here, so no-v1-support cannot be induced').

%The one row needing a file on disk carries its own fixture, so the table
%keeps three columns rather than growing a fourth for a single case.
a_malformed_json_lines_file_is_read :-
    with_scratch_directory(jsonl, read_malformed_json_lines).

read_malformed_json_lines(Directory) :-
    directory_file_path(Directory, 'bad.jsonl', Path),
    setup_call_cleanup(open(Path, write, Stream),
                       format(Stream, '{"a":1}~nnot json at all~n', []),
                       close(Stream)),
    findall(Value, 'json-lines-read!'(Path, Value), _).

test(a_documented_refusal_refuses, [forall(refusal_case(_, Goal, Expected))]) :-
    must_throw(Goal, Expected).

test(a_capability_refusal_is_not_inducible_here,
     [forall(not_inducible(_, Goal, _))]) :-
    assertion(call(Goal)).

%A clean run above says nothing unless the assertion can go red. These three
%plant each way it must: no throw, no solution, and the wrong term. They test
%throws_matching/2 rather than must_throw/2 because plunit marks a failed
%assertion/1 and continues, so a planted must_throw reports as a real failure.
test(the_assertion_sees_a_planted_success) :-
    assertion(\+ throws_matching(true, error(_, _))).
test(the_assertion_sees_a_planted_failure) :-
    assertion(\+ throws_matching(fail, error(_, _))).
test(the_assertion_sees_a_planted_mismatch) :-
    assertion(\+ throws_matching(throw(error(type_error(a, b), c)),
                                 error(domain_error(_, _), _))).

:- end_tests(library_refusals).
