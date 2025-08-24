# Complete Test Coverage Implementation Guide for erldn

## Overview

The current test coverage for the `erldn` module is at 89%. This guide provides detailed instructions to implement tests that will bring coverage to 100% by targeting the specific uncovered lines identified in the coverage reports.

## Missing Coverage Analysis

Based on the coverage reports, the following lines are not covered by tests:

### Core Multi-Value File Functions (Lines 56, 62-71, 82)
- `parse_multi_file/1` function is completely untested
- Error handling in `parse_multi_str/1` lexer error path

### String Escaping (Line 174)
- Tab character escaping in `map_escaped_char/1`

## Required Test Implementations

### 1. Multi-Value File Parsing Tests

Create a new test module `test/erldn_multi_value_file_tests.erl` with the following test cases:

```erlang
-module(erldn_multi_value_file_tests).
-include_lib("eunit/include/eunit.hrl").

%% Test parse_multi_file/1 with valid .edn file
parse_multi_file_success_test() ->
    % Create a temporary .edn file with multiple values
    TempFile = "temp_multi_test.edn",
    Content = "42\n\"hello\"\ntrue\n:keyword",
    file:write_file(TempFile, Content),
    
    % Test the function
    Result = erldn:parse_multi_file(TempFile),
    file:delete(TempFile),
    
    ?assertMatch({ok, [42, <<"hello">>, true, keyword]}, Result).

%% Test parse_multi_file/1 with file read error
parse_multi_file_read_error_test() ->
    % Try to parse a non-existent file
    Result = erldn:parse_multi_file("nonexistent_multi.edn"),
    ?assertMatch({error, {file_error, enoent}}, Result).

%% Test parse_multi_file/1 with wrong extension
parse_multi_file_wrong_extension_test() ->
    % Create temp file with wrong extension
    TempFile = "temp_multi_test.txt",
    file:write_file(TempFile, "42"),
    
    Result = erldn:parse_multi_file(TempFile),
    file:delete(TempFile),
    
    ?assertMatch({error, {invalid_extension, ".txt"}}, Result).

%% Test parse_multi/1 with filename that exists (triggers parse_multi_file)
parse_multi_with_existing_file_test() ->
    % Create a temporary .edn file
    TempFile = "temp_parse_multi.edn",
    Content = "1 2 3",
    file:write_file(TempFile, Content),
    
    % This should call parse_multi_file internally
    Result = erldn:parse_multi(TempFile),
    file:delete(TempFile),
    
    ?assertMatch({ok, [1, 2, 3]}, Result).
```

### 2. Lexer Error Handling Tests

Add to existing test module or create `test/erldn_lexer_error_tests.erl`:

```erlang
-module(erldn_lexer_error_tests).
-include_lib("eunit/include/eunit.hrl").

%% Test lexer error handling in parse_multi_str/1
parse_multi_str_lexer_error_test() ->
    % Create input that causes lexer error
    % Note: Finding actual lexer error cases requires examining erldn_lexer
    % This might be malformed string literals or invalid character sequences
    InvalidInput = "\"unclosed string",
    
    Result = erldn:parse_multi_str(InvalidInput),
    
    % Should return the lexer error directly
    ?assertMatch({error, _}, Result).

%% Alternative approach: Use mocking to force lexer error
parse_multi_str_forced_lexer_error_test() ->
    % This test might require mocking erldn_lexer:string/1 to return an error
    % If mocking is not available, try to find actual lexer error cases
    
    % Example of potentially problematic input:
    BadInputs = [
        "\"unterminated string",
        "\\invalid_char_escape",
        "#invalid_tag_format",
        "#{unclosed set"
    ],
    
    % Test each and expect at least one to trigger lexer error path
    lists:foreach(fun(Input) ->
        Result = erldn:parse_multi_str(Input),
        % Accept either parser error or lexer error
        ?assert(case Result of
            {error, _, _} -> true;  % Parser error
            {error, _} -> true;     % Lexer error
            _ -> false
        end)
    end, BadInputs).
```

### 3. String Escaping Completeness Tests

Add to existing `test/erldn_tests.erl` or create specific escaping tests:

```erlang
%% Test tab character escaping (covers line 174)
string_with_tab_escaping_test() ->
    % Create string containing tab character
    StringWithTab = <<"hello\tworld">>,
    Result = erldn:to_string(StringWithTab),
    Expected = "\"hello\\tworld\"",
    ?assertEqual(Expected, lists:flatten(Result)).

%% Test all escape characters comprehensively
comprehensive_string_escaping_test() ->
    % Test string with all escapable characters
    StringWithEscapes = <<"hello\n\r\t\"\\world">>,
    Result = erldn:to_string(StringWithEscapes),
    Expected = "\"hello\\n\\r\\t\\\"\\\\world\"",
    ?assertEqual(Expected, lists:flatten(Result)).

%% Test individual escape characters
individual_escape_chars_test() ->
    Escapes = [
        {<<"\n">>, "\"\\n\""},     % newline - already covered
        {<<"\r">>, "\"\\r\""},     % carriage return - already covered  
        {<<"\t">>, "\"\\t\""},     % tab - THIS COVERS LINE 174
        {<<"\"">>, "\"\\\"\""},    % quote - already covered
        {<<"\\">>, "\"\\\\\""}     % backslash - already covered
    ],
    
    lists:foreach(fun({Input, Expected}) ->
        Result = lists:flatten(erldn:to_string(Input)),
        ?assertEqual(Expected, Result)
    end, Escapes).
```

### 4. Integration Tests for Complete Coverage

Create `test/erldn_integration_coverage_tests.erl`:

```erlang
-module(erldn_integration_coverage_tests).
-include_lib("eunit/include/eunit.hrl").

%% Comprehensive test covering multiple code paths
comprehensive_multi_value_workflow_test() ->
    % Test the complete workflow: file creation -> multi parsing -> validation
    TestData = [
        42,
        <<"test string with\ttab">>,  % This ensures tab escaping is tested
        true,
        false,
        nil,
        keyword,
        {vector, [1, 2, 3]},
        {set, [a, b, c]},
        {map, [{key, value}]}
    ],
    
    % Create temporary file
    TempFile = "comprehensive_test.edn",
    
    % Convert test data to EDN strings and write to file
    EdnStrings = [lists:flatten(erldn:to_string(Item)) || Item <- TestData],
    Content = string:join(EdnStrings, "\n"),
    file:write_file(TempFile, Content),
    
    % Test multi-file parsing
    {ok, ParsedData} = erldn:parse_multi_file(TempFile),
    
    % Clean up
    file:delete(TempFile),
    
    % Validate results
    ?assertEqual(length(TestData), length(ParsedData)),
    
    % Test that tab character was properly handled in string
    StringItem = lists:nth(2, ParsedData),
    ?assertMatch(<<_/binary>>, StringItem),
    ?assert(binary:match(StringItem, <<"\t">>) =/= nomatch).

%% Test error propagation through all layers
error_propagation_test() ->
    % Test that errors propagate correctly through the call chain
    
    % 1. Test file error propagation
    ?assertMatch({error, {file_error, _}}, 
                 erldn:parse_multi_file("nonexistent.edn")),
    
    % 2. Test extension error propagation  
    TempFile = "test.wrong",
    file:write_file(TempFile, "data"),
    ?assertMatch({error, {invalid_extension, ".wrong"}}, 
                 erldn:parse_multi_file(TempFile)),
    file:delete(TempFile),
    
    % 3. Test parse error propagation
    ?assertMatch({error, _, _}, 
                 erldn:parse_multi_str("{")),  % Unclosed map
                 
    % 4. Test that parse_multi correctly handles both cases
    ?assertMatch({ok, [42]}, erldn:parse_multi("42")),
    ?assertMatch({ok, [1,2]}, erldn:parse_multi("1 2")).
```

### 5. Edge Cases and Boundary Tests

Add these tests to ensure robustness:

```erlang
%% Test empty multi-value parsing
empty_multi_value_test() ->
    ?assertMatch({ok, []}, erldn:parse_multi_str("")).

%% Test whitespace-only multi-value parsing  
whitespace_only_multi_value_test() ->
    ?assertMatch({ok, []}, erldn:parse_multi_str("   \n\t  ")).

%% Test comments-only multi-value parsing
comments_only_multi_value_test() ->
    ?assertMatch({ok, []}, erldn:parse_multi_str("; just a comment\n")).

%% Test mixed whitespace and comments
mixed_whitespace_comments_test() ->
    Input = "  ; comment 1\n  ; comment 2\n  ",
    ?assertMatch({ok, []}, erldn:parse_multi_str(Input)).
```

## Implementation Strategy

### Phase 1: Core Missing Coverage
1. **Implement multi-value file parsing tests** (lines 56, 62-71)
   - Create temporary .edn files for testing
   - Test success and error cases
   - Verify file cleanup in all cases

2. **Implement lexer error handling test** (line 82)
   - Find input that triggers lexer errors
   - Test error propagation through `parse_multi_str/1`

### Phase 2: String Escaping Coverage  
3. **Implement tab character escaping test** (line 174)
   - Create strings with tab characters
   - Verify proper escaping with `\t`
   - Test through `to_string/1` function

### Phase 3: Integration and Edge Cases
4. **Comprehensive integration tests**
   - Test complete workflows
   - Verify error propagation
   - Test boundary conditions

### Phase 4: Validation
5. **Run coverage analysis**
   - Execute `rebar3 cover` or equivalent
   - Verify 100% coverage achieved
   - Fix any remaining gaps

## Special Considerations

### File Handling
- Always clean up temporary files in test teardown
- Use unique filenames to avoid conflicts
- Handle file permission issues gracefully

### Error Testing
- Test both expected errors and unexpected edge cases
- Verify error message formats match expectations
- Ensure error propagation maintains original error information

### String Testing
- Test all escape sequences, especially tab (`\t`)
- Verify both single and multiple character escaping
- Test edge cases like empty strings and strings with only escape chars

### Multi-Value Testing
- Test empty inputs
- Test single values vs multiple values
- Test mixed data types
- Test deeply nested structures in multi-value context

## Expected Outcome

After implementing these tests:
- Coverage should reach 100%
- All code paths will be exercised
- Error handling will be thoroughly tested
- The multi-value parsing feature will be fully validated
- String escaping edge cases will be covered

## Test Execution

Run the tests with:
```bash
rebar3 eunit
rebar3 cover
```

The coverage report should show 100% line coverage for the `erldn` module, with all previously missed lines now covered by the new test cases.