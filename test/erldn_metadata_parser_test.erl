-module(erldn_metadata_parser_test).
-include_lib("eunit/include/eunit.hrl").

check_parse(Str, Expected) ->
    {ok, Result} = erldn:parse_str(Str),
    ?assertEqual(Expected, Result).

basic_metadata_parse_test() ->
    check_parse(
        "^:keyword value",
        {metadata, {symbol, value}, keyword}
    ).

metadata_map_parse_test() ->
    check_parse(
        "^{:author \"Alice\"} [1 2 3]",
        {metadata, {vector, [1, 2, 3]}, {map, [{author, <<"Alice">>}]}}
    ).

metadata_string_parse_test() ->
    check_parse(
        "^\"documentation\" symbol",
        {metadata, {symbol, symbol}, <<"documentation">>}
    ).

chained_metadata_parse_test() ->
    check_parse(
        "^:a ^:b value",
        {metadata, {metadata, {symbol, value}, b}, a}
    ).

nested_metadata_parse_test() ->
    check_parse(
        "^{:outer true} [^:inner 1]",
        {metadata, {vector, [{metadata, 1, inner}]}, {map, [{outer, true}]}}
    ).

multiple_values_with_metadata_test() ->
    Result = erldn:parse_str("^:first 1 ^:second 2"),
    ?assertMatch({ok, [{metadata, 1, first}, {metadata, 2, second}]}, Result).

metadata_with_vector_test() ->
    check_parse(
        "^:test [1 2 3]",
        {metadata, {vector, [1, 2, 3]}, test}
    ).

metadata_with_map_test() ->
    check_parse(
        "^{:version 1} {:key :val}",
        {metadata, {map, [{key, val}]}, {map, [{version, 1}]}}
    ).

triple_chained_metadata_test() ->
    check_parse(
        "^:a ^:b ^{:c 1} value",
        {metadata, {metadata, {metadata, {symbol, value}, {map, [{c, 1}]}}, b}, a}
    ).

metadata_with_string_test() ->
    check_parse(
        "^\"docs\" \"hello\"",
        {metadata, <<"hello">>, <<"docs">>}
    ).
