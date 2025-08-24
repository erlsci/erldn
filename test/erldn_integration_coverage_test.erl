-module(erldn_integration_coverage_test).
-include_lib("eunit/include/eunit.hrl").

%% Comprehensive test covering multiple code paths
comprehensive_multi_value_workflow_test() ->
    % Test the complete workflow: file creation -> multi parsing -> validation
    TestData = [
        42,
        % This ensures tab escaping is tested
        <<"test string with\ttab">>,
        true,
        false,
        nil,
        keyword,
        {vector, [1, 2, 3]},
        {set, [a, b, c]},
        {map, [{key, value}]}
    ],

    % Create temporary file
    TempFile = "comprehensive_test.edn",

    % Convert test data to EDN strings and write to file
    EdnStrings = [lists:flatten(erldn:to_string(Item)) || Item <- TestData],
    Content = string:join(EdnStrings, "\n"),
    file:write_file(TempFile, Content),

    % Test multi-file parsing
    {ok, ParsedData} = erldn:parse_multi_file(TempFile),

    % Clean up
    file:delete(TempFile),

    % Validate results
    ?assertEqual(length(TestData), length(ParsedData)),

    % Test that tab character was properly handled in string
    StringItem = lists:nth(2, ParsedData),
    ?assertMatch(<<_/binary>>, StringItem),
    ?assert(binary:match(StringItem, <<"\t">>) =/= nomatch).

%% Test error propagation through all layers
error_propagation_test() ->
    % Test that errors propagate correctly through the call chain

    % 1. Test file error propagation
    ?assertMatch(
        {error, {file_error, _}},
        erldn:parse_multi_file("nonexistent.edn")
    ),

    % 2. Test extension error propagation
    TempFile = "test.wrong",
    file:write_file(TempFile, "data"),
    ?assertMatch(
        {error, {invalid_extension, ".wrong"}},
        erldn:parse_multi_file(TempFile)
    ),
    file:delete(TempFile),

    % 3. Test parse error propagation
    ?assertMatch(
        {error, _, _},
        % Unclosed map
        erldn:parse_multi_str("{")
    ),

    % 4. Test that parse_multi correctly handles both cases
    ?assertMatch({ok, [42]}, erldn:parse_multi("42")),
    ?assertMatch({ok, [1, 2]}, erldn:parse_multi("1 2")).

%% Test complete round-trip: create -> parse -> convert -> parse again
round_trip_integration_test() ->
    % Create complex nested structure
    OriginalData =
        {map, [
            {name, <<"Alice">>},
            {age, 30},
            {skills, {vector, [<<"erlang">>, <<"testing">>]}},
            {active, true},
            {metadata, {set, [admin, verified]}}
        ]},

    % Convert to EDN string
    EdnString = lists:flatten(erldn:to_string(OriginalData)),

    % Parse it back
    {ok, ParsedData} = erldn:parse_str(EdnString),

    % Should get the same structure
    ?assertEqual(OriginalData, ParsedData).

%% Test file-based round trip
file_round_trip_test() ->
    TempFile = "round_trip.edn",

    % Test data with various types including strings with special chars
    TestValues = [
        <<"string\twith\ttabs">>,
        <<"line1\nline2\rline3">>,
        <<"quotes\"and\\\\\\\\slashes">>,
        {vector, [1, 2, 3]},
        {map, [{key, <<"value\twith\ttab">>}]}
    ],

    % Convert to EDN and write to file
    EdnStrings = [lists:flatten(erldn:to_string(V)) || V <- TestValues],
    Content = string:join(EdnStrings, "\n"),
    file:write_file(TempFile, Content),

    % Parse from file
    {ok, ParsedValues} = erldn:parse_multi_file(TempFile),
    file:delete(TempFile),

    % Verify we got back what we put in
    ?assertEqual(TestValues, ParsedValues).

%% Test edge cases and boundary conditions
edge_cases_test() ->
    % Test various edge cases that might not be covered elsewhere
    EdgeCases = [
        % Single character strings
        <<"a">>,
        <<"1">>,
        <<" ">>,

        % Strings with only escape characters
        <<"\n">>,
        <<"\t">>,
        <<"\"">>,
        <<"\\">>,

        % Empty collections
        {vector, []},
        {set, []},
        {map, []},

        % Nested empty collections
        {vector, [{vector, []}, {set, []}, {map, []}]}
    ],

    % Test each through complete parsing cycle
    lists:foreach(
        fun(TestCase) ->
            EdnString = lists:flatten(erldn:to_string(TestCase)),
            {ok, Parsed} = erldn:parse_str(EdnString),
            ?assertEqual(TestCase, Parsed)
        end,
        EdgeCases
    ).

%% Test binary vs string input handling
binary_string_input_test() ->
    TestData = "42 \"hello\" true",

    % Test string input
    {ok, Result1} = erldn:parse_multi(TestData),

    % Test binary input
    {ok, Result2} = erldn:parse_multi(list_to_binary(TestData)),

    % Should get same results
    ?assertEqual(Result1, Result2),
    ?assertEqual([42, <<"hello">>, true], Result1).

%% Test large multi-value parsing
large_multi_value_test() ->
    % Create large dataset
    LargeData = lists:seq(1, 100),

    % Convert to EDN format
    EdnStrings = [integer_to_list(N) || N <- LargeData],
    Content = string:join(EdnStrings, " "),

    % Parse as multi-value
    {ok, ParsedData} = erldn:parse_multi_str(Content),

    % Verify all data parsed correctly
    ?assertEqual(LargeData, ParsedData),
    ?assertEqual(100, length(ParsedData)).

%% Test mixed file operations
mixed_file_operations_test() ->
    TempFile = "mixed_ops.edn",

    try
        % Write some data
        file:write_file(TempFile, "1 2 3"),

        % Parse with parse_multi (should detect file)
        {ok, Result1} = erldn:parse_multi(TempFile),
        ?assertEqual([1, 2, 3], Result1),

        % Parse with parse_multi_file directly
        {ok, Result2} = erldn:parse_multi_file(TempFile),
        ?assertEqual([1, 2, 3], Result2),

        % Parse with regular parse (should detect file)
        {ok, Result3} = erldn:parse(TempFile),
        ?assertEqual([1, 2, 3], Result3),

        % Parse with parse_file directly
        {ok, Result4} = erldn:parse_file(TempFile),
        ?assertEqual([1, 2, 3], Result4),

        % All should give same result
        ?assertEqual(Result1, Result2),
        ?assertEqual(Result2, Result3),
        ?assertEqual(Result3, Result4)
    after
        file:delete(TempFile)
    end.
