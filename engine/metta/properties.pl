% Purpose: answer head properties from occurrence provenance and engine claims.
% Guarantees: get-property, explain and host reflection share these answers;
%   origins retain each defining occurrence and resolve aliases at their home
%   [tested: head_properties; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
% Guarantees: argument-pattern aliases report the original definition's home
%   [tested: reference_patterns; commit=a95e6c90c910db30c72311abadd58dee5349978c].
% Guarantees: named equation ownership uses the storage index before general
%   row classification; unrelated atoms do not add work to compilation claims
%   [tested: head_properties:unrelated_rows_do_not_change_a_named_definition_claim_cost;
%   commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
% Owns resources: source text and positions are cached only for one origin read.
% Decides: absent source files retain their path and answer line -1. Reflection
%   does not compile a deferred equation or load an unimported library.

:- use_module('../source_positions', [source_positions/3]).
:- use_module(library(pairs), [pairs_values/2]).

'get-property'(Name, Property) :-
    must_be(atom, Name), current_metta_space(Space),
    metta_head_property(Space, Name, Property).

metta_head_property(Space, Name, [visibility, Visibility]) :-
    metta_with_under(visibility,
        findall(Grade,
                ( metta_graded_pair(Space, Row, _, _, Grade),
                  metta_reference_row_head(Row, Name) ), Grades)),
    ( Grades = [First|Rest]
    -> foldl(metta_apply_algebra_operation(visibility, max), Rest, First, Joined),
       downcase_atom(Joined, Visibility)
    ; metta_reference_internal(Space, Name)
    -> Visibility = internal
    ; metta_head_owns_name(Space, Name)
    -> Visibility = 'public'
    ; metta_contract_fact([visibility, Name, Grade])
    -> downcase_atom(Grade, Visibility)
    ; Visibility = 'public' ).
metta_head_property(Space, Name, [origin, Home, File, Line]) :-
    metta_head_origins(Space, Name, Origins), member([Home, File, Line], Origins).
metta_head_property(Space, Name, [effect, Effect]) :-
    metta_head_sources(Space, Name, Sources),
    findall(E, (member(_-Original, Sources), metta_operation_effect(Original, E)), Es),
    Es = [_|_], metta_effect_compose(Es, Effect).
metta_head_property(Space, Name, [cost, Class, Measure]) :-
    metta_head_sources(Space, Name, Sources),
    findall(C-M,
            ( member(_-Original, Sources), metta_cost_declaration(Original, _, C, M) ),
            Claims0),
    sort(Claims0, Claims), member(Class-Measure, Claims).
metta_head_property(Space, Name, [deprecated, Since, Remedy]) :-
    metta_head_sources(Space, Name, Sources),
    findall(S-R, (member(_-Original, Sources), metta_deprecation(Original, S, R)), Claims0),
    sort(Claims0, Claims), member(Since-Remedy, Claims).
metta_head_property(Space, Name, [doc|Fields]) :-
    'get-doc-space'(Space, Name, ['@doc', Name|Fields]).
metta_head_property(Space, Name, [Key, Value]) :-
    % policy-inventory-exempt: mechanism-internal; reason=source export properties handled by this generic property clause; evidence=engine/metta/properties.pl:metta_head_export_property/4
    member(Key, [volatility, determinism]),
    metta_head_sources(Space, Name, Sources),
    findall(Claim, (member(Home-Original, Sources),
                    metta_head_export_property(Home, Original, Key, Claim)), Claims0),
    sort(Claims0, Claims), member(Value, Claims).

% Retain source-owned declaration occurrences. The latest surviving one in a
% home overrides earlier declarations; withdrawing it reveals its predecessor.
metta_head_export_property(Home, Name, Key, Value) :-
    findall((Generation-Actor)-Claim,
            ( spaces:metta_space_pair(Home, [Key,Name,Claim], Token, _),
              spaces:metta_token_parts(Token, Actor, Generation) ), Claims),
    ( Claims == []
    -> \+ metta_reference_prolog_head(Home, Name, _),
       metta_head_global_export_property(Name, Key, Value)
    ; keysort(Claims, Ordered), last(Ordered, _-Value) ).

metta_head_global_export_property(Name, volatility, Value) :-
    metta_function_volatility(Name, Value).
metta_head_global_export_property(Name, determinism, Value) :-
    metta_function_determinism(Name, Value).

% A bound pattern reaches the existing native clause index, unlike reading
% every row before classifying it. Both written equation shapes share it.
metta_head_owns_name(Space, Name) :-
    atom(Name),
    ( Head = [Name|_] ; Head = Name ),
    spaces:metta_space_pair(Space, [=,Head,_], _, _), !.
metta_head_owns_name(Space, Name) :-
    spaces:metta_space_pair(Space, Row, _, _),
    metta_reference_row_head(Row, Name), !.
metta_head_owns_name(Space, Name) :-
    space_module(Space, Module), metta_reference_roots(Module, Name, _, _), !.
metta_head_owns_name(Space, Name) :- metta_reference_prolog_head(Space, Name, _), !.

metta_head_sources(Space, Name, Sources) :-
    space_module(Space, Module),
    findall(Home-Original,
            ( metta_reference_roots(Module, Name, _, Roots),
              member(root(Home, Original, _, _), Roots) ), Found),
    ( Found == []
    -> metta_head_home(Space, Module, Name, Home), Sources = [Home-Name]
    ; sort(Found, Sources) ).

metta_head_home(Space, _, Name, Space) :- metta_head_owns_name(Space, Name), !.
metta_head_home(_, Module, Name, Home) :-
    compiled_function_name(Name, Predicate),
    arity(Name, Arity), current_predicate(Module:Predicate/Arity),
    functor(Head, Predicate, Arity),
    predicate_property(Module:Head, implementation_module(Owner)), !,
    ( metta_module_space(Owner, Home) -> true ; Home = '&metta' ).
metta_head_home(Space, _, _, Space).

% A library card names source files, while a callable door names its space.
% Both are read-only scopes; a card of an unloaded library uses the existing
% global claims and never causes an import.
metta_head_claims(space(Space), Names, Rows) :-
    metta_head_claims_in(Space, Names, Rows).
metta_head_claims(sources(Paths), Names, Rows) :-
    ( member(Path, Paths), metta_reference_library_home(Home, Path)
    -> Space = Home ; Space = '&self' ),
    metta_head_claims_in(Space, Names, Rows).

metta_head_claims_in(Space, Names, Rows) :-
    findall([Name, Properties],
            ( member(Name, Names),
              findall(Property, metta_head_property(Space, Name, Property), Properties) ),
            Rows).

% The former Python origin walk lived above the host seam. Its source cache
% and per-load occurrence counter now use the engine's source_positions/3.
% Stored occurrences avoid forcing a lazy body merely to locate its equation.
metta_head_origins(Space, Name, Origins) :-
    metta_head_sources(Space, Name, Sources),
    findall(Item,
            ( member(Home-Original, Sources),
              metta_head_origin_items(Home, Original, Items), member(Item, Items) ),
            All),
    metta_origin_locations(All, [], _, [], _, Origins).

metta_head_origin_items(Home, Name, Items) :-
    findall(Arity-row(Home, Row, Ref),
            ( spaces:metta_space_pair(Home, Row, Token, Ref),
              Row = [=, [Name|Args], _],
              metta_reference_equation_arity(Home, Name, Token, Args, Arity) ), Rows),
    ( Rows = [_|_]
    -> keysort(Rows, Ordered), pairs_values(Ordered, Items)
    ; space_module(Home, Module), compiled_function_name(Name, Predicate),
      findall(A, arity(Name, A), As0), sort(As0, As),
      findall(clause(Home, Ref),
              ( member(A, As), current_predicate(Module:Predicate/A),
                functor(Head, Predicate, A),
                predicate_property(Module:Head, number_of_clauses(_)),
                nth_clause(Module:Head, _, Ref) ), Items) ).

metta_origin_locations([], Seen, Seen, Cache, Cache, []).
metta_origin_locations([Item|Items], Seen0, Seen, Cache0, Cache, [Origin|Origins]) :-
    metta_origin_location(Item, Seen0, Seen1, Cache0, Cache1, Origin),
    metta_origin_locations(Items, Seen1, Seen, Cache1, Cache, Origins).

metta_origin_location(clause(Home, Ref), Seen, Seen, Cache, Cache, [Home, File, Line]) :-
    ( clause_property(Ref, file(Path)), clause_property(Ref, line_count(K))
    -> atom_string(Path, File), Line = K
    ; File = "", Line = -1 ).
metta_origin_location(row(Home, Row, Ref), Seen0, Seen, Cache0, Cache,
                      [Home, File, Line]) :-
    ( filereader:source_load_assertion(Load, stored, Ref),
      filereader:source_load_identity(Load, Path, _)
    -> atom_string(Path, File),
       metta_origin_source(Path, Cache0, Cache, Forms),
       copy_term(Row, KeyRow), numbervars(KeyRow, 0, _),
       metta_origin_ordinal(Load-KeyRow, Seen0, Seen, K),
       findall(L,
               ( member(form(Parsed, L), Forms),
                 parsed_form_parts(Parsed, function, _, Equation), Equation =@= Row ),
               Lines),
       findall(Stored,
               ( filereader:source_load_assertion(Load, stored, Stored),
                 spaces:stored_atom_of_ref(Stored, Home, Held, _), Held =@= Row ), Alive),
       ( same_length(Lines, Alive), nth0(K, Lines, Found)
       -> Line = Found ; Line = -1 )
    ; File = "", Line = -1, Seen = Seen0, Cache = Cache0 ).

metta_origin_ordinal(Key, Seen0, [Key-Next|Rest], K) :-
    ( selectchk(Key-K0, Seen0, Rest) -> K = K0 ; K = 0, Rest = Seen0 ),
    Next is K+1.

metta_origin_source(Path, Cache, Cache, Forms) :- memberchk(Path-Forms, Cache), !.
metta_origin_source(Path, Cache, [Path-Forms|Cache], Forms) :-
    ( catch(filereader:read_source_text(Path, Text), _, fail),
      catch(filereader:metta_host_tagged_parse(Text, Parsed), _, fail),
      catch(source_positions(Text, Parsed, Positioned), _, fail)
    -> maplist(metta_origin_form, Parsed, Positioned, Forms)
    ; Forms = [] ).

metta_origin_form(Parsed, positioned(_, _, Line, _, _), form(Parsed, Line)).
