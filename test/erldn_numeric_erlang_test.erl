-module(erldn_numeric_erlang_test).
-include_lib("eunit/include/eunit.hrl").

% Test numeric conversions to Erlang
hex_to_erlang_test() ->
    {ok, Parsed} = erldn:parse_str("0xFF"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual(255, Result).

octal_to_erlang_test() ->
    {ok, Parsed} = erldn:parse_str("0777"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual(511, Result).

radix_to_erlang_test() ->
    {ok, Parsed} = erldn:parse_str("36rZZ"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual(1295, Result).

rational_to_erlang_test() ->
    {ok, Parsed} = erldn:parse_str("22/7"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual({rational, 22, 7}, Result).

% Test negative numbers
negative_hex_to_erlang_test() ->
    {ok, Parsed} = erldn:parse_str("-0xFF"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual(-255, Result).

negative_rational_to_erlang_test() ->
    {ok, Parsed} = erldn:parse_str("-22/7"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual({rational, -22, 7}, Result).

% Test collections with mixed numeric types
mixed_numbers_collection_test() ->
    {ok, Parsed} = erldn:parse_str("[0xFF 0777 2r1010 22/7]"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual([255, 511, 10, {rational, 22, 7}], Result).
