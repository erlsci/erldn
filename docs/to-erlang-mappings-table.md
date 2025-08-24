# To Erlang Transformation Mappings

This table shows how the parsed EDN data structures are transformed by `erldn:to_erlang/1` and `erldn:to_erlang/2` into more Erlang-idiomatic representations. These transformations make the data easier to work with in Erlang but cannot be directly converted back to EDN without additional type information.

| Parsed Representation | Erlang-Friendly Result | Example Transformation |
|----------------------|----------------------|----------------------|
| `nil` | `nil` | `nil` → `nil` |
| `true` | `true` | `true` → `true` |
| `false` | `false` | `false` → `false` |
| `42` | `42` | `42` → `42` |
| `3.14` | `3.14` | `3.14` → `3.14` |
| `{char, 99}` | `"c"` | `{char, 99}` → `"c"` |
| `<<"hello">>` | `<<"hello">>` | `<<"hello">>` → `<<"hello">>` |
| `foo` (keyword) | `foo` | `foo` → `foo` |
| `{keyword, nil}` | `nil` | `{keyword, nil}` → `nil` |
| `{symbol, foo}` | `{symbol, foo}` | `{symbol, foo}` → `{symbol, foo}` |
| `[1, 2, 3]` (list) | `[1, 2, 3]` | `[1, 2, 3]` → `[1, 2, 3]` |
| `{vector, [1, 2, 3]}` | `[1, 2, 3]` | `{vector, [1, 2, 3]}` → `[1, 2, 3]` |
| `{map, [{a, 1}, {b, 2}]}` | `dict:dict()` | `{map, [{a, 1}, {b, 2}]}` → `dict` with `a→1, b→2` |
| `{set, [1, 2, 3]}` | `sets:set()` | `{set, [1, 2, 3]}` → `sets` with `{1, 2, 3}` |
| `{tag, Symbol, Value}` | *Handler Result* | Calls registered tag handler or fails |
| `{ignore, Value}` | *Undefined* | No documented transformation |

## Tag Handler System

Tagged elements are processed using a configurable handler system:

### Default Handlers
The `to_erlang/2` function accepts handler specifications:

```erlang
Handlers = [{tag_symbol, fun(Tag, Value, OtherHandlers) -> Result end}]
erldn:to_erlang(ParsedData, Handlers)
```

### Handler Function Signature
```erlang
Handler = fun(Tag, Value, OtherHandlers) -> TransformedValue end
```

- **Tag**: The tag symbol (e.g., `'inst'`, `'uuid'`)
- **Value**: The tagged value after transformation
- **OtherHandlers**: List of other available handlers for nested processing

### Common Tag Examples

| Tag | Example Input | Typical Handler Result |
|-----|--------------|----------------------|
| `#inst` | `{tag, 'inst', <<"2024-01-01T12:00:00Z">>}` | `{datetime, {{2024,1,1}, {12,0,0}}}` |
| `#uuid` | `{tag, 'uuid', <<"550e8400-e29b-41d4-a716-446655440000">>}` | Binary UUID or custom UUID record |
| Custom tags | `{tag, 'myapp/Person', {map, [...]}}` | Application-specific data structure |

## Data Structure Transformations

### Maps → Dicts
- **Before**: `{map, [{key1, val1}, {key2, val2}]}`
- **After**: `dict:dict()` with key-value associations
- **Access**: Use `dict:fetch/2`, `dict:find/2`, etc.
- **Benefits**: O(log n) lookup, functional updates

### Sets → Sets Module
- **Before**: `{set, [elem1, elem2, elem3]}`
- **After**: `sets:set()` with unique elements
- **Access**: Use `sets:is_element/2`, `sets:to_list/1`, etc.
- **Benefits**: Automatic uniqueness, set operations

### Vectors → Lists
- **Before**: `{vector, [1, 2, 3]}`
- **After**: `[1, 2, 3]`
- **Benefits**: Simpler Erlang idiom
- **Trade-offs**: Loses type distinction from lists

### Characters → Strings
- **Before**: `{char, 65}`
- **After**: `"A"`
- **Benefits**: More natural Erlang representation
- **Note**: Single-character strings, not charlists

## Error Handling

### Unknown Tags
When `to_erlang/1` encounters a tag without a registered handler:
- **Behavior**: Raises an error
- **Solution**: Use `to_erlang/2` with appropriate handlers
- **Alternative**: Implement a catch-all default handler

### Nested Transformations
All nested values are recursively transformed:
- Map values are processed through `to_erlang`
- Set elements are processed through `to_erlang`
- List elements are processed through `to_erlang`
- Tagged values are processed *before* being passed to handlers

## Usage Patterns

### Simple Transformation
```erlang
{ok, ParsedData} = erldn:parse("{:name \"John\" :age 30}"),
ErlangData = erldn:to_erlang(ParsedData).
% ErlangData is a dict with name→<<"John">>, age→30
```

### With Custom Handlers
```erlang
Handlers = [
    {'inst', fun(Tag, DateStr, _) -> parse_iso_date(DateStr) end},
    {'uuid', fun(Tag, UuidStr, _) -> uuid:parse(UuidStr) end}
],
ErlangData = erldn:to_erlang(ParsedData, Handlers).
```

## Limitations

1. **Information Loss**: Cannot reconstruct original EDN types (vectors vs lists)
2. **Handler Dependencies**: Tagged elements require appropriate handlers
3. **Type Ambiguity**: Some transformations lose type information
4. **Discard Elements**: No clear specification for `{ignore, Value}` handling

## Best Practices

1. **Use with Tag Handlers**: Always provide handlers for expected tagged elements
2. **Document Transformations**: Keep track of which data came from EDN for debugging
3. **Test Round-trips**: Verify data integrity when relevant
4. **Handle Errors**: Account for missing tag handlers in production code
