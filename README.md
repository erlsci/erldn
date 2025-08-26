# erldn

[![Build Status][gh-actions-badge]][gh-actions]

[![Project Logo][logo]][logo-large]

*An EDN parser for BEAM languages, to read Clojure's Extensible Data Notation*

## Overview

`erldn` is a low level parser: it simply provides an Erlang data structure.

This project implements EDN support using leex and yecc. Results are tested with eunit.

## Features

Notes on how this fork differs from the original are given below.

#### v1.2.0
* support for special numerical values `##Inf`, `##-Inf`, and `##NaN`
* support for EDN metadata syntax `^{:meta true} value`
* bug fix: symbols cannot start with integers
* TBD

#### v1.1.0
* provides a new top-level `parse/1` function
* supports binary input (in addition to the original string input)
* supports file input (if the passed string is a file that exists and ends with `.edn`, it will be read)
* provides a `parse_file/1` function
* adds support for multiple top-level EDN data elements in a single input (returns a list of results)

And [more to come](https://github.com/erlsci/erldn/milestones?sort=title&direction=asc) ...

## Usage

### Add Dependency

In your project's `rebar.config`:

```erlang
{deps, [
    {erldn, "1.1.0", {pkg, erlsci_edn}},
]}.
```

### Examples

```erlang
1> erldn:parse("{}").
{ok,{map,[]}}

2> erldn:parse("1").
{ok,1}

3> erldn:parse("true").
{ok,true}

4> erldn:parse("nil").
{ok,nil}

5> erldn:parse("[1 true nil]").
{ok,{vector,[1,true,nil]}}

6> erldn:parse("(1 true nil :foo)").
{ok,[1,true,nil,foo]}

7> erldn:parse("(1 true nil :foo ns/foo)").
{ok,[1,true,nil,foo,{symbol,'ns/foo'}]}

8> erldn:parse("#{1 true nil :foo ns/foo}").
{ok,{set,[1,true,nil,foo,{symbol,'ns/foo'}]}}

9> erldn:parse("#myapp/Person {:first \"Fred\" :last \"Mertz\"}").
{ok,{tag,'myapp/Person',
         {map,[{first,"Fred"},{last,"Mertz"}]}}}

10> erldn:parse("#{1 true #_ nil :foo ns/foo}").
{ok,{set,[1,true,{ignore,nil},foo,{symbol,'ns/foo'}]}}
11> erldn:parse("#{1 true #_ 42 :foo ns/foo}").
{ok,{set,[1,true,{ignore,42},foo,{symbol,'ns/foo'}]}}

% to_string

12> {ok, Result} = erldn:parse("{:a 42}").
{ok,{map,[{a,42}]}}
13> io:format("~s~n", [erldn:to_string(Result)]).
{:a 42}
ok

% to_erlang

14> erldn:to_erlang(element(2, erldn:parse("[1, nil, :nil, \"asd\"]"))).
[1,nil,nil,<<"asd">>]

% metadata

15> erldn:parse("^:keyword value").
{ok,{metadata,{symbol,value},keyword}}
16> erldn:parse("^{:author \"Alice\"} [1 2 3]").
{ok,{metadata,{vector,[1,2,3]},{map,[{author,<<"Alice">>}]}}}
17> erldn:parse("^:a ^:b value").
{ok,{metadata,{symbol,value},{map,[{a,true},{b,true}]}}}
```

## API

### parse/1
high-level parsing function that accepts either binary or string input; automatically
detects if input is a filename ending in `.edn` and reads the file, otherwise
parses the input directly; for single values returns the unwrapped result,
for multiple values returns a list

### parse_file/1
parses an EDN file by reading the contents and parsing them; the filename must
end with `.edn` extension; supports both single and multiple top-level values

### parse_str/1
parses a string with EDN into an erlang data structure maintaining all
the details from the original edn; for single values returns unwrapped result,
for multiple values returns a list

### to_string/1
converts the result from parsing functions into an edn string representation

### to_erlang/1
converts the result from parsing functions into an erlang-friendly version of
itself; see "To Erlang Mappings" below.

### to_erlang/2
like `to_erlang/1` but accepts a tuplelist as a second argument with a
tag as the first argument and a function `(fun (Tag, Value, OtherHandlers) -> .. end)`
as the second of each pair to handle tagged values.

### lex_str/1
tokenizes an EDN string into a list of lexical tokens; primarily used internally
by the parser but can be useful for debugging or custom parsing scenarios

Be sure to check the unit tests for usage examples; there are hundreds of them.

## Parser Type Mappings

This table shows how EDN data types are represented in Erlang after parsing with `erldn:parse/1` or `erldn:parse_str/1`. These are the "raw" parsed representations that preserve EDN semantics and can be converted back to EDN strings.

| EDN Type                   | EDN Example                           | Erlang Representation                        | Erlang Example                                         |
|----------------------------|---------------------------------------|----------------------------------------------|--------------------------------------------------------|
| **nil**                    | `nil`                                 | `nil` (atom)                                 | `nil`                                                  |
| **boolean**                | `true`, `false`                       | boolean atoms                                | `true`, `false`                                        |
| **integer**                | `42`, `-17`, `+5`                     | integer                                      | `42`, `-17`, `5`                                       |
| **integer with N suffix**  | `42N`                                 | integer (arbitrary precision marker ignored) | `42`                                                   |
| **float**                  | `3.14`, `1.2e5`                       | float                                        | `3.14`, `120000.0`                                     |
| **float with M suffix**    | `3.14M`                               | float (exact precision marker ignored)       | `3.14`                                                 |
| **character**              | `\c`, `\A`, `\newline`                | `{char, Integer}`                            | `{char, 99}`, `{char, 65}`, `{char, 10}`               |
| **string**                 | `"hello world"`                       | binary (UTF-8)                               | `<<"hello world">>`                                    |
| **keyword (simple)**       | `:foo`                                | atom                                         | `foo`                                                  |
| **keyword (namespaced)**   | `:ns/foo`                             | atom                                         | `'ns/foo'`                                             |
| **keyword (special case)** | `:nil`                                | `{keyword, nil}`                             | `{keyword, nil}`                                       |
| **symbol**                 | `foo`, `ns/bar`, `/`                  | `{symbol, Atom}`                             | `{symbol, foo}`, `{symbol, 'ns/bar'}`, `{symbol, '/'}` |
| **list**                   | `(1 2 3)`                             | list                                         | `[1, 2, 3]`                                            |
| **vector**                 | `[1 2 3]`                             | `{vector, List}`                             | `{vector, [1, 2, 3]}`                                  |
| **map**                    | `{:a 1 :b 2}`                         | `{map, PropList}`                            | `{map, [{a, 1}, {b, 2}]}`                              |
| **set**                    | `#{1 2 3}`                            | `{set, List}`                                | `{set, [1, 2, 3]}`                                     |
| **tagged element**         | `#inst "2024-01-01"`                  | `{tag, Symbol, Value}`                       | `{tag, 'inst', <<"2024-01-01">>}`                      |
| **discard element**        | `#_ 42`                               | `{ignore, Value}`                            | `{ignore, 42}`                                         |
| **comments**               | `; comment`                           | (ignored during parsing)                     | (not represented)                                      |
| **positive infinity**      | `##Inf`                               | `{tag, inf, pos}`                            | `{tag, inf, pos}`                                      |
| **negative infinity**      | `##-Inf`                              | `{tag, inf, neg}`                            | `{tag, inf, neg}`                                      |
| **not a number**           | `##NaN`                               | `{tag, nan, nil}`                            | `{tag, nan, nil}`                                      |
| **metadata**               | `^:keyword value`, `^{:key val} data` | `{metadata, Value, Meta}`                    | `{metadata, {symbol, test}, keyword}`                  |

## Implementation Status

| Feature               | Status             | Notes                                  |
|-----------------------|--------------------|----------------------------------------|
| **Ratios**            | ❌ Not implemented  | `22/7` will parse as symbol, not ratio |
| **Advanced integers** | ❌ Not implemented  | `0xFF`, `0777`, `36rZ` not supported   |
| **Unicode chars**     | ❌ Limited          | `\uNNNN` format not supported          |
| **Octal chars**       | ❌ Not implemented  | `\oNNN` format not supported           |
| **String escapes**    | ⚠️ Partial         | Basic escapes only                     |
| **Metadata**          | ✅ Supported        | `^{:meta true} value` supported        |

## Notes

1. **Keywords vs Symbols**: Keywords start with `:` and become atoms. Symbols become `{symbol, atom}` tuples to distinguish them from keywords.

2. **Namespace Handling**: Both keywords and symbols can have namespaces separated by `/`. The entire string becomes a single atom with the `/` included.

3. **Set Uniqueness**: Sets are parsed as lists and do not enforce uniqueness at parse time.

4. **Map Ordering**: Maps are represented as property lists maintaining insertion order.

5. **Character Representation**: Characters are tagged tuples containing the Unicode code point as an integer.

6. **Nil Keyword Special Case**: The keyword `:nil` is handled specially to avoid confusion with the `nil` atom.

7. **Binary Strings**: All strings are converted to UTF-8 binaries for efficient memory usage and Unicode support.

8. **Nested Structures**: All container types (lists, vectors, maps, sets) can contain any other EDN types including other containers.

## To Erlang Mappings

This table shows how the parsed EDN data structures are transformed by `erldn:to_erlang/1` and `erldn:to_erlang/2` into more Erlang-idiomatic representations. These transformations make the data easier to work with in Erlang but cannot be directly converted back to EDN without additional type information.

| Parsed Representation     | Erlang-Friendly Result                | Notes                                 |
|---------------------------|---------------------------------------|---------------------------------------|
| `nil`                     | `nil`                                 |                                       |
| `true`                    | `true`                                |                                       |
| `false`                   | `false`                               |                                       |
| `42`                      | `42`                                  |                                       |
| `3.14`                    | `3.14`                                |                                       |
| `{char, 99}`              | `"c"`                                 |                                       |
| `<<"hello">>`             | `<<"hello">>`                         |                                       |
| `foo` (keyword)           | `foo`                                 |                                       |
| `{keyword, nil}`          | `nil`                                 |                                       |
| `{symbol, foo}`           | `{symbol, foo}`                       |                                       |
| `[1, 2, 3]` (list)        | `[1, 2, 3]`                           |                                       |
| `{vector, [1, 2, 3]}`     | `[1, 2, 3]`                           |                                       |
| `{map, [{a, 1}, {b, 2}]}` | `dict:dict()`                         |                                       |
| `{set, [1, 2, 3]}`        | `sets:set()`                          |                                       |
| `{tag, inf, pos}`         | `positive_infinity`                   |                                       |
| `{tag, inf, neg}`         | `negative_infinity`                   |                                       |
| `{tag, nan, nil}`         | `not_a_number`                        |                                       |
| `{tag, Symbol, Value}`    | *Handler Result*                      | Calls registered tag handler or fails |
| `{ignore, Value}`         | *Undefined*                           | No documented transformation          |
| `{metadata, Value, Meta}` | `{metadata, ErlangValue, ErlangMeta}` |                                       |

## Tag Handler System

Tagged elements are processed using a configurable handler system:

### Default Handlers
The `to_erlang/2` function accepts handler specifications:

```erlang
Handlers = [{tag_symbol, fun(Tag, Value, OtherHandlers) -> Result end}]
erldn:to_erlang(ParsedData, Handlers)
```

### Handler Function Signature
```erlang
Handler = fun(Tag, Value, OtherHandlers) -> TransformedValue end
```

- **Tag**: The tag symbol (e.g., `'inst'`, `'uuid'`)
- **Value**: The tagged value after transformation
- **OtherHandlers**: List of other available handlers for nested processing

### Common Tag Examples

| Tag         | Example Input                                               | Typical Handler Result               |
|-------------|-------------------------------------------------------------|--------------------------------------|
| `#inst`     | `{tag, 'inst', <<"2024-01-01T12:00:00Z">>}`                 | `{datetime, {{2024,1,1}, {12,0,0}}}` |
| `#uuid`     | `{tag, 'uuid', <<"550e8400-e29b-41d4-a716-446655440000">>}` | Binary UUID or custom UUID record    |
| Custom tags | `{tag, 'myapp/Person', {map, [...]}}`                       | Application-specific data structure  |

## Data Structure Transformations

### Maps → Dicts
- **Before**: `{map, [{key1, val1}, {key2, val2}]}`
- **After**: `dict:dict()` with key-value associations
- **Access**: Use `dict:fetch/2`, `dict:find/2`, etc.
- **Benefits**: O(log n) lookup, functional updates

### Sets → Sets Module
- **Before**: `{set, [elem1, elem2, elem3]}`
- **After**: `sets:set()` with unique elements
- **Access**: Use `sets:is_element/2`, `sets:to_list/1`, etc.
- **Benefits**: Automatic uniqueness, set operations

### Vectors → Lists
- **Before**: `{vector, [1, 2, 3]}`
- **After**: `[1, 2, 3]`
- **Benefits**: Simpler Erlang idiom
- **Trade-offs**: Loses type distinction from lists

### Characters → Strings
- **Before**: `{char, 65}`
- **After**: `"A"`
- **Benefits**: More natural Erlang representation
- **Note**: Single-character strings, not charlists

## Error Handling

### Unknown Tags
When `to_erlang/1` encounters a tag without a registered handler:
- **Behavior**: Raises an error
- **Solution**: Use `to_erlang/2` with appropriate handlers
- **Alternative**: Implement a catch-all default handler

### Nested Transformations
All nested values are recursively transformed:
- Map values are processed through `to_erlang`
- Set elements are processed through `to_erlang`
- List elements are processed through `to_erlang`
- Tagged values are processed *before* being passed to handlers

## Usage Patterns

### Simple Transformation
```erlang
{ok, ParsedData} = erldn:parse("{:name \"John\" :age 30}"),
ErlangData = erldn:to_erlang(ParsedData).
% ErlangData is a dict with name→<<"John">>, age→30
```

### With Custom Handlers
```erlang
Handlers = [
    {'inst', fun(Tag, DateStr, _) -> parse_iso_date(DateStr) end},
    {'uuid', fun(Tag, UuidStr, _) -> uuid:parse(UuidStr) end}
],
ErlangData = erldn:to_erlang(ParsedData, Handlers).
```

## Limitations

1. **Information Loss**: Cannot reconstruct original EDN types (vectors vs lists)
2. **Handler Dependencies**: Tagged elements require appropriate handlers
3. **Type Ambiguity**: Some transformations lose type information
4. **Discard Elements**: No clear specification for `{ignore, Value}` handling

## Best Practices

1. **Use with Tag Handlers**: Always provide handlers for expected tagged elements
2. **Document Transformations**: Keep track of which data came from EDN for debugging
3. **Test Round-trips**: Verify data integrity when relevant
4. **Handle Errors**: Account for missing tag handlers in production code

## License

The MIT License

[//]: ---Named-Links---

[logo]: priv/images/project.jpg
[logo-large]: priv/images/project-large.jpg
[gh-actions-badge]: https://github.com/erlsci/erldn/workflows/ci/badge.svg
[gh-actions]: https://github.com/erlsci/erldn/actions?query=workflow%3Aci
