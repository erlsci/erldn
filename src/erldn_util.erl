-module(erldn_util).
-export([
    get_metadata/1,
    strip_metadata/1,
    with_metadata/2,
    merge_metadata/2
]).

%% Get metadata from a value
get_metadata({metadata, _Value, Meta}) ->
    Meta;
get_metadata(_) ->
    undefined.

%% Strip metadata from a structure
strip_metadata({metadata, Value, _Meta}) ->
    strip_metadata(Value);
strip_metadata({vector, Items}) ->
    {vector, [strip_metadata(I) || I <- Items]};
strip_metadata({map, Pairs}) ->
    {map, [{strip_metadata(K), strip_metadata(V)} || {K, V} <- Pairs]};
strip_metadata({set, Items}) ->
    {set, [strip_metadata(I) || I <- Items]};
strip_metadata(Items) when is_list(Items) ->
    [strip_metadata(I) || I <- Items];
strip_metadata(Other) ->
    Other.

%% Add metadata to a value
with_metadata(Value, Meta) ->
    {metadata, Value, Meta}.

%% Merge metadata onto a value
merge_metadata(Value, NewMeta) ->
    case Value of
        {metadata, V, ExistingMeta} ->
            {metadata, V, combine_metadata_maps(ExistingMeta, NewMeta)};
        _ ->
            {metadata, Value, NewMeta}
    end.

%% Helper functions for metadata processing
combine_metadata_maps(Meta1, Meta2) ->
    Map1 = normalize_metadata_to_map(Meta1),
    Map2 = normalize_metadata_to_map(Meta2),
    merge_maps(Map1, Map2).

normalize_metadata_to_map(Keyword) when is_atom(Keyword) ->
    {map, [{Keyword, true}]};
normalize_metadata_to_map({map, _} = Map) ->
    Map;
normalize_metadata_to_map(String) when is_binary(String) ->
    {map, [{tag, String}]};
normalize_metadata_to_map(Other) ->
    {map, [{value, Other}]}.

merge_maps({map, Pairs1}, {map, Pairs2}) ->
    {map, Pairs1 ++ Pairs2}.
