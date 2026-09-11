% Purpose: verify crypto formats, reduced providers, refusal and resource paths.
% Guarantees: every public crypto head is called by the shipped example
% [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/06-crypto_lib.metta; commit=WORKTREE].
% Owns resources: fixture files and streams are closed and removed on every exit.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_stream), [open_prolog_stream/4]).
:- use_module(library(crypto), []).
:- initialization(consult('../../lib/lib_crypto/lib_crypto.pl')).

:- begin_tests(lib_crypto_surface).

:- meta_predicate with_bytes(+, 1).
with_bytes(Bytes, Goal) :-
    setup_call_cleanup(tmp_file_stream(binary, File, Out),
                       ( maplist(put_byte(Out), Bytes), close(Out), call(Goal, File) ),
                       ( (is_stream(Out) -> close(Out) ; true), delete_file(File) )).

:- meta_predicate must_raise(0, ?).
must_raise(Goal, Expected) :-
    catch((call(Goal), Outcome = answered), Error, Outcome = raised(Error)),
    assertion(Outcome = raised(Expected)).

test(native_and_portable_sha_agree_for_text_and_all_byte_values) :-
    numlist(0, 255, Bytes),
    forall(( member(Algorithm, [sha1, sha224, sha256, sha384, sha512]),
             member(Source, [utf8(""), utf8("é\u0000🦊"), octets(Bytes)]) ),
           ( lib_crypto_native:digest(Algorithm, Source, none, Native),
             lib_crypto:portable_digest(Algorithm, Source, none, Portable),
             assertion(Native == Portable) )).

test(text_keeps_atom_string_codes_and_nul) :-
    string_codes("é\u0000🦊", Codes), atom_codes(Atom, Codes),
    findall(Hex, (member(Text, ["é\u0000🦊", Atom, Codes]), crypto_hash(sha256, Text, Hex)), Hashes),
    Hashes = [Hash, Hash, Hash],
    crypto_hash("sha256", "é\u0000🦊", Hash).

test(swi_algorithm_names_and_unknown_native_errors) :-
    forall(member(Algorithm, [md5, sha3_224, sha3_256, sha3_384, sha3_512,
                              blake2s256, blake2b512, ripemd160]),
           ( crypto_hash(Algorithm, "hello", Actual),
             crypto:crypto_data_hash("hello", Expected, [algorithm(Algorithm)]),
             atom_string(Expected, Actual) )),
    must_raise(crypto_hash(unknown_digest, "x", _), error(crypto_native_error('EVP_MD_fetch', _, _), _)).

test(variable_output_digest_requires_an_output_length,
     [error(domain_error(fixed_output_digest, 'shake-128'))]) :-
    crypto_hash(shake_128, "x", _).

test(hash_bytes_checks_every_element,
     [forall(member(Bytes, [[-1], [256], [1.5], [a], [x|tail]]))]) :-
    must_raise('crypto-hash-bytes'(sha256, Bytes, _), error(_, _)).

test(hash_bytes_rejects_a_cycle, [error(type_error(list(between(0,255)), _))]) :-
    Bytes = [0|Bytes], 'crypto-hash-bytes'(sha256, Bytes, _).

test(empty_byte_hash_is_the_sha256_empty_vector) :-
    'crypto-hash-bytes'(sha256, [],
       "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855").

test(hmac_rfc4231_and_empty_key) :-
    'crypto-hmac'(sha256, "Jefe", "what do ya want for nothing?",
        "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"),
    forall(member(Algorithm, [sha1, sha256]),
           ( lib_crypto_native:digest(Algorithm, utf8(""), [], Native),
             lib_crypto:portable_digest(Algorithm, utf8(""), [], Portable),
             assertion(Native == Portable) )).

test(hmac_text_and_bytes_keep_distinct_encodings) :-
    'crypto-hmac'(sha256, "é", "\u0000ÿ", Text),
    'crypto-hmac-bytes'(sha256, [195,169], [0,195,191], Text),
    'crypto-hmac-bytes'(sha256, [195,169], [0,255],
        "6a96aac37f1ab07208ddcd8a71292bd9fc92722a85ca984fa3adcd07fede237d").

test(hmac_checks_the_key, [error(type_error(between(0,255), 256))]) :-
    'crypto-hmac-bytes'(sha256, [256], [], _).

test(files_hash_empty_and_more_than_one_buffer) :-
    with_bytes([], compare_file),
    length(Bytes, 140003), maplist(=(255), Bytes), with_bytes(Bytes, compare_file).
compare_file(File) :-
    forall(member(Algorithm, [sha1, sha224, sha256, sha384, sha512]),
           ( 'crypto-hash-file!'(Algorithm, File, Hex),
             setup_call_cleanup(open(File, read, Stream, [type(binary)]),
                                lib_crypto:portable_digest(Algorithm, stream(Stream), none, Bytes),
                                close(Stream)),
             crypto_hash:hash_atom(Bytes, Atom), atom_string(Atom, Hex),
             crypto:crypto_file_hash(File, Expected, [algorithm(Algorithm), encoding(octet)]),
             atom_string(Expected, Hex) )),
    assertion(\+ stream_property(_, file_name(File))).

test(file_closes_on_output_mismatch_and_unknown_algorithm) :- with_bytes([1,2,3], file_failures).
file_failures(File) :-
    assertion(\+ 'crypto-hash-file!'(sha256, File, "wrong")),
    assertion(\+ stream_property(_, file_name(File))),
    must_raise('crypto-hash-file!'(unknown_digest, File, _), error(_, _)),
    assertion(\+ stream_property(_, file_name(File))).

test(missing_files_raise, [error(existence_error(source_sink, _))]) :-
    tmp_file(crypto_missing, File), 'crypto-hash-file!'(sha256, File, _).

stream_read(Stream, _) :-
    (   nb_current(crypto_stream_queue, Queue)
    ->  thread_send_message(Queue, reading(Stream)), thread_get_message(continue)
    ;   throw(crypto_fixture_read_failure)
    ).
stream_close(_).
stream_write(_, _).

test(read_failure_releases_the_stream_lock) :-
    open_prolog_stream(plunit_lib_crypto_surface, read, Stream, []),
    setup_call_cleanup(true,
                       must_raise(lib_crypto_native:digest(sha256, stream(Stream), none, _),
                                  crypto_fixture_read_failure),
                       ( thread_create(close(Stream), Thread, []), thread_join(Thread, true) )).

test(cancelling_a_native_read_closes_the_stream) :-
    setup_call_cleanup(message_queue_create(Queue),
        setup_call_cleanup(
            thread_create(catch(
                ( nb_setval(crypto_stream_queue, Queue),
                  setup_call_cleanup(open_prolog_stream(plunit_lib_crypto_surface, read, Stream, []),
                                     lib_crypto_native:digest(sha256, stream(Stream), none, _),
                                     close(Stream)) ),
                crypto_read_cancelled, true), Thread, []),
            ( thread_get_message(Queue, reading(Opened)), assertion(is_stream(Opened)) ),
            ( thread_signal(Thread, throw(crypto_read_cancelled)), thread_join(Thread, Status) )),
        message_queue_destroy(Queue)),
    assertion(Status == true), assertion(\+ is_stream(Opened)).

test(native_output_mismatches_keep_later_operations_usable) :-
    assertion(\+ lib_crypto_native:digest(sha256, utf8(fixture), none, [])),
    assertion(\+ lib_crypto_native:digest(sha256, utf8(fixture), [1], [])),
    assertion(\+ lib_crypto_native:random_bytes(3, [])),
    assertion(\+ lib_crypto_native:random_below_hex('1', "bad")),
    assertion(\+ lib_crypto_native:password_hash(fixture, [], 1, [])),
    lib_crypto_native:password_hash(fixture, [], 1, Digest),
    assertion(\+ lib_crypto_native:password_verify(fixture, [], 1, Digest, false)),
    lib_crypto_native:password_verify(fixture, [], 1, Digest, true).

test(empty_random_requests_and_singleton_intervals) :-
    crypto_random_hex(0, ""), 'crypto-random-hex'(0, ""), 'crypto-random-bytes'(0, []),
    'crypto-random-integer'(-9, -8, -9),
    Big is 1 << 4096, Next is Big + 1, 'crypto-random-integer'(Big, Next, Big).

test(random_byte_shape_and_unrepresentable_sizes) :-
    'crypto-random-bytes'(256, Bytes), length(Bytes, 256), maplist(between(0,255), Bytes),
    Big is 1 << 256,
    must_raise('crypto-random-bytes'(Big, _), error(representation_error(_), _)),
    must_raise('crypto-random-bytes'(-1, _), error(_, _)).

test(intervals_cover_signed_and_arbitrary_size_bounds) :-
    Big is 1 << 2048, Low is -Big, High is Big + 17,
    forall((member(L-U, [-11-(-2), 0-3, Low-High]), between(1, 12, _)),
           ('crypto-random-integer'(L, U, N), assertion(N >= L), assertion(N < U))).

test(empty_and_reversed_intervals_raise,
     [forall(member(L-U, [0-0, 3-2])), error(domain_error(nonempty_integer_interval, _))]) :-
    'crypto-random-integer'(L, U, _).

test(password_zero_cost_is_one_iteration_and_wrong_password_is_false) :-
    'crypto-password-hash'("é\u0000🦊", 0, Record),
    sub_string(Record, 0, _, _, "$pbkdf2-sha512$t=1$"),
    'crypto-password-verify'("é\u0000🦊", Record, true),
    'crypto-password-verify'("different", Record, false),
    atom_string(Atom, Record), crypto:crypto_password_hash("é\u0000🦊", Atom).

test(legacy_password_salts_and_iteration_counts_remain_readable) :-
    forall(member(Salt, [[], [0], [0,255,1,128], [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17]]),
           ( crypto:crypto_password_hash("fixture", Record, [cost(2), salt(Salt)]),
             'crypto-password-verify'("fixture", Record, true) )).

test(password_cost_checks_before_exponentiation) :-
    must_raise('crypto-password-hash'("fixture", -1, _), error(domain_error(not_less_than_zero, -1), _)),
    must_raise('crypto-password-hash'("fixture", 31, _), error(representation_error(int), _)),
    must_raise('crypto-password-hash'("fixture", 1.5, _), error(type_error(integer, 1.5), _)),
    Huge is 1 << 1024,
    must_raise('crypto-password-hash'("fixture", Huge, _), error(representation_error(int), _)).

test(private_pbkdf2_rejects_zero_instead_of_publishing_uninitialized_bytes,
     [error(domain_error(positive_integer, 0))]) :-
    lib_crypto_native:password_hash("fixture", [], 0, _).

test(malformed_password_envelopes_raise,
     [forall(member(Record, ["", "pbkdf2-sha512$t=1$$", "$bcrypt$t=1$$",
                             "$pbkdf2-sha512$t=0$$", "$pbkdf2-sha512$t=-1$$",
                             "$pbkdf2-sha512$t=1+1$$", "$pbkdf2-sha512$t=1$$extra$",
                             "$pbkdf2-sha512$t=1$?$AQ", "$pbkdf2-sha512$t=1$$AQ"]))]) :-
    must_raise('crypto-password-verify'("fixture", Record, _), error(_, _)).

test(password_digest_padding_and_noncanonical_bits_raise) :-
    crypto:crypto_password_hash("fixture", Original, [cost(0), salt([1])]),
    atom_string(Original, Text),
    string_concat(Text, "=", Padded),
    must_raise('crypto-password-verify'("fixture", Padded, _), error(_, _)),
    split_string(Text, "$", "", ["", Algorithm, Params, _, Digest]),
    format(string(Noncanonical), '$~s$~s$AR$~s', [Algorithm, Params, Digest]),
    must_raise('crypto-password-verify'("fixture", Noncanonical, _), error(_, _)).

test(password_verification_rejects_nonrepresentable_iterations) :-
    crypto:crypto_password_hash("fixture", Original, [cost(0), salt([])]),
    split_string(Original, "$", "", ["", Algorithm, _, Salt, Digest]),
    format(string(Record), '$~s$t=2147483648$~s$~s', [Algorithm, Salt, Digest]),
    must_raise('crypto-password-verify'("fixture", Record, _), error(representation_error(int), _)).

:- end_tests(lib_crypto_surface).
