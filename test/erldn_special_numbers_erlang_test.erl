-module(erldn_special_numbers_erlang_test).
-include_lib("eunit/include/eunit.hrl").

erlang_conversion_test() ->
    % Test conversion to Erlang atoms
    PosInf = erldn:to_erlang({tag, inf, pos}),
    NegInf = erldn:to_erlang({tag, inf, neg}),
    NaN = erldn:to_erlang({tag, nan, nil}),

    % Verify they are the expected special atom values
    ?assertEqual(positive_infinity, PosInf),
    ?assertEqual(negative_infinity, NegInf),
    ?assertEqual(not_a_number, NaN),

    % Verify they are atoms
    ?assert(is_atom(PosInf)),
    ?assert(is_atom(NegInf)),
    ?assert(is_atom(NaN)).

erlang_conversion_in_collections_test() ->
    % Test conversion of collections containing special values
    VectorWithSpecialValues = {vector, [{tag, inf, pos}, {tag, inf, neg}, {tag, nan, nil}]},
    [PosInf, NegInf, NaN] = erldn:to_erlang(VectorWithSpecialValues),

    ?assertEqual(positive_infinity, PosInf),
    ?assertEqual(negative_infinity, NegInf),
    ?assertEqual(not_a_number, NaN),
    ?assert(is_atom(PosInf)),
    ?assert(is_atom(NegInf)),
    ?assert(is_atom(NaN)).
