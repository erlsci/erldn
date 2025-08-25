# Implementation Guide: EDN Metadata Support

## Overview

This document provides detailed instructions for implementing support for EDN metadata in the erldn library. Metadata in EDN/Clojure allows attaching additional information to data structures without affecting their semantic value. Currently, the erldn library does not support metadata parsing or preservation.

## Background

EDN metadata is expressed using the `^` (caret) symbol followed by metadata and then the target value:

```edn
^{:author "John" :version 1} [1 2 3]
^:keyword some-symbol
^"string-metadata" {:key :value}
^{:doc "A function"} (fn [x] x)
```

Key characteristics:
- Metadata can be maps, keywords, symbols, or strings
- Multiple metadata forms can be chained: `^:a ^:b ^{:c 1} value`
- Metadata is "invisible" to equality comparisons but preserved for tooling
- Shorthand forms: `^:keyword` expands to `^{:keyword true}`

## Current State Analysis

Based on the provided test files, the library currently does **not** handle metadata. Looking at the EDN files in `priv/edn/`, there don't appear to be any examples of metadata syntax (`^` prefix), suggesting this feature is completely unimplemented.

## Implementation Steps

### 1. Update the Lexer (`src/erldn_lexer.xrl`)

Add lexer rules to recognize the metadata caret symbol:

```erlang
% Add to Definitions section:
Caret       = \^

% Add to Rules section (place before symbol rules):
{Caret}                  : make_token(caret, TokenLine, TokenChars).
```

**Important Notes:**
- Place the caret rule BEFORE general symbol rules to ensure proper tokenization
- The caret `^` symbol is the metadata prefix in EDN

### 2. Update the Parser (`src/erldn_parser.yrl`)

Add metadata support to the parser grammar:

```erlang
% Add to Nonterminals:
Nonterminals
    values value list list_items vector set map key_value_pairs key_value_pair 
    tagged metadata_value.

% Add to Terminals:
Terminals
    float integer boolean string nil open_list close_list open_vector
    close_vector open_map close_map sharp ignore keyword symbol char
    caret.

% Add metadata parsing rules:
metadata_value -> caret value value : {with_meta, '$3', '$2'}.

% Update value rules to include metadata:
value -> nil     : unwrap('$1').
value -> float   : unwrap('$1').
value -> integer : unwrap('$1').
value -> boolean : unwrap('$1').
value -> string  : unwrap('$1').
value -> list    : '$1'.
value -> vector  : '$1'.
value -> set     : '$1'.
value -> map     : '$1'.
value -> keyword : 
    Keyword = unwrap('$1'),
    if
        Keyword == nil -> {keyword, nil};
        true -> Keyword
    end.
value -> symbol  : {symbol, unwrap('$1')}.
value -> tagged  : '$1'.
value -> char    : {char, unwrap('$1')}.
value -> ignore value : {ignore, '$2'}.
value -> metadata_value : '$1'.  % <-- Add this
```

**Design Decisions:**
- Use `{metadata, Value, Meta}` tuple structure
- This preserves both the value and its associated metadata
- Allows for nested metadata processing

### 3. Handle Metadata Chaining

For chained metadata like `^:a ^:b ^{:c 1} value`, extend the parser:

```erlang
% Enhanced metadata parsing with chaining support:
metadata_value -> caret value value : {metadata, '$3', '$2'}.
metadata_value -> caret value metadata_value : 
    {metadata, Value, PrevMeta} = '$3',
    NewMeta = merge_metadata('$2', PrevMeta),
    {metadata, Value, NewMeta}.
```

Note: You'll need to implement `merge_metadata/2` in the Erlang code section.

### 4. Update String Conversion (`src/erldn.erl`)

Add cases to the `to_string/2` function for metadata:

```erlang
to_string({metadata, Value, Meta}, Accum) ->
    % Convert metadata to string form
    MetaStr = to_string(Meta),
    ValueStr = to_string(Value),
    [ValueStr, " ", MetaStr, "^" | Accum];
```

**Important:** Handle different metadata types appropriately:
- Keywords should be rendered as `^:keyword`
- Maps should be rendered as `^{:key value}`
- Strings should be rendered as `^"string"`

### 5. Update Erlang Conversion (`src/erldn.erl`)

Add metadata handling to `to_erlang/2`:

```erlang
% Option 1: Preserve metadata in tuple
to_erlang({metadata, Value, Meta}, Handlers) ->
    {with_metadata, to_erlang(Value, Handlers), to_erlang(Meta, Handlers)};

% Option 2: Strip metadata (if not needed in Erlang)
to_erlang({metadata, Value, _Meta}, Handlers) ->
    to_erlang(Value, Handlers);

% Option 3: Store in process dictionary or ETS for retrieval
to_erlang({metadata, Value, Meta}, Handlers) ->
    ConvertedValue = to_erlang(Value, Handlers),
    % Store metadata associated with value
    store_metadata(ConvertedValue, to_erlang(Meta, Handlers)),
    ConvertedValue.
```

Choose the approach that best fits your use case.

### 6. Add Helper Functions

Add utility functions for metadata processing:

```erlang
% Helper function for merging chained metadata
merge_metadata(NewMeta, {with_meta, Value, ExistingMeta}) ->
    % Handle chained metadata case
    CombinedMeta = combine_metadata_maps(NewMeta, ExistingMeta),
    {with_meta, Value, CombinedMeta};
merge_metadata(NewMeta, ExistingMeta) ->
    % Handle simple case
    combine_metadata_maps(NewMeta, ExistingMeta).

% Combine different metadata types into a map
combine_metadata_maps(Meta1, Meta2) ->
    Map1 = normalize_metadata_to_map(Meta1),
    Map2 = normalize_metadata_to_map(Meta2),
    merge_maps(Map1, Map2).

% Convert different metadata forms to maps
normalize_metadata_to_map(Keyword) when is_atom(Keyword) ->
    {map, [{Keyword, true}]};
normalize_metadata_to_map({map, _} = Map) ->
    Map;
normalize_metadata_to_map(String) when is_binary(String) ->
    {map, [{tag, String}]};
normalize_metadata_to_map(Other) ->
    {map, [{value, Other}]}.
```

### 7. Create Test Data

Create comprehensive test EDN files in `priv/edn/`:

#### `priv/edn/metadata-basic.edn`
```edn
^{:author "Alice"} [1 2 3]
^:keyword symbol
^"string-meta" {:key :value}
^42 some-symbol
```

#### `priv/edn/metadata-chained.edn`
```edn
^:a ^:b ^{:c 1} [1 2 3]
^{:author "Bob"} ^:validated ^"v1.0" {:data "important"}
^:first ^{:second true} ^"third" nested-metadata
```

#### `priv/edn/metadata-complex.edn`
```edn
^{:doc "A vector of maps"} 
[^{:id 1} {:name "Alice"}
 ^{:id 2} {:name "Bob"}
 ^{:id 3} {:name "Charlie"}]

^{:version 1 :author "system"}
{:users ^{:indexed true} [1 2 3]
 :config ^:readonly {:debug false}}
```

#### `priv/edn/metadata-nested.edn`
```edn
^{:level 1} 
{:outer ^{:level 2} 
  {:inner ^{:level 3} 
    [^:item 1 ^:item 2 ^:item 3]}}
```

### 8. Add Comprehensive Tests

#### 8.1 Lexer Tests (`test/erldn_metadata_lexer_test.erl`)

```erlang
-module(erldn_metadata_lexer_test).
-include_lib("eunit/include/eunit.hrl").

check_lex(Str, ExpectedTokens) ->
    {ok, Tokens, _} = erldn:lex_str(Str),
    TokenTypes = [element(1, T) || T <- Tokens],
    ?assertEqual(ExpectedTokens, TokenTypes).

basic_metadata_tokenization_test() ->
    check_lex("^:keyword value", 
              [caret, keyword, symbol]).

metadata_map_tokenization_test() ->
    check_lex("^{:key :value} [1 2 3]",
              [caret, open_map, keyword, keyword, close_map, 
               open_vector, integer, integer, integer, close_vector]).

chained_metadata_tokenization_test() ->
    check_lex("^:a ^:b ^{:c 1} value",
              [caret, keyword, caret, keyword, caret, open_map, 
               keyword, integer, close_map, symbol]).

metadata_string_tokenization_test() ->
    check_lex("^\"string-meta\" symbol",
              [caret, string, symbol]).

caret_recognition_test() ->
    {ok, [CaretToken], _} = erldn:lex_str("^"),
    ?assertEqual({caret, 1, '^'}, CaretToken).
```

#### 8.2 Parser Tests (`test/erldn_metadata_parser_test.erl`)

```erlang
-module(erldn_metadata_parser_test).
-include_lib("eunit/include/eunit.hrl").

check_parse(Str, Expected) ->
    {ok, Result} = erldn:parse_str(Str),
    ?assertEqual(Expected, Result).

basic_metadata_parse_test() ->
    check_parse("^:keyword value",
                {with_meta, {symbol, value}, keyword}).

metadata_map_parse_test() ->
    check_parse("^{:author \"Alice\"} [1 2 3]",
                {with_meta, 
                 {vector, [1, 2, 3]}, 
                 {map, [{author, <<"Alice">>}]}}).

metadata_string_parse_test() ->
    check_parse("^\"documentation\" symbol",
                {with_meta, {symbol, symbol}, <<"documentation">>}).

chained_metadata_parse_test() ->
    check_parse("^:a ^:b value",
                {with_meta, {symbol, value}, 
                 {map, [{a, true}, {b, true}]}}).

nested_metadata_parse_test() ->
    check_parse("^{:outer true} [^:inner 1]",
                {with_meta,
                 {vector, [{with_meta, 1, inner}]},
                 {map, [{outer, true}]}}).

multiple_values_with_metadata_test() ->
    check_parse("^:first 1 ^:second 2",
                [{with_meta, 1, first}, {with_meta, 2, second}]).
```

#### 8.3 String Conversion Tests (`test/erldn_metadata_string_test.erl`)

```erlang
-module(erldn_metadata_string_test).
-include_lib("eunit/include/eunit.hrl").

check_roundtrip(EdnStr) ->
    {ok, Parsed} = erldn:parse_str(EdnStr),
    Reconstructed = lists:flatten(erldn:to_string(Parsed)),
    {ok, ReParsed} = erldn:parse_str(Reconstructed),
    ?assertEqual(Parsed, ReParsed).

keyword_metadata_roundtrip_test() ->
    check_roundtrip("^:keyword value").

map_metadata_roundtrip_test() ->
    check_roundtrip("^{:author \"Alice\"} [1 2 3]").

string_metadata_roundtrip_test() ->
    check_roundtrip("^\"docs\" symbol").

chained_metadata_roundtrip_test() ->
    check_roundtrip("^:a ^:b value").

complex_metadata_roundtrip_test() ->
    check_roundtrip("^{:version 1} {:data ^:validated [1 2 3]}").

metadata_string_format_test() ->
    Value = {metadata, {symbol, test}, keyword},
    Result = lists:flatten(erldn:to_string(Value)),
    ?assertEqual("^:keyword test", Result).

metadata_map_string_format_test() ->
    Value = {metadata, {vector, [1, 2]}, {map, [{author, <<"Alice">>}]}},
    Result = lists:flatten(erldn:to_string(Value)),
    ?assertEqual("^{:author \"Alice\"} [1 2]", Result).
```

#### 8.4 Erlang Conversion Tests (`test/erldn_metadata_erlang_test.erl`)

```erlang
-module(erldn_metadata_erlang_test).
-include_lib("eunit/include/eunit.hrl").

metadata_preservation_test() ->
    % Test that metadata is preserved in Erlang conversion
    Input = {with_meta, [1, 2, 3], {map, [{author, <<"Alice">>}]}},
    Result = erldn:to_erlang(Input),
    ?assertMatch({with_metadata, [1, 2, 3], _}, Result).

metadata_stripping_test() ->
    % Alternative: test that metadata can be stripped if desired
    Input = {with_meta, [1, 2, 3], {map, [{author, <<"Alice">>}]}},
    % Assuming a strip_metadata option
    Result = erldn:to_erlang(Input, [{strip_metadata, true}]),
    ?assertEqual([1, 2, 3], Result).

nested_metadata_erlang_test() ->
    Input = {metadata, 
             {vector, [{metadata, 1, inner}]}, 
             {map, [{outer, true}]}},
    Result = erldn:to_erlang(Input),
    ?assertMatch({with_metadata, 
                  [{with_metadata, 1, inner}], 
                  _}, Result).
```

#### 8.5 Integration Tests (`test/erldn_metadata_integration_test.erl`)

```erlang
-module(erldn_metadata_integration_test).
-include_lib("eunit/include/eunit.hrl").

file_parsing_metadata_test() ->
    % Test parsing files with metadata
    MetadataFiles = [
        "metadata-basic.edn",
        "metadata-chained.edn", 
        "metadata-complex.edn",
        "metadata-nested.edn"
    ],
    
    lists:foreach(fun(Filename) ->
        FilePath = filename:join([code:priv_dir(erldn), "edn", Filename]),
        Result = erldn:parse_file(FilePath),
        ?assertMatch({ok, _}, Result),
        
        % Test that result contains metadata structures
        {ok, Data} = Result,
        ?assert(contains_metadata(Data))
    end, MetadataFiles).

contains_metadata(Data) when is_list(Data) ->
    lists:any(fun contains_metadata/1, Data);
contains_metadata({metadata, _, _}) ->
    true;
contains_metadata({vector, Items}) ->
    contains_metadata(Items);
contains_metadata({map, Pairs}) ->
    lists:any(fun({K, V}) -> 
        contains_metadata(K) orelse contains_metadata(V) 
    end, Pairs);
contains_metadata({set, Items}) ->
    contains_metadata(Items);
contains_metadata(_) ->
    false.

large_metadata_file_test() ->
    % Test with large file containing many metadata annotations
    Content = generate_large_metadata_content(),
    TempFile = "large_metadata_test.edn",
    file:write_file(TempFile, Content),
    
    {ok, Data} = erldn:parse_file(TempFile),
    file:delete(TempFile),
    
    % Verify metadata is preserved throughout
    ?assert(contains_metadata(Data)).

generate_large_metadata_content() ->
    Items = [io_lib:format("^{:id ~p :type \"item\"} ~p", [N, N]) 
             || N <- lists:seq(1, 100)],
    Content = string:join(Items, "\n"),
    lists:flatten(Content).

metadata_performance_test() ->
    % Test that metadata doesn't significantly impact performance
    SimpleContent = string:join([integer_to_list(N) || N <- lists:seq(1, 1000)], " "),
    MetadataContent = string:join([io_lib:format("^:item ~p", [N]) || N <- lists:seq(1, 1000)], " "),
    
    SimpleContent2 = lists:flatten(SimpleContent),
    MetadataContent2 = lists:flatten(MetadataContent),
    
    {SimpleTime, _} = timer:tc(fun() -> erldn:parse_str(SimpleContent2) end),
    {MetaTime, _} = timer:tc(fun() -> erldn:parse_str(MetadataContent2) end),
    
    % Metadata parsing should not be more than 3x slower
    Ratio = MetaTime / SimpleTime,
    ?assert(Ratio < 3.0).
```

### 9. Update Documentation

#### 9.1 Update README.md

Add metadata support to the feature table:

```markdown
| EDN Feature | Supported | Erlang Representation |
|-------------|-----------|---------------------|
| Metadata | ✅ | `{metadata, Value, Meta}` |

## Metadata Support

The library supports EDN metadata syntax:

```erlang
% Parse metadata
{ok, Data} = erldn:parse_str("^{:author \"Alice\"} [1 2 3]"),
% Data = {metadata, {vector, [1, 2, 3]}, {map, [{author, <<"Alice">>}]}}

% Convert to Erlang with metadata preserved
ErlangData = erldn:to_erlang(Data),
% ErlangData = {with_metadata, [1, 2, 3], [{author, <<"Alice">>}]}
```

### Metadata Forms

- **Map metadata**: `^{:key value}` 
- **Keyword metadata**: `^:keyword` (expands to `^{:keyword true}`)
- **String metadata**: `^"documentation"`
- **Chained metadata**: `^:a ^:b ^{:c 1} value`
```

#### 9.2 Add Metadata Examples

Create examples showing common metadata patterns:

```erlang
% Function with documentation
FunctionMeta = "^{:doc \"Adds two numbers\"} add",

% Configuration with validation
ConfigMeta = "^:validated ^{:version 1} {:debug true}",

% Data structure with type information
TypedMeta = "^{:type \"user-record\"} {:name \"Alice\" :age 30}".
```

### 10. Error Handling

Add proper error handling for malformed metadata:

```erlang
% In parser, handle cases like:
% - Dangling caret: "^" (no metadata or value)
% - Invalid metadata: "^}invalid{"
% - Metadata without value: "^:keyword"

% Add error recovery rules:
metadata_value -> caret error : 
    return_error(TokenLine, "Invalid metadata syntax").
```

### 11. Performance Considerations

#### Memory Usage
- Metadata increases memory usage per value
- Consider whether to preserve metadata during conversion
- Provide options to strip metadata if not needed

#### Parsing Performance
- Metadata adds parsing complexity
- Ensure lexer rules are ordered efficiently
- Consider caching compiled metadata expressions

### 12. Advanced Features

#### Metadata Inheritance
Consider whether child elements should inherit parent metadata:

```erlang
% Should this:
"^{:namespace \"user\"} {:data [1 2 3]}"
% Result in the vector also having namespace metadata?
```

#### Metadata Queries
Provide utilities for working with metadata:

```erlang
% Get metadata from a value
get_metadata({metadata, _Value, Meta}) -> Meta;
get_metadata(_) -> undefined.

% Strip metadata from a structure  
strip_metadata({metadata, Value, _Meta}) -> strip_metadata(Value);
strip_metadata({vector, Items}) -> {vector, [strip_metadata(I) || I <- Items]};
strip_metadata(Other) -> Other.

% Merge metadata
merge_metadata(Value, NewMeta) ->
    case Value of
        {metadata, V, ExistingMeta} ->
            {metadata, V, combine_metadata_maps(ExistingMeta, NewMeta)};
        _ ->
            {metadata, Value, NewMeta}
    end.
```

## Implementation Notes

### Lexer Considerations
- The caret `^` must be distinguished from symbols that might contain `^`
- Whitespace handling around metadata expressions
- Ensure caret tokenization doesn't break existing symbol parsing

### Parser Considerations
- Metadata can appear before any value type
- Handle precedence correctly with tagged literals: `#tag ^meta value`
- Support recursive metadata parsing for chained expressions

### Backward Compatibility
- This is a pure addition - no breaking changes
- Existing EDN without metadata should parse unchanged
- Consider version detection for metadata support

### Alternative Representations
If the `{with_meta, Value, Meta}` tuple isn't suitable:

```erlang
% Record-based approach
-record(metadata, {value, meta}).
to_erlang({metadata, Value, Meta}, _) ->
    #metadata{value = to_erlang(Value), meta = to_erlang(Meta)}.

% Map-based approach  
to_erlang({metadata, Value, Meta}, _) ->
    #{value => to_erlang(Value), metadata => to_erlang(Meta)}.

% Process dictionary approach
to_erlang({metadata, Value, Meta}, _) ->
    ConvertedValue = to_erlang(Value),
    Key = make_ref(),
    put({metadata, Key}, to_erlang(Meta)),
    {with_metadata_key, ConvertedValue, Key}.
```

## Validation Checklist

- [ ] Lexer recognizes `^` caret symbol
- [ ] Parser handles basic metadata: `^:keyword value`
- [ ] Parser handles map metadata: `^{:key value} target`  
- [ ] Parser handles string metadata: `^"docs" target`
- [ ] Parser handles chained metadata: `^:a ^:b target`
- [ ] String conversion produces correct EDN representation
- [ ] Round-trip conversion works (parse → stringify → parse)
- [ ] Erlang conversion preserves/handles metadata appropriately
- [ ] Nested metadata works: `^:outer [^:inner 1]`
- [ ] File parsing works with metadata-containing EDN files
- [ ] Performance impact is reasonable
- [ ] Error handling for malformed metadata
- [ ] Documentation updated with examples
- [ ] Comprehensive tests covering edge cases
- [ ] No regressions in existing functionality

## Common Pitfalls

1. **Lexer Rule Ordering**: Caret rule must come before symbol rules
2. **Whitespace**: Ensure proper whitespace handling around metadata
3. **Chaining**: Complex logic needed for chained metadata merging  
4. **Precedence**: Handle interaction with tagged literals correctly
5. **Memory**: Metadata significantly increases memory usage
6. **Round-trip**: Ensure string conversion preserves exact metadata structure
7. **Nesting**: Handle deeply nested metadata correctly
8. **Error Recovery**: Provide meaningful errors for malformed metadata

This implementation will provide complete EDN metadata support while maintaining performance and backward compatibility with the existing erldn library.