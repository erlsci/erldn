-module(erldn_numeric_string_test).
-include_lib("eunit/include/eunit.hrl").

% Test that rationals round-trip correctly
rational_roundtrip_test() ->
    Input = "22/7",
    {ok, Parsed} = erldn:parse_str(Input),
    Reconstructed = lists:flatten(erldn:to_string(Parsed)),
    ?assertEqual("22/7", Reconstructed).

rational_negative_roundtrip_test() ->
    Input = "-3/4",
    {ok, Parsed} = erldn:parse_str(Input),
    Reconstructed = lists:flatten(erldn:to_string(Parsed)),
    ?assertEqual("-3/4", Reconstructed).

% Test that hex/octal/radix convert to decimal representation
hex_to_decimal_string_test() ->
    {ok, Parsed} = erldn:parse_str("0xFF"),
    Result = lists:flatten(erldn:to_string(Parsed)),
    ?assertEqual("255", Result).

octal_to_decimal_string_test() ->
    {ok, Parsed} = erldn:parse_str("0777"),
    Result = lists:flatten(erldn:to_string(Parsed)),
    ?assertEqual("511", Result).

radix_to_decimal_string_test() ->
    {ok, Parsed} = erldn:parse_str("2r1010"),
    Result = lists:flatten(erldn:to_string(Parsed)),
    ?assertEqual("10", Result).

% Test rational formatting edge cases
rational_unit_string_test() ->
    {ok, Parsed} = erldn:parse_str("1/1"),
    Result = lists:flatten(erldn:to_string(Parsed)),
    ?assertEqual("1/1", Result).

rational_in_collection_string_test() ->
    Input = {vector, [{rational, 22, 7}, 255]},
    Result = lists:flatten(erldn:to_string(Input)),
    ?assertEqual("[22/7 255]", Result).
