# EDN Implementation Analysis: Java vs Erlang

## Overview

This analysis compares the official Clojure Java EDN implementation against the Erlang EDN implementation, examining how well each follows the EDN specification and identifying gaps or deviations.

This analysis was performed on 23 Aug 2025. See the "Resources" section below for specifics on the documents used for this analysis.

## Key Components Analyzed

1. **EDN Specification** - The official format specification
2. **Java Implementation** - Clojure's `EdnReader.java` (official reference)
3. **Erlang Implementation** - `erldn_lexer.xrl` and `erldn_parser.yrl`

## 1. Java Implementation vs EDN Spec: Extensions Beyond Spec

The Java implementation provides several features not explicitly specified in the EDN spec:

### Meta Reader (`^`)
- **Java**: Implements metadata reading with `^` character
- **EDN Spec**: No explicit mention of metadata syntax
- **Analysis**: This is a Clojure-specific extension for attaching metadata to forms

### Ratios 
- **Java**: Supports ratio literals like `22/7` via `ratioPat` regex
- **EDN Spec**: Not mentioned in the specification  
- **Analysis**: Clojure extension for exact fractional representation

### Advanced Numeric Formats
- **Java**: Supports various integer formats (hex `0x`, octal `0`, arbitrary radix `36rZ`)
- **EDN Spec**: Only mentions basic integers and floats
- **Analysis**: Extended numeric literal support beyond spec

### Line/Column Tracking
- **Java**: Extensive line and column number tracking for error reporting
- **EDN Spec**: No requirement for position tracking
- **Analysis**: Implementation detail for better error messages

### Suppressed Reading
- **Java**: `RT.suppressRead()` mechanism for conditional parsing
- **EDN Spec**: No mention of conditional reading
- **Analysis**: Internal Clojure optimization feature

## 2. Erlang Implementation Coverage: Missing Features

The Erlang implementation has several gaps compared to the Java implementation:

### Critical Missing Features

#### Ratio Support
- **Java**: Full ratio parsing with `ratioPat` regex `([-+]?[0-9]+)/([0-9]+)`
- **Erlang**: No ratio support in lexer or parser
- **Impact**: Cannot parse valid EDN like `22/7`

#### Advanced Integer Formats  
- **Java**: Supports hex (`0xFF`), octal (`077`), arbitrary radix (`36rZ`)
- **Erlang**: Only basic decimal integers `[+-]?[0-9]+`
- **Impact**: Limited numeric literal support

#### Comprehensive Character Literals
- **Java**: Supports `\newline`, `\space`, `\tab`, `\return`, `\backspace`, `\formfeed`, Unicode `\uNNNN`, octal `\oNNN`
- **Erlang**: Only `\newline`, `\return`, `\tab`, `\space`, plus single characters
- **Impact**: Missing Unicode and octal character support

#### Tagged Element Validation
- **Java**: Validates that tags are followed by exactly one element
- **Erlang**: Basic tagged parsing but less validation
- **Impact**: May accept malformed tagged elements

#### String Escape Sequences
- **Java**: Complete escape support including `\b`, `\f`, `\uNNNN`, octal sequences
- **Erlang**: Basic string parsing, unclear escape sequence handling
- **Impact**: May not handle all valid EDN strings

### Error Handling Differences

#### EOF Handling
- **Java**: Comprehensive EOF error messages with line numbers
- **Erlang**: Basic error handling
- **Impact**: Less informative error reporting

#### Delimiter Matching
- **Java**: Specific "Unmatched delimiter" errors
- **Erlang**: Parser-level error handling
- **Impact**: May have less precise error messages

## 3. Potential Issues in Erlang Implementation

### Symbol/Keyword Pattern Issues

#### Overly Permissive Symbol Pattern
```erlang
Symbol = [\.\*\+\!\-\_\?\$%&=<>a-zA-Z0-9][\.\*\+\!\-\_\?\$%&=<>a-zA-Z0-9:#]*
```
- **Issue**: Allows `#` and `:` anywhere after first character
- **EDN Spec**: `: #` only allowed as constituents, not as first character
- **Problem**: May accept invalid symbols like `a##b` or `a::b`

#### Keyword Pattern Concerns
```erlang  
{Colon}{Symbol}{Slash}{Symbol} : make_token(keyword, TokenLine, tl(TokenChars)).
```
- **Issue**: Pattern allows keywords with multiple `/` characters
- **EDN Spec**: Only one `/` allowed in symbols/keywords
- **Problem**: May accept invalid keywords

### Set vs Map Parsing
- **Erlang**: Uses `sharp open_map` for sets
- **Issue**: Correct syntax but may not validate uniqueness requirement
- **EDN Spec**: Sets require unique elements

### Tagged Element Parsing
- **Erlang**: Basic `sharp symbol value` pattern
- **Issue**: Limited validation of tag format
- **Java**: More robust tag validation and error handling

## 4. Compliance Assessment

### EDN Spec Compliance

| Feature | Java | Erlang | Notes |
|---------|------|---------|--------|
| Basic Types | ✅ | ✅ | Both support nil, booleans, strings |
| Numbers | ✅+ | ⚠️ | Java has extensions, Erlang missing ratios |
| Collections | ✅ | ✅ | Lists, vectors, maps, sets |
| Keywords/Symbols | ✅ | ⚠️ | Erlang pattern issues |
| Characters | ✅ | ⚠️ | Erlang missing Unicode support |
| Tagged Elements | ✅ | ✅ | Both support, Java more robust |
| Comments | ✅ | ✅ | Both support `;` comments |
| Discard `#_` | ✅ | ✅ | Both support |

### Beyond Spec Features

| Feature | Java | Erlang | Compliant |
|---------|------|---------|-----------|
| Metadata `^` | ✅ | ❌ | Extension |
| Ratios | ✅ | ❌ | Extension |
| Advanced Numbers | ✅ | ❌ | Extension |
| Error Reporting | ✅ | ⚠️ | Implementation detail |

## 5. Recommendations for Erlang Implementation

### High Priority Fixes

1. **Fix Symbol Pattern**: Restrict `#` and `:` placement according to EDN spec
2. **Add Ratio Support**: Implement `numerator/denominator` parsing  
3. **Enhance Character Support**: Add Unicode `\uNNNN` and octal sequences
4. **Improve String Escapes**: Handle all standard escape sequences

### Medium Priority Improvements

1. **Better Error Messages**: Add line/column tracking
2. **Tagged Element Validation**: Ensure proper tag format validation
3. **Set Uniqueness**: Validate set element uniqueness during parsing

### Optional Extensions (Beyond Spec)

1. **Advanced Numeric Formats**: Support hex, octal, arbitrary radix integers
2. **Metadata Support**: Add `^` metadata syntax if needed for Clojure compatibility

## 6. Summary

The Java implementation extends the EDN specification with Clojure-specific features (metadata, ratios, advanced numerics) while maintaining full spec compliance. The Erlang implementation covers the core EDN features but has notable gaps in numeric support, character handling, and symbol pattern validation that could cause parsing failures with valid EDN data.

The most critical issues for the Erlang implementation are the missing ratio support and potentially incorrect symbol patterns, which could break compatibility with valid EDN content from other implementations.

## 7. Resources

* The [EDN spec](https://raw.githubusercontent.com/edn-format/edn/a51127aecd318096667ae0dafa25353ecb07c9c3/README.md), based on edits last made 8 Jan 2014
* Clojure's [EdnReader.java](https://raw.githubusercontent.com/clojure/clojure/692817a10283c98c5d57bf3515ba39cf533d7aad/src/jvm/clojure/lang/EdnReader.java), based on edits last made 7 Feb 2013
* This project's [erldn_lexer.xrl](https://raw.githubusercontent.com/erlsci/erldn/72fa6a4bad5753493b61fd4d7a2c44a62a396e7f/src/erldn_lexer.xrl), based on edits last made 25 Jul 2019
* This project's [erldn_parser.yrl](https://raw.githubusercontent.com/erlsci/erldn/72fa6a4bad5753493b61fd4d7a2c44a62a396e7f/src/erldn_parser.yrl), based on edits last made 15 Mar 2013
