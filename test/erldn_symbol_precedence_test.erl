-module(erldn_symbol_precedence_test).
-include_lib("eunit/include/eunit.hrl").

% Test symbol vs numeric precedence with the new pattern

% These should parse as symbols
symbol_plus_alpha_test() ->
    {ok, [Result], _} = erldn:lex_str("+abc"),
    ?assertMatch({symbol, 1, '+abc'}, Result).

symbol_minus_alpha_test() ->
    {ok, [Result], _} = erldn:lex_str("-def"),
    ?assertMatch({symbol, 1, '-def'}, Result).

symbol_star_var_test() ->
    {ok, [Result], _} = erldn:lex_str("*var"),
    ?assertMatch({symbol, 1, '*var'}, Result).

symbol_plus_special_test() ->
    {ok, [Result], _} = erldn:lex_str("+*special"),
    ?assertMatch({symbol, 1, '+*special'}, Result).

% These should parse as numbers (not symbols)
number_minus_digits_test() ->
    {ok, [Result], _} = erldn:lex_str("-123"),
    ?assertMatch({integer, 1, -123}, Result).

number_plus_digits_test() ->
    {ok, [Result], _} = erldn:lex_str("+120"),
    ?assertMatch({integer, 1, 120}, Result).

number_signed_octal_test() ->
    {ok, [Result], _} = erldn:lex_str("-0123"),
    ?assertMatch({octal, 1, -83}, Result).

number_signed_hex_test() ->
    {ok, [Result], _} = erldn:lex_str("+0xFF"),
    ?assertMatch({hexadecimal, 1, 255}, Result).

% These should cause lexical errors (multiple tokens or parse failures)
invalid_mixed_alpha_digit_test() ->
    % 0abc should not be a valid single token
    {ok, Tokens, _} = erldn:lex_str("0abc"),
    % Should be parsed as multiple tokens: 0 and abc
    ?assertEqual(2, length(Tokens)).

invalid_signed_mixed_test() ->
    % +0abc should not be a valid single token
    {ok, Tokens, _} = erldn:lex_str("+0abc"),
    % Should be parsed as multiple tokens
    ?assert(length(Tokens) > 1).

invalid_minus_mixed_test() ->
    % -0abc should not be a valid single token
    {ok, Tokens, _} = erldn:lex_str("-0abc"),
    % Should be parsed as multiple tokens
    ?assert(length(Tokens) > 1).
