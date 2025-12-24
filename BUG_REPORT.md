# Segfault with nested sum types when using -prod (-O3) on Linux x86_64

## Description

When using complex nested sum types (recursive Statement type, large Expression sum type with 27 variants, and BlockItem struct bridging both), the V compiler generates code that causes a segmentation fault when compiled with `-prod` (which enables `-O3`) on Linux x86_64.

The same code runs correctly:
- On macOS with `-prod`
- On Linux with debug builds (no optimization)
- On Linux with `-O2` (but NOT `-O3`)

## Minimal Reproduction

**Repository**: https://github.com/alii/v-nested-sumtype-repro

**CI showing the bug**: https://github.com/alii/v-nested-sumtype-repro/actions/runs/20492877691

```bash
# Clone the minimal reproduction
git clone https://github.com/alii/v-nested-sumtype-repro
cd v-nested-sumtype-repro

# Build with -prod (triggers segfault on Linux x86_64)
v -prod -o repro_prod .

# Run - crashes on Linux x86_64
./repro_prod
# Result: signal 11: segmentation fault (exit code 139)
```

The CI shows:
- **Linux x86_64**: `Run (Production)` fails with segfault
- **macOS ARM64**: All tests pass

### Workaround that works:
```bash
v -cc gcc -cflags "-O2" -o repro_o2 .
./repro_o2
# Works correctly
```

## Minimization Findings

The reproduction has been minimized to ~4000 lines across 11 V source files.

**Key finding**: The bug requires the interaction of BOTH:
1. **Parser** (creates untyped AST with Statement/Expression sum types)
2. **Type checker** (converts untyped AST to typed AST with its own Statement/Expression sum types)

Neither component alone triggers the bug:
- Parser alone: ✅ Works
- Type checker alone: ✅ Works
- Parser + Type checker: ❌ **Segfault**

This suggests the bug is related to having multiple modules with similar sum type structures interacting.

## Expected Behavior

The program should run without crashing, the same as it does:
- On macOS with `-prod`
- On Linux without `-prod`
- On Linux with `-O2`

## Current Behavior

The program crashes with:
```
Parsed AST with 25 nodes
signal 11: segmentation fault
                                                        | 0x55591aa6086b | ./repro_prod(+0x1486b)
                                                        | 0x55591aa67ab9 | ./repro_prod(+0x1bab9)
                                                        | 0x55591aab4075 | ./repro_prod(+0x68075)
                                                        | 0x55591aab56d6 | ./repro_prod(+0x696d6)
                                                        | 0x55591aa92218 | ./repro_prod(+0x46218)
                                                        | 0x55591aa4fc0f | ./repro_prod(+0x3c0f)
                                                        | 0x7fdfa442a1ca | /lib/x86_64-linux-gnu/libc.so.6(+0x2a1ca)
                                                        | 0x7fdfa442a28b | /lib/x86_64-linux-gnu/libc.so.6(__libc_start_main+0x8b)
                                                        | 0x55591aa4fc45 | ./repro_prod(+0x3c45)
Process completed with exit code 139.
```

The crash occurs during the type checker phase, after parsing successfully completes.

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

## Files in Minimal Reproduction

```
src/
├── ast/ast.v           # Untyped AST (Statement, Expression sum types)
├── typed_ast/          # Typed AST (mirrors untyped with Type info)
├── types/              # Type checker (converts untyped -> typed)
├── type_def/           # Type sum type (9 variants)
├── parser/             # Creates untyped AST
├── scanner/            # Tokenizer for parser
├── token/              # Token types
├── span/               # Source location tracking
└── diagnostic/         # Error reporting
```

## Key Code Patterns

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
    // ... 21 more variants
```

**BlockItem bridging both types:**
```v
pub struct BlockItem {
pub:
    is_statement bool
    statement    Statement
    expression   Expression
}
```

**Type sum type (9 variants):**
```v
pub type Type = TypeArray
    | TypeBase
    | TypeEnum
    | TypeFunction
    | TypeOption
    | TypeResult
    | TypeStruct
    | TypeTuple
    | TypeVar
```

The full original source is at: https://github.com/alii/al
