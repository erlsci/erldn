# erldn

[![Build Status][gh-actions-badge]][gh-actions]

[![Project Logo][logo]][logo-large]

*An EDN parser for BEAM languages, to read Clojure's Extensible Data Notation*

`erldn` is a low level parser: it simply provides an Erlang data structure.

This project implements EDN support using leex and yecc. Results are tested with eunit.

Notes on how this fork differs from the original:

* provides a new top-level `parse/1` function
* supports binary input (in addition to the original string input)
* support file input (if the passed string is a file that exists and ends with `.edn`, it will be read)
* provides a `parse_file/1` function
* adds support for multiple top-level EDN data elements in a single input (returns a list of results)
* WIP: add support for special numerical values `##Inf`, `##-Inf`, and `##NaN`

## Add Dependency

In your project's `rebar.config`:

```erlang
{deps, [
    {erldn, "1.1.0", {pkg, erlsci_edn}},
]}.
```

## Usage Examples

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

## Type Mappings

| edn | erlang |
|-----|--------|
| integer | integer |
| float | float |
| boolean | boolean |
| nil | nil (atom) |
| char | tagged integer -> {char, <integer>}} |
| string | binary string (utf-8) |
| list | list |
| vector | tagged list -> {vector, [...]} |
| map | tagged property list -> {map, [{key1, val1}, ...]} |
| set | tagged list -> {set, [...]} (not made unique on parsing) |
| symbol | tagged atom -> {symbol, <symbol>} |
| tagged elements | tagged tuple with tag and value -> {tag, Symbol, Value} |

## To Erlang Mappings

The `to_erlang` function transforms the incoming data structure into a more
erlang-friendly data structure, but this can't be converted back to a string
without transforming it again. The mappings by default are:

| edn | erlang |
|-----|--------|
| integer | integer |
| float | float |
| boolean | boolean |
| char | string |
| nil (atom) | nil (atom) |
| nil (symbol) | nil (atom) |
| binary string | binary string |
| list | list |
| vector | list |
| map | dict (dict module) |
| set | set (sets module) |
| symbol | stay the same |
| tagged elements | call registered handler for that tag, fail if not found |

## Notes

* since keywords are mapped to atoms and nil is mapped to the nil atom, if
  the nil keyword is encountered it will be mapped to {keyword, nil}.

## License

The MIT License

[//]: ---Named-Links---

[logo]: priv/images/project.jpg
[logo-large]: priv/images/project-large.jpg
[gh-actions-badge]: https://github.com/erlsci/erldn/workflows/ci/badge.svg
[gh-actions]: https://github.com/erlsci/erldn/actions?query=workflow%3Aci
