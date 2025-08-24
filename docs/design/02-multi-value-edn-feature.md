# Multi-Value EDN Parsing Feature Implementation Guide

## Overview

The current `erldn` library can only parse EDN files containing a single top-level value. This limitation prevents it from handling EDN files with multiple consecutive top-level expressions, which is a common pattern in EDN data files, especially for configuration, data dumps, or streaming data formats.

## The Problem

### Current Limitation

The root cause of this limitation lies in the parser grammar defined in `src/erldn_parser.yrl`:

```erlang
Rootsymbol value.
```

This grammar definition means the parser expects exactly **one** top-level value and stops parsing after finding it. Any additional content in the input will either be ignored or cause a parsing error.

### Evidence from Test Files

The test file `test/erldn_parse_file_test.erl` explicitly acknowledges this limitation:

```erlang
% The result should be either {ok, _} or {error, _, _} (parsing error for multi-value files)
case Result of
    {ok, _} ->
        % Single value file parsed successfully
        ok;
    {error, _, _} ->
        % Multi-value file failed to parse as single EDN (expected)
        ok;
```

The test expects multi-value files to fail parsing, confirming the limitation.

### Impact

Several EDN files in the test data demonstrate this pattern:
- `priv/edn/hierarchical.edn` - Contains multiple expressions separated by blank lines
- `priv/edn/complex-hierarchical.edn` - Contains multiple complex nested structures
- Other test files likely contain multiple values

## The Solution

### Required Changes

To implement multi-value EDN parsing, the following components need modification:

#### 1. Parser Grammar (`src/erldn_parser.yrl`)

**Current Grammar:**
```erlang
Rootsymbol value.
```

**New Grammar:**
```erlang
Nonterminals
    values value list list_items vector set map key_value_pairs key_value_pair tagged.

Rootsymbol values.

values -> value : ['$1'].
values -> value values : ['$1'|'$2'].
```

This change:
- Introduces a new `values` nonterminal that can match one or more values
- Changes the rootsymbol from `value` to `values`
- Ensures the parser returns a list of values (even for single values)

#### 2. Main Module API (`src/erldn.erl`)

The parsing functions need to be updated to handle the new return format:

**Add new functions:**
```erlang
-export([
    lex_str/1,
    parse/1,
    parse_file/1,
    parse_str/1,
    parse_multi/1,        % New: parse multiple values
    parse_multi_str/1,    % New: parse multiple values from string
    parse_multi_file/1,   % New: parse multiple values from file
    to_string/1,
    to_erlang/1, to_erlang/2
]).
```

**Update existing functions to maintain backward compatibility:**
```erlang
parse_str(Str) ->
    case parse_multi_str(Str) of
        {ok, [SingleValue]} ->
            {ok, SingleValue};  % Single value - return as before
        {ok, MultipleValues} ->
            {ok, MultipleValues}; % Multiple values - return list
        Error ->
            Error
    end.

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
```

#### 3. Backward Compatibility

To maintain backward compatibility:
- Existing `parse_str/1`, `parse_file/1`, and `parse/1` functions should continue to work as before
- When parsing results in a single value, return it directly (not wrapped in a list)
- When parsing results in multiple values, return the list
- Add new `parse_multi_*` functions for explicit multi-value parsing

### API Design

#### New Functions

1. **`parse_multi_str/1`**
   - Always returns `{ok, [Value1, Value2, ...]}` or `{error, Reason}`
   - Explicitly designed for multi-value parsing

2. **`parse_multi_file/1`**
   - File version of `parse_multi_str/1`

3. **`parse_multi/1`**
   - Auto-detects file vs string, similar to `parse/1`

#### Modified Existing Functions

1. **`parse_str/1`**, **`parse_file/1`**, **`parse/1`**
   - For single values: return `{ok, Value}` (unchanged)
   - For multiple values: return `{ok, [Value1, Value2, ...]}` (new behavior)
   - This provides a smooth upgrade path

## Implementation Instructions

### Step 1: Update Parser Grammar

Modify `src/erldn_parser.yrl`:

1. Add `values` to the Nonterminals list
2. Change `Rootsymbol value.` to `Rootsymbol values.`
3. Add the new grammar rules:
   ```erlang
   values -> value : ['$1'].
   values -> value values : ['$1'|'$2'].
   ```

### Step 2: Update Main Module

Modify `src/erldn.erl`:

1. Add the new function exports
2. Implement `parse_multi_str/1`:
   ```erlang
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
   ```

3. Implement `parse_multi_file/1` and `parse_multi/1` following the same pattern as existing functions

4. Update existing `parse_str/1` to handle both cases:
   ```erlang
   parse_str(Str) ->
       case parse_multi_str(Str) of
           {ok, [SingleValue]} ->
               {ok, SingleValue};
           {ok, MultipleValues} ->
               {ok, MultipleValues};
           Error ->
               Error
       end.
   ```

### Step 3: Update Tests

#### Enable File Parsing Tests

Modify `test/erldn_parse_file_test.erl`:

Remove the error expectation for multi-value files:
```erlang
% Old code that expects multi-value files to fail:
case Result of
    {ok, _} ->
        % Single value file parsed successfully
        ok;
    {error, _, _} ->
        % Multi-value file failed to parse as single EDN (expected)
        ok;

% New code that expects success:
case Result of
    {ok, _} ->
        % Successfully parsed (single or multiple values)
        ok;
    {error, {file_error, _}} ->
        % File read error (unexpected)
        ?assert(false);
    {error, _, _} ->
        % Parsing error (unexpected for valid EDN)
        ?assert(false)
end
```

#### Add Multi-Value Specific Tests

Create comprehensive tests in `test/erldn_multi_value_tests.erl`:

```erlang
-module(erldn_multi_value_tests).
-include_lib("eunit/include/eunit.hrl").

% Test parsing multiple integers
multi_integers_test() ->
    Input = "1 2 3",
    {ok, Result} = erldn:parse_multi_str(Input),
    ?assertEqual([1, 2, 3], Result).

% Test parsing mixed types
mixed_types_test() ->
    Input = "42 \"hello\" true nil :keyword",
    {ok, Result} = erldn:parse_multi_str(Input),
    ?assertEqual([42, <<"hello">>, true, nil, keyword], Result).

% Test parsing complex structures
complex_structures_test() ->
    Input = "{:a 1} [1 2 3] #{4 5}",
    {ok, Result} = erldn:parse_multi_str(Input),
    Expected = [
        {map, [{a, 1}]},
        {vector, [1, 2, 3]},
        {set, [4, 5]}
    ],
    ?assertEqual(Expected, Result).

% Test single value still works
single_value_compatibility_test() ->
    Input = "42",
    {ok, Result} = erldn:parse_str(Input),
    ?assertEqual(42, Result),
    
    {ok, MultiResult} = erldn:parse_multi_str(Input),
    ?assertEqual([42], MultiResult).

% Test backward compatibility
backward_compatibility_test() ->
    % Single value should return unwrapped
    {ok, Single} = erldn:parse_str("42"),
    ?assertEqual(42, Single),
    
    % Multiple values should return wrapped
    {ok, Multiple} = erldn:parse_str("42 43"),
    ?assertEqual([42, 43], Multiple).

% Test with comments and whitespace
with_comments_test() ->
    Input = "1 ; comment\n2 ; another comment\n3",
    {ok, Result} = erldn:parse_multi_str(Input),
    ?assertEqual([1, 2, 3], Result).

% Test file parsing
file_parsing_test() ->
    % This test should now pass for multi-value files
    EdnFiles = ["hierarchical.edn", "complex-hierarchical.edn"],
    lists:foreach(fun(File) ->
        Path = filename:join([code:priv_dir(erldn), "edn", File]),
        Result = erldn:parse_multi_file(Path),
        ?assertMatch({ok, _}, Result)
    end, EdnFiles).
```

### Step 4: Update Documentation

1. Update function documentation to clarify single vs multi-value behavior
2. Add examples of multi-value parsing
3. Document the new API functions

## Testing Strategy

### Unit Tests for Multi-Value Parsing

1. **Basic Multi-Value Tests**
   - Multiple integers: `"1 2 3"`
   - Mixed types: `"42 \"hello\" true nil"`
   - Empty input: `""`
   - Whitespace handling: `"1   2    3"`

2. **Complex Structure Tests**
   - Multiple maps: `"{:a 1} {:b 2}"`
   - Multiple vectors: `"[1 2] [3 4]"`
   - Mixed structures: `"{:a 1} [2 3] #{4}"`

3. **Edge Cases**
   - Comments between values: `"1 ; comment\n2"`
   - Nested structures: `"((1)) [[2]] #{{3}}"`
   - Tagged values: `"#tag1 42 #tag2 \"hello\""`

4. **Backward Compatibility Tests**
   - Verify single-value files still return unwrapped values
   - Verify multi-value files return lists
   - Test all existing functionality still works

### Integration Tests

1. **File Parsing Tests**
   - All existing `.edn` files should parse successfully
   - Multi-value files should return lists
   - Single-value files should return single values (for backward compatibility)

2. **Performance Tests**
   - Large multi-value files
   - Deeply nested structures in multi-value context

### Regression Tests

1. Ensure all existing tests continue to pass
2. Verify `to_string/1` works with both single and multi-value results
3. Verify `to_erlang/1` works correctly with new format

## Expected Outcomes

After implementing this feature:

1. **Enhanced Capability**
   - Parse EDN files with multiple top-level expressions
   - Handle streaming EDN data
   - Process configuration files with multiple sections

2. **Backward Compatibility**
   - Existing code continues to work unchanged
   - Single-value parsing behavior preserved
   - Gradual migration path available

3. **Test Success**
   - All existing `.edn` test files parse successfully
   - File parsing tests no longer expect errors for multi-value files
   - Comprehensive test coverage for multi-value scenarios

4. **API Flexibility**
   - Choose between single-value and multi-value parsing
   - Explicit multi-value functions for new code
   - Automatic handling in existing functions

This implementation will make the `erldn` library fully compliant with EDN specification for handling multiple top-level expressions while maintaining complete backward compatibility.