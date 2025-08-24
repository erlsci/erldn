-module(erldn_string_escaping_test).
-include_lib("eunit/include/eunit.hrl").

%% Test tab character escaping (covers line 174 in map_escaped_char/1)
string_with_tab_escaping_test() ->
    % Create string containing tab character
    StringWithTab = <<"hello\tworld">>,
    Result = erldn:to_string(StringWithTab),
    Expected = "\"hello\\tworld\"",
    ?assertEqual(Expected, lists:flatten(Result)).

%% Test all escape characters comprehensively
comprehensive_string_escaping_test() ->
    % Test string with all escapable characters
    StringWithEscapes = <<"hello\n\r\t\"\\world">>,
    Result = erldn:to_string(StringWithEscapes),
    Expected = "\"hello\\n\\r\\t\\\"\\\\world\"",
    ?assertEqual(Expected, lists:flatten(Result)).

%% Test individual escape characters
individual_escape_chars_test() ->
    Escapes = [
        % newline
        {<<"\n">>, "\"\\n\""},
        % carriage return
        {<<"\r">>, "\"\\r\""},
        % tab - THIS COVERS LINE 174
        {<<"\t">>, "\"\\t\""},
        % quote
        {<<"\"">>, "\"\\\"\""},
        % backslash
        {<<"\\">>, "\"\\\\\""}
    ],

    lists:foreach(
        fun({Input, Expected}) ->
            Result = lists:flatten(erldn:to_string(Input)),
            ?assertEqual(Expected, Result)
        end,
        Escapes
    ).

%% Test string with only tab characters
tab_only_string_test() ->
    TabString = <<"\t\t\t">>,
    Result = erldn:to_string(TabString),
    Expected = "\"\\t\\t\\t\"",
    ?assertEqual(Expected, lists:flatten(Result)).

%% Test mixed tab and other characters
mixed_tab_escaping_test() ->
    % Test tab mixed with other special characters
    MixedString = <<"start\ttab\nline\tend">>,
    Result = erldn:to_string(MixedString),
    Expected = "\"start\\ttab\\nline\\tend\"",
    ?assertEqual(Expected, lists:flatten(Result)).

%% Test empty string escaping
empty_string_escaping_test() ->
    EmptyString = <<"">>,
    Result = erldn:to_string(EmptyString),
    Expected = "\"\"",
    ?assertEqual(Expected, lists:flatten(Result)).

%% Test string with no escapable characters
no_escape_needed_test() ->
    NormalString = <<"hello world">>,
    Result = erldn:to_string(NormalString),
    Expected = "\"hello world\"",
    ?assertEqual(Expected, lists:flatten(Result)).

%% Test tab escaping in multi-value context
tab_escaping_multi_value_test() ->
    % Create multiple strings with tabs
    Strings = [<<"first\ttab">>, <<"second\ttab">>, <<"third\ttab">>],
    Results = [lists:flatten(erldn:to_string(S)) || S <- Strings],
    Expected = [
        "\"first\\ttab\"",
        "\"second\\ttab\"",
        "\"third\\ttab\""
    ],
    ?assertEqual(Expected, Results).

%% Test escape_string/1 function directly with tab
escape_string_tab_test() ->
    % Test the internal escape_string function with tab character
    Input = "hello\tworld",
    % We need to test the internal function, but it's not exported
    % Instead, test through to_string which calls it
    Binary = list_to_binary(Input),
    Result = erldn:to_string(Binary),
    Expected = "\"hello\\tworld\"",
    ?assertEqual(Expected, lists:flatten(Result)).
