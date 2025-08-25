# Implementation Guide: EDN Special Numerical Values Support

## Overview

This document provides detailed instructions for implementing support for EDN's special numerical values (`##Inf`, `##-Inf`, and `##NaN`) in the erldn library. Currently, these values are not supported and cause parse errors.

## Background

EDN (Extensible Data Notation) defines three special numerical values:
- `##Inf` - Positive infinity
- `##-Inf` - Negative infinity  
- `##NaN` - Not a Number

These values should be parsed as tagged literals and converted to appropriate Erlang representations.

## Implementation Steps

### 1. Update the Lexer (`src/erldn_lexer.xrl`)

Add lexer rules to recognize the special numerical patterns:

```erlang
% Add to Definitions section:
InfPos      = ##Inf
InfNeg      = ##-Inf  
NaN         = ##NaN

% Add to Rules section:
{InfPos}                 : make_token(inf_pos, TokenLine, TokenChars).
{InfNeg}                 : make_token(inf_neg, TokenLine, TokenChars).
{NaN}                    : make_token(nan, TokenLine, TokenChars).
```

**Important Notes:**
- Place these rules BEFORE the general `{Sharp}` rule to ensure proper matching
- The lexer uses `##` as the prefix for these special values
- Each rule should generate a distinct token type for the parser

### 2. Update the Parser (`src/erldn_parser.yrl`)

Add the new tokens to the parser grammar:

```erlang
% Add to Terminals section:
Terminals
    float integer boolean string nil open_list close_list open_vector
    close_vector open_map close_map sharp ignore keyword symbol char
    inf_pos inf_neg nan.  % <-- Add these

% Add to value rules:
value -> inf_pos : {tag, 'inf', pos}.
value -> inf_neg : {tag, 'inf', neg}.  
value -> nan     : {tag, 'nan', nil}.
```

**Design Decisions:**
- Use tagged literals: `{tag, 'inf', pos}`, `{tag, 'inf', neg}`, `{tag, 'nan', nil}`
- This follows the existing pattern for other EDN tagged literals
- Allows for extensible handling in `to_erlang/2`

### 3. Update String Conversion (`src/erldn.erl`)

Add cases to the `to_string/2` function:

```erlang
to_string({tag, inf, pos}, Accum) ->
    ["##Inf" | Accum];
to_string({tag, inf, neg}, Accum) ->
    ["##-Inf" | Accum];
to_string({tag, nan, nil}, Accum) ->
    ["##NaN" | Accum];
```

**Important:** Add these cases BEFORE the general tagged value case to ensure proper matching.

### 4. Update Erlang Conversion (`src/erldn.erl`)

Add handlers for converting to Erlang numeric types:

```erlang
% In to_erlang/2 function, add before the general tag handler:
to_erlang({tag, inf, pos}, _Handlers) ->
    % Positive infinity as float
    1.0 / 0.0;
to_erlang({tag, inf, neg}, _Handlers) ->
    % Negative infinity as float  
    -1.0 / 0.0;
to_erlang({tag, nan, nil}, _Handlers) ->
    % NaN as float
    0.0 / 0.0;
```

**Alternative Approach:** If direct float arithmetic is problematic, consider using atoms:
```erlang
to_erlang({tag, inf, pos}, _Handlers) -> pos_infinity;
to_erlang({tag, inf, neg}, _Handlers) -> neg_infinity;
to_erlang({tag, nan, nil}, _Handlers) -> not_a_number;
```

### 5. Update Tests

#### 5.1 Re-enable Existing Tests

Look for commented-out tests in `test/erldn_parse_file_test.erl`:

```erlang
% Find and uncomment tests related to "edge-numbers.edn"
% Currently there's a special case that expects these to fail:
case Filename of
    % Remove or modify this case
    "edge-numbers.edn" -> ok;  % <-- Update this
    _ -> ?assert(false)
end
```

#### 5.2 Add Comprehensive Lexer Tests

Create `test/erldn_special_numbers_lexer_test.erl`:

```erlang
-module(erldn_special_numbers_lexer_test).
-include_lib("eunit/include/eunit.hrl").

check_lex(Str, Expected) ->
    {ok, [Result], _} = erldn:lex_str(Str),
    ?assertEqual(Expected, Result).

positive_infinity_test() -> 
    check_lex("##Inf", {inf_pos, 1, '##Inf'}).

negative_infinity_test() -> 
    check_lex("##-Inf", {inf_neg, 1, '##-Inf'}).

nan_test() -> 
    check_lex("##NaN", {nan, 1, '##NaN'}).

% Test in context
infinity_in_vector_test() ->
    {ok, Tokens, _} = erldn:lex_str("[##Inf ##-Inf ##NaN]"),
    ExpectedTypes = [open_vector, inf_pos, inf_neg, nan, close_vector],
    ActualTypes = [element(1, T) || T <- Tokens],
    ?assertEqual(ExpectedTypes, ActualTypes).
```

#### 5.3 Add Parser Tests

Create `test/erldn_special_numbers_parser_test.erl`:

```erlang
-module(erldn_special_numbers_parser_test).
-include_lib("eunit/include/eunit.hrl").

check_parse(Str, Expected) ->
    {ok, Result} = erldn:parse_str(Str),
    ?assertEqual(Expected, Result).

positive_infinity_parse_test() ->
    check_parse("##Inf", {tag, inf, pos}).

negative_infinity_parse_test() ->
    check_parse("##-Inf", {tag, inf, neg}).

nan_parse_test() ->
    check_parse("##NaN", {tag, nan, nil}).

% Test in collections
infinity_in_vector_parse_test() ->
    check_parse("[##Inf ##-Inf ##NaN]", 
                {vector, [{tag, inf, pos}, {tag, inf, neg}, {tag, nan, nil}]}).

infinity_in_map_parse_test() ->
    check_parse("{:inf ##Inf :neg-inf ##-Inf :nan ##NaN}",
                {map, [{inf, {tag, inf, pos}}, 
                       {'neg-inf', {tag, inf, neg}}, 
                       {nan, {tag, nan, nil}}]}).
```

#### 5.4 Add Round-Trip Tests

```erlang
round_trip_infinity_test() ->
    Values = [{tag, inf, pos}, {tag, inf, neg}, {tag, nan, nil}],
    lists:foreach(fun(Value) ->
        EdnStr = lists:flatten(erldn:to_string(Value)),
        {ok, Parsed} = erldn:parse_str(EdnStr),
        ?assertEqual(Value, Parsed)
    end, Values).
```

#### 5.5 Add Erlang Conversion Tests

```erlang
-module(erldn_special_numbers_erlang_test).
-include_lib("eunit/include/eunit.hrl").

erlang_conversion_test() ->
    % Test conversion to Erlang floats
    PosInf = erldn:to_erlang({tag, inf, pos}),
    NegInf = erldn:to_erlang({tag, inf, neg}),
    NaN = erldn:to_erlang({tag, nan, nil}),
    
    % Verify they are the expected special float values
    ?assert(PosInf > 0),
    ?assert(is_float(PosInf)),
    ?assert(NegInf < 0), 
    ?assert(is_float(NegInf)),
    ?assert(is_float(NaN)),
    
    % NaN comparison always fails
    ?assertNot(NaN == NaN),
    ?assert(PosInf > NegInf).
```

### 6. Update Documentation

#### 6.1 Update README.md

Find the EDN type mapping tables and add:

```markdown
| EDN | Erlang |
|-----|--------|
| ##Inf | positive infinity (float) |
| ##-Inf | negative infinity (float) |
| ##NaN | NaN (float) |
```

#### 6.2 Remove Limitation Notes

Search for and remove/update any mentions of:
- "does not support ##Inf, ##-Inf, ##NaN"
- Comments about these values being unsupported
- Any TODOs referencing these features

## Testing Strategy

### Comprehensive Test Coverage

1. **Lexer Level**: Verify tokens are generated correctly
2. **Parser Level**: Verify AST structure is correct
3. **String Conversion**: Verify round-trip string conversion
4. **Erlang Conversion**: Verify conversion to appropriate Erlang values
5. **File Parsing**: Test with actual EDN files containing these values
6. **Edge Cases**: Test in various contexts (vectors, maps, nested structures)

### Test Files to Create/Update

1. `test/erldn_special_numbers_lexer_test.erl` - Lexer-specific tests
2. `test/erldn_special_numbers_parser_test.erl` - Parser-specific tests  
3. `test/erldn_special_numbers_erlang_test.erl` - Erlang conversion tests
4. `test/erldn_special_numbers_integration_test.erl` - End-to-end tests
5. Update `test/erldn_parse_file_test.erl` - Remove special case for edge-numbers.edn

### Sample Test Data

Create test files in `priv/edn/`:

```edn
// special-numbers.edn
##Inf
##-Inf  
##NaN
[##Inf ##-Inf ##NaN]
{:positive ##Inf :negative ##-Inf :not-a-number ##NaN}
```

## Implementation Notes

### Error Handling
- Ensure lexer errors are meaningful if malformed input is provided
- Consider partial matches like `##In` or `##Na` - should these be symbols?

### Performance Considerations
- The new lexer rules should be positioned to minimize backtracking
- Consider the impact on parsing performance for regular numeric literals

### Backward Compatibility
- This is a pure addition - no breaking changes to existing functionality
- Existing code that doesn't use these values should be unaffected

### Alternative Representations

If direct float arithmetic for infinity/NaN is problematic in your environment, consider:

```erlang
% Atom-based approach
to_erlang({tag, inf, pos}, _Handlers) -> positive_infinity;
to_erlang({tag, inf, neg}, _Handlers) -> negative_infinity;  
to_erlang({tag, nan, nil}, _Handlers) -> not_a_number;

% Record-based approach  
-record(special_float, {type :: inf_pos | inf_neg | nan}).
to_erlang({tag, inf, pos}, _Handlers) -> #special_float{type = inf_pos};
```

Choose the approach that best fits your application's needs for handling these special values.

## Validation Checklist

- [ ] Lexer recognizes `##Inf`, `##-Inf`, `##NaN`
- [ ] Parser creates appropriate tagged literal AST nodes
- [ ] String conversion produces correct EDN representation
- [ ] Erlang conversion produces appropriate values
- [ ] Round-trip conversion works (parse → stringify → parse)
- [ ] Tests pass for all edge cases
- [ ] File parsing works with existing EDN files containing these values
- [ ] Documentation updated
- [ ] No regressions in existing functionality

## Common Pitfalls

1. **Lexer Rule Ordering**: Ensure special number rules come before general `{Sharp}` rule
2. **Case Sensitivity**: EDN spec requires exact case: `##Inf`, `##-Inf`, `##NaN`
3. **Pattern Matching**: In `to_string/2`, specific patterns must come before general tag pattern
4. **Float Arithmetic**: Direct division by zero might not work in all Erlang contexts
5. **Test Organization**: Group tests logically and ensure good coverage of edge cases

This implementation should provide complete support for EDN special numerical values while maintaining backward compatibility and following the existing code patterns in the erldn library.