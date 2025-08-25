-module(erldn_metadata_lexer_test).
-include_lib("eunit/include/eunit.hrl").

check_lex(Str, ExpectedTokens) ->
    {ok, Tokens, _} = erldn:lex_str(Str),
    TokenTypes = [element(1, T) || T <- Tokens],
    ?assertEqual(ExpectedTokens, TokenTypes).

basic_metadata_tokenization_test() ->
    check_lex(
        "^:keyword value",
        [caret, keyword, symbol]
    ).

metadata_map_tokenization_test() ->
    check_lex(
        "^{:key :value} [1 2 3]",
        [
            caret,
            open_map,
            keyword,
            keyword,
            close_map,
            open_vector,
            integer,
            integer,
            integer,
            close_vector
        ]
    ).

chained_metadata_tokenization_test() ->
    check_lex(
        "^:a ^:b ^{:c 1} value",
        [
            caret,
            keyword,
            caret,
            keyword,
            caret,
            open_map,
            keyword,
            integer,
            close_map,
            symbol
        ]
    ).

metadata_string_tokenization_test() ->
    check_lex(
        "^\"string-meta\" symbol",
        [caret, string, symbol]
    ).

caret_recognition_test() ->
    {ok, [CaretToken], _} = erldn:lex_str("^"),
    ?assertEqual({caret, 1, '^'}, CaretToken).

metadata_with_vector_test() ->
    check_lex(
        "^:test [1 2 3]",
        [caret, keyword, open_vector, integer, integer, integer, close_vector]
    ).

metadata_with_map_test() ->
    check_lex(
        "^{:author \"Alice\"} {:key :val}",
        [
            caret,
            open_map,
            keyword,
            string,
            close_map,
            open_map,
            keyword,
            keyword,
            close_map
        ]
    ).

complex_chained_metadata_test() ->
    check_lex(
        "^{:a 1} ^:b ^\"doc\" symbol",
        [
            caret,
            open_map,
            keyword,
            integer,
            close_map,
            caret,
            keyword,
            caret,
            string,
            symbol
        ]
    ).
