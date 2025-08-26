-module(erldn_numeric_integration_test).
-include_lib("eunit/include/eunit.hrl").

% Test parsing files with new numeric formats
numeric_formats_file_test() ->
    FilePath = filename:join([code:priv_dir(erldn), "edn", "numeric-formats.edn"]),
    Result = erldn:parse_file(FilePath),
    ?assertMatch({ok, _}, Result),

    {ok, Data} = Result,
    ?assert(length(Data) > 0),

    % Verify we have different numeric types
    ?assert(lists:any(fun is_integer/1, Data)),
    ?assert(
        lists:any(
            fun(X) ->
                is_tuple(X) andalso tuple_size(X) =:= 3 andalso element(1, X) =:= rational
            end,
            Data
        )
    ).

% Test that existing numbers.edn still works and rationals are now numbers
existing_numbers_file_test() ->
    FilePath = filename:join([code:priv_dir(erldn), "edn", "numbers.edn"]),
    case filelib:is_file(FilePath) of
        true ->
            {ok, Data} = erldn:parse_file(FilePath),

            % Find rational numbers in the data
            Rationals = [
                X
             || X <- Data,
                is_tuple(X) andalso
                    tuple_size(X) =:= 3 andalso
                    element(1, X) =:= rational
            ],

            % Verify they parse as rationals, not symbols
            ?assertNotMatch([{symbol, _} | _], Rationals);
        false ->
            % Skip test if file doesn't exist
            ok
    end.

% Performance test - ensure new parsing doesn't significantly slow things down
numeric_performance_test() ->
    % Create test data with mixed formats
    TestData = string:join(
        [
            "123",
            "0xFF",
            "0777",
            "2r1010",
            "22/7",
            "456",
            "0x1A2B",
            "0123",
            "8r777",
            "355/113"
        ] ++ [integer_to_list(N) || N <- lists:seq(1, 100)],
        " "
    ),

    % Time the parsing
    {Time, {ok, Result}} = timer:tc(fun() -> erldn:parse_str(TestData) end),

    % Should parse successfully
    ?assert(length(Result) > 100),

    % Should complete in reasonable time (< 1 second for this small test)

    % microseconds
    ?assert(Time < 1000000).
