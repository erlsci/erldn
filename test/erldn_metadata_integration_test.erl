-module(erldn_metadata_integration_test).
-include_lib("eunit/include/eunit.hrl").

file_parsing_metadata_test() ->
    MetadataFiles = [
        "metadata-basic.edn",
        "metadata-chained.edn",
        "metadata-complex.edn",
        "metadata-nested.edn"
    ],

    lists:foreach(
        fun(Filename) ->
            FilePath = filename:join([code:priv_dir(erldn), "edn", Filename]),
            Result = erldn:parse_file(FilePath),
            ?assertMatch({ok, _}, Result),

            {ok, Data} = Result,
            ?assert(contains_metadata(Data))
        end,
        MetadataFiles
    ).

contains_metadata(Data) when is_list(Data) ->
    lists:any(fun contains_metadata/1, Data);
contains_metadata({metadata, _, _}) ->
    true;
contains_metadata({vector, Items}) ->
    contains_metadata(Items);
contains_metadata({map, Pairs}) ->
    lists:any(
        fun({K, V}) ->
            contains_metadata(K) orelse contains_metadata(V)
        end,
        Pairs
    );
contains_metadata({set, Items}) ->
    contains_metadata(Items);
contains_metadata(_) ->
    false.

large_metadata_file_test() ->
    Content = generate_large_metadata_content(),
    TempFile = "large_metadata_test.edn",
    file:write_file(TempFile, Content),

    {ok, Data} = erldn:parse_file(TempFile),
    file:delete(TempFile),

    ?assert(contains_metadata(Data)).

generate_large_metadata_content() ->
    Items = [
        io_lib:format("^{:id ~p :type \"item\"} ~p", [N, N])
     || N <- lists:seq(1, 100)
    ],
    Content = string:join(Items, "\n"),
    lists:flatten(Content).

metadata_performance_test() ->
    SimpleContent = string:join([integer_to_list(N) || N <- lists:seq(1, 1000)], " "),
    MetadataContent = string:join(
        [io_lib:format("^:item ~p", [N]) || N <- lists:seq(1, 1000)], " "
    ),

    SimpleContent2 = lists:flatten(SimpleContent),
    MetadataContent2 = lists:flatten(MetadataContent),

    {SimpleTime, _} = timer:tc(fun() -> erldn:parse_str(SimpleContent2) end),
    {MetaTime, _} = timer:tc(fun() -> erldn:parse_str(MetadataContent2) end),

    Ratio = MetaTime / SimpleTime,
    ?assert(Ratio < 5.0).

roundtrip_integration_test() ->
    TestCases = [
        "^:keyword value",
        "^{:author \"Alice\"} [1 2 3]",
        "^:a ^:b ^{:c 1} value",
        "^{:nested true} [^:item 1 ^:item 2]"
    ],

    lists:foreach(
        fun(TestCase) ->
            {ok, Parsed} = erldn:parse_str(TestCase),
            StringForm = lists:flatten(erldn:to_string(Parsed)),
            {ok, Reparsed} = erldn:parse_str(StringForm),
            ?assertEqual(Parsed, Reparsed)
        end,
        TestCases
    ).

metadata_with_erlang_conversion_integration_test() ->
    TestCase = "^{:author \"Alice\"} [1 2 3]",
    {ok, Parsed} = erldn:parse_str(TestCase),
    ErlangForm = erldn:to_erlang(Parsed),

    ?assertMatch({metadata, [1, 2, 3], _}, ErlangForm).

util_functions_integration_test() ->
    TestCase = "^{:author \"Alice\"} [1 2 3]",
    {ok, Parsed} = erldn:parse_str(TestCase),

    Meta = erldn_util:get_metadata(Parsed),
    ?assertMatch({map, [{author, <<"Alice">>}]}, Meta),

    Stripped = erldn_util:strip_metadata(Parsed),
    ?assertEqual({vector, [1, 2, 3]}, Stripped),

    NewMeta = erldn_util:with_metadata({vector, [4, 5, 6]}, test),
    ?assertEqual({metadata, {vector, [4, 5, 6]}, test}, NewMeta).
