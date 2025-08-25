-module(erldn).
-export([
    lex_str/1,
    parse/1,
    parse_file/1,
    parse_str/1,
    to_string/1,
    to_erlang/1, to_erlang/2
]).

%%% API functions

lex_str(Str) -> erldn_lexer:string(Str).

parse(Bin) when is_binary(Bin) ->
    parse_str(binary_to_list(Bin));
parse(Input) when is_list(Input) ->
    case filelib:is_file(Input) of
        true ->
            parse_file(Input);
        false ->
            parse_str(Input)
    end.

parse_file(Filename) ->
    case filename:extension(Filename) of
        ".edn" ->
            case file:read_file(Filename) of
                {ok, Data} ->
                    parse(Data);
                {error, Reason} ->
                    {error, {file_error, Reason}}
            end;
        _ ->
            {error, {invalid_extension, filename:extension(Filename)}}
    end.

parse_str(Str) ->
    case parse_multi_str(Str) of
        {ok, [SingleValue]} ->
            {ok, SingleValue};
        {ok, MultipleValues} ->
            {ok, MultipleValues};
        Error ->
            Error
    end.

to_string(Edn) -> lists:reverse(to_string(Edn, [])).

to_erlang(Val) -> to_erlang(Val, []).

to_erlang({char, Char}, _Handlers) ->
    unicode:characters_to_binary([Char], utf8);
to_erlang({keyword, nil}, _Handlers) ->
    nil;
to_erlang({vector, Items}, Handlers) ->
    to_erlang(Items, Handlers);
to_erlang({set, Items}, Handlers) ->
    sets:from_list(to_erlang(Items, Handlers));
to_erlang({map, Kvs}, Handlers) ->
    dict:from_list(lists:map(fun(V) -> key_vals_to_erlang(V, Handlers) end, Kvs));
to_erlang(Val, Handlers) when is_list(Val) ->
    lists:map(fun(V) -> to_erlang(V, Handlers) end, Val);
to_erlang({tag, inf, pos}, _Handlers) ->
    positive_infinity;
to_erlang({tag, inf, neg}, _Handlers) ->
    negative_infinity;
to_erlang({tag, nan, nil}, _Handlers) ->
    not_a_number;
to_erlang({tag, Tag, Val}, Handlers) ->
    Result = lists:keyfind(Tag, 1, Handlers),

    if
        Result == false ->
            throw({handler_not_found_for_tag, Tag});
        true ->
            {_, Handler} = Result,
            Handler(Tag, Val, Handlers)
    end;
to_erlang(Val, _Handlers) ->
    Val.

%%% Private functions
%%%
%%% These functions are not exported and are used internally by the module.

parse_multi_str(Str) ->
    case lex_str(Str) of
        {ok, Tokens, _} ->
            case erldn_parser:parse(Tokens) of
                {ok, Values} -> {ok, Values};
                {error, Error} -> {error, Error, nil}
            end;
        Error ->
            Error
    end.

keyvals_to_string(Items) -> keyvals_to_string(Items, []).

keyvals_to_string([], Accum) ->
    lists:reverse(Accum);
keyvals_to_string([{K, V}], Accum) ->
    keyvals_to_string([], [to_string(V), " ", to_string(K) | Accum]);
keyvals_to_string([{K, V} | T], Accum) ->
    keyvals_to_string(T, [" ", to_string(V), " ", to_string(K) | Accum]).

items_to_string(Items) -> items_to_string(Items, []).

items_to_string([], Accum) -> lists:reverse(Accum);
items_to_string([H], Accum) -> items_to_string([], [to_string(H) | Accum]);
items_to_string([H | T], Accum) -> items_to_string(T, [(to_string(H) ++ " ") | Accum]).

to_string(Value, Accum) when is_binary(Value) ->
    ["\"", escape_string(unicode:characters_to_list(Value)), "\"" | Accum];
to_string({symbol, Symbol}, Accum) ->
    [atom_to_list(Symbol) | Accum];
to_string({keyword, nil}, Accum) ->
    [":nil" | Accum];
to_string({char, C}, Accum) ->
    [["\\" | [C]] | Accum];
to_string({vector, Items}, Accum) ->
    ["]", items_to_string(Items), "[" | Accum];
to_string({set, Items}, Accum) ->
    ["}", items_to_string(Items), "#{" | Accum];
to_string({map, Items}, Accum) ->
    ["}", keyvals_to_string(Items), "{" | Accum];
to_string(Items, Accum) when is_list(Items) -> [")", items_to_string(Items), "(" | Accum];
to_string(true, Accum) ->
    ["true" | Accum];
to_string(false, Accum) ->
    ["false" | Accum];
to_string(nil, Accum) ->
    ["nil" | Accum];
to_string(Item, Accum) when is_atom(Item) -> [atom_to_list(Item), ":" | Accum];
to_string({tag, inf, pos}, Accum) ->
    ["##Inf" | Accum];
to_string({tag, inf, neg}, Accum) ->
    ["##-Inf" | Accum];
to_string({tag, nan, nil}, Accum) ->
    ["##NaN" | Accum];
to_string({tag, Tag, Value}, Accum) ->
    [to_string(Value), " ", atom_to_list(Tag), "#" | Accum];
to_string(Value, Accum) ->
    [io_lib:format("~p", [Value]) | Accum].

escape_string(String) -> escape_string(String, []).

escape_string([], Output) ->
    lists:reverse(Output);
escape_string([Char | Rest], Output) ->
    Chars = map_escaped_char(Char),
    escape_string(Rest, [Chars | Output]).

map_escaped_char(Char) ->
    case Char of
        $\\ -> [$\\, $\\];
        $\" -> [$\\, $\"];
        $\n -> [$\\, $n];
        $\r -> [$\\, $r];
        $\t -> [$\\, $t];
        _ -> Char
    end.

key_vals_to_erlang({Key, Val}, Handlers) ->
    {to_erlang(Key, Handlers), to_erlang(Val, Handlers)}.
