-module(erldn_special_numbers_parser_test).
-include_lib("eunit/include/eunit.hrl").

check_parse(Str, Expected) ->
    {ok, Result} = erldn:parse_str(Str),
    ?assertEqual(Expected, Result).

positive_infinity_parse_test() ->
    check_parse("##Inf", {tag, inf, pos}).

negative_infinity_parse_test() ->
    check_parse("##-Inf", {tag, inf, neg}).

nan_parse_test() ->
    check_parse("##NaN", {tag, nan, nil}).

% Test in collections
infinity_in_vector_parse_test() ->
    check_parse(
        "[##Inf ##-Inf ##NaN]",
        {vector, [{tag, inf, pos}, {tag, inf, neg}, {tag, nan, nil}]}
    ).

infinity_in_map_parse_test() ->
    check_parse(
        "{:inf ##Inf :neg-inf ##-Inf :nan ##NaN}",
        {map, [
            {inf, {tag, inf, pos}},
            {'neg-inf', {tag, inf, neg}},
            {nan, {tag, nan, nil}}
        ]}
    ).

% Test round-trip conversion
round_trip_infinity_test() ->
    Values = [{tag, inf, pos}, {tag, inf, neg}, {tag, nan, nil}],
    lists:foreach(
        fun(Value) ->
            EdnStr = lists:flatten(erldn:to_string(Value)),
            {ok, Parsed} = erldn:parse_str(EdnStr),
            ?assertEqual(Value, Parsed)
        end,
        Values
    ).
