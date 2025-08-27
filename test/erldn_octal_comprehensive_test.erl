-module(erldn_octal_comprehensive_test).
-include_lib("eunit/include/eunit.hrl").

% Comprehensive tests for octal handling following Clojure behavior

% Zero sequences should all parse as integer 0
zero_single_test() ->
    {ok, Result} = erldn:parse_str("0"),
    ?assertEqual(0, Result).

zero_double_test() ->
    {ok, Result} = erldn:parse_str("00"),
    ?assertEqual(0, Result).

zero_triple_test() ->
    {ok, Result} = erldn:parse_str("000"),
    ?assertEqual(0, Result).

zero_quad_test() ->
    {ok, Result} = erldn:parse_str("0000"),
    ?assertEqual(0, Result).

% Valid octal numbers
octal_single_digit_test() ->
    {ok, Result} = erldn:parse_str("01"),
    ?assertEqual(1, Result).

octal_seven_test() ->
    {ok, Result} = erldn:parse_str("07"),
    ?assertEqual(7, Result).

octal_large_test() ->
    {ok, Result} = erldn:parse_str("0777"),
    ?assertEqual(511, Result).

octal_signed_positive_test() ->
    {ok, Result} = erldn:parse_str("+0123"),
    ?assertEqual(83, Result).

octal_signed_negative_test() ->
    {ok, Result} = erldn:parse_str("-0456"),
    ?assertEqual(-302, Result).

% Invalid octal numbers should break apart (following Clojure strict validation)
invalid_octal_08_test() ->
    % Should generate error for invalid octal
    Result = erldn:parse_str("08"),
    ?assertMatch({error, _, _}, Result).

invalid_octal_09_test() ->
    % Should generate error for invalid octal
    Result = erldn:parse_str("09"),
    ?assertMatch({error, _, _}, Result).

invalid_octal_0888_test() ->
    % Should generate error for invalid octal
    Result = erldn:parse_str("0888"),
    ?assertMatch({error, _, _}, Result).

invalid_octal_089_test() ->
    % Should generate error for invalid octal
    Result = erldn:parse_str("089"),
    ?assertMatch({error, _, _}, Result).

% Test that these invalid cases don't parse as valid octals
invalid_not_single_octal_test() ->
    Result = erldn:parse_str("08"),
    % Should not be a single octal value - should be error
    ?assertMatch({error, _, _}, Result).

invalid_mixed_not_octal_test() ->
    {ok, Tokens} = erldn:parse_str("0abc"),
    % Should be multiple tokens, not a single value
    ?assert(is_list(Tokens) andalso length(Tokens) > 1).
