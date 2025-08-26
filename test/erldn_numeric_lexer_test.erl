-module(erldn_numeric_lexer_test).
-include_lib("eunit/include/eunit.hrl").

check_lex(Str, Expected) ->
    {ok, [Result], _} = erldn:lex_str(Str),
    ?assertEqual(Expected, Result).

% Hexadecimal tests
hex_basic_test() ->
    check_lex("0xFF", {hexadecimal, 1, 255}).

hex_uppercase_test() ->
    check_lex("0X1A2B", {hexadecimal, 1, 6699}).

hex_negative_test() ->
    check_lex("-0xff", {hexadecimal, 1, -255}).

hex_positive_test() ->
    check_lex("+0xFF", {hexadecimal, 1, 255}).

% Octal tests
octal_basic_test() ->
    check_lex("0777", {octal, 1, 511}).

octal_negative_test() ->
    check_lex("-0123", {octal, 1, -83}).

octal_positive_test() ->
    check_lex("+0456", {octal, 1, 302}).

% Radix tests
radix_binary_test() ->
    check_lex("2r1010", {radix, 1, 10}).

radix_base36_test() ->
    check_lex("36rZZ", {radix, 1, 1295}).

radix_negative_test() ->
    check_lex("-8r777", {radix, 1, -511}).

radix_hex_equivalent_test() ->
    check_lex("16rFF", {radix, 1, 255}).

% Rational tests
rational_basic_test() ->
    check_lex("22/7", {rational, 1, {rational, 22, 7}}).

rational_negative_test() ->
    check_lex("-3/4", {rational, 1, {rational, -3, 4}}).

rational_positive_test() ->
    check_lex("+1/2", {rational, 1, {rational, 1, 2}}).

% Edge cases
hex_zero_test() ->
    check_lex("0x0", {hexadecimal, 1, 0}).

octal_simple_test() ->
    check_lex("01", {octal, 1, 1}).

integer_zero_test() ->
    check_lex("0", {integer, 1, 0}).

rational_unit_test() ->
    check_lex("1/1", {rational, 1, {rational, 1, 1}}).

radix_edge_test() ->
    check_lex("2r0", {radix, 1, 0}).

% Test precedence - ensure these don't get parsed as symbols
hex_not_symbol_test() ->
    {ok, [Token], _} = erldn:lex_str("0xFF"),
    ?assertMatch({hexadecimal, _, _}, Token).

rational_not_symbol_test() ->
    {ok, [Token], _} = erldn:lex_str("22/7"),
    ?assertMatch({rational, _, _}, Token).
