-module(erldn_parse_file_test).
-include_lib("eunit/include/eunit.hrl").

%% Test that all .edn files in priv/edn can be parsed without error
parse_all_edn_files_test_() ->
    EdnDir = filename:join([code:priv_dir(erldn), "edn"]),
    EdnFiles = filelib:wildcard("*.edn", EdnDir),
    [test_parse_edn_file(EdnDir, Filename) || Filename <- EdnFiles].

%% Helper function to create a test for each .edn file
test_parse_edn_file(EdnDir, Filename) ->
    FullPath = filename:join(EdnDir, Filename),
    TestName = "parse_" ++ filename:basename(Filename, ".edn"),
    {TestName, fun() ->
        % Test that the file can be read
        ?assertMatch({ok, _}, file:read_file(FullPath)),

        % Test that erldn:parse_file/1 is called without crashing
        Result = erldn:parse_file(FullPath),

        % Test that erldn:parse/1 with filename also works (should give same result)
        Result2 = erldn:parse(FullPath),
        ?assertEqual(Result, Result2),

        % The result should be {ok, _} (either single value or list of values)
        case Result of
            {ok, _} ->
                % Successfully parsed (single or multiple values)
                ok;
            {error, {file_error, _}} ->
                % File read error (unexpected)
                ?assert(false);
            {error, _, _} ->
                % TODO: Some files may contain unsupported EDN features (like ##Inf, ##-Inf, ##NaN)
                % See: https://github.com/erlsci/erldn/issues/10
                % For now, we expect these to fail gracefully
                case Filename of
                    % Known to contain ##Inf, ##-Inf, ##NaN
                    "edge-numbers.edn" -> ok;
                    _ -> ?assert(false)
                end
        end
    end}.

%% Test error cases
parse_file_errors_test_() ->
    [
        {"parse_nonexistent_file", fun() ->
            Result = erldn:parse_file("nonexistent.edn"),
            ?assertMatch({error, {file_error, _}}, Result)
        end},

        {"parse_file_wrong_extension", fun() ->
            % Create a temporary file with wrong extension
            TempFile = "temp_test.txt",
            file:write_file(TempFile, "{:key :value}"),
            Result = erldn:parse_file(TempFile),
            file:delete(TempFile),
            ?assertMatch({error, {invalid_extension, ".txt"}}, Result)
        end},

        {"parse_string_vs_file", fun() ->
            % Test that parse/1 correctly distinguishes between string and file
            StringResult = erldn:parse("{:key :value}"),
            ?assertMatch({ok, _}, StringResult),

            % Non-existent filename should be treated as string and parsed as symbol
            NonExistentResult = erldn:parse("nonexistent.edn"),
            ?assertMatch({ok, {symbol, 'nonexistent.edn'}}, NonExistentResult)
        end}
    ].
