# EDN to Erlang Parsing Mappings

This table shows how EDN data types are represented in Erlang after parsing with `erldn:parse/1` or `erldn:parse_str/1`. These are the "raw" parsed representations that preserve EDN semantics and can be converted back to EDN strings.

| EDN Type | EDN Example | Erlang Representation | Erlang Example |
|----------|-------------|----------------------|----------------|
| **nil** | `nil` | `nil` (atom) | `nil` |
| **boolean** | `true`, `false` | boolean atoms | `true`, `false` |
| **integer** | `42`, `-17`, `+5` | integer | `42`, `-17`, `5` |
| **integer with N suffix** | `42N` | integer (arbitrary precision marker ignored) | `42` |
| **float** | `3.14`, `1.2e5` | float | `3.14`, `120000.0` |
| **float with M suffix** | `3.14M` | float (exact precision marker ignored) | `3.14` |
| **character** | `\c`, `\A`, `\newline` | `{char, Integer}` | `{char, 99}`, `{char, 65}`, `{char, 10}` |
| **string** | `"hello world"` | binary (UTF-8) | `<<"hello world">>` |
| **keyword (simple)** | `:foo` | atom | `foo` |
| **keyword (namespaced)** | `:ns/foo` | atom | `'ns/foo'` |
| **keyword (special case)** | `:nil` | `{keyword, nil}` | `{keyword, nil}` |
| **symbol** | `foo`, `ns/bar`, `/` | `{symbol, Atom}` | `{symbol, foo}`, `{symbol, 'ns/bar'}`, `{symbol, '/'}` |
| **list** | `(1 2 3)` | list | `[1, 2, 3]` |
| **vector** | `[1 2 3]` | `{vector, List}` | `{vector, [1, 2, 3]}` |
| **map** | `{:a 1 :b 2}` | `{map, PropList}` | `{map, [{a, 1}, {b, 2}]}` |
| **set** | `#{1 2 3}` | `{set, List}` | `{set, [1, 2, 3]}` |
| **tagged element** | `#inst "2024-01-01"` | `{tag, Symbol, Value}` | `{tag, 'inst', <<"2024-01-01">>}` |
| **discard element** | `#_ 42` | `{ignore, Value}` | `{ignore, 42}` |
| **comments** | `; comment` | (ignored during parsing) | (not represented) |

## Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| **Ratios** | ❌ Not implemented | `22/7` will parse as symbol, not ratio |
| **Advanced integers** | ❌ Not implemented | `0xFF`, `0777`, `36rZ` not supported |
| **Unicode chars** | ❌ Limited | `\uNNNN` format not supported |
| **Octal chars** | ❌ Not implemented | `\oNNN` format not supported |
| **String escapes** | ⚠️ Partial | Basic escapes only |
| **Metadata** | ❌ Not implemented | `^{:meta true} value` not supported |

## Notes

1. **Keywords vs Symbols**: Keywords start with `:` and become atoms. Symbols become `{symbol, atom}` tuples to distinguish them from keywords.

2. **Namespace Handling**: Both keywords and symbols can have namespaces separated by `/`. The entire string becomes a single atom with the `/` included.

3. **Set Uniqueness**: Sets are parsed as lists and do not enforce uniqueness at parse time.

4. **Map Ordering**: Maps are represented as property lists maintaining insertion order.

5. **Character Representation**: Characters are tagged tuples containing the Unicode code point as an integer.

6. **Nil Keyword Special Case**: The keyword `:nil` is handled specially to avoid confusion with the `nil` atom.

7. **Binary Strings**: All strings are converted to UTF-8 binaries for efficient memory usage and Unicode support.

8. **Nested Structures**: All container types (lists, vectors, maps, sets) can contain any other EDN types including other containers.
