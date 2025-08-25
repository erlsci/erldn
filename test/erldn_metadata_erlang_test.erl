-module(erldn_metadata_erlang_test).
-include_lib("eunit/include/eunit.hrl").

metadata_preservation_test() ->
    Input = {metadata, [1, 2, 3], {map, [{author, <<"Alice">>}]}},
    Result = erldn:to_erlang(Input),
    ?assertMatch({metadata, [1, 2, 3], _}, Result).

metadata_nested_conversion_test() ->
    Input = {metadata, {vector, [{metadata, 1, inner}]}, {map, [{outer, true}]}},
    Result = erldn:to_erlang(Input),
    ?assertMatch({metadata, [{metadata, 1, inner}], _}, Result).

metadata_with_map_conversion_test() ->
    Input = {metadata, {map, [{key, val}]}, {map, [{version, 1}]}},
    Result = erldn:to_erlang(Input),
    Expected = {metadata, dict:from_list([{key, val}]), dict:from_list([{version, 1}])},
    ?assertEqual(Expected, Result).

metadata_with_vector_conversion_test() ->
    Input = {metadata, {vector, [1, 2, 3]}, test},
    Result = erldn:to_erlang(Input),
    Expected = {metadata, [1, 2, 3], test},
    ?assertEqual(Expected, Result).

metadata_with_set_conversion_test() ->
    Input = {metadata, {set, [1, 2, 3]}, test},
    Result = erldn:to_erlang(Input),
    Expected = {metadata, sets:from_list([1, 2, 3]), test},
    ?assertEqual(Expected, Result).

metadata_string_conversion_test() ->
    Input = {metadata, {symbol, test}, <<"documentation">>},
    Result = erldn:to_erlang(Input),
    Expected = {metadata, {symbol, test}, <<"documentation">>},
    ?assertEqual(Expected, Result).

metadata_keyword_conversion_test() ->
    Input = {metadata, {symbol, test}, keyword},
    Result = erldn:to_erlang(Input),
    Expected = {metadata, {symbol, test}, keyword},
    ?assertEqual(Expected, Result).

complex_nested_metadata_conversion_test() ->
    Input =
        {metadata,
            {vector, [
                {metadata, 1, {map, [{id, 1}]}},
                {metadata, 2, {map, [{id, 2}]}}
            ]},
            {map, [{doc, <<"A vector">>}]}},
    Result = erldn:to_erlang(Input),
    ?assertMatch(
        {metadata,
            [
                {metadata, 1, _},
                {metadata, 2, _}
            ],
            _},
        Result
    ).
