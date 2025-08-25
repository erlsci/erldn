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

metadata_with_string_format_test() ->
    Value = {metadata, {symbol, test}, <<"documentation">>},
    Result = lists:flatten(erldn:to_string(Value)),
    ?assertEqual("^\"documentation\" test", Result).

nested_metadata_string_format_test() ->
    Value = {metadata, {vector, [{metadata, 1, inner}]}, {map, [{outer, true}]}},
    Result = lists:flatten(erldn:to_string(Value)),
    ?assertEqual("^{:outer true} [^:inner 1]", Result).

chained_metadata_string_format_test() ->
    Value = {metadata, {symbol, value}, {map, [{a, true}, {b, true}]}},
    Result = lists:flatten(erldn:to_string(Value)),
    ?assertEqual("^{:a true :b true} value", Result).
