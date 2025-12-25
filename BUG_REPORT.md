# Segfault with nested sum types when using -prod (-O3) on Linux x86_64

## Description

When using complex nested sum types (recursive Statement type, large Expression sum type with 27 variants, and BlockItem struct bridging both), the V compiler generates code that causes a segmentation fault when compiled with `-prod` (which enables `-O3`) on Linux x86_64.

The same code runs correctly:
- On macOS with `-prod`
- On Linux with debug builds (no optimization)
- On Linux with `-O2` (but NOT `-O3`)

## Minimal Reproduction

**Repository**: https://github.com/alii/v-nested-sumtype-repro

**CI showing the bug**: https://github.com/alii/v-nested-sumtype-repro/actions

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

The reproduction has been minimized to ~2550 lines across the source files.

### Key Findings

1. **Requires both parser AND type checker**: Neither component alone triggers the bug
   - Parser alone: ✅ Works
   - Type checker alone: ✅ Works
   - Parser + Type checker: ❌ **Segfault**

2. **Requires actual TypeEnv usage**: The bug does NOT trigger if:
   - TypeEnv struct exists but is never used
   - Only a single define() call is made

   The bug DOES trigger when:
   - Multiple define() calls are made to a `map[string]Type`
   - This happens during type checking of variable/function declarations

3. **Minimal type checker triggers it**: Even with:
   - No type inference or unification
   - No error checking
   - Just pure AST conversion from `ast.*` to `typed_ast.*`
   - Plus multiple `c.env.define(name, type)` calls

4. **The trigger appears to be**: The combination of:
   - Large match expressions (3 Statement variants, 13 Expression variants)
   - Two similar sum type hierarchies in different modules (ast and typed_ast)
   - Writes to a `map[string]Type` during match processing

5. **Sum type size matters**: The bug is sensitive to the number of variants:
   - With 12 Expression + 3 Statement variants: ✅ **Works** (no crash)
   - With 13 Expression + 3 Statement variants: ❌ **Segfault**
   - The threshold is exactly 13 Expression variants - adding just 1 more variant to a working 12-variant sum type triggers the bug

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

This appears to be a GCC `-O3` optimization bug specific to the generated C code for nested/recursive sum types combined with map writes. The workaround is to use `-O2` instead of `-O3` on Linux:

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
├── ast/ast.v           # Untyped AST (Statement 3 variants, Expression 13 variants)
├── typed_ast/          # Typed AST (mirrors untyped structure)
├── types/
│   ├── checker.v       # Minimal type checker (~194 lines)
│   └── environment.v   # Simple TypeEnv with map[string]Type (~18 lines)
├── type_def/           # Type sum type (just TypeNone)
├── parser/             # Creates untyped AST (~1078 lines)
├── scanner/            # Tokenizer for parser (~485 lines)
├── token/              # Token types
├── span/               # Source location tracking
└── diagnostic/         # Error reporting
```

## Minimal Type Checker That Triggers Bug

The type checker has been minimized to just:

```v
pub struct TypeEnv {
mut:
    bindings map[string]Type
}

pub fn (mut e TypeEnv) define(name string, t Type) {
    e.bindings[name] = t  // Writing to this map during match processing triggers the bug
}
```

And the check_statement function:
```v
fn (mut c TypeChecker) check_statement(stmt ast.Statement) typed_ast.Statement {
    match stmt {
        ast.VariableBinding {
            typed_init := c.check_expr(stmt.init)
            c.env.define(stmt.identifier.name, t_none())  // This triggers it
            return typed_ast.VariableBinding{ ... }
        }
        // ... other variants
    }
}
```

## Key Code Patterns

**Recursive Statement type (3 variants):**
```v
pub struct ExportDeclaration {
pub:
    declaration Statement  // Contains Statement (recursive)
    span        Span @[required]
}

pub type Statement = ExportDeclaration  // <- recursive reference
    | FunctionDeclaration
    | VariableBinding
```

**Expression sum type (13 variants - the threshold):**
```v
pub type Expression = ArrayExpression
    | BinaryExpression
    | BlockExpression
    | BooleanLiteral
    | ErrorNode
    | FunctionCallExpression
    | FunctionExpression
    | Identifier
    | IfExpression
    | NumberLiteral
    | PropertyAccessExpression
    | StringLiteral
    | UnaryExpression
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

The full original source is at: https://github.com/alii/al
