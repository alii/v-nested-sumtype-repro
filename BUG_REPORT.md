# Segfault with nested sum types when using -prod (-O3) on Linux x86_64

## Description

When using complex nested sum types (recursive Statement type, large Expression sum type with 27 variants, and BlockItem struct bridging both), the V compiler generates code that causes a segmentation fault when compiled with `-prod` (which enables `-O3`) on Linux x86_64.

The same code runs correctly:
- On macOS with `-prod`
- On Linux with debug builds (no optimization)
- On Linux with `-O2` (but NOT `-O3`)

## Reproduction Steps

```bash
# Clone the project
git clone https://github.com/alii/al
cd al

# Build with -prod (triggers segfault on Linux x86_64)
v -prod -o al .

# Run any program
./al run program/src/all_language_features.al
# Result: signal 11: segmentation fault (exit code 139)
```

### Workaround that works:
```bash
v -cc gcc -cflags "-O2" -o al .
./al run program/src/all_language_features.al
# Works correctly
```

## Expected Behavior

The program should run without crashing, the same as it does:
- On macOS with `-prod`
- On Linux without `-prod`
- On Linux with `-O2`

## Current Behavior

The program crashes with:
```
signal 11: segmentation fault
                                                        | 0x564a2bbf318b | ./al(+0x7f18b)
                                                        | 0x564a2bc199a5 | ./al(+0xa59a5)
                                                        | 0x564a2bca85c8 | ./al(+0x1345c8)
                                                        | 0x564a2bcaa03a | ./al(+0x13603a)
                                                        | 0x564a2bcab7ba | ./al(+0x1377ba)
                                                        | 0x564a2bc887d9 | ./al(+0x1147d9)
                                                        | 0x564a2bbe90cb | ./al(+0x750cb)
                                                        | 0x564a2bc62669 | ./al(+0xee669)
                                                        | 0x564a2bc13680 | ./al(+0x9f680)
                                                        | 0x564a2bc1388c | ./al(+0x9f88c)
                                                        | 0x564a2bc56aff | ./al(+0xe2aff)
                                                        | 0x564a2bb802af | ./al(+0xc2af)
                                                        | 0x7f388ee2a1ca | /lib/x86_64-linux-gnu/libc.so.6(+0x2a1ca)
                                                        | 0x7f388ee2a28b | /lib/x86_64-linux-gnu/libc.so.6(__libc_start_main+0x8b)
                                                        | 0x564a2bb802e5 | ./al(+0xc2e5)
Process completed with exit code 139.
```

## V Version

Latest V (tested on weekly.2025.49-103-g1cdb0f57 and in CI with latest download)

## Environment Details

**Failing environment** (GitHub Actions ubuntu-latest):
- OS: Linux x86_64 (Ubuntu)
- Compiler: GCC (default)
- V: Latest from https://github.com/vlang/v/releases/latest/download/v_linux.zip

**Working environments**:
- macOS ARM64 with `-prod`
- Linux x86_64 with `-O2` or debug builds

## Possible Solution

This appears to be a GCC `-O3` optimization bug specific to the generated C code for nested/recursive sum types. The workaround is to use `-O2` instead of `-O3` on Linux:

```yaml
# In CI workflow:
- name: Build (Production)
  run: |
    if [ "${{ matrix.platform }}" = "linux" ]; then
      v -cc gcc -cflags "-O2" -o al .
    else
      v -prod -o al .
    fi
```

## Additional Context

### Key code patterns that may trigger this:

**Recursive Statement type:**
```v
pub struct ExportDeclaration {
pub:
    declaration Statement  // Contains Statement (recursive)
    span        Span @[required]
}

pub type Statement = ConstBinding
    | EnumDeclaration
    | ExportDeclaration  // <- recursive reference
    | FunctionDeclaration
    | ImportDeclaration
    | StructDeclaration
    | TypePatternBinding
    | VariableBinding
```

**Large Expression sum type (27 variants):**
```v
pub type Expression = ArrayExpression
    | ArrayIndexExpression
    | AssertExpression
    | BinaryExpression
    | BlockExpression
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

**BlockItem bridging both types:**
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

**Iteration pattern in compiler:**
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
            }
        }
        // 26 other cases...
    }
}
```

The full source is at: https://github.com/alii/al

Relevant files:
- `src/typed_ast/typed_ast.v` - Sum type definitions
- `src/bytecode/compiler.v` - Code that triggers the bug
- `src/types/checker.v` - Also walks the AST similarly
