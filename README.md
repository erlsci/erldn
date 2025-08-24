# erldn

[![Build Status][gh-actions-badge]][gh-actions]

[![Project Logo][logo]][logo-large]

*An EDN parser for BEAM languages, to read Clojure's Extensible Data Notation*

`erldn` is a low level parser: it simply provides an Erlang data structure.

This project implements EDN support using leex and yecc. Results are tested with eunit.

Notes on how this fork differs from the original:

* provides a new top-level `parse/1` function
* supports binary input
* support file input (if the passed string is a file that exists and ends with `.edn`, it will be read)
* provides a `parse_file/1` function

## Add Dependency

In your project's `rebar.config`:

```erlang
{deps, [
    {erldn, "1.1.0", {pkg, erlsci_edn}},
]}.
```

## Use

```erlang
1> erldn:parse_str("{}").
{ok,{map,[]}}

2> erldn:parse_str("1").
{ok,1}

3> erldn:parse_str("true").
{ok,true}

4> erldn:parse_str("nil").
{ok,nil}

5> erldn:parse_str("[1 true nil]").
{ok,{vector,[1,true,nil]}}

6> erldn:parse_str("(1 true nil :foo)").
{ok,[1,true,nil,foo]}

7> erldn:parse_str("(1 true nil :foo ns/foo)").
{ok,[1,true,nil,foo,{symbol,'ns/foo'}]}

8> erldn:parse_str("#{1 true nil :foo ns/foo}").
{ok,{set,[1,true,nil,foo,{symbol,'ns/foo'}]}}

9> erldn:parse_str("#myapp/Person {:first \"Fred\" :last \"Mertz\"}").
{ok,{tag,'myapp/Person',
         {map,[{first,"Fred"},{last,"Mertz"}]}}}
         10> erldn:parse_str("#{1 true #_ nil :foo ns/foo}").
         {ok,{set,[1,true,{ignore,nil},foo,{symbol,'ns/foo'}]}}
         11> erldn:parse_str("#{1 true #_ 42 :foo ns/foo}").
         {ok,{set,[1,true,{ignore,42},foo,{symbol,'ns/foo'}]}}

 % to_string

 10> {ok, Result} = erldn:parse_str("{:a 42}").
 {ok,{map,[{a,42}]}}

 11> io:format("~s~n", [erldn:to_string(Result)]).
 {:a 42}
 ok

 % to_erlang

 12> erldn:to_erlang(element(2, erldn:parse_str("[1, nil, :nil, \"asd\"]"))).
 [1,nil,nil,<<"asd">>]
```

## API

### parse_str/1
parses a string with edn into an erlang data structure maintaining all
the details from the original edn

### to_string/1
converts the result from *parse_str/1* into an edn string representation

### to_erlang/1
converts the result from *parse_str/1* into an erlang-friendly version of
itself; see "To Erlang Mappings" below.

### to_erlang/2
like *to_erlang/1* but accepts a tuplelist as a second argument with a
tag as the first argument and a function `(fun (Tag, Value, OtherHandlers) -> .. end)`
as the second of each pair to handle tagged values.

check the unit tests for usage examples.

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
