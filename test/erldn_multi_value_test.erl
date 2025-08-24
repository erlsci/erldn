-module(erldn_multi_value_test).
-include_lib("eunit/include/eunit.hrl").

%% Test parsing multiple integers
multi_integers_test() ->
    Input = "1 2 3",
    {ok, Result} = erldn:parse_multi_str(Input),
    ?assertEqual([1, 2, 3], Result).

%% Test parsing mixed types
mixed_types_test() ->
    Input = "42 \"hello\" true nil :keyword",
    {ok, Result} = erldn:parse_multi_str(Input),
    ?assertEqual([42, <<"hello">>, true, nil, keyword], Result).

%% Test parsing complex structures
complex_structures_test() ->
    Input = "{:a 1} [1 2 3] #{4 5}",
    {ok, Result} = erldn:parse_multi_str(Input),
    Expected = [
        {map, [{a, 1}]},
        {vector, [1, 2, 3]},
        {set, [4, 5]}
    ],
    ?assertEqual(Expected, Result).

%% Test single value still works
single_value_compatibility_test() ->
    Input = "42",
    {ok, Result} = erldn:parse_str(Input),
    ?assertEqual(42, Result),

    {ok, MultiResult} = erldn:parse_multi_str(Input),
    ?assertEqual([42], MultiResult).

%% Test backward compatibility
backward_compatibility_test() ->
    % Single value should return unwrapped
    {ok, Single} = erldn:parse_str("42"),
    ?assertEqual(42, Single),

    % Multiple values should return wrapped
    {ok, Multiple} = erldn:parse_str("42 43"),
    ?assertEqual([42, 43], Multiple).

%% Test with comments and whitespace
with_whitespace_test() ->
    Input = "1   2    3",
    {ok, Result} = erldn:parse_multi_str(Input),
    ?assertEqual([1, 2, 3], Result).

%% Test empty input (expect error as parser cannot handle empty input)
empty_input_test() ->
    Result = erldn:parse_multi_str(""),
    ?assertMatch({error, _, _}, Result).

%% Test multiple maps
multiple_maps_test() ->
    Input = "{:a 1} {:b 2}",
    {ok, Result} = erldn:parse_multi_str(Input),
    Expected = [
        {map, [{a, 1}]},
        {map, [{b, 2}]}
    ],
    ?assertEqual(Expected, Result).

%% Test multiple vectors
multiple_vectors_test() ->
    Input = "[1 2] [3 4]",
    {ok, Result} = erldn:parse_multi_str(Input),
    Expected = [
        {vector, [1, 2]},
        {vector, [3, 4]}
    ],
    ?assertEqual(Expected, Result).

%% Test nested structures
nested_structures_test() ->
    Input = "((1)) [[2]] #{#{3}}",
    {ok, Result} = erldn:parse_multi_str(Input),
    Expected = [
        [[1]],
        {vector, [{vector, [2]}]},
        {set, [{set, [3]}]}
    ],
    ?assertEqual(Expected, Result).

%% Test parse_multi/1 with binary input
multi_binary_input_test() ->
    Input = <<"1 2 3">>,
    {ok, Result} = erldn:parse_multi(Input),
    ?assertEqual([1, 2, 3], Result).

%% Test parse_multi/1 with string input (non-file)
multi_string_input_test() ->
    Input = "1 2 3",
    {ok, Result} = erldn:parse_multi(Input),
    ?assertEqual([1, 2, 3], Result).

%% Test symbols and keywords
symbols_and_keywords_test() ->
    Input = "symbol1 :keyword1 symbol2 :keyword2",
    {ok, Result} = erldn:parse_multi_str(Input),
    Expected = [
        {symbol, symbol1},
        keyword1,
        {symbol, symbol2},
        keyword2
    ],
    ?assertEqual(Expected, Result).

%% Test boolean and nil values
boolean_nil_test() ->
    Input = "true false nil",
    {ok, Result} = erldn:parse_multi_str(Input),
    ?assertEqual([true, false, nil], Result).

%% Test characters (note: $a syntax is parsed as symbols in this implementation)
characters_test() ->
    Input = "$a $b $c",
    {ok, Result} = erldn:parse_multi_str(Input),
    Expected = [
        {symbol, '$a'},
        {symbol, '$b'},
        {symbol, '$c'}
    ],
    ?assertEqual(Expected, Result).

%% Test strings
strings_test() ->
    Input = "\"hello\" \"world\"",
    {ok, Result} = erldn:parse_multi_str(Input),
    ?assertEqual([<<"hello">>, <<"world">>], Result).

%% Test floats
floats_test() ->
    Input = "1.5 2.7 -3.14",
    {ok, Result} = erldn:parse_multi_str(Input),
    ?assertEqual([1.5, 2.7, -3.14], Result).

%% Test large numbers
large_numbers_test() ->
    Input = "123456789 -987654321",
    {ok, Result} = erldn:parse_multi_str(Input),
    ?assertEqual([123456789, -987654321], Result).

%% Test parse/1 auto-detection with multi-value
parse_auto_detection_test() ->
    % String input with multiple values
    {ok, Result1} = erldn:parse("1 2 3"),
    ?assertEqual([1, 2, 3], Result1),

    % Binary input with multiple values
    {ok, Result2} = erldn:parse(<<"4 5 6">>),
    ?assertEqual([4, 5, 6], Result2).
