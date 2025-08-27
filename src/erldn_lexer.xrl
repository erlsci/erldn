Definitions.

Bool = (true|false)
Nil  = nil

% Invalid numeric patterns that must be caught as errors
InvalidHex = 0[xX]([0-9a-fA-F]*[g-zG-Z]+[0-9a-zA-Z]*|[^0-9a-fA-F\s\[\]\{\}\(\),;]+)
InvalidOctal = 0[0-7]*[89]+[0-9]*
InvalidRational = [+-]?[0-9]+//+[0-9]*
% More explicit and clearer:
InvalidRadix = [+-]?[0-9]+[rR]([0-9a-zA-Z]*[^0-9a-zA-Z\s\n\r\t\[\]\{\}\(\),;]+|[^0-9a-zA-Z]+)
% InvalidNumeric = [+-]?[0-9]+[a-zA-Z]+[0-9a-zA-Z]*

% numbers (ordered by specificity)
Hexadecimal = [+-]?0[xX][0-9a-fA-F]+
Octal       = [+-]?0[0-7]+
Zero        = [+-]?0+
Number      = [+-]?[1-9][0-9]*
Float       = [+-]?[0-9]+\.[0-9]+([eE][-+]?[0-9]+)?
Radix       = [+-]?[0-9]+[rR][0-9a-zA-Z]+
Rational    = [+-]?[0-9]+/[0-9]+

% special numerical values
InfPos      = ##Inf
InfNeg      = ##-Inf  
NaN         = ##NaN

% delimiters and operators
OpenList    = \(
CloseList   = \)
OpenMap     = {
CloseMap    = }
OpenVector  = \[
CloseVector = \]
Whites      = [\s|,\n]+
Sharp       = #
Caret       = \^
Slash       = /
Colon       = :
Comments    = ;.*\n
CharNewLine = \\newline
CharReturn  = \\return
CharTab     = \\tab
CharSpace   = \\space
BackSlash   = \\
% Original symbol pattern - commented out for debugging
% Symbol      = ([\.\*\!\-\_\?\$%&=<>a-zA-Z]|[+\-][a-zA-Z\.\*\!\-\_\?\$%&=<>])[\.\*\+\!\-\_\?\$%&=<>a-zA-Z0-9:#]*
% New pattern: allow +/- only when NOT followed by digits
Symbol      = ([a-zA-Z\.\*\!\_\?\$%&=<>]|[+\-][^0-9])[\.\*\+\!\-\_\?\$%&=<>a-zA-Z0-9:#]*

% keywords - mixed alphanumeric pattern for after colon
Keyword     = [\.\*\+\!\-\_\?\$%&=<>a-zA-Z0-9:#/]+

% string stuff
String      = "(\\\^.|\\.|[^\"])*"

Rules.

% Invalid patterns MUST come first to take precedence
{InvalidHex}      : {error, {invalid_hexadecimal, TokenLine, TokenChars}}.
{InvalidOctal}    : {error, {invalid_octal, TokenLine, TokenChars}}.
{InvalidRational} : {error, {invalid_rational, TokenLine, TokenChars}}.
{InvalidRadix}    : {error, {invalid_radix, TokenLine, TokenChars}}.
% {InvalidNumeric}  : {error, {invalid_numeric, TokenLine, TokenChars}}.

% Then the valid numeric patterns (ordered by specificity)
{Hexadecimal}            : make_token(hexadecimal, TokenLine, TokenChars, fun parse_hexadecimal/1).
{Octal}                  : make_token(octal, TokenLine, TokenChars, fun parse_octal/1).
{Zero}                   : make_token(integer, TokenLine, TokenChars, fun parse_zero/1).
{Radix}                  : make_token(radix, TokenLine, TokenChars, fun parse_radix/1).
{Rational}               : make_token(rational, TokenLine, TokenChars, fun parse_rational/1).

% numbers
{Float}                  : make_token(float, TokenLine, TokenChars, fun erlang:list_to_float/1).
{Number}+                : make_token(integer, TokenLine, TokenChars, fun parse_number/1).
{Float}M                 : make_token(float, TokenLine, TokenChars, fun list_to_float_without_suffix/1).
{Number}+N               : make_token(integer, TokenLine, TokenChars, fun parse_number_without_suffix/1).

% delimiters and operators
{OpenList}               : make_token(open_list, TokenLine, TokenChars).
{CloseList}              : make_token(close_list, TokenLine, TokenChars).
{OpenMap}                : make_token(open_map, TokenLine, TokenChars).
{CloseMap}               : make_token(close_map, TokenLine, TokenChars).
{OpenVector}             : make_token(open_vector, TokenLine, TokenChars).
{CloseVector}            : make_token(close_vector, TokenLine, TokenChars).

% string stuff
{String}                 : build_string(string, TokenChars, TokenLine, TokenLen).

% identifiers and atoms
{BackSlash}.             : {token, {char, TokenLine, hd(tl(TokenChars))}}.
{Bool}                   : make_token(boolean, TokenLine, TokenChars).
{Nil}                    : make_token(nil, TokenLine, TokenChars).

% special numerical values (must come before general Sharp rule)
{InfPos}                 : make_token(inf_pos, TokenLine, TokenChars).
{InfNeg}                 : make_token(inf_neg, TokenLine, TokenChars).
{NaN}                    : make_token(nan, TokenLine, TokenChars).

{Sharp}_                 : make_token(ignore, TokenLine, TokenChars).
{Sharp}                  : make_token(sharp, TokenLine, TokenChars).
{Caret}                  : make_token(caret, TokenLine, TokenChars).
{Symbol}                 : make_token(symbol, TokenLine, TokenChars).
{Slash}                  : make_token(symbol, TokenLine, TokenChars).
{Slash}{Symbol}          : make_token(symbol, TokenLine, TokenChars).
{Symbol}{Slash}{Symbol}  : make_token(symbol, TokenLine, TokenChars).

% General keyword rule - must come first to catch mixed alphanumeric like :300x450
{Colon}{Keyword}                : make_token(keyword, TokenLine, tl(TokenChars)).
{Colon}{Symbol}                 : make_token(keyword, TokenLine, tl(TokenChars)).
{Colon}{Number}                 : make_token(keyword, TokenLine, tl(TokenChars)).
{Colon}{Slash}                  : make_token(keyword, TokenLine, tl(TokenChars)).
{Colon}{Slash}{Symbol}          : make_token(keyword, TokenLine, tl(TokenChars)).
{Colon}{Symbol}{Slash}{Symbol}  : make_token(keyword, TokenLine, tl(TokenChars)).

{CharNewLine}            : make_token(char, TokenLine, $\n).
{CharReturn}             : make_token(char, TokenLine, $\r).
{CharTab}                : make_token(char, TokenLine, $\t).
{CharSpace}              : make_token(char, TokenLine, 32).

{Whites}                : skip_token.
{Comments}              : skip_token.

Erlang code.

make_token(Name, Line, Chars) when is_list(Chars) ->
    {token, {Name, Line, list_to_atom(Chars)}};
make_token(Name, Line, Chars) ->
    {token, {Name, Line, Chars}}.

make_token(Name, Line, Chars, Fun) ->
    try 
        {token, {Name, Line, Fun(Chars)}}
    catch
        error:Reason ->
            {error, Reason}
    end.

%build_string(Type, Str0, Line, _Len) ->
  %Str = re:replace(Str0, "\\\\(?!\\\\)", "", [global, {return, list}]),
  %StrLen = length(Str),
  %StringContent = lists:sublist(Str, 2, StrLen - 2),
  %String = unicode:characters_to_binary(StringContent, utf8),
  %{token, {Type, Line, String}}.

build_string(Type, Str, Line, _Len) ->
  StrLen = length(Str),
  StringContent = lists:sublist(Str, 2, StrLen - 2),
  String = unicode:characters_to_binary(StringContent, utf8),
  String2 = re:replace(
            re:replace(
              re:replace(
                re:replace(
                  re:replace(
                    re:replace(
                      re:replace(String, "\\\\n", "\n", [global, {return, binary}]),
                      "\\\\t", "\t", [global, {return, binary}]),
                    "\\\\r", "\r", [global, {return, binary}]),
                  "\\\\f", "\f", [global, {return, binary}]),
                "\\\\b", "\b", [global, {return, binary}]),
              "\\\\\"", "\"", [global, {return, binary}]),
            "\\\\\\\\", "\\", [global, {return, binary}]),
  {token, {Type, Line, String2}}.

parse_number(Str) ->
    list_to_integer(Str).

parse_number_without_suffix(Str) ->
    Init = lists:droplast(Str),
    list_to_integer(Init).

list_to_float_without_suffix(Str) ->
    Init = lists:droplast(Str),
    erlang:list_to_float(Init).

% NEW: Add these parsing functions
parse_zero(Str) ->
    % Parse sequences of zeros as integer 0
    {Sign, _Rest} = extract_sign(Str),
    Sign * 0.

parse_hexadecimal(Str) ->
    % Remove optional sign and 0x/0X prefix
    {Sign, Rest} = extract_sign(Str),
    NoPrefix = case Rest of
        "0x" ++ Hex -> Hex;
        "0X" ++ Hex -> Hex;
        _ -> error({invalid_hex, Str})
    end,
    Sign * list_to_integer(NoPrefix, 16).

parse_octal(Str) ->
    % Remove optional sign and leading 0
    {Sign, Rest} = extract_sign(Str),
    case Rest of
        "0" ++ Octal when Octal =/= "" -> Sign * list_to_integer(Octal, 8);
        _ -> error({invalid_octal, Str})
    end.

parse_radix(Str) ->
    % Parse NrDIGITS format
    {Sign, Rest} = extract_sign(Str),
    case re:split(Rest, "[rR]", [{return, list}]) of
        [RadixStr, DigitStr] ->
            Radix = list_to_integer(RadixStr),
            if 
                Radix >= 2 andalso Radix =< 36 ->
                    try
                        Sign * list_to_integer(DigitStr, Radix)
                    catch
                        error:badarg ->
                            error({invalid_radix_digits, DigitStr, Radix})
                    end;
                true -> 
                    error({invalid_radix, Radix})
            end;
        _ -> error({invalid_radix_format, Str})
    end.

parse_rational(Str) ->
    % Parse numerator/denominator format
    {Sign, Rest} = extract_sign(Str),
    case re:split(Rest, "/", [{return, list}]) of
        [NumerStr, DenomStr] ->
            Numerator = list_to_integer(NumerStr),
            Denominator = list_to_integer(DenomStr),
            if 
                Denominator =/= 0 ->
                    {rational, Sign * Numerator, Denominator};
                true -> 
                    error({zero_denominator, Str})
            end;
        _ -> error({invalid_rational_format, Str})
    end.

% Helper function to extract sign
extract_sign([$+ | Rest]) -> {1, Rest};
extract_sign([$- | Rest]) -> {-1, Rest};
extract_sign(Rest) -> {1, Rest}.
