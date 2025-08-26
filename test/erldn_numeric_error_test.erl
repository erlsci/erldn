-module(erldn_numeric_error_test).
-include_lib("eunit/include/eunit.hrl").

% Test invalid numeric formats cause appropriate errors
invalid_hex_test() ->
    Result = erldn:parse_str("0xGG"),
    ?assertMatch({error, _, _}, Result).

invalid_octal_test() ->
    Result = erldn:parse_str("0899"),
    ?assertMatch({error, _, _}, Result).

invalid_radix_base_test() ->
    Result = erldn:parse_str("37rABC"),
    ?assertMatch({error, _, _}, Result).

invalid_radix_digits_test() ->
    Result = erldn:parse_str("2r123"),
    ?assertMatch({error, _, _}, Result).

zero_denominator_rational_test() ->
    Result = erldn:parse_str("22/0"),
    ?assertMatch({error, _, _}, Result).

malformed_rational_test() ->
    Result = erldn:parse_str("22//7"),
    ?assertMatch({error, _, _}, Result).
