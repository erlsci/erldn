-module(erldn_multi_value_file_test).
-include_lib("eunit/include/eunit.hrl").

%% Test parse_multi_file/1 with valid .edn file
parse_multi_file_success_test() ->
    % Create a temporary .edn file with multiple values
    TempFile = "temp_multi_test.edn",
    Content = "42\n\"hello\"\ntrue\n:keyword",
    file:write_file(TempFile, Content),

    % Test the function
    Result = erldn:parse_multi_file(TempFile),
    file:delete(TempFile),

    ?assertMatch({ok, [42, <<"hello">>, true, keyword]}, Result).

%% Test parse_multi_file/1 with file read error
parse_multi_file_read_error_test() ->
    % Try to parse a non-existent file
    Result = erldn:parse_multi_file("nonexistent_multi.edn"),
    ?assertMatch({error, {file_error, enoent}}, Result).

%% Test parse_multi_file/1 with wrong extension
parse_multi_file_wrong_extension_test() ->
    % Create temp file with wrong extension
    TempFile = "temp_multi_test.txt",
    file:write_file(TempFile, "42"),

    Result = erldn:parse_multi_file(TempFile),
    file:delete(TempFile),

    ?assertMatch({error, {invalid_extension, ".txt"}}, Result).

%% Test parse_multi/1 with filename that exists (triggers parse_multi_file)
parse_multi_with_existing_file_test() ->
    % Create a temporary .edn file
    TempFile = "temp_parse_multi.edn",
    Content = "1 2 3",
    file:write_file(TempFile, Content),

    % This should call parse_multi_file internally
    Result = erldn:parse_multi(TempFile),
    file:delete(TempFile),

    ?assertMatch({ok, [1, 2, 3]}, Result).

%% Test parse_multi_file/1 with empty .edn file
parse_multi_file_empty_test() ->
    TempFile = "temp_empty_multi.edn",
    file:write_file(TempFile, ""),

    Result = erldn:parse_multi_file(TempFile),
    file:delete(TempFile),

    % Empty input should cause parser error
    ?assertMatch({error, _, _}, Result).

%% Test parse_multi_file/1 with complex data
parse_multi_file_complex_test() ->
    TempFile = "temp_complex_multi.edn",
    Content = "{:a 1}\n[1 2 3]\n#{:x :y}\n{:nested {:map true}}",
    file:write_file(TempFile, Content),

    Result = erldn:parse_multi_file(TempFile),
    file:delete(TempFile),

    Expected = [
        {map, [{a, 1}]},
        {vector, [1, 2, 3]},
        {set, [x, y]},
        {map, [{nested, {map, [{map, true}]}}]}
    ],
    ?assertMatch({ok, Expected}, Result).

%% Test that parse_multi_file/1 handles binary file content correctly
parse_multi_file_binary_content_test() ->
    TempFile = "temp_binary_multi.edn",
    Content = <<"42\n\"test\"\ntrue">>,
    file:write_file(TempFile, Content),

    Result = erldn:parse_multi_file(TempFile),
    file:delete(TempFile),

    ?assertMatch({ok, [42, <<"test">>, true]}, Result).
