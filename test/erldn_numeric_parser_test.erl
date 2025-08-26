-module(erldn_numeric_parser_test).
-include_lib("eunit/include/eunit.hrl").

check_parse(Str, Expected) ->
    {ok, Result} = erldn:parse_str(Str),
    ?assertEqual(Expected, Result).

% Hexadecimal parsing
hex_parse_test() ->
    check_parse("0xFF", 255).

hex_negative_parse_test() ->
    check_parse("-0x123", -291).

% Octal parsing
octal_parse_test() ->
    check_parse("0777", 511).

octal_negative_parse_test() ->
    check_parse("-0123", -83).

% Radix parsing
radix_binary_parse_test() ->
    check_parse("2r1010", 10).

radix_base36_parse_test() ->
    check_parse("36rZZ", 1295).

radix_negative_parse_test() ->
    check_parse("-8r777", -511).

% Rational parsing
rational_parse_test() ->
    check_parse("22/7", {rational, 22, 7}).

rational_negative_parse_test() ->
    check_parse("-3/4", {rational, -3, 4}).

rational_positive_parse_test() ->
    check_parse("+1/2", {rational, 1, 2}).

% Mixed numeric types in collections
mixed_numbers_vector_test() ->
    check_parse(
        "[0xFF 0777 2r1010 22/7]",
        {vector, [255, 511, 10, {rational, 22, 7}]}
    ).

mixed_numbers_map_test() ->
    check_parse(
        "{:hex 0xFF :octal 0777 :rational 22/7}",
        {map, [{hex, 255}, {octal, 511}, {rational, {rational, 22, 7}}]}
    ).

% Multi-value parsing
multi_numeric_test() ->
    check_parse(
        "0xFF 0777 2r1010 22/7",
        [255, 511, 10, {rational, 22, 7}]
    ).
