# V Compiler Segfault with Nested Sum Types and -O3 Optimization

## Summary

When using complex nested sum types with the `-prod` flag (which enables `-O3`), the V compiler generates code that causes a segmentation fault on Linux x86_64. The same code runs correctly:
- On macOS with `-prod`
- On Linux with debug builds (no optimization)
- On Linux with `-O2` (but NOT `-O3`)

## Reproduction

The bug can be reproduced using the [al](https://github.com/alii/al) programming language compiler:

```bash
git clone https://github.com/alii/al
cd al

# Build with -prod (triggers segfault on Linux x86_64)
v -prod -o al .

# Run any program
./al run program/src/all_language_features.al
# Result: signal 11: segmentation fault (exit code 139)
```

### Workaround

Using `-O2` instead of `-prod` fixes the issue:

```bash
v -cc gcc -cflags "-O2" -o al .
./al run program/src/all_language_features.al
# Works correctly
```

## Environment

- **Failing**: Linux x86_64 (tested on Ubuntu latest in GitHub Actions)
- **Working**: macOS ARM64, Linux x86_64 with `-O2` or debug build
- **V Version**: Latest (tested December 2024)
- **GCC**: Default on Ubuntu

## Key Code Patterns

The codebase uses nested sum types with mutual recursion. Specifically:

### Statement sum type with recursive member
```v
pub struct ExportDeclaration {
pub:
    declaration Statement  // Contains Statement (recursive)
    span        Span @[required]
}

pub type Statement = ConstBinding
    | EnumDeclaration
    | ExportDeclaration  // Contains Statement
    | FunctionDeclaration
    | ImportDeclaration
    | StructDeclaration
    | TypePatternBinding
    | VariableBinding
```

### Expression sum type (27 variants)
```v
pub type Expression = ArrayExpression
    | ArrayIndexExpression
    | AssertExpression
    | BinaryExpression
    | BlockExpression  // Contains []BlockItem
    | BooleanLiteral
    | ErrorExpression
    | ErrorNode
    | FunctionCallExpression
    | FunctionExpression
    | Identifier
    | IfExpression
    | InterpolatedString
    | MatchExpression
    | NoneExpression
    | NumberLiteral
    | OrExpression
    | OrPattern
    | PropertyAccessExpression
    | PropagateNoneExpression
    | RangeExpression
    | SpreadExpression
    | StringLiteral
    | StructInitExpression
    | TypeIdentifier
    | UnaryExpression
    | WildcardPattern
```

### BlockItem that bridges Statement and Expression
```v
pub struct BlockItem {
pub:
    is_statement bool
    statement    Statement
    expression   Expression
}

pub struct BlockExpression {
pub:
    body []BlockItem
    span Span @[required]
}
```

## Code that iterates over BlockItems

The compiler and type checker iterate over BlockItems and dispatch based on `is_statement`:

```v
fn (mut c Compiler) compile_expr(expr typed_ast.Expression) ! {
    match expr {
        typed_ast.BlockExpression {
            last_idx := expr.body.len - 1
            for i, item in expr.body {
                is_last := i == last_idx
                if item.is_statement {
                    c.compile_statement(item.statement)!
                } else {
                    c.compile_expr(item.expression)!
                }
                // ...
            }
        }
        // ...
    }
}
```

## Analysis

The bug appears to be triggered by GCC's `-O3` optimization on the generated C code. The combination of:
1. Nested/recursive sum types
2. Large sum types (27+ variants)
3. Struct containing both Statement and Expression fields
4. Iteration patterns with conditional dispatch

seems to cause incorrect code generation at `-O3` optimization level.

## CI Workaround

The project's CI now uses platform-specific build commands:

```yaml
- name: Build (Production)
  run: |
    if [ "${{ matrix.platform }}" = "linux" ]; then
      v -cc gcc -cflags "-O2" -o al .
    else
      v -prod -o al .
    fi
```

## Related Files

- `src/typed_ast/typed_ast.v` - Sum type definitions
- `src/bytecode/compiler.v` - Code that triggers the bug
- `src/types/checker.v` - Also walks the AST similarly
