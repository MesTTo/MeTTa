% Purpose: verify RFC3986 examples, component round trips and strict URI codecs.
% Guarantees: the fixtures cover empty delimiters, reserved octets, Unicode
% scalar boundaries, malformed input and generated references/query relations.
% [tested: lib_uri; commit=24b96f8ec8468bc97cec35e1d71ce689ede7fdcf].
% Owns resources: the generated query test restores its native random state.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_uri/lib_uri').
:- use_module(library(lists), [member/2, append/2, reverse/2]).
:- use_module(library(apply), [maplist/2]).
:- use_module(library(random), [getrand/1, setrand/1, random_between/3]).

:- begin_tests(lib_uri).
:- meta_predicate must_throw(0, ?).
must_throw(Goal,Expected) :-
    catch(Goal,Error,true), assertion(nonvar(Error)), assertion(Error=Expected).

test(uri_capability_is_declared) :-
    findall(S,metta_engine:metta_platform_capability(uri,S,_),Sources),
    assertion(Sources == [library(uri)]).

% RFC3986 section5.4, including its strict interpretation of http:g.
test(all_rfc3986_resolution_examples) :-
    Cases=["g:h"-"g:h", "g"-"http://a/b/c/g", "./g"-"http://a/b/c/g",
           "g/"-"http://a/b/c/g/", "/g"-"http://a/g", "//g"-"http://g",
           "?y"-"http://a/b/c/d;p?y", "g?y"-"http://a/b/c/g?y",
           "#s"-"http://a/b/c/d;p?q#s", "g#s"-"http://a/b/c/g#s",
           "g?y#s"-"http://a/b/c/g?y#s", ";x"-"http://a/b/c/;x",
           "g;x"-"http://a/b/c/g;x", "g;x?y#s"-"http://a/b/c/g;x?y#s",
           ""-"http://a/b/c/d;p?q", "."-"http://a/b/c/", "./"-"http://a/b/c/",
           ".."-"http://a/b/", "../"-"http://a/b/", "../g"-"http://a/b/g",
           "../.."-"http://a/", "../../"-"http://a/", "../../g"-"http://a/g",
           "../../../g"-"http://a/g", "../../../../g"-"http://a/g",
           "/./g"-"http://a/g", "/../g"-"http://a/g", "g."-"http://a/b/c/g.",
           ".g"-"http://a/b/c/.g", "g.."-"http://a/b/c/g..", "..g"-"http://a/b/c/..g",
           "./../g"-"http://a/b/g", "./g/."-"http://a/b/c/g/",
           "g/./h"-"http://a/b/c/g/h", "g/../h"-"http://a/b/c/h",
           "g;x=1/./y"-"http://a/b/c/g;x=1/y", "g;x=1/../y"-"http://a/b/c/y",
           "g?y/./x"-"http://a/b/c/g?y/./x", "g?y/../x"-"http://a/b/c/g?y/../x",
           "g#s/./x"-"http://a/b/c/g#s/./x", "g#s/../x"-"http://a/b/c/g#s/../x",
           "http:g"-"http:g"],
    forall(member(Reference-Expected,Cases),
           ('uri-resolve'(Reference,"http://a/b/c/d;p?q",Actual),assertion(Actual==Expected))).

test(empty_delimiters_urns_and_authority_only_bases) :-
    forall(member(URI,["","?","#","?#","http://a?","http://a?#","//",
                        "urn:example:ABC?x#","URN:Example:ABC","a:b","http://host:"]),
           ('uri-parts'(URI,Parts),'uri-build'(Parts,Again),assertion(Again==URI))),
    forall(member(Ref-Base-Expected,
                  ["g"-"http://a"-"http://a/g", "?"-"http://a?q#f"-"http://a?",
                   "#"-"http://a?q#f"-"http://a?q#", ""-"http://a?q#f"-"http://a?q",
                   "urn:example:ABC"-"http://a"-"urn:example:ABC",
                   "x"-"urn:example:ABC"-"urn:x",
                   "%2e%2e/x"-"http://a/b/"-"http://a/b/%2e%2e/x"]),
           ('uri-resolve'(Ref,Base,Actual),assertion(Actual==Expected))).

test(component_dimensions_round_trip_in_any_row_order) :-
    forall((member(S,[[],[["scheme","http"]],[["scheme","a"]],[["scheme","urn"]]]),
            member(A,[[],[["authority",""]],[["authority","User:Pass@HOST:0012"]],
                      [["authority","[::1]"]]]),
            member(P,["","/","/a//b","/%2F"]),
            member(Q,[[],[["query",""]],[["query","a=1&a=2"]]]),
            member(F,[[],[["fragment",""]],[["fragment","a/b?c"]]])),
           (append([S,A,[["path",P]],Q,F],Rows),reverse(Rows,Reversed),
            'uri-build'(Reversed,URI),'uri-parts'(URI,Parts),assertion(Parts==Rows),
            'uri-build'(Parts,Again),assertion(Again==URI))).

test(normalization_preserves_data_and_is_idempotent) :-
    Cases=["HTTP://User:Pass@HOST/a/%2e%2e/b?x=%7e#F"-"http://User:Pass@host/b?x=~#F",
           "urn:Example:ABC"-"urn:Example:ABC", "../a/./b"-"../a/./b",
           "HTTP://%55ser:P%61ss@%48OST/%2f%3f%23"-"http://User:Pass@host/%2F%3F%23",
           "foo:/a/..//b"-"foo:/.//b", "http://HOST:0012?#"-"http://host:0012?#"],
    forall(member(URI-Expected,Cases),
           ('uri-normalize'(URI,N),assertion(N==Expected),'uri-normalize'(N,Again),
            assertion(Again==N),'uri-parts'(N,_))),
    'uri-parts'("foo:/.//b",Parts),
    assertion(Parts==[["scheme","foo"],["path","/.//b"]]).

test(every_percent_octet_preserves_its_identity) :-
    string_codes("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~",Unreserved),
    forall(between(0,255,Byte),
           (format(string(Hex),'~|~`0t~16r~2|',[Byte]),string_concat("%",Hex,Escape),
            'uri-normalize'(Escape,Actual),
            (member(Byte,Unreserved) -> string_codes(Expected,[Byte])
            ; string_upper(Escape,Expected)),assertion(Actual==Expected))).

test(all_contexts_round_trip_scalar_boundaries) :-
    'uri-contexts'(Contexts),
    assertion(Contexts==[path,segment,'query-value',fragment]),
    forall((member(Context,Contexts),
            member(Code,[0,1,31,32,37,43,47,63,127,128,255,256,0x7ff,0x800,
                         0xd7ff,0xe000,0xffff,0x10000,0x10ffff,0x3c0,0x1f642])),
           (string_codes(Text,[Code,0,Code]),'uri-encode'(Context,Text,Encoded),
            'uri-decode'(Encoded,Again),assertion(Again==Text))),
    'uri-encode'(path,"a/b",P),assertion(P=="a/b"),
    'uri-encode'(segment,"a/b",S),assertion(S=="a%2Fb"),
    'uri-decode'("%252F+a",D),assertion(D=="%2F+a").

test(query_conventions_duplicates_blank_values_and_separators) :-
    'uri-query-parse'(uri,"a+b=c+d&&a=2&bare&empty=&",URI),
    assertion(URI==[["a+b","c+d"],["a","2"],["bare",""],["empty",""]]),
    'uri-query-parse'(form,"a+b=c+d&&a=2&bare&empty=&",Form),
    assertion(Form==[["a b","c d"],["a","2"],["bare",""],["empty",""]]),
    'uri-query-parse'(form,"a=1;b=2&=x",Semicolon),
    assertion(Semicolon==[["a","1;b=2"],["","x"]]),
    forall(member(Style,[uri,form]),
           ('uri-query-parse'(Style,"&&",Empty),assertion(Empty==[]),
            'uri-query-build'(Style,[],Text),assertion(Text==""))).

test(generated_unicode_query_relations_round_trip) :-
    setup_call_cleanup(getrand(State),
        (set_random(seed(3986)),forall(between(0,500,Index),generated_query(Index))),
        setrand(State)).
generated_query(Index) :-
    Size is Index mod 9, length(Codes,Size),maplist(scalar_draw,Codes),
    string_codes(Text,Codes),Pairs=[["a+b",Text],[Text,"a b/?&=;"],[Text,""]],
    forall(member(Style,[uri,form]),
           ('uri-query-build'(Style,Pairs,Encoded),
            'uri-query-parse'(Style,Encoded,Again),assertion(Again==Pairs))).
scalar_draw(Code) :- random_between(0,0x10f7ff,Index),
    ( Index>=0xd800 -> Code is Index+0x800 ; Code=Index ).

test(malformed_escapes_and_utf8_are_refused) :-
    forall(member(Text,["%","%A","%ZZ","%FF","%C0%AF","%E0%80%AF",
                         "%ED%A0%80","%F4%90%80%80","%E2%82","%80"]),
           (must_throw('uri-decode'(Text,_),error(domain_error(_,_),_)),
            string_concat("x=",Text,Query),
            must_throw('uri-query-parse'(form,Query,_),error(domain_error(_,_),_)))).

test(boundary_refusals_cover_complete_input) :-
    forall(member(Text,["a b","a\u0000b","1:b","x%ZZ","x#y#z","http://a/π"]),
           must_throw('uri-parts'(Text,_),error(domain_error(_,_),_))),
    forall(member(Rows,[[["path","a"],["authority","host"]],
                        [["path","//x"]],[["path","a:b"]],[["path","a?b"]],
                        [["scheme",""]],[["path","a"],["path","b"]],[["missing","x"]]]),
           must_throw('uri-build'(Rows,_),error(domain_error(_,_),_))),
    Cycle=[[]|Cycle],must_throw('uri-build'(Cycle,_),error(type_error(list,_),_)),
    must_throw('uri-build'([["path",42]],_),error(type_error(string,42),_)),
    must_throw('uri-resolve'("x","relative",_),error(domain_error(absolute_uri_base,_),_)),
    must_throw('uri-query-build'(missing,[],_),error(domain_error(uri_query_style,missing),_)),
    must_throw('uri-query-build'(uri,[["x","ok"],["x",7]],_),error(type_error(string,7),_)),
    must_throw('uri-query-parse'(_,"",_),error(instantiation_error,_)),
    must_throw('uri-encode'(missing,"x",_),error(domain_error(uri_encoding_context,missing),_)).

test(dot_removal_scales_with_input_length) :-
    path_work(1500,Small),path_work(3000,Large),
    assertion(Large>Small*1.8),assertion(Large<Small*2.2),
    format('URI dot removal: 1500 pairs ~d inferences; 3000 pairs ~d inferences~n',[Small,Large]).
path_work(Count,Work) :-
    findall("a/..",between(1,Count,_),Segments),atomics_to_string(Segments,"/",Path),
    statistics(inferences,Before),'uri-resolve'(Path,"http://a/",URI),
    statistics(inferences,After),Work is After-Before,assertion(URI=="http://a/").

:- end_tests(lib_uri).
