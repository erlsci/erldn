-module(erldn_util_test).
-include_lib("eunit/include/eunit.hrl").

%% Test get_metadata/1
get_metadata_with_metadata_test() ->
    Input = {metadata, value, meta_data},
    Result = erldn_util:get_metadata(Input),
    ?assertEqual(meta_data, Result).

get_metadata_without_metadata_test() ->
    Input = {symbol, test},
    Result = erldn_util:get_metadata(Input),
    ?assertEqual(undefined, Result).

get_metadata_with_atom_test() ->
    Input = atom_value,
    Result = erldn_util:get_metadata(Input),
    ?assertEqual(undefined, Result).

%% Test strip_metadata/1
strip_metadata_basic_test() ->
    Input = {metadata, {symbol, test}, meta_data},
    Result = erldn_util:strip_metadata(Input),
    ?assertEqual({symbol, test}, Result).

strip_metadata_nested_test() ->
    Input = {metadata, {metadata, value, inner_meta}, outer_meta},
    Result = erldn_util:strip_metadata(Input),
    ?assertEqual(value, Result).

strip_metadata_vector_test() ->
    Input = {vector, [{metadata, 1, meta1}, 2, {metadata, 3, meta2}]},
    Result = erldn_util:strip_metadata(Input),
    ?assertEqual({vector, [1, 2, 3]}, Result).

strip_metadata_map_test() ->
    Input = {map, [{{metadata, key1, meta1}, {metadata, val1, meta2}}, {key2, val2}]},
    Result = erldn_util:strip_metadata(Input),
    ?assertEqual({map, [{key1, val1}, {key2, val2}]}, Result).

strip_metadata_set_test() ->
    Input = {set, [{metadata, 1, meta1}, 2, {metadata, 3, meta2}]},
    Result = erldn_util:strip_metadata(Input),
    ?assertEqual({set, [1, 2, 3]}, Result).

strip_metadata_list_test() ->
    Input = [{metadata, 1, meta1}, 2, {metadata, 3, meta2}],
    Result = erldn_util:strip_metadata(Input),
    ?assertEqual([1, 2, 3], Result).

strip_metadata_no_metadata_test() ->
    Input = {symbol, test},
    Result = erldn_util:strip_metadata(Input),
    ?assertEqual({symbol, test}, Result).

%% Test with_metadata/2
with_metadata_basic_test() ->
    Result = erldn_util:with_metadata({symbol, test}, meta_data),
    ?assertEqual({metadata, {symbol, test}, meta_data}, Result).

with_metadata_atom_test() ->
    Result = erldn_util:with_metadata(atom_value, keyword_meta),
    ?assertEqual({metadata, atom_value, keyword_meta}, Result).

%% Test merge_metadata/2
merge_metadata_with_existing_test() ->
    Input = {metadata, {symbol, test}, existing_meta},
    Result = erldn_util:merge_metadata(Input, new_meta),
    Expected = {metadata, {symbol, test}, {map, [{existing_meta, true}, {new_meta, true}]}},
    ?assertEqual(Expected, Result).

merge_metadata_without_existing_test() ->
    Input = {symbol, test},
    Result = erldn_util:merge_metadata(Input, new_meta),
    ?assertEqual({metadata, {symbol, test}, new_meta}, Result).

merge_metadata_keyword_to_keyword_test() ->
    Input = {metadata, value, existing_keyword},
    Result = erldn_util:merge_metadata(Input, new_keyword),
    Expected = {metadata, value, {map, [{existing_keyword, true}, {new_keyword, true}]}},
    ?assertEqual(Expected, Result).

merge_metadata_map_to_map_test() ->
    Input = {metadata, value, {map, [{key1, val1}]}},
    Result = erldn_util:merge_metadata(Input, {map, [{key2, val2}]}),
    Expected = {metadata, value, {map, [{key1, val1}, {key2, val2}]}},
    ?assertEqual(Expected, Result).

merge_metadata_string_to_keyword_test() ->
    Input = {metadata, value, existing_keyword},
    Result = erldn_util:merge_metadata(Input, <<"string_meta">>),
    Expected = {metadata, value, {map, [{existing_keyword, true}, {tag, <<"string_meta">>}]}},
    ?assertEqual(Expected, Result).

merge_metadata_number_to_keyword_test() ->
    Input = {metadata, value, existing_keyword},
    Result = erldn_util:merge_metadata(Input, 42),
    Expected = {metadata, value, {map, [{existing_keyword, true}, {value, 42}]}},
    ?assertEqual(Expected, Result).
