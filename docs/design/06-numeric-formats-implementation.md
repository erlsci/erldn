# Implementation Guide: EDN Numeric Formats Support

## Overview

This document provides detailed instructions for implementing support for EDN's additional numeric formats in the erldn library. Currently, the library only supports basic integers, floats, and arbitrary precision numbers (M/N suffixes). The missing formats are:

- **Hexadecimal numbers**: `0xFF`, `0x1A2B`, `0X123`
- **Octal numbers**: `0777`, `0123`
- **Arbitrary radix numbers**: `2r1010`, `8r777`, `16rFF`, `36rZZ`
- **Rational numbers**: `22/7`, `-3/4`, `355/113`

## Current State Analysis

The existing lexer in `src/erldn_lexer.xrl` only handles:
- Basic integers: `[+-]?[0-9]+`
- Floats: `[+-]?[0-9]+\.[0-9]+([eE][-+]?[0-9]+)?`
- Arbitrary precision: `123M`, `456N`

The test file `priv/edn/numbers.edn` contains rational numbers like `62/27`, but these are currently parsed as **symbols** rather than numeric values because the lexer's Symbol rule includes `/`.

## Implementation Steps

### 1. Update the Lexer (`src/erldn_lexer.xrl`)

#### 1.1 Add New Numeric Patterns to Definitions

```erlang
Definitions.

Bool = (true|false)
Nil  = nil

% Existing number patterns
Number      = [+-]?[0-9]
Float       = [+-]?[0-9]+\.[0-9]+([eE][-+]?[0-9]+)?

% NEW: Add these numeric format patterns
Hexadecimal = [+-]?0[xX][0-9a-fA-F]+
Octal       = [+-]?0[0-7]+
Radix       = [+-]?[0-9]+[rR][0-9a-zA-Z]+
Rational    = [+-]?[0-9]+/[0-9]+

% Rest of existing definitions...
```

#### 1.2 Add New Rules (Place BEFORE Existing Number Rules)

```erlang
Rules.

% NEW: Add these rules BEFORE the existing number rules for proper precedence
{Hexadecimal}            : make_token(hexadecimal, TokenLine, TokenChars, fun parse_hexadecimal/1).
{Octal}                  : make_token(octal, TokenLine, TokenChars, fun parse_octal/1).
{Radix}                  : make_token(radix, TokenLine, TokenChars, fun parse_radix/1).
{Rational}               : make_token(rational, TokenLine, TokenChars, fun parse_rational/1).

% Existing number rules follow...
{Float}                  : make_token(float, TokenLine, TokenChars, fun erlang:list_to_float/1).
{Number}+                : make_token(integer, TokenLine, TokenChars, fun parse_number/1).
% ... rest of existing rules
```

#### 1.3 Add Parsing Functions to Erlang Code Section

```erlang
Erlang code.

% Existing functions...

% NEW: Add these parsing functions
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
        "0" ++ Octal -> Sign * list_to_integer(Octal, 8);
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
                    Sign * list_to_integer(DigitStr, Radix);
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
```

**Important Notes:**
- Place new numeric rules BEFORE existing number rules to ensure proper precedence
- Hexadecimal uses base 16: `0xFF` = 255
- Octal uses base 8: `0777` = 511
- Radix format: `NrDIGITS` where N is 2-36
- Rationals are represented as `{rational, Numerator, Denominator}` tuples

### 2. Update the Parser (`src/erldn_parser.yrl`)

#### 2.1 Add New Terminals

```erlang
Terminals
    float integer boolean string nil open_list close_list open_vector
    close_vector open_map close_map sharp ignore keyword symbol char
    hexadecimal octal radix rational.  % <-- Add these
```

#### 2.2 Add New Value Rules

```erlang
value -> nil         : unwrap('$1').
value -> float       : unwrap('$1').
value -> integer     : unwrap('$1').
value -> hexadecimal : unwrap('$1').  % <-- Add these
value -> octal       : unwrap('$1').
value -> radix       : unwrap('$1').
value -> rational    : unwrap('$1').
value -> boolean     : unwrap('$1').
% ... rest of existing rules
```

### 3. Update String Conversion (`src/erldn.erl`)

#### 3.1 Add Cases to `to_string/2` Function

```erlang
% Add these cases to to_string/2 function
to_string({rational, Numerator, Denominator}, Accum) ->
    RationalStr = io_lib:format("~p/~p", [Numerator, Denominator]),
    [RationalStr | Accum];
% Note: Hex, octal, and radix numbers convert to their integer values
% and are serialized as regular integers
```

**Design Decision:** Hex, octal, and radix numbers are parsed to integer values and serialized back as decimal integers. Only rationals maintain their special format.

### 4. Update Erlang Conversion (`src/erldn.erl`)

#### 4.1 Handle Rational Numbers in `to_erlang/2`

```erlang
% Add to to_erlang/2 function
to_erlang({rational, Numerator, Denominator}, _Handlers) ->
    % Option 1: Keep as tuple
    {rational, Numerator, Denominator};
    
    % Option 2: Convert to float (may lose precision)
    % Numerator / Denominator;
    
    % Option 3: Use a record
    % #rational{numerator = Numerator, denominator = Denominator}.
```

Choose the representation that best fits your needs. The tuple format is recommended for precision preservation.

### 5. Create Comprehensive Test Data

#### 5.1 Create `priv/edn/numeric-formats.edn`

```edn
; Hexadecimal numbers
0xFF
0x1A2B
-0x123
0X456
+0xABCD

; Octal numbers  
0777
0123
-0456
+0111

; Arbitrary radix numbers
2r1010
8r777
16rFF
36rZZ
-2r1111
+36rABC123

; Rational numbers
22/7
-3/4
355/113
+1/2
1000/1
-999/333
```

#### 5.2 Create `priv/edn/numeric-edge-cases.edn`

```edn
; Edge cases
0x0
0x1
-0x1
0
01
-01
2r0
2r1
36r0
-36rZ
1/1
-1/1
0/1
```

#### 5.3 Update Existing `priv/edn/numbers.edn`

The existing rational numbers in this file should now parse correctly as numeric values instead of symbols.

### 6. Add Comprehensive Tests

#### 6.1 Lexer Tests (`test/erldn_numeric_lexer_test.erl`)

```erlang
-module(erldn_numeric_lexer_test).
-include_lib("eunit/include/eunit.hrl").

check_lex(Str, Expected) ->
    {ok, [Result], _} = erldn:lex_str(Str),
    ?assertEqual(Expected, Result).

% Hexadecimal tests
hex_basic_test() -> 
    check_lex("0xFF", {hexadecimal, 1, 255}).

hex_uppercase_test() -> 
    check_lex("0X1A2B", {hexadecimal, 1, 6699}).

hex_negative_test() -> 
    check_lex("-0xff", {hexadecimal, 1, -255}).

hex_positive_test() -> 
    check_lex("+0xFF", {hexadecimal, 1, 255}).

% Octal tests
octal_basic_test() -> 
    check_lex("0777", {octal, 1, 511}).

octal_negative_test() -> 
    check_lex("-0123", {octal, 1, -83}).

octal_positive_test() -> 
    check_lex("+0456", {octal, 1, 302}).

% Radix tests
radix_binary_test() -> 
    check_lex("2r1010", {radix, 1, 10}).

radix_base36_test() -> 
    check_lex("36rZZ", {radix, 1, 1295}).

radix_negative_test() -> 
    check_lex("-8r777", {radix, 1, -511}).

radix_hex_equivalent_test() -> 
    check_lex("16rFF", {radix, 1, 255}).

% Rational tests
rational_basic_test() -> 
    check_lex("22/7", {rational, 1, {rational, 22, 7}}).

rational_negative_test() -> 
    check_lex("-3/4", {rational, 1, {rational, -3, 4}}).

rational_positive_test() -> 
    check_lex("+1/2", {rational, 1, {rational, 1, 2}}).

% Edge cases
hex_zero_test() -> 
    check_lex("0x0", {hexadecimal, 1, 0}).

octal_zero_test() -> 
    check_lex("0", {octal, 1, 0}).

rational_unit_test() -> 
    check_lex("1/1", {rational, 1, {rational, 1, 1}}).

radix_edge_test() -> 
    check_lex("2r0", {radix, 1, 0}).

% Test precedence - ensure these don't get parsed as symbols
hex_not_symbol_test() ->
    {ok, [Token], _} = erldn:lex_str("0xFF"),
    ?assertMatch({hexadecimal, _, _}, Token).

rational_not_symbol_test() ->
    {ok, [Token], _} = erldn:lex_str("22/7"),
    ?assertMatch({rational, _, _}, Token).
```

#### 6.2 Parser Tests (`test/erldn_numeric_parser_test.erl`)

```erlang
-module(erldn_numeric_parser_test).
-include_lib("eunit/include/eunit.hrl").

check_parse(Str, Expected) ->
    {ok, Result} = erldn:parse_str(Str),
    ?assertEqual(Expected, Result).

% Hexadecimal parsing
hex_parse_test() ->
    check_parse("0xFF", 255).

hex_negative_parse_test() ->
    check_parse("-0x123", -291).

% Octal parsing
octal_parse_test() ->
    check_parse("0777", 511).

octal_negative_parse_test() ->
    check_parse("-0123", -83).

% Radix parsing
radix_binary_parse_test() ->
    check_parse("2r1010", 10).

radix_base36_parse_test() ->
    check_parse("36rZZ", 1295).

radix_negative_parse_test() ->
    check_parse("-8r777", -511).

% Rational parsing
rational_parse_test() ->
    check_parse("22/7", {rational, 22, 7}).

rational_negative_parse_test() ->
    check_parse("-3/4", {rational, -3, 4}).

rational_positive_parse_test() ->
    check_parse("+1/2", {rational, 1, 2}).

% Mixed numeric types in collections
mixed_numbers_vector_test() ->
    check_parse("[0xFF 0777 2r1010 22/7]", 
                {vector, [255, 511, 10, {rational, 22, 7}]}).

mixed_numbers_map_test() ->
    check_parse("{:hex 0xFF :octal 0777 :rational 22/7}",
                {map, [{hex, 255}, {octal, 511}, {rational, {rational, 22, 7}}]}).

% Multi-value parsing
multi_numeric_test() ->
    check_parse("0xFF 0777 2r1010 22/7", 
                [255, 511, 10, {rational, 22, 7}]).
```

#### 6.3 String Conversion Tests (`test/erldn_numeric_string_test.erl`)

```erlang
-module(erldn_numeric_string_test).
-include_lib("eunit/include/eunit.hrl").

% Test that rationals round-trip correctly
rational_roundtrip_test() ->
    Input = "22/7",
    {ok, Parsed} = erldn:parse_str(Input),
    Reconstructed = lists:flatten(erldn:to_string(Parsed)),
    ?assertEqual("22/7", Reconstructed).

rational_negative_roundtrip_test() ->
    Input = "-3/4",
    {ok, Parsed} = erldn:parse_str(Input),
    Reconstructed = lists:flatten(erldn:to_string(Parsed)),
    ?assertEqual("-3/4", Reconstructed).

% Test that hex/octal/radix convert to decimal representation
hex_to_decimal_string_test() ->
    {ok, Parsed} = erldn:parse_str("0xFF"),
    Result = lists:flatten(erldn:to_string(Parsed)),
    ?assertEqual("255", Result).

octal_to_decimal_string_test() ->
    {ok, Parsed} = erldn:parse_str("0777"),
    Result = lists:flatten(erldn:to_string(Parsed)),
    ?assertEqual("511", Result).

radix_to_decimal_string_test() ->
    {ok, Parsed} = erldn:parse_str("2r1010"),
    Result = lists:flatten(erldn:to_string(Parsed)),
    ?assertEqual("10", Result).

% Test rational formatting edge cases
rational_unit_string_test() ->
    {ok, Parsed} = erldn:parse_str("1/1"),
    Result = lists:flatten(erldn:to_string(Parsed)),
    ?assertEqual("1/1", Result).

rational_in_collection_string_test() ->
    Input = {vector, [{rational, 22, 7}, 255]},
    Result = lists:flatten(erldn:to_string(Input)),
    ?assertEqual("[22/7 255]", Result).
```

#### 6.4 Erlang Conversion Tests (`test/erldn_numeric_erlang_test.erl`)

```erlang
-module(erldn_numeric_erlang_test).
-include_lib("eunit/include/eunit.hrl").

% Test numeric conversions to Erlang
hex_to_erlang_test() ->
    {ok, Parsed} = erldn:parse_str("0xFF"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual(255, Result).

octal_to_erlang_test() ->
    {ok, Parsed} = erldn:parse_str("0777"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual(511, Result).

radix_to_erlang_test() ->
    {ok, Parsed} = erldn:parse_str("36rZZ"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual(1295, Result).

rational_to_erlang_test() ->
    {ok, Parsed} = erldn:parse_str("22/7"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual({rational, 22, 7}, Result).

% Test negative numbers
negative_hex_to_erlang_test() ->
    {ok, Parsed} = erldn:parse_str("-0xFF"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual(-255, Result).

negative_rational_to_erlang_test() ->
    {ok, Parsed} = erldn:parse_str("-22/7"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual({rational, -22, 7}, Result).

% Test collections with mixed numeric types
mixed_numbers_collection_test() ->
    {ok, Parsed} = erldn:parse_str("[0xFF 0777 2r1010 22/7]"),
    Result = erldn:to_erlang(Parsed),
    ?assertEqual([255, 511, 10, {rational, 22, 7}], Result).
```

#### 6.5 Error Handling Tests (`test/erldn_numeric_error_test.erl`)

```erlang
-module(erldn_numeric_error_test).
-include_lib("eunit/include/eunit.hrl").

% Test invalid numeric formats cause appropriate errors
invalid_hex_test() ->
    Result = erldn:parse_str("0xGG"),
    ?assertMatch({error, _, _}, Result).

invalid_octal_test() ->
    Result = erldn:parse_str("0899"),
    ?assertMatch({error, _, _}, Result).

invalid_radix_base_test() ->
    Result = erldn:parse_str("37rABC"),
    ?assertMatch({error, _, _}, Result).

invalid_radix_digits_test() ->
    Result = erldn:parse_str("2r123"),
    ?assertMatch({error, _, _}, Result).

zero_denominator_rational_test() ->
    Result = erldn:parse_str("22/0"),
    ?assertMatch({error, _, _}, Result).

malformed_rational_test() ->
    Result = erldn:parse_str("22//7"),
    ?assertMatch({error, _, _}, Result).
```

#### 6.6 Integration Tests (`test/erldn_numeric_integration_test.erl`)

```erlang
-module(erldn_numeric_integration_test).
-include_lib("eunit/include/eunit.hrl").

% Test parsing files with new numeric formats
numeric_formats_file_test() ->
    FilePath = filename:join([code:priv_dir(erldn), "edn", "numeric-formats.edn"]),
    Result = erldn:parse_file(FilePath),
    ?assertMatch({ok, _}, Result),
    
    {ok, Data} = Result,
    ?assert(length(Data) > 0),
    
    % Verify we have different numeric types
    ?assert(lists:any(fun is_integer/1, Data)),
    ?assert(lists:any(fun(X) -> element(1, X) =:= rational end, Data)).

% Test that existing numbers.edn still works and rationals are now numbers
existing_numbers_file_test() ->
    FilePath = filename:join([code:priv_dir(erldn), "edn", "numbers.edn"]),
    {ok, Data} = erldn:parse_file(FilePath),
    
    % Find rational numbers in the data
    Rationals = [X || X <- Data, 
                      is_tuple(X) andalso 
                      tuple_size(X) =:= 3 andalso 
                      element(1, X) =:= rational],
    
    ?assert(length(Rationals) > 0),
    
    % Verify they parse as rationals, not symbols
    ?assertNotMatch([{symbol, _} | _], Rationals).

% Performance test - ensure new parsing doesn't significantly slow things down
numeric_performance_test() ->
    % Create test data with mixed formats
    TestData = string:join([
        "123", "0xFF", "0777", "2r1010", "22/7",
        "456", "0x1A2B", "0123", "8r777", "355/113"
    ] ++ [integer_to_list(N) || N <- lists:seq(1, 100)], " "),
    
    % Time the parsing
    {Time, {ok, Result}} = timer:tc(fun() -> erldn:parse_str(TestData) end),
    
    % Should parse successfully
    ?assert(length(Result) > 100),
    
    % Should complete in reasonable time (< 1 second for this small test)
    ?assert(Time < 1000000). % microseconds
```

### 7. Update Documentation

#### 7.1 Update README.md

##### Add to Features Table

```markdown
| EDN Feature | Supported | Erlang Representation |
|-------------|-----------|---------------------|
| Integers | ✅ | `integer()` |
| Floats | ✅ | `float()` |
| Hexadecimal | ✅ | `integer()` |
| Octal | ✅ | `integer()` |  
| Arbitrary Radix | ✅ | `integer()` |
| Rational Numbers | ✅ | `{rational, integer(), integer()}` |
| Arbitrary Precision | ✅ | `integer()` (M suffix), `float()` (N suffix) |
```

##### Add Numeric Formats Section

```markdown
## Numeric Formats

The library supports all EDN numeric formats:

### Basic Numbers
```erlang
{ok, Data} = erldn:parse_str("42 -17 3.14 -2.71e-3"),
% Data = [42, -17, 3.14, -0.002713]
```

### Hexadecimal Numbers
```erlang
{ok, Data} = erldn:parse_str("0xFF 0x1A2B -0x123"),
% Data = [255, 6699, -291]
```

### Octal Numbers  
```erlang
{ok, Data} = erldn:parse_str("0777 0123 -0456"),
% Data = [511, 83, -302]
```

### Arbitrary Radix Numbers
```erlang
{ok, Data} = erldn:parse_str("2r1010 8r777 16rFF 36rZZ"),
% Data = [10, 511, 255, 1295]
```

### Rational Numbers
```erlang
{ok, Data} = erldn:parse_str("22/7 -3/4 355/113"),
% Data = [{rational, 22, 7}, {rational, -3, 4}, {rational, 355, 113}]

% Convert rationals to floats if needed
Floats = [N/D || {rational, N, D} <- Data],
% Floats = [3.142857..., -0.75, 3.141592...]
```

### Arbitrary Precision
```erlang
{ok, Data} = erldn:parse_str("123456789012345678901234567890N 3.141592653589793238462643383279M"),
% Large integers and high-precision floats
```
```

##### Remove Limitation Notes

Search for and remove any mentions like:
- "hexadecimal numbers are not supported"
- "octal format not implemented" 
- "arbitrary radix parsing TODO"
- Any other references to these formats being unsupported

#### 7.2 Add Usage Examples

Add a new section showing practical examples:

```markdown
## Numeric Format Examples

### Mathematical Constants
```erlang
% Pi approximations
{ok, [Pi1, Pi2]} = erldn:parse_str("22/7 355/113"),
% Pi1 = {rational, 22, 7}     (3.142857...)
% Pi2 = {rational, 355, 113}  (3.141592...)

% Convert to float for calculations
PiFloat = 355/113,  % 3.141592920353982
```

### Color Values  
```erlang
% RGB color values in hex
{ok, [Red, Green, Blue]} = erldn:parse_str("0xFF 0x80 0x00"),
% Red = 255, Green = 128, Blue = 0

% Or using rationals for percentages  
{ok, [R, G, B]} = erldn:parse_str("255/255 128/255 0/255"),
% R = {rational, 255, 255}, G = {rational, 128, 255}, B = {rational, 0, 255}
```

### File Permissions (Octal)
```erlang
{ok, [Perms]} = erldn:parse_str("0755"),
% Perms = 493 (rwxr-xr-x)
```

### Binary Data
```erlang  
{ok, [Byte1, Byte2]} = erldn:parse_str("2r11110000 8r360"),
% Byte1 = 240, Byte2 = 240 (same value in binary and octal)
```
```

### 8. Code Quality and Validation

#### 8.1 Run Code Formatting

After implementing all changes, run:

```bash
rebar3 fmt
```

This will format the code according to Erlang standards.

#### 8.2 Run Static Analysis

Run the following to check for issues:

```bash
rebar3 check
```

This runs various checks including:
- Dialyzer (type analysis)
- Elvis (style checking)  
- Xref (cross-reference analysis)

Fix any warnings or errors that are reported.

#### 8.3 Run Tests

Verify all tests pass:

```bash
rebar3 eunit
```

Ensure 100% test coverage by running:

```bash
rebar3 cover
```

Check the coverage report to verify all new code paths are tested.

### 9. Implementation Checklist

#### Core Implementation
- [ ] Add numeric patterns to lexer definitions
- [ ] Add parsing rules to lexer (BEFORE existing number rules)
- [ ] Implement parsing functions (hex, octal, radix, rational)
- [ ] Add terminals to parser grammar
- [ ] Add value rules to parser
- [ ] Update string conversion for rationals
- [ ] Update Erlang conversion for rationals

#### Test Implementation  
- [ ] Create comprehensive test data files
- [ ] Add lexer tests for all numeric formats
- [ ] Add parser tests for all numeric formats  
- [ ] Add string conversion tests
- [ ] Add Erlang conversion tests
- [ ] Add error handling tests
- [ ] Add integration tests
- [ ] Add performance tests

#### Documentation
- [ ] Update README feature table
- [ ] Add numeric formats section with examples
- [ ] Remove any limitation notes
- [ ] Add practical usage examples

#### Quality Assurance
- [ ] Run `rebar3 fmt` 
- [ ] Run `rebar3 check` and fix issues
- [ ] Run `rebar3 eunit` - all tests pass
- [ ] Run `rebar3 cover` - 100% coverage achieved
- [ ] Test with existing EDN files still work
- [ ] Verify no performance regression

### 10. Common Pitfalls

1. **Rule Precedence**: New numeric rules MUST come before existing number/symbol rules
2. **Radix Validation**: Ensure radix is 2-36 and digits are valid for that base
3. **Zero Denominator**: Rationals with zero denominator should error gracefully
4. **Sign Handling**: All formats support optional +/- signs
5. **Case Sensitivity**: Hex supports both 0x and 0X, radix supports both r and R
6. **Symbol Conflicts**: Ensure rationals don't get parsed as symbols anymore
7. **Performance**: Test that new parsing doesn't significantly slow down the lexer
8. **String Conversion**: Only rationals maintain their original format; others convert to decimal

### 11. Advanced Considerations

#### Rational Number Operations
Consider providing utility functions for working with rationals:

```erlang
% Helper functions for rational arithmetic
add_rationals({rational, N1, D1}, {rational, N2, D2}) ->
    {rational, N1*D2 + N2*D1, D1*D2}.

simplify_rational({rational, N, D}) ->
    GCD = gcd(abs(N), abs(D)),
    {rational, N div GCD, D div GCD}.
```

#### Configuration Options
Consider adding options to control numeric parsing:

```erlang
% Parse with options
erldn:parse_str("22/7", [{rationals_as_floats, true}]).
% Returns 3.142857... instead of {rational, 22, 7}
```

This implementation will provide complete support for all EDN numeric formats while maintaining backward compatibility and performance.