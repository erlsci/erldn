-module(erldn_lexer_error_test).
-include_lib("eunit/include/eunit.hrl").

%% Test lexer error handling in parse_multi_str/1
parse_multi_str_lexer_error_test() ->
    % Create input that causes lexer error
    % Unterminated string should cause lexer error
    InvalidInput = "\"unclosed string",

    Result = erldn:parse_str(InvalidInput),

    % Lexer error comes back in a complex format, just check it's an error
    ?assert(
        case Result of
            {error, _} -> true;
            {error, _, _} -> true;
            _ -> false
        end
    ).

%% Test various inputs that should trigger lexer or parser errors
parse_multi_str_various_lexer_errors_test() ->
    BadInputs = [
        "\"unterminated string literal",
        % unclosed map - should cause parser error
        "{",
        % unclosed vector - should cause parser error
        "[",
        % unclosed set - should cause parser error
        "#{"
    ],

    % Test each and expect some kind of error
    lists:foreach(
        fun(Input) ->
            Result = erldn:parse_str(Input),
            % Should be some kind of error
            case Result of
                % Lexer error
                {error, _} ->
                    ok;
                % Parser error
                {error, _, _} ->
                    ok;
                {ok, _} ->
                    % Should not succeed with bad input
                    ?assert(false)
            end
        end,
        BadInputs
    ).

%% Test that lexer errors are propagated correctly through parse_multi_str
lexer_error_propagation_test() ->
    % Test specific lexer error that we know should occur

    % Invalid UTF-8 byte
    BadChar = [255],
    Result = erldn:parse_str(BadChar),

    % Should get some kind of error
    ?assert(
        case Result of
            % Direct lexer error
            {error, _} -> true;
            % Parser error (also acceptable)
            {error, _, _} -> true;
            _ -> false
        end
    ).

%% Test empty input handling in parse_multi_str
empty_input_lexer_test() ->
    Result = erldn:parse_str(""),
    % Empty input should cause an error (no tokens to parse)
    ?assertMatch({error, _, _}, Result).

%% Test whitespace-only input
whitespace_only_lexer_test() ->
    Result = erldn:parse_str("   \n\t  "),
    % Whitespace-only should also cause an error (no meaningful tokens)
    ?assertMatch({error, _, _}, Result).
