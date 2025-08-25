-module(erldn_special_numbers_lexer_test).
-include_lib("eunit/include/eunit.hrl").

check_lex(Str, Expected) ->
    {ok, [Result], _} = erldn:lex_str(Str),
    ?assertEqual(Expected, Result).

positive_infinity_test() ->
    check_lex("##Inf", {inf_pos, 1, '##Inf'}).

negative_infinity_test() ->
    check_lex("##-Inf", {inf_neg, 1, '##-Inf'}).

nan_test() ->
    check_lex("##NaN", {nan, 1, '##NaN'}).

% Test in context
infinity_in_vector_test() ->
    {ok, Tokens, _} = erldn:lex_str("[##Inf ##-Inf ##NaN]"),
    ExpectedTypes = [open_vector, inf_pos, inf_neg, nan, close_vector],
    ActualTypes = [element(1, T) || T <- Tokens],
    ?assertEqual(ExpectedTypes, ActualTypes).
